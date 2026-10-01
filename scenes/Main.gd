extends Node2D
## Main scene: loads the campus, builds a timetable, starts a run and shows a small HUD.
##
## The HUD here is a temporary control strip so the first version can be played with.
## The real ParamPanel and Dashboard (Siw's scenes in docs/ROADMAP.md) replace it.

const CAMPUS_PATH: String = "res://data/campus.json"
const UNITS_PATH: String = "res://data/units.json"
## Speeds offered by the speed buttons, in sim minutes per real second.
const SPEEDS: Array[float] = [5.0, 30.0, 120.0, 240.0]
const START_SPEED_INDEX: int = 1
## The run starts this long before the first class of Monday, so arrivals are visible.
const LEAD_IN_MINUTES: float = 60.0
const HUD_WIDTH_PX: float = 300.0

var _campus: Campus = Campus.new()
var _units: Array = []
var _students: Array[Student] = []
var _clock_label: Label
var _stats_label: Label
var _play_button: Button

@onready var _runner: SimRunner = $SimRunner
@onready var _map: MapView = $MapView


func _ready() -> void:
	if _campus.load_from_file(CAMPUS_PATH) != OK:
		push_error("Main: couldn't load the campus")
		return
	_units = TimetableGenerator.load_units(UNITS_PATH)
	_build_hud()
	_runner.playing_changed.connect(func(playing: bool) -> void: _play_button.text = "Pause" if playing else "Play")
	Params.set_value(&"sim_minutes_per_second", SPEEDS[START_SPEED_INDEX])
	_start_run()


func _process(_delta: float) -> void:
	if _runner.engine == null:
		return
	_clock_label.text = SimTime.format(_runner.engine.now)
	_stats_label.text = _stats_text()


## Builds a new timetable and run from the current Params.
func _start_run() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Params.random_seed
	var result: Dictionary = TimetableGenerator.new().generate(_campus, _units, rng)
	var sessions: Array[ClassSession] = result["sessions"]
	_students = result["students"]
	_map.setup(_campus, _students)
	_runner.start_run(_campus, sessions, _students, RuleDecision.new())
	_runner.engine.advance_to(SimTime.at(0, Params.day_start_hour) - LEAD_IN_MINUTES)


func _stats_text() -> String:
	var counts: Dictionary = {}
	var stress: float = 0.0
	var energy: float = 0.0
	var satisfaction: float = 0.0
	for student: Student in _students:
		counts[student.state] = int(counts.get(student.state, 0)) + 1
		stress += student.stress
		energy += student.energy
		satisfaction += student.satisfaction
	var total: float = maxf(1.0, float(_students.size()))
	return "\n".join([
		"Students: %d" % _students.size(),
		"  walking: %d" % counts.get(Student.State.TRAVELLING, 0),
		"  in class: %d" % counts.get(Student.State.IN_CLASS, 0),
		"  waiting: %d" % counts.get(Student.State.WAITING, 0),
		"  off campus: %d" % counts.get(Student.State.OFF_CAMPUS, 0),
		"",
		"Attended: %d (late %d)" % [Stats.attended, Stats.late],
		"Skipped: %d" % Stats.skipped,
		"Attendance: %.1f%%" % (Stats.attendance_rate() * 100.0),
		"Average minutes late: %.1f" % Stats.average_minutes_late(),
		"",
		"Average stress: %.1f" % (stress / total),
		"Average energy: %.1f" % (energy / total),
		"Average satisfaction: %.1f" % (satisfaction / total),
	])


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(HUD_WIDTH_PX, 0)
	layer.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "Monash University Malaysia"
	box.add_child(title)
	_clock_label = Label.new()
	box.add_child(_clock_label)

	var controls: HBoxContainer = HBoxContainer.new()
	box.add_child(controls)
	_play_button = _add_button(controls, "Play", _runner.toggle)
	_add_button(controls, "+1 hour", func() -> void: _runner.step(60.0))
	_add_button(controls, "New run", _on_new_run)

	var speeds: HBoxContainer = HBoxContainer.new()
	box.add_child(speeds)
	for speed: float in SPEEDS:
		_add_button(speeds, "%d min/s" % speed, func() -> void: Params.set_value(&"sim_minutes_per_second", speed))

	_stats_label = Label.new()
	box.add_child(_stats_label)
	var legend: Label = Label.new()
	legend.text = "Dots: blue walking, green in class, orange waiting"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(legend)


func _add_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


## Starts again with the next seed, so each new run has a different timetable.
func _on_new_run() -> void:
	Params.set_value(&"random_seed", Params.random_seed + 1)
	_start_run()
