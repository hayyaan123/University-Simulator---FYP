class_name Student
extends RefCounted
## One simulated student.
##
## Holds the student's timetable, where they are, what they are doing, and the
## attributes that decision models read (motivation, tiredness, history).

enum State {
	OFF_CAMPUS,  ## Not on campus.
	WAITING,     ## On campus, between classes or waiting for a class to start.
	TRAVELLING,  ## Walking between buildings.
	IN_CLASS,    ## Inside a class session.
}

var id: int
var year: int = 1
## This student's sessions for the week, sorted by start time.
var timetable: Array[ClassSession] = []
var state: State = State.OFF_CAMPUS
## Building the student is in (or last left while travelling).
var location: StringName = &""
## Session the student is walking to or sitting in (null if none).
var target_session: ClassSession = null

## 0..1. Lower motivation makes skipping more likely (used by decision models).
var motivation: float = 1.0
## 0..1. Rises with walking and long days.
var tiredness: float = 0.0

var attended_count: int = 0
var late_count: int = 0
var skipped_count: int = 0


func _init(p_id: int, p_year: int = 1) -> void:
	id = p_id
	year = p_year


## Sets the timetable and sorts it by start time.
func set_timetable(sessions: Array[ClassSession]) -> void:
	timetable = sessions.duplicate()
	timetable.sort_custom(func(a: ClassSession, b: ClassSession) -> bool: return a.start < b.start)


## First session that starts at or after `time`, or null.
func next_session(time: float) -> ClassSession:
	for session: ClassSession in timetable:
		if session.start >= time:
			return session
	return null


## First session that starts at or after `time` on the same day, or null.
func next_session_today(time: float) -> ClassSession:
	var session: ClassSession = next_session(time)
	if session != null and session.day() == SimTime.day_of(time):
		return session
	return null


## All of this student's sessions on a given day (0 = Monday), in order.
func sessions_on_day(day: int) -> Array[ClassSession]:
	var result: Array[ClassSession] = []
	for session: ClassSession in timetable:
		if session.day() == day:
			result.append(session)
	return result


func attendance_rate() -> float:
	var total: int = attended_count + skipped_count
	return 1.0 if total == 0 else float(attended_count) / float(total)
