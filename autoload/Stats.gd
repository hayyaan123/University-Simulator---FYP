extends Node
## Running statistics for the current run (autoload "Stats").
##
## Listens to EventBus and keeps counters the dashboard reads. Resets when a run starts.
## Add new metrics here (room use, crowding) rather than inside SimEngine.

var attended: int = 0
var late: int = 0
var total_minutes_late: float = 0.0
var skipped: int = 0
## reason -> count
var skipped_by_reason: Dictionary = {}
## unit_code -> {"attended": int, "skipped": int}
var by_unit: Dictionary = {}
## day index -> {"attended": int, "skipped": int}
var by_day: Dictionary = {}


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.student_attended.connect(_on_student_attended)
	EventBus.student_skipped.connect(_on_student_skipped)


func reset() -> void:
	attended = 0
	late = 0
	total_minutes_late = 0.0
	skipped = 0
	skipped_by_reason.clear()
	by_unit.clear()
	by_day.clear()


func attendance_rate() -> float:
	var total: int = attended + skipped
	return 0.0 if total == 0 else float(attended) / float(total)


func average_minutes_late() -> float:
	return 0.0 if late == 0 else total_minutes_late / float(late)


## Plain dictionary of the headline numbers, for the dashboard and CSV logs.
func snapshot() -> Dictionary:
	return {
		"attended": attended,
		"skipped": skipped,
		"attendance_rate": attendance_rate(),
		"late": late,
		"average_minutes_late": average_minutes_late(),
		"skipped_by_reason": skipped_by_reason.duplicate(),
	}


func _on_run_started(_seed: int) -> void:
	reset()


func _on_student_attended(_student: Student, session: ClassSession, minutes_late: float, is_late: bool) -> void:
	attended += 1
	if is_late:
		late += 1
		total_minutes_late += minutes_late
	_bump(by_unit, session.unit_code, "attended")
	_bump(by_day, session.day(), "attended")


func _on_student_skipped(_student: Student, session: ClassSession, reason: StringName) -> void:
	skipped += 1
	skipped_by_reason[reason] = int(skipped_by_reason.get(reason, 0)) + 1
	_bump(by_unit, session.unit_code, "skipped")
	_bump(by_day, session.day(), "skipped")


func _bump(table: Dictionary, key: Variant, field: String) -> void:
	if not table.has(key):
		table[key] = {"attended": 0, "skipped": 0}
	table[key][field] += 1
