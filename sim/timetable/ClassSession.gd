class_name ClassSession
extends RefCounted
## One scheduled class (a lecture, tutorial or lab) in a room at a fixed time.
##
## Created by the timetable generator. Times are absolute simulation minutes (see SimTime).

enum Kind { LECTURE, TUTORIAL, LAB }

var id: int
var unit_code: StringName
var kind: Kind
var room_id: StringName
var building_id: StringName
var start: float
var duration: float
## Seats in the room (after Params.room_capacity_multiplier is applied).
var capacity: int
## Students enrolled in this session.
var enrolled_ids: Array[int] = []
## Students currently inside. Filled on arrival, cleared when the class ends.
var present_ids: Array[int] = []

var end: float:
	get:
		return start + duration


func _init(
	p_id: int,
	p_unit_code: StringName,
	p_kind: Kind,
	p_room_id: StringName,
	p_building_id: StringName,
	p_start: float,
	p_duration: float,
	p_capacity: int = 0,
) -> void:
	id = p_id
	unit_code = p_unit_code
	kind = p_kind
	room_id = p_room_id
	building_id = p_building_id
	start = p_start
	duration = p_duration
	capacity = p_capacity


func day() -> int:
	return SimTime.day_of(start)


func _to_string() -> String:
	return "%s %s @ %s %s" % [unit_code, Kind.keys()[kind], room_id, SimTime.format(start)]
