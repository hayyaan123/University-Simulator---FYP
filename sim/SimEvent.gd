class_name SimEvent
extends RefCounted
## One scheduled event in the simulation.
##
## Events are ordered by time. Events at the same time keep the order they were
## scheduled in (seq), so every run with the same seed gives the same result.

enum Type {
	DAY_START,       ## A new day begins; students plan their first class.
	CLASS_START,     ## A class session begins.
	CLASS_END,       ## A class session ends; students inside decide what to do next.
	STUDENT_DECIDE,  ## A student chooses what to do about their next class (and leaves if attending).
	STUDENT_ARRIVE,  ## A student reaches the building of the class they walked to.
}

var time: float
var type: Type
## Id of the student or class session this event is about (-1 if none).
var subject_id: int
## Extra data, e.g. {"session_id": 12}.
var payload: Dictionary
## Set by EventQueue when scheduled. Breaks ties between events at the same time.
var seq: int = -1


func _init(p_time: float, p_type: Type, p_subject_id: int = -1, p_payload: Dictionary = {}) -> void:
	time = p_time
	type = p_type
	subject_id = p_subject_id
	payload = p_payload


## True if this event should be processed before `other`.
func precedes(other: SimEvent) -> bool:
	if time != other.time:
		return time < other.time
	return seq < other.seq
