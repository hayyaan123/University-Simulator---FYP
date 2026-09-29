"""Build data/campus.json for Monash University Malaysia from an OpenStreetMap extract.

Usage:
    python tools/build_campus_from_osm.py data/osm/monash_malaysia.osm data/campus.json

The extract was downloaded from the OpenStreetMap API (bbox 101.5980,3.0615,101.6030,3.0665).
Map data (c) OpenStreetMap contributors, available under the Open Database Licence (ODbL).

What the script does:
1. Picks the campus buildings we simulate (BUILDINGS below) and keeps other buildings
   in the area as grey scenery.
2. Builds the walking network from OSM footways, steps, service roads and streets.
3. Joins each building to the network, and joins buildings whose outlines touch with
   an "indoor" link, because most Monash Malaysia buildings are connected inside.
4. Merges chains of path points into single links (keeping the points for drawing).
5. Converts metres to map pixels for the 1600 x 900 viewport.

Rooms are NOT in OpenStreetMap. ROOMS below are placeholders until the team replaces
them with real room lists.
"""

from __future__ import annotations

import argparse
import heapq
import json
import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

# OSM way id -> (our id, display name, kind). Kinds: teaching, library, link, sports,
# transport, residence, parking.
BUILDINGS: dict[str, tuple[str, str, str]] = {
    "775138187": ("B2", "Building 2", "teaching"),
    "210994219": ("B3", "Building 3", "teaching"),
    "775138182": ("B4", "Building 4", "teaching"),
    "775138185": ("B5", "Building 5", "teaching"),
    "775138184": ("B5A", "Building 5A", "teaching"),
    "775138190": ("B6", "Building 6", "teaching"),
    "775138189": ("B6B", "Building 6B", "teaching"),
    "775138186": ("B9", "Building 9", "teaching"),
    "775138191": ("B7", "Library (Building 7)", "library"),
    "1008780195": ("LINK", "Link Deck", "link"),
    "210994230": ("SPORTS", "Monash Sports Centre", "sports"),
    "428126740": ("SB5", "SunU-Monash BRT station", "transport"),
    "775152608": ("RES", "Sunway Waterfront Residence", "residence"),
    "210994255": ("CARPARK", "Monash University Parking", "parking"),
}
ENTRANCE = "SB5"
ENTRANCES = ["SB5", "CARPARK", "RES"]

# Placeholder rooms per teaching building: (type, count, capacity).
ROOMS: dict[str, list[tuple[str, int, int]]] = {
    "B2": [("lecture_hall", 2, 250), ("tutorial_room", 6, 35)],
    "B3": [("lecture_hall", 1, 200), ("tutorial_room", 6, 35), ("lab", 2, 40)],
    "B4": [("tutorial_room", 6, 35), ("lab", 2, 40)],
    "B5": [("lecture_hall", 1, 300), ("tutorial_room", 6, 35)],
    "B5A": [("tutorial_room", 4, 35), ("lab", 2, 40)],
    "B6": [("lecture_hall", 2, 180), ("tutorial_room", 8, 35)],
    "B6B": [("tutorial_room", 4, 35), ("lab", 2, 40)],
    "B9": [("lecture_hall", 1, 220), ("tutorial_room", 6, 35), ("lab", 4, 40)],
}
ROOM_PREFIX = {"lecture_hall": "LT", "tutorial_room": "T", "lab": "LAB"}

WALKABLE = {
    "footway", "steps", "service", "cycleway", "residential", "pedestrian",
    "unclassified", "tertiary", "secondary", "secondary_link", "path", "living_street",
}
ORIGIN_LAT, ORIGIN_LON = 3.0639, 101.6005
METRES_PER_DEG_LAT = 110_574.0
METRES_PER_DEG_LON = 111_320.0 * math.cos(math.radians(ORIGIN_LAT))
ROI_MARGIN_M = 35.0            # walking network kept this far around the chosen buildings
DOOR_REACH_M = 12.0            # path points this close to an outline count as a way in
INDOOR_GAP_M = 6.0             # outlines closer than this are treated as connected inside
VIEW_RECT = (40.0, 30.0, 1560.0, 870.0)  # pixel area the map is fitted into


@dataclass
class Graph:
    pos: dict[str, tuple[float, float]] = field(default_factory=dict)
    adj: dict[str, dict[str, dict]] = field(default_factory=dict)

    def add_edge(self, a: str, b: str, dist: float, indoor: bool = False, points=None) -> None:
        if a == b:
            return
        old = self.adj.setdefault(a, {}).get(b)
        if old is not None and old["d"] <= dist:
            return
        self.adj.setdefault(b, {})
        edge = {"d": dist, "indoor": indoor, "points": points or []}
        self.adj[a][b] = edge
        self.adj[b][a] = {"d": dist, "indoor": indoor, "points": list(reversed(points or []))}


