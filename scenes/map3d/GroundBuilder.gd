class_name GroundBuilder
extends RefCounted
## Builds the ground of the 3D map from campus_ground.json: grass, land areas, water,
## roads with markings, raised roads (the BRT guideway, motorway ramps) on pillars, and
## covered walkways.

## How high one OSM layer lifts a bridge, in metres. Assumption: the BRT guideway
## (layer 2) runs about 10 m up, which matches photos of the SunU-Monash station.
const LAYER_HEIGHT_M: float = 5.0
## Length of the slope where a bridge comes down to the ground.
const RAMP_M: float = 45.0
const DECK_THICKNESS_M: float = 0.9
const PARAPET_M: float = 0.9
const PILLAR_SPACING_M: float = 24.0
const CANOPY_HEIGHT_M: float = 3.1
const CANOPY_POST_SPACING_M: float = 7.0

## Area kind -> [colour, pattern, height above ground]. Pattern values: see ground.gdshader.
const AREA_LOOK: Dictionary = {
	"residential": [Color("93aa72"), 0.25, 0.010],
	"industrial": [Color("a7a9a3"), 0.0, 0.010],
	"school": [Color("8fb06c"), 0.25, 0.012],
	"campus": [Color("c4bcad"), 0.5, 0.020],
	"grass": [Color("86b05f"), 0.25, 0.022],
	"wood": [Color("5f8a43"), 0.25, 0.025],
	"parking": [Color("6c6f72"), 0.75, 0.030],
	"pool": [Color("4cb6d4"), 0.0, 0.034],
	"pitch": [Color("5c9a4e"), 0.0, 0.040],
}
## Pitch colours by sport.
const PITCH_LOOK: Dictionary = {
	"soccer": Color("4f8f47"), "basketball": Color("b9643f"),
}
const BASE_GRASS: Color = Color("7fab58")
## Road kind -> [colour, markings (see road.gdshader), height above ground].
const ROAD_LOOK: Dictionary = {
	"motorway": [Color("46494e"), 1.0, 0.060], "motorway_link": [Color("46494e"), 0.5, 0.060],
	"trunk": [Color("46494e"), 1.0, 0.060], "primary": [Color("47494e"), 1.0, 0.060],
	"secondary": [Color("484b50"), 1.0, 0.060], "secondary_link": [Color("484b50"), 0.5, 0.060],
	"tertiary": [Color("4b4e53"), 1.0, 0.058], "residential": [Color("515459"), 1.0, 0.056],
	"unclassified": [Color("515459"), 0.5, 0.056], "living_street": [Color("56595d"), 0.0, 0.056],
	"service": [Color("5a5d61"), 0.0, 0.052], "bus_guideway": [Color("55585c"), 0.5, 0.060],
	"pedestrian": [Color("c9b9a4"), 0.0, 0.070], "footway": [Color("bf7a5e"), 0.0, 0.072],
	"path": [Color("b9a07f"), 0.0, 0.072], "steps": [Color("b8ada0"), 0.0, 0.074],
	"cycleway": [Color("9c5f50"), 0.0, 0.071],
}
const GUIDEWAY_PILLAR: Color = Color("2f6db3")
## Only wide roads get a centre line.
const CENTRE_LINE_MIN_WIDTH_M: float = 6.0

var _frame: MapFrame
var _bank: MaterialBank
var _bounds: Rect2  # ground-plane metres
var _bridge_ends: PackedVector2Array = PackedVector2Array()


func _init(frame: MapFrame, bank: MaterialBank) -> void:
	_frame = frame
	_bank = bank


