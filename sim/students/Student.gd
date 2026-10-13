class_name Student
extends RefCounted
## One simulated student.
##
## Holds the student's timetable, where they are, what they are doing, and the
## states that the determinants move (stress, energy) and that decision models
## read. See docs/STUDENT_MODEL.md.

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

## 0..100. Academic pressure. Changed only by StateEffects.
var stress: float = StateEffects.START_STRESS
## 0..100. Drains with class hours and walking; back to full each morning.
var energy: float = StateEffects.START_ENERGY
## Minutes this student travels to reach campus.
var commute_minutes: float = 0.0

## Hours of class attended so far, per unit. Grades are measured from these.
var hours_attended: Dictionary = {}  # StringName unit code -> float
## Hours of study in free time so far, per unit.
var hours_studied: Dictionary = {}   # StringName unit code -> float
## Assessment marks so far, per unit, with each assessment's weight.
var marks: Dictionary = {}           # StringName unit code -> Array of float
var mark_weights: Dictionary = {}    # StringName unit code -> Array of float
## Units this student takes, in timetable order. Set with the timetable.
var unit_codes: Array[StringName] = []
## When the student sat down in the class they are in now.
var joined_class_at: float = 0.0
## When the last class they attended today ended (-INF if none yet).
var last_class_end: float = -INF

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
	unit_codes.clear()
	for session: ClassSession in timetable:
		if not unit_codes.has(session.unit_code):
			unit_codes.append(session.unit_code)


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


## Adds time sat in a class to the unit's total.
func add_hours_attended(unit_code: StringName, hours: float) -> void:
	hours_attended[unit_code] = float(hours_attended.get(unit_code, 0.0)) + hours


## Class hours plus study hours for a unit. Assessment marks come from this.
func hours_put_in(unit_code: StringName) -> float:
	return float(hours_attended.get(unit_code, 0.0)) + float(hours_studied.get(unit_code, 0.0))


## Records the mark for one assessment of a unit.
func add_mark(unit_code: StringName, mark: float, weight: float) -> void:
	if not marks.has(unit_code):
		marks[unit_code] = []
		mark_weights[unit_code] = []
	marks[unit_code].append(mark)
	mark_weights[unit_code].append(weight)


## Grade (0 to 100) for one unit from the assessments marked so far. Grades.NO_GRADE if none yet.
func unit_grade(unit_code: StringName) -> float:
	return Grades.unit_grade(marks.get(unit_code, []), mark_weights.get(unit_code, []))


## The grades state: the average grade over the units that have a mark. Grades.NO_GRADE if none yet.
func grade() -> float:
	var total: float = 0.0
	for unit_code: StringName in marks:
		total += unit_grade(unit_code)
	return Grades.NO_GRADE if marks.is_empty() else total / float(marks.size())


func attendance_rate() -> float:
	var total: int = attended_count + skipped_count
	return 1.0 if total == 0 else float(attended_count) / float(total)