def to_metres(lat: float, lon: float) -> tuple[float, float]:
    return ((lon - ORIGIN_LON) * METRES_PER_DEG_LON, (lat - ORIGIN_LAT) * METRES_PER_DEG_LAT)


def dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def seg_dist(p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
    ax, ay, bx, by = a[0], a[1], b[0], b[1]
    dx, dy = bx - ax, by - ay
    if dx == dy == 0:
        return dist(p, a)
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / (dx * dx + dy * dy)))
    return dist(p, (ax + t * dx, ay + t * dy))


def inside(p: tuple[float, float], poly: list[tuple[float, float]]) -> bool:
    x, y, hit = p[0], p[1], False
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def poly_dist(p: tuple[float, float], poly: list[tuple[float, float]]) -> float:
    if inside(p, poly):
        return 0.0
    return min(seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def outline_gap(a: list[tuple[float, float]], b: list[tuple[float, float]]) -> float:
    return min(min(poly_dist(p, b) for p in a), min(poly_dist(p, a) for p in b))


def centroid(poly: list[tuple[float, float]]) -> tuple[float, float]:
    area = cx = cy = 0.0
    for i in range(len(poly)):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % len(poly)]
        cross = x1 * y2 - x2 * y1
        area += cross
        cx += (x1 + x2) * cross
        cy += (y1 + y2) * cross
    if abs(area) < 1e-9:
        return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
    return (cx / (3 * area), cy / (3 * area))


def load_osm(path: str):
    root = ET.parse(path).getroot()
    nodes = {n.get("id"): to_metres(float(n.get("lat")), float(n.get("lon"))) for n in root.iter("node")}
    ways = []
    for w in root.iter("way"):
        tags = {t.get("k"): t.get("v") for t in w.iter("tag")}
        refs = [nd.get("ref") for nd in w.iter("nd") if nd.get("ref") in nodes]
        ways.append((w.get("id"), tags, refs))
    return nodes, ways


def reachable(graph: Graph, start: str) -> set[str]:
    seen, stack = {start}, [start]
    while stack:
        for nxt in graph.adj.get(stack.pop(), {}):
            if nxt not in seen:
                seen.add(nxt)
                stack.append(nxt)
    return seen


def build(osm_path: str) -> dict:
    nodes, ways = load_osm(osm_path)
    outlines: dict[str, list[tuple[float, float]]] = {}
    levels: dict[str, int] = {}
    scenery: list[list[tuple[float, float]]] = []
    for wid, tags, refs in ways:
        pts = [nodes[r] for r in refs]
        if pts and pts[0] == pts[-1]:
            pts = pts[:-1]
        if wid in BUILDINGS:
            bid = BUILDINGS[wid][0]
            outlines[bid] = pts
            levels[bid] = int(tags.get("building:levels", "1"))
        elif "building" in tags and len(pts) >= 3:
            scenery.append(pts)
    missing = [v[0] for k, v in BUILDINGS.items() if v[0] not in outlines]
    if missing:
        raise SystemExit(f"Buildings missing from the extract: {missing}")

    all_pts = [p for poly in outlines.values() for p in poly]
    min_x = min(p[0] for p in all_pts) - ROI_MARGIN_M
    max_x = max(p[0] for p in all_pts) + ROI_MARGIN_M
    min_y = min(p[1] for p in all_pts) - ROI_MARGIN_M
    max_y = max(p[1] for p in all_pts) + ROI_MARGIN_M

    def in_roi(p: tuple[float, float]) -> bool:
        return min_x <= p[0] <= max_x and min_y <= p[1] <= max_y

    graph = Graph()
    for wid, tags, refs in ways:
        if tags.get("highway") not in WALKABLE:
            continue
        for a, b in zip(refs, refs[1:]):
            pa, pb = nodes[a], nodes[b]
            if in_roi(pa) and in_roi(pb):
                graph.pos[a], graph.pos[b] = pa, pb
                graph.add_edge(a, b, dist(pa, pb))

    path_nodes = list(graph.pos)
    for bid, poly in outlines.items():
        c = centroid(poly)
        graph.pos[bid] = c
        near = sorted(path_nodes, key=lambda n: poly_dist(graph.pos[n], poly))
        doors = [n for n in near if poly_dist(graph.pos[n], poly) <= DOOR_REACH_M] or near[:1]
        for n in doors[:4]:
            graph.add_edge(bid, n, dist(c, graph.pos[n]))

    ids = list(outlines)
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            if outline_gap(outlines[a], outlines[b]) <= INDOOR_GAP_M:
                graph.add_edge(a, b, dist(graph.pos[a], graph.pos[b]), indoor=True)

    keep = reachable(graph, ENTRANCE)
    unreached = [b for b in ids if b not in keep]
    if unreached:
        raise SystemExit(f"Buildings not connected to {ENTRANCE}: {unreached}")
    graph.pos = {k: v for k, v in graph.pos.items() if k in keep}
    graph.adj = {k: {n: e for n, e in v.items() if n in keep} for k, v in graph.adj.items() if k in keep}

    simplify(graph, set(ids))
    return to_json(graph, outlines, levels, scenery, (min_x, min_y, max_x, max_y))


