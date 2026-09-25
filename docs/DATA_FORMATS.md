# Data formats

All data files are JSON with tab indentation and live in `data/`. Ids are strings and are loaded as `StringName`.

## campus.json

```json
{
	"entrance": "ENTRANCE",
	"buildings": [
		{ "id": "ENTRANCE", "name": "Main Gate", "position": [80, 450] },
		{ "id": "B1", "name": "Building 1", "position": [320, 300] },
		{ "id": "B2", "name": "Building 2", "position": [600, 520] }
	],
	"rooms": [
		{ "id": "B1-LT1", "building": "B1", "capacity": 250, "type": "lecture_hall" },
		{ "id": "B2-201", "building": "B2", "capacity": 30, "type": "tutorial_room" },
		{ "id": "B2-LAB1", "building": "B2", "capacity": 40, "type": "lab" }
	],
	"paths": [
		{ "from": "ENTRANCE", "to": "B1", "distance_m": 260 },
		{ "from": "B1", "to": "B2", "distance_m": 340 }
	]
}
```

| Field | Rules |
| --- | --- |
| `entrance` | Must be a building id. Students enter and leave campus here. |
| `buildings[].position` | Map position in pixels (viewport is 1600 × 900). |
| `rooms[].type` | `lecture_hall`, `tutorial_room` or `lab` |
| `paths` | Undirected. Distance is the walking distance in metres, not the straight line. Every building must be reachable from the entrance. |

## units.json

```json
{
	"units": [
		{ "code": "FIT1045", "name": "Introduction to Programming", "year": 1,
		  "enrolment": 220, "lectures_per_week": 1, "tutorials_per_week": 1, "labs_per_week": 0 }
	]
}
```

The timetable generator reads this file along with `Params` (lecture and tutorial lengths, day start and end, slot gap, `units_per_student`, `student_count`). If `Params.unit_count` is smaller than the file, it uses the first N units.

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
	"features": ["expected_minutes_late", "motivation", "tiredness", "minute_of_day"],
	"scaler": { "mean": [2.1, 0.8, 0.3, 720.0], "std": [4.0, 0.15, 0.2, 180.0] },
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
	"features": ["attendance_rate", "year", "motivation"],
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