## Builds everything into one node. `data` is the parsed campus_ground.json.
func build(data: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Ground"
	var b: Array = data.get("bounds", [0, 0, 1600, 900])
	var top_left: Vector2 = _frame.to_plane(Vector2(b[0], b[1]))
	var bottom_right: Vector2 = _frame.to_plane(Vector2(b[2], b[3]))
	_bounds = Rect2(top_left, bottom_right - top_left).abs()
	root.add_child(_build_base())
	root.add_child(_build_areas(data.get("areas", [])))
	root.add_child(_build_water(data.get("areas", [])))
	_collect_bridge_ends(data.get("roads", []))
	root.add_child(_build_roads(data.get("roads", [])))
	root.add_child(_build_bridges(data.get("roads", [])))
	root.add_child(_build_canopies(data.get("roads", [])))
	return root


## Ground-plane bounds of the whole map, in metres.
func bounds() -> Rect2:
	return _bounds


func _build_base() -> MeshInstance3D:
	var st: SurfaceTool = _begin(BASE_GRASS, 0.25)
	# A skirt beyond the data bounds so the edge of the map isn't a hard line.
	var r: Rect2 = _bounds.grow(400.0)
	var outline: PackedVector2Array = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	MeshKit.add_cap(st, outline, 0.0)
	return _finish(st, _bank.ground, "Grass")


func _build_areas(areas: Array) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for area: Dictionary in areas:
		var kind: String = area["kind"]
		if not AREA_LOOK.has(kind):
			continue
		var look: Array = AREA_LOOK[kind]
		var color: Color = look[0]
		if kind == "pitch":
			color = PITCH_LOOK.get(area.get("sport", ""), Color("86b863"))
		st.set_color(Color(color, look[1]))
		var outline: PackedVector2Array = _frame.to_plane_points(MapFrame.points_from_json(area["outline"]))
		MeshKit.add_cap(st, outline, look[2])
	return _finish(st, _bank.ground, "Areas")


func _build_water(areas: Array) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for area: Dictionary in areas:
		if area["kind"] == "water":
			var outline: PackedVector2Array = _frame.to_plane_points(MapFrame.points_from_json(area["outline"]))
			MeshKit.add_cap(st, outline, 0.03)
	return _finish(st, _bank.water, "Water")


func _build_roads(roads: Array) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var order: int = 0
	for road: Dictionary in roads:
		if road.get("bridge", false):
			continue
		var look: Array = ROAD_LOOK.get(road["kind"], ROAD_LOOK["service"])
		var width: float = float(road["width_m"])
		var marks: float = look[1]
		if marks > 0.75 and width < CENTRE_LINE_MIN_WIDTH_M:
			marks = 0.5
		st.set_color(Color(look[0], marks))
		var points: PackedVector2Array = _frame.to_plane_points(MapFrame.points_from_json(road["points"]))
		# A tiny lift per road keeps overlapping junctions from flickering.
		order += 1
		MeshKit.add_ribbon(st, points, width, float(look[2]) + order * 0.00005)
	return _finish(st, _bank.road, "Roads")


func _build_bridges(roads: Array) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Bridges"
	var deck: SurfaceTool = SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: SurfaceTool = SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pillars: Array[Transform3D] = []
	var blue_pillars: Array[Transform3D] = []
	for road: Dictionary in roads:
		if not road.get("bridge", false):
			continue
		var points: PackedVector2Array = _frame.to_plane_points(MapFrame.points_from_json(road["points"]))
		var lift: float = maxf(1.0, float(road.get("layer", 1))) * LAYER_HEIGHT_M
		var heights: PackedFloat32Array = _ramp_heights(points, lift)
		var width: float = float(road["width_m"])
		var look: Array = ROAD_LOOK.get(road["kind"], ROAD_LOOK["service"])
		deck.set_color(Color(look[0], minf(float(look[1]), 0.5)))
		MeshKit.add_ribbon(deck, points, width, 0.0, heights)
		_add_deck_sides(sides, points, width, heights)
		var target: Array[Transform3D] = blue_pillars if road["kind"] == "bus_guideway" else pillars
		target.append_array(_pillar_transforms(points, width, heights))
	root.add_child(_finish(deck, _bank.road, "Decks"))
	root.add_child(_finish(sides, _bank.concrete, "DeckSides"))
	root.add_child(_pillars(pillars, _bank.concrete, "Pillars"))
	var blue: StandardMaterial3D = StandardMaterial3D.new()
	blue.albedo_color = GUIDEWAY_PILLAR
	blue.roughness = 0.6
	root.add_child(_pillars(blue_pillars, blue, "GuidewayPillars"))
	return root


## Side walls, underside and parapets of a raised deck.
func _add_deck_sides(st: SurfaceTool, points: PackedVector2Array, width: float, heights: PackedFloat32Array) -> void:
	var edges: Array[PackedVector2Array] = MeshKit.ribbon_edges(points, width)
	for side: int in range(2):
		var edge: PackedVector2Array = edges[side]
		for i: int in range(edge.size() - 1):
			var a: Vector2 = edge[i]
			var b: Vector2 = edge[i + 1]
			var out2: Vector2 = (edge[i] - points[i]).normalized()
			var normal: Vector3 = Vector3(out2.x, 0.0, out2.y)
			var a_top: float = heights[i] + PARAPET_M
			var b_top: float = heights[i + 1] + PARAPET_M
			var a_low: float = maxf(0.0, heights[i] - DECK_THICKNESS_M)
			var b_low: float = maxf(0.0, heights[i + 1] - DECK_THICKNESS_M)
			var a0: Vector3 = Vector3(a.x, a_low, a.y)
			var b0: Vector3 = Vector3(b.x, b_low, b.y)
			var a1: Vector3 = Vector3(a.x, a_top, a.y)
			var b1: Vector3 = Vector3(b.x, b_top, b.y)
			MeshKit.add_tri(st, a0, b0, b1, normal)
			MeshKit.add_tri(st, a0, b1, a1, normal)
	# Underside, so the deck doesn't look hollow from a low camera.
	var low: PackedFloat32Array = PackedFloat32Array()
	for h: float in heights:
		low.append(maxf(0.0, h - DECK_THICKNESS_M))
	var under: SurfaceTool = st
	for i: int in range(points.size() - 1):
		var l0: Vector3 = Vector3(edges[0][i].x, low[i], edges[0][i].y)
		var r0: Vector3 = Vector3(edges[1][i].x, low[i], edges[1][i].y)
		var l1: Vector3 = Vector3(edges[0][i + 1].x, low[i + 1], edges[0][i + 1].y)
		var r1: Vector3 = Vector3(edges[1][i + 1].x, low[i + 1], edges[1][i + 1].y)
		MeshKit.add_tri(under, l0, r0, r1, Vector3.DOWN)
		MeshKit.add_tri(under, l0, r1, l1, Vector3.DOWN)


## Bridge height at each point: full height in the middle, sloping down at any end that
## meets the ground (not at ends that join another bridge or leave the map).
func _ramp_heights(points: PackedVector2Array, lift: float) -> PackedFloat32Array:
	var total: float = MeshKit.polyline_length(points)
	var start_low: bool = _end_meets_ground(points[0])
	var end_low: bool = _end_meets_ground(points[points.size() - 1])
	var ramp: float = minf(RAMP_M, total * 0.5)
	var heights: PackedFloat32Array = PackedFloat32Array()
	var along: float = 0.0
	for i: int in range(points.size()):
		if i > 0:
			along += points[i - 1].distance_to(points[i])
		var k: float = 1.0
		if start_low:
			k = minf(k, smoothstep(0.0, ramp, along))
		if end_low:
			k = minf(k, smoothstep(0.0, ramp, total - along))
		heights.append(lift * k)
	return heights


func _end_meets_ground(p: Vector2) -> bool:
	var edge_gap: float = minf(minf(p.x - _bounds.position.x, _bounds.end.x - p.x),
		minf(p.y - _bounds.position.y, _bounds.end.y - p.y))
	if edge_gap < 2.0:
		return false
	var touching: int = 0
	for q: Vector2 in _bridge_ends:
		if q.distance_to(p) < 1.5:
			touching += 1
	# Its own end is in the list once; any more means another bridge joins here.
	return touching <= 1


func _collect_bridge_ends(roads: Array) -> void:
	_bridge_ends.clear()
	for road: Dictionary in roads:
		if road.get("bridge", false):
			var points: PackedVector2Array = _frame.to_plane_points(MapFrame.points_from_json(road["points"]))
			_bridge_ends.append(points[0])
			_bridge_ends.append(points[points.size() - 1])


func _pillar_transforms(points: PackedVector2Array, width: float, heights: PackedFloat32Array) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var total: float = MeshKit.polyline_length(points)
	for sample: Dictionary in MeshKit.sample_polyline(points, PILLAR_SPACING_M):
		var p: Vector2 = sample["point"]
		var h: float = _height_at(points, heights, p) - DECK_THICKNESS_M
		if h < 3.0 or total < 10.0:
			continue
		var dir: Vector2 = sample["dir"]
		var thickness: float = clampf(width * 0.35, 1.0, 2.2)
		var basis: Basis = Basis(Vector3.UP, atan2(dir.x, dir.y)).scaled(Vector3(width * 0.55, h, thickness))
		result.append(Transform3D(basis, Vector3(p.x, h * 0.5, p.y)))
	return result


func _height_at(points: PackedVector2Array, heights: PackedFloat32Array, p: Vector2) -> float:
	var best: float = INF
	var result: float = 0.0
	for i: int in range(points.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		var d: float = closest.distance_to(p)
		if d < best:
			best = d
			var seg: float = points[i].distance_to(points[i + 1])
			var t: float = 0.0 if seg <= 0.0 else points[i].distance_to(closest) / seg
			result = lerpf(heights[i], heights[i + 1], t)
	return result


## Roofs over covered footways (the canopy walkways), on thin posts.
func _build_canopies(roads: Array) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Canopies"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var posts: Array[Transform3D] = []
	for road: Dictionary in roads:
		if not road.get("covered", false):
			continue
		var points: PackedVector2Array = _frame.to_plane_points(MapFrame.points_from_json(road["points"]))
		var base: float = 0.0
		if road.get("bridge", false):
			base = maxf(1.0, float(road.get("layer", 1))) * LAYER_HEIGHT_M
		var width: float = float(road["width_m"]) + 1.2
		MeshKit.add_ribbon(st, points, width, base + CANOPY_HEIGHT_M)
		MeshKit.add_ribbon(st, points, width, base + CANOPY_HEIGHT_M - 0.15)
		for sample: Dictionary in MeshKit.sample_polyline(points, CANOPY_POST_SPACING_M):
			var p: Vector2 = sample["point"]
			var dir: Vector2 = sample["dir"]
			var side: Vector2 = Vector2(-dir.y, dir.x) * (width * 0.5 - 0.2)
			for s: float in [1.0, -1.0]:
				var q: Vector2 = p + side * s
				var basis: Basis = Basis().scaled(Vector3(0.15, CANOPY_HEIGHT_M, 0.15))
				posts.append(Transform3D(basis, Vector3(q.x, base + CANOPY_HEIGHT_M * 0.5, q.y)))
	var roof_mesh: MeshInstance3D = _finish(st, _bank.steel, "CanopyRoofs")
	roof_mesh.material_override = _bank.steel
	root.add_child(roof_mesh)
	root.add_child(_pillars(posts, _bank.steel, "CanopyPosts"))
	return root


func _pillars(transforms: Array[Transform3D], material: Material, node_name: String) -> MultiMeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


func _begin(color: Color, pattern: float) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(color, pattern))
	return st


static func _finish(st: SurfaceTool, material: Material, node_name: String) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.material_override = material
	return instance
