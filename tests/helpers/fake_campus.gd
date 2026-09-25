class_name FakeCampus
extends Campus
## Campus for tests: walking times are set directly instead of loaded from JSON.

var _minutes: Dictionary = {}  # "A>B" -> minutes


## Sets the walking time between two buildings (both directions).
func set_travel(a: StringName, b: StringName, minutes: float) -> void:
	_minutes["%s>%s" % [a, b]] = minutes
	_minutes["%s>%s" % [b, a]] = minutes


func travel_minutes(from_building: StringName, to_building: StringName) -> float:
	if from_building == to_building:
		return 0.0
	return float(_minutes.get("%s>%s" % [from_building, to_building], 0.0))
