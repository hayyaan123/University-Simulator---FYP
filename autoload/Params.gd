extends Node
## Global simulation parameters (autoload "Params").
##
## Values are read when a run starts, so change them and restart the run to see
## the effect. SPECS drives validation, the parameter panel and scenario files.
## To add a parameter: add a typed var below AND an entry in SPECS.

signal changed(key: StringName, value: Variant)
signal scenario_loaded(path: String)

## key -> {min, max, step, label, group}. Order here is the order shown in the UI.
const SPECS: Dictionary = {
	&"student_count": {"min": 50, "max": 5000, "step": 50, "label": "Students", "group": "Population"},
	&"unit_count": {"min": 5, "max": 60, "step": 1, "label": "Units", "group": "Population"},
	&"units_per_student": {"min": 1, "max": 6, "step": 1, "label": "Units per student", "group": "Population"},
	&"lecture_minutes": {"min": 30, "max": 180, "step": 10, "label": "Lecture length (min)", "group": "Timetable"},
	&"tutorial_minutes": {"min": 30, "max": 180, "step": 10, "label": "Tutorial length (min)", "group": "Timetable"},
	&"slot_gap_minutes": {"min": 0, "max": 30, "step": 5, "label": "Gap between slots (min)", "group": "Timetable"},
	&"day_start_hour": {"min": 6, "max": 12, "step": 1, "label": "Day starts (hour)", "group": "Timetable"},
	&"day_end_hour": {"min": 14, "max": 22, "step": 1, "label": "Day ends (hour)", "group": "Timetable"},
	&"days_to_simulate": {"min": 1, "max": 7, "step": 1, "label": "Days to simulate", "group": "Timetable"},
	&"room_capacity_multiplier": {"min": 0.5, "max": 1.5, "step": 0.05, "label": "Room capacity x", "group": "Campus"},
	&"walking_speed_m_per_min": {"min": 40.0, "max": 120.0, "step": 5.0, "label": "Walking speed (m/min)", "group": "Campus"},
	&"crowding_strength": {"min": 0.0, "max": 1.0, "step": 0.05, "label": "Crowding strength", "group": "Campus"},
	&"arrival_buffer_minutes": {"min": 0.0, "max": 15.0, "step": 1.0, "label": "Leave early by (min)", "group": "Behaviour"},
	&"late_grace_minutes": {"min": 0.0, "max": 15.0, "step": 1.0, "label": "Late after (min)", "group": "Behaviour"},
	&"skip_threshold_minutes": {"min": 5.0, "max": 60.0, "step": 5.0, "label": "Too late to enter (min)", "group": "Behaviour"},
	&"base_attendance_chance": {"min": 0.3, "max": 1.0, "step": 0.01, "label": "Base attendance chance", "group": "Behaviour"},
	&"sim_minutes_per_second": {"min": 0.5, "max": 240.0, "step": 0.5, "label": "Sim minutes per second", "group": "Run"},
	&"random_seed": {"min": 0, "max": 2147483647, "step": 1, "label": "Random seed", "group": "Run"},
}

var student_count: int = 500
var unit_count: int = 20
var units_per_student: int = 4
var lecture_minutes: int = 120
var tutorial_minutes: int = 60
var slot_gap_minutes: int = 10
var day_start_hour: int = 8
var day_end_hour: int = 18
var days_to_simulate: int = 5
var room_capacity_multiplier: float = 1.0
var walking_speed_m_per_min: float = 80.0
var crowding_strength: float = 0.3
var arrival_buffer_minutes: float = 5.0
var late_grace_minutes: float = 5.0
var skip_threshold_minutes: float = 20.0
var base_attendance_chance: float = 0.85
var sim_minutes_per_second: float = 5.0
var random_seed: int = 42

var _defaults: Dictionary = {}


func _init() -> void:
	_defaults = to_dict()


func has_param(key: StringName) -> bool:
	return SPECS.has(key)


func get_value(key: StringName) -> Variant:
	assert(has_param(key), "Unknown parameter: %s" % key)
	return get(key)


## Sets a parameter, clamped to its range. Returns false for unknown keys.
func set_value(key: StringName, value: Variant) -> bool:
	if not has_param(key):
		push_warning("Params: unknown parameter '%s'" % key)
		return false
	var spec: Dictionary = SPECS[key]
	var current: Variant = get(key)
	var clamped: Variant
	if typeof(current) == TYPE_INT:
		clamped = clampi(int(value), int(spec.min), int(spec.max))
	else:
		clamped = clampf(float(value), float(spec.min), float(spec.max))
	if clamped == current:
		return true
	set(key, clamped)
	changed.emit(key, clamped)
	return true


func reset_to_defaults() -> void:
	from_dict(_defaults)


func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in SPECS:
		result[String(key)] = get(key)
	return result


## Applies every known key in `data`. Unknown keys are ignored with a warning.
func from_dict(data: Dictionary) -> void:
	for key: Variant in data:
		set_value(StringName(str(key)), data[key])


## Saves the current parameters as a scenario file (JSON).
func save_scenario(path: String, scenario_name: String = "") -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"name": scenario_name, "params": to_dict()}, "\t"))
	return OK


## Loads a scenario file. Missing keys keep their current values.
func load_scenario(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("params"):
		push_error("Params: bad scenario file %s" % path)
		return ERR_PARSE_ERROR
	from_dict(parsed["params"])
	scenario_loaded.emit(path)
	return OK
