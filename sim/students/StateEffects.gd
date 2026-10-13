class_name StateEffects
extends RefCounted
## The determinants table: how each thing a student does or experiences moves
## their stress and energy (docs/STUDENT_MODEL.md).
##
## This is the only place that changes those two states. Each state is moved
## by events, never by another state. Grades are not in this table: nothing changes
## grades directly, they are measured from the hours a student puts into a unit
## (see Grades).
##
## Every size is fixed for a run and the same for every student. Each effect is a
## straight line: one more unit of the event always moves the state by the same
## amount, until the state reaches 0 or 100. The reasoning and the source for each
## number are in "Effect sizes" in docs/STUDENT_MODEL.md.
##
## To add a determinant: add an event name and a row to EFFECTS, give every number
## a source, emit it from the engine with apply(), and add the row to the docs.

const STATE_MIN: float = 0.0
const STATE_MAX: float = 100.0

## A semester starts with no academic pressure.
const START_STRESS: float = 0.0
## A rested student. Energy is back to this every morning.
const START_ENERGY: float = 100.0

## Energy one hour of activity costs. Assumption: ten active hours with no break,
## the length of the default teaching day (08:00 to 18:00), empty a rested student.
const ENERGY_PER_ACTIVE_HOUR: float = -10.0
## Stress one hour of academic work adds. Assumption: a default workload (about
## 24 hours a week on campus over 12 weeks) adds about 30 points over a semester.
const STRESS_PER_WORK_HOUR: float = 0.1

## Per hour sitting in a class.
const ATTENDED_CLASS_HOUR: StringName = &"attended_class_hour"
## Per hour of study in free time.
const STUDIED_HOUR: StringName = &"studied_hour"
## Once per class the student chose not to go to.
const SKIPPED_CLASS: StringName = &"skipped_class"
## Once per arrival after the late grace period, including too late to enter.
const ARRIVED_LATE: StringName = &"arrived_late"
## Once per day per deadline that is near (FixedSettings.DEADLINE_NEAR_DAYS).
const DEADLINE_NEAR: StringName = &"deadline_near"
## Per minute of the trip to campus.
const COMMUTED_MINUTE: StringName = &"commuted_minute"
## Per hour the first class starts before a normal start time.
const EARLY_START_HOUR: StringName = &"early_start_hour"
## Per minute walked between buildings.
const WALKED_MINUTE: StringName = &"walked_minute"
## Once per food stop in free time. Every outlet has the same effect.
const FOOD_STOP: StringName = &"food_stop"
## Per day of a break (mid-semester, between semesters).
const BREAK_DAY: StringName = &"break_day"
## Once per class the student sits in a room that is over its capacity.
const OVERCROWDED_ROOM: StringName = &"overcrowded_room"
## Once per class that starts with no break after the one before it.
const BACK_TO_BACK_CLASS: StringName = &"back_to_back_class"

## event -> {state: change per unit of the event}.
const EFFECTS: Dictionary = {
	# An hour of class and an hour of study are the same academic work.
	ATTENDED_CLASS_HOUR: {&"stress": STRESS_PER_WORK_HOUR, &"energy": ENERGY_PER_ACTIVE_HOUR},
	STUDIED_HOUR: {&"stress": STRESS_PER_WORK_HOUR, &"energy": ENERGY_PER_ACTIVE_HOUR},
	# Assumption: a skipped class is rest, worth half an active hour.
	SKIPPED_CLASS: {&"energy": 5.0},
	# Assumption: the unit that the other one-off stress events are sized against.
	ARRIVED_LATE: {&"stress": 1.0},
	# Stress builds through the semester and peaks around assessments (Pitt et al.
	# 2018). Sized so that 12 deadlines, each near for 7 days, add about 40 points.
	DEADLINE_NEAR: {&"stress": 0.5},
	# Travel is active time: 10 an hour, the same as class.
	COMMUTED_MINUTE: {&"energy": ENERGY_PER_ACTIVE_HOUR / 60.0},
	# Students slept about an hour less before 08:00 classes, and attendance was
	# about 10 percentage points lower (Yeo et al. 2023). With RuleDecision's skip
	# curve, 25 an hour gives that 10-point drop at the default commute.
	EARLY_START_HOUR: {&"energy": -25.0},
	WALKED_MINUTE: {&"energy": ENERGY_PER_ACTIVE_HOUR / 60.0},
	# Breaks reduce fatigue and raise vigour, more so the longer the break
	# (Albulescu et al. 2022). Assumption: a meal gives back two active hours and
	# takes off half the stress of arriving late.
	FOOD_STOP: {&"stress": -0.5, &"energy": 20.0},
	# Time off improves well-being, and the gain fades once work resumes (de Bloom
	# et al. 2009). Assumption: a 7-day break takes off about 20 points. Energy needs
	# no number: there is no commute or class on a break day.
	BREAK_DAY: {&"stress": -3.0},
	# Arousal rises as people are packed closer together (Beermann and Sieben 2023).
	# Assumption: three times the stress of arriving late, and a slight energy cost.
	OVERCROWDED_ROOM: {&"stress": 3.0, &"energy": -2.0},
	# Stress builds across back-to-back sessions and resets with a 10-minute break
	# (Microsoft Human Factors Lab 2021). Assumption: half the stress of arriving late.
	BACK_TO_BACK_CLASS: {&"stress": 0.5, &"energy": -2.0},
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
## Stress carries over.
static func start_day(student: Student) -> void:
	student.energy = START_ENERGY
	student.last_class_end = -INF
