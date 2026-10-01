class_name StateEffects
extends RefCounted
## The determinants table: how each thing a student does or experiences moves
## their stress, energy and satisfaction (docs/STUDENT_MODEL.md).
##
## This is the only place that changes those three states. Each state is moved
## by events, never by another state. Grades are not in this table: nothing changes
## grades directly, they are measured from the hours a student puts into a unit.
##
## To add a determinant: add an event name and a row to EFFECTS, give every number
## a source, emit it from the engine with apply(), and add the row to the docs.

const STATE_MIN: float = 0.0
const STATE_MAX: float = 100.0

# PLACEHOLDER starting values. Each needs a source or a stated assumption (Arya).
const START_STRESS: float = 0.0
const START_ENERGY: float = 100.0
## Midpoint, so satisfaction can move either way.
const START_SATISFACTION: float = 50.0
## Resilience of a student made without the timetable generator (tests). The
## generator draws each student's value around Params.resilience.
const DEFAULT_RESILIENCE: float = 70.0

## Per hour sitting in a class.
const ATTENDED_CLASS_HOUR: StringName = &"attended_class_hour"
## Per hour of study in free time.
const STUDIED_HOUR: StringName = &"studied_hour"
## Once per class the student chose not to go to.
const SKIPPED_CLASS: StringName = &"skipped_class"
## Once per arrival after the late grace period, including too late to enter.
const ARRIVED_LATE: StringName = &"arrived_late"
## Once per day per deadline that is close.
const DEADLINE_NEAR: StringName = &"deadline_near"
## Per minute of the trip to campus.
const COMMUTED_MINUTE: StringName = &"commuted_minute"
## Per hour the first class starts before a normal start time.
const EARLY_START_HOUR: StringName = &"early_start_hour"
## Per minute walked between buildings.
const WALKED_MINUTE: StringName = &"walked_minute"
## Once per food stop in free time.
const FOOD_STOP: StringName = &"food_stop"
## Per day of a break (mid-semester, between semesters).
const BREAK_DAY: StringName = &"break_day"
## Once per class the student could not enter because the room was full.
const TURNED_AWAY: StringName = &"turned_away"
## Per minute queueing at a food outlet.
const QUEUED_MINUTE: StringName = &"queued_minute"
## Once per class that starts with no break after the one before it.
const BACK_TO_BACK_CLASS: StringName = &"back_to_back_class"

## event -> {state: change per unit of the event}.
## PLACEHOLDER numbers: only the direction of each effect is agreed. Each number
## needs a source or a stated assumption before the results are reported (Arya).
const EFFECTS: Dictionary = {
	ATTENDED_CLASS_HOUR: {&"stress": 0.5, &"energy": -8.0},
	STUDIED_HOUR: {&"energy": -6.0},
	SKIPPED_CLASS: {&"energy": 4.0},
	ARRIVED_LATE: {&"stress": 1.0, &"satisfaction": -1.0},
	DEADLINE_NEAR: {&"stress": 2.0},
	COMMUTED_MINUTE: {&"energy": -0.1, &"satisfaction": -0.02},
	EARLY_START_HOUR: {&"energy": -5.0},
	WALKED_MINUTE: {&"energy": -0.2},
	FOOD_STOP: {&"energy": 20.0, &"satisfaction": 1.0},
	BREAK_DAY: {&"stress": -3.0, &"energy": 5.0, &"satisfaction": 1.0},
	TURNED_AWAY: {&"stress": 1.0, &"satisfaction": -3.0},
	QUEUED_MINUTE: {&"satisfaction": -0.2},
	BACK_TO_BACK_CLASS: {&"stress": 0.5, &"energy": -1.0},
}


## Applies one row of the table to a student. `amount` is how much of the event
## happened (hours, minutes, or 1 for a one-off). States stay within 0 to 100.
static func apply(student: Student, event: StringName, amount: float = 1.0) -> void:
	assert(EFFECTS.has(event), "StateEffects: unknown event '%s'" % event)
	var changes: Dictionary = EFFECTS[event]
	for state: StringName in changes:
		var value: float = float(student.get(state)) + float(changes[state]) * amount
		student.set(state, clampf(value, STATE_MIN, STATE_MAX))


## Overnight recovery: energy is back to full at the start of each day.
## Stress and satisfaction carry over.
static func start_day(student: Student) -> void:
	student.energy = START_ENERGY
	student.last_class_end = -INF
