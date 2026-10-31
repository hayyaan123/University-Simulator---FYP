# Data formats

All data files are JSON with tab indentation and live in `data/`. Ids are strings and are loaded as `StringName`.

## campus.json

`data/campus.json` is Monash University Malaysia, generated from OpenStreetMap by `tools/build_campus_from_osm.py` (map data © OpenStreetMap contributors, ODbL). To change the map, change the script or the OSM extract in `data/osm/` and run it again rather than editing the JSON by hand. Rooms are placeholders until we have real room lists.

```json
{
	"name": "Monash University Malaysia",
	"source": "Map data (c) OpenStreetMap contributors, ODbL. ...",
	"metres_per_pixel": 0.4994,
	"entrance": "SB5",
	"entrances": ["SB5", "CARPARK", "RES"],
	"buildings": [
		{ "id": "B2", "name": "Building 2", "kind": "teaching", "levels": 7,
		  "position": [1001.3, 283.5], "outline": [[930.4, 270.1], [1003.2, 270.9], ...] }
	],
	"waypoints": [
		{ "id": "W0", "position": [352.1, 604.8] }
	],
	"rooms": [
		{ "id": "B2-LT1", "building": "B2", "capacity": 250, "type": "lecture_hall" },
		{ "id": "B2-T1", "building": "B2", "capacity": 35, "type": "tutorial_room" }
	],
	"paths": [
		{ "from": "W96", "to": "B2", "distance_m": 49.9 },
		{ "from": "B9", "to": "B2", "distance_m": 49.6, "indoor": true },
		{ "from": "W3", "to": "W7", "distance_m": 88.2, "points": [[1100.5, 180.2], [1120.0, 176.4]] }
	],
	"scenery": [[[420.0, 40.0], [472.0, 40.0], [472.0, 81.0], [420.0, 81.0]]]
}
```

| Field | Rules |
| --- | --- |
| `entrance` | Must be a building id. Students enter and leave campus here. |
| `entrances` | Every place students can arrive at (BRT station, car park, residence). The first one is `entrance`. Used later for the commute mix. |
| `buildings[].kind` | `teaching`, `library`, `link`, `sports`, `transport`, `residence` or `parking`. |
| `buildings[].levels` | Floors, from OpenStreetMap where known. For the 3D version later. |
| `buildings[].position` | Map position in pixels (viewport is 1600 × 900). This is where the building joins the path network. |
| `buildings[].outline` | Building footprint in pixels, for drawing. |
| `waypoints` | Path junctions. They are graph nodes like buildings, but have no rooms. |
| `rooms[].type` | `lecture_hall`, `tutorial_room` or `lab` |
| `paths` | Undirected links between buildings or waypoints. `distance_m` is the walking distance in metres along the path, not the straight line. `indoor: true` marks a link through connected buildings. `points` are the bends between the two ends, in pixels, for drawing. Every building must be reachable from the entrance. |
| `scenery` | Outlines of other buildings in the area. Drawn only. |

## campus_ground.json

The ground layer for the 3D map, generated with campus.json by `tools/build_campus_from_osm.py ... --ground data/campus_ground.json`. Same pixel frame and `metres_per_pixel` as campus.json, so the two line up. Don't edit it by hand.

```json
{
	"metres_per_pixel": 0.4994,
	"bounds": [417.8, -104.0, 1530.7, 1003.0],
	"roads": [
		{ "kind": "secondary", "width_m": 6.6, "points": [[639.0, 145.6], [981.4, 148.7]] },
		{ "kind": "bus_guideway", "width_m": 8.0, "layer": 2, "bridge": true, "points": [...] },
		{ "kind": "footway", "width_m": 2.5, "covered": true, "points": [...] }
	],
	"areas": [ { "kind": "pitch", "sport": "soccer", "name": "MPC1", "outline": [[...]] } ],
	"buildings": [ { "kind": "retail", "levels": 2, "outline": [[...]] } ]
}
```

| Field | Rules |
| --- | --- |
| `bounds` | The OSM extract's bounding box in pixels: left, top, right, bottom. Pixels may be outside the 1600 × 900 view |
| `roads[].kind` | The OSM `highway` value. `width_m` comes from `width`, then `lanes` × 3.3 m, then a default per kind |
| `roads[].layer`, `bridge`, `covered` | From OSM. Bridges are raised 5 m per layer in 3D; covered paths get a roof |
| `areas[].kind` | `water`, `pool`, `pitch`, `wood`, `parking`, `campus`, `school`, `residential`, `industrial` or `grass`. Big areas come first |
| `buildings` | Every building in the extract that is not a campus building. `levels` is 0 when OSM has none |

