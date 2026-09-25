class_name SimRunner
extends Node
## Drives a SimEngine in real time: play, pause, speed.
##
## Each frame advances the engine by delta * Params.sim_minutes_per_second.
## The engine itself knows nothing about frames, so tests and headless runs
## call engine.advance_to() / engine.run_to_end() directly instead.

signal playing_changed(is_playing: bool)

var engine: SimEngine = null
var is_playing: bool = false


## Builds a fresh engine for a new run. Call again (with new data) to restart.
func start_run(
	campus: Campus,
	sessions: Array[ClassSession],
	students: Array[Student],
	model: DecisionModel,
) -> void:
	engine = SimEngine.new()
	engine.setup(campus, sessions, students, model)
	pause()


func play() -> void:
	if engine == null or engine.is_finished():
		return
	_set_playing(true)


func pause() -> void:
	_set_playing(false)


func toggle() -> void:
	if is_playing:
		pause()
	else:
		play()


## Advances by a fixed number of sim minutes (for a "step" button).
func step(minutes: float) -> void:
	if engine != null:
		engine.advance_to(engine.now + minutes)


func _process(delta: float) -> void:
	if not is_playing or engine == null:
		return
	engine.advance_to(engine.now + delta * Params.sim_minutes_per_second)
	if engine.is_finished():
		pause()


func _set_playing(value: bool) -> void:
	if is_playing == value:
		return
	is_playing = value
	playing_changed.emit(is_playing)
