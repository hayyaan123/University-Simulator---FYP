class_name DecisionContext
extends RefCounted
## What a student knows when making a decision. Built by SimEngine.
##
## Decision models (rules now, ML later) read only from this and from Student,
## so the same features are available to every model and can be logged for training.

## Current simulation time (minutes from Monday 00:00).
var now: float
## The next class the student is enrolled in today (never null when a decision is asked for).
var next_session: ClassSession
## Minutes from now until next_session starts (negative if it has already started).
var minutes_until_start: float
## Walking time from the student's current building to next_session's building.
var travel_minutes: float
## How late the student would be if they left right now (0 if on time).
var expected_minutes_late: float
## Classes left today, including next_session.
var sessions_left_today: int
## Classes already attended today.
var attended_today: int


func _init(
	p_now: float,
	p_next_session: ClassSession,
	p_travel_minutes: float,
	p_sessions_left_today: int,
	p_attended_today: int,
) -> void:
	now = p_now
	next_session = p_next_session
	minutes_until_start = p_next_session.start - p_now
	travel_minutes = p_travel_minutes
	expected_minutes_late = maxf(0.0, p_now + p_travel_minutes - p_next_session.start)
	sessions_left_today = p_sessions_left_today
	attended_today = p_attended_today


## Flat feature dictionary for logging and ML models. Keep keys stable once data is collected.
func to_features(student: Student) -> Dictionary:
	return {
		"minute_of_day": SimTime.minute_of_day(now),
		"day": SimTime.day_of(now),
		"minutes_until_start": minutes_until_start,
		"travel_minutes": travel_minutes,
		"expected_minutes_late": expected_minutes_late,
		"sessions_left_today": sessions_left_today,
		"attended_today": attended_today,
		"session_kind": next_session.kind,
		"session_duration": next_session.duration,
		"year": student.year,
		"motivation": student.motivation,
		"tiredness": student.tiredness,
		"attendance_rate": student.attendance_rate(),
	}
