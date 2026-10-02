class_name Assessment
extends RefCounted
## One assessment of a unit: where a student's grade for the unit is measured.
##
## Created by AssessmentPlanner. It is due at the end of its due week.

var id: int
var unit_code: StringName
## Teaching week it is due in (1 = the first week). Due at the end of that week.
var due_week: int
## Share of the unit grade. A unit's weights add up to 1.
var weight: float


func _init(p_id: int, p_unit_code: StringName, p_due_week: int, p_weight: float) -> void:
	id = p_id
	unit_code = p_unit_code
	due_week = p_due_week
	weight = p_weight


## Day index (0 = the first Monday) of the midnight the assessment is due at.
func due_day() -> int:
	return due_week * SimTime.DAYS_PER_WEEK


func _to_string() -> String:
	return "%s assessment due week %d (%.0f%%)" % [unit_code, due_week, weight * 100.0]