def simplify(graph: Graph, fixed: set[str]) -> None:
    """Removes path points that only join two links, keeping their positions for drawing."""
    changed = True
    while changed:
        changed = False
        for n in list(graph.adj):
            if n in fixed or n not in graph.adj or len(graph.adj[n]) != 2:
                continue
            (a, ea), (b, eb) = graph.adj[n].items()
            if a == b or b in graph.adj[a]:
                continue
            points = list(reversed(ea["points"])) + [graph.pos[n]] + eb["points"]
            # ea goes n -> a, so its points run from n towards a; reverse for a -> n.
            del graph.adj[a][n], graph.adj[b][n], graph.adj[n]
            graph.add_edge(a, b, ea["d"] + eb["d"], ea["indoor"] and eb["indoor"], points)
            changed = True
    graph.pos = {k: v for k, v in graph.pos.items() if k in graph.adj}


def to_json(graph: Graph, outlines, levels, scenery, roi) -> dict:
    min_x, min_y, max_x, max_y = roi
    left, top, right, bottom = VIEW_RECT
    scale = min((right - left) / (max_x - min_x), (bottom - top) / (max_y - min_y))
    off_x = left + ((right - left) - (max_x - min_x) * scale) / 2
    off_y = top + ((bottom - top) - (max_y - min_y) * scale) / 2

    def px(p: tuple[float, float]) -> list[float]:
        return [round(off_x + (p[0] - min_x) * scale, 1), round(off_y + (max_y - p[1]) * scale, 1)]

    def in_view(poly) -> bool:
        return all(min_x <= p[0] <= max_x and min_y <= p[1] <= max_y for p in poly)

    names = {v[0]: v for v in BUILDINGS.values()}
    waypoint_ids = {n: f"W{i}" for i, n in enumerate(sorted(n for n in graph.pos if n not in outlines))}
    rename = lambda n: n if n in outlines else waypoint_ids[n]  # noqa: E731

    buildings = []
    for bid, poly in outlines.items():
        _, name, kind = names[bid]
        buildings.append({
            "id": bid, "name": name, "kind": kind, "levels": levels[bid],
            "position": px(graph.pos[bid]), "outline": [px(p) for p in poly],
        })
    rooms = []
    for bid, specs in ROOMS.items():
        for room_type, count, capacity in specs:
            for i in range(1, count + 1):
                rid = f"{bid}-{ROOM_PREFIX[room_type]}{i}"
                rooms.append({"id": rid, "building": bid, "capacity": capacity, "type": room_type})
    paths, seen = [], set()
    for a, edges in graph.adj.items():
        for b, e in edges.items():
            key = tuple(sorted((a, b)))
            if key in seen:
                continue
            seen.add(key)
            path = {"from": rename(a), "to": rename(b), "distance_m": round(e["d"], 1)}
            if e["indoor"]:
                path["indoor"] = True
            if e["points"]:
                path["points"] = [px(p) for p in e["points"]]
            paths.append(path)
    return {
        "name": "Monash University Malaysia",
        "source": "Map data (c) OpenStreetMap contributors, ODbL. Built by tools/build_campus_from_osm.py. Rooms are placeholders.",
        "metres_per_pixel": round(1.0 / scale, 4),
        "entrance": ENTRANCE,
        "entrances": ENTRANCES,
        "buildings": buildings,
        "waypoints": [{"id": waypoint_ids[n], "position": px(graph.pos[n])} for n in sorted(waypoint_ids, key=waypoint_ids.get)],
        "rooms": rooms,
        "paths": paths,
        "scenery": [[px(p) for p in poly] for poly in scenery if in_view(poly)],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("osm", help="OpenStreetMap XML extract")
    parser.add_argument("out", help="campus.json to write")
    args = parser.parse_args()
    data = build(args.osm)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")
    print(f"{len(data['buildings'])} buildings, {len(data['waypoints'])} waypoints, "
          f"{len(data['paths'])} paths, {len(data['rooms'])} rooms -> {args.out}")


if __name__ == "__main__":
    main()