## campus_3d.json

Hand-edited looks for the 3D map: what OpenStreetMap doesn't know. Sources and assumptions are in `docs/MAP_3D.md`.

| Key | Meaning |
| --- | --- |
| `styles` | Named facade styles: colours (`"#rrggbb"`), `floor_height`, `bay_width`, window `sill`/`head` (fractions of a floor), `pier_every`, `base_height`, `lit_fraction` |
| `kind_styles`, `scenery_styles` | Which style each campus building kind / OSM building kind uses |
| `scenery_default_levels` | Floors for scenery buildings when OSM has none |
| `buildings.<id>` | Per campus building: `levels`, `base_m` (raised on columns), `roof` (`flat`, `green`, `canopy`), `glass_towers` (pixel positions), `open_ground_floor` (`"through"` = open passage on columns; `true`, a side such as `"north"` or a list = covered walkway on those sides), `interior` (`rooms`, `canteen`, `library`), `flat` (`parking`: not extruded) |
| `landmarks` | `{id, scene, position_px, facing_deg, clear_radius_m}`: a scene placed on the map; props keep `clear_radius_m` away |

## units.json

```json
{
	"units": [
		{ "code": "FIT1045", "name": "Introduction to Programming", "year": 1,
		  "enrolment": 220, "lectures_per_week": 1, "tutorials_per_week": 1, "labs_per_week": 0 }
	]
}
```

The timetable generator reads this file along with `Params` (lecture and tutorial lengths, day start and end, slot gap, `units_per_student`, `student_count`). It uses every unit in the file. `enrolment` is used as a weight when students pick units, and `year` makes students more likely to pick units from their own year level. The current `data/units.json` is a placeholder list that still needs checking against the Monash handbook.

## Scenario files (data/scenarios/*.json)

A saved set of parameters. Keys match `Params.SPECS`, and missing keys keep their current value.

```json
{ "name": "Default week", "params": { "student_count": 500, "random_seed": 42 } }
```

Save and load them with `Params.save_scenario(path, name)` and `Params.load_scenario(path)`.

## Run logs (Semester 2)

Written to `user://logs/<run_id>/` by the run logger. The column names are chosen so they can be matched to OULAD and UCI later.

**decisions.csv**: one row per `EventBus.student_decided`

| Column | From |
| --- | --- |
| `run_id`, `seed`, `model` | run info |
| `student_id` | Student |
| every key of `DecisionContext.to_features()` | features, in that order |
| `action` | `ATTEND_NEXT` / `SKIP_NEXT` / `LEAVE_CAMPUS` |

**outcomes.csv**: one row per `student_attended` or `student_skipped`

`run_id, student_id, session_id, unit_code, day, outcome (on_time|late|skipped), minutes_late, reason`

## ML model files (Semester 2, ml/*.json)

Trained in Python (`tools/`) and loaded by `MLDecision.gd`. `features` lists the `DecisionContext.to_features()` keys, in the order the model expects.

**Logistic regression**
```json
{
	"type": "logistic_regression",
	"name": "attend_v1",
	"features": ["expected_minutes_late", "energy", "stress", "minute_of_day"],
	"scaler": { "mean": [2.1, 75.0, 10.0, 720.0], "std": [4.0, 15.0, 8.0, 180.0] },
	"weights": [-0.42, 2.3, -1.1, -0.05],
	"bias": 0.7,
	"positive_class": "ATTEND_NEXT",
	"trained_on": "OULAD + sim logs 2027-03-10"
}
```
Prediction: `p = sigmoid(bias + Σ weights[i] * (x[i] - mean[i]) / std[i])`

**Decision tree** (random forest = `"type": "random_forest"` with a `"trees"` list of these node lists, votes averaged)
```json
{
	"type": "decision_tree",
	"name": "dropout_risk_v1",
	"features": ["attendance_rate", "year", "satisfaction"],
	"classes": ["low", "high"],
	"nodes": [
		{ "feature": 0, "threshold": 0.62, "left": 1, "right": 2 },
		{ "leaf": true, "value": [0.2, 0.8] },
		{ "leaf": true, "value": [0.9, 0.1] }
	]
}
```
Go `left` when `x[feature] <= threshold`. `value` holds the class probabilities in `classes` order.

Any change to a format must be made in the same PR as the code that reads it, and this file must be updated too.
