extends Node
## Renders fixed views of the 3D map to PNG files, so changes can be checked by eye.
##
## Run with a window (the renderer is needed, so not --headless):
##   godot --path . res://tools/Screenshot3D.tscn -- --out <folder> [--only overview,gate] [--sim]
##       [--students 5000] [--perf [--2d] [--low] [--paused]]
## --students sets the student count for --sim. --perf plays the sim in the 3D overview
## for PERF_SECONDS and prints the average frame rate instead of taking shots.
##
## With --sim it runs the real Main scene, switches to the 3D view and moves the clock
## to SIM_START so students are on the map. Without it, it shows the map on its own.
## Each shot: [focus pixel on the 2D map, camera yaw in degrees, distance in metres, minute of day
## (-1 keeps the sim clock), and optionally a building to look inside].

const MAP_SCENE: String = "res://scenes/map3d/MapView3D.tscn"
const MAIN_SCENE: String = "res://scenes/Main.tscn"
const SETTLE_FRAMES: int = 12
## The clock starts here, then moves a minute at a time until at least MIN_WALKING
## students are out walking (up to MAX_SEARCH_MINUTES), so the shot shows a crowd.
const SIM_START: float = 8.0 * 60.0 + 30.0
const MIN_WALKING: int = 40
const MAX_SEARCH_MINUTES: int = 240
const SPREAD_MINUTES: float = 1.0
const PERF_SECONDS: float = 8.0
const PERF_SPEED: float = 30.0
const SHOTS: Dictionary = {
	"overview": [Vector2(980.0, 430.0), 200.0, 520.0, 630.0],
	"campus": [Vector2(1010.0, 420.0), 215.0, 260.0, 600.0],
	"gate": [Vector2(1079.0, 228.0), 160.0, 95.0, 600.0],
	"canteen": [Vector2(983.0, 522.0), 10.0, 55.0, 750.0],
	"walkways": [Vector2(1050.0, 365.0), 80.0, 32.0, 640.0],
	"students": [Vector2(1110.0, 250.0), 150.0, 110.0, -1.0],
	"students_close": [Vector2(1130.0, 225.0), 120.0, 40.0, -1.0],
	"inside_b2": [Vector2(1000.0, 280.0), 200.0, 75.0, -1.0, &"B2"],
	"inside_canteen": [Vector2(895.0, 480.0), 270.0, 120.0, -1.0, &"B6"],
	"inside_library": [Vector2(945.0, 392.0), 200.0, 60.0, -1.0, &"B7"],
	"dusk": [Vector2(1000.0, 430.0), 205.0, 300.0, 1150.0],
	"night": [Vector2(1000.0, 430.0), 205.0, 300.0, 1290.0],
	"top": [Vector2(960.0, 450.0), 180.0, 650.0, 720.0],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = _arg(args, "--out", "user://screenshots")
	var only: PackedStringArray = _arg(args, "--only", "").split(",", false)
	DirAccess.make_dir_recursive_absolute(out_dir)
	if args.has("--students"):
		Params.set_value(&"student_count", int(_arg(args, "--students", "500")))
	var view: MapView3D = await _open_view(args.has("--sim") or args.has("--perf"))
	if args.has("--perf"):
		await _measure(view)
		get_tree().quit()
		return
	for name: String in SHOTS:
		if not only.is_empty() and not only.has(name):
			continue
		var shot: Array = SHOTS[name]
		if shot.size() > 4:
			view.look_inside(shot[4])
		else:
			view.clear_selection()
		view.camera_rig.set_view(view.world_point(shot[0]), shot[1], shot[2])
		if float(shot[3]) >= 0.0:
			view.day_night.apply_minute(shot[3])
		await _frames(SETTLE_FRAMES)
		var path: String = out_dir.path_join(name + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()


func _open_view(with_sim: bool) -> MapView3D:
	if not with_sim:
		var view: MapView3D = (load(MAP_SCENE) as PackedScene).instantiate()
		add_child(view)
		await _frames(SETTLE_FRAMES)
		return view
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(main)
	await _frames(SETTLE_FRAMES)
	main.call(&"show_3d", true)
	var runner: SimRunner = main.get_node(^"SimRunner")
	runner.step(SIM_START - SimTime.minute_of_day(runner.engine.now))
	var students: Array[Student] = main.get(&"_students")
	for minute: int in range(MAX_SEARCH_MINUTES):
		var walking: int = students.filter(func(s: Student) -> bool: return s.state == Student.State.TRAVELLING).size()
		if walking >= MIN_WALKING:
			print("walking: %d at %s" % [walking, SimTime.format(runner.engine.now)])
			break
		runner.step(1.0)
	# A few more minutes so the crowd spreads out along the paths.
	runner.step(SPREAD_MINUTES)
	await _frames(SETTLE_FRAMES)
	return main.get_node(^"MapView3D")


## Plays the simulation with the camera over the whole campus and prints the frame rate.
func _measure(view: MapView3D) -> void:
	var shot: Array = SHOTS["overview"]
	view.camera_rig.set_view(view.world_point(shot[0]), shot[1], shot[2])
	var runner: SimRunner = view.get_parent().get_node(^"SimRunner")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--2d"):
		view.get_parent().call(&"show_3d", false)
	if args.has("--low"):
		view.set_high_quality(false)
	Params.set_value(&"sim_minutes_per_second", PERF_SPEED)
	if not args.has("--paused"):
		runner.play()
	await _frames(30)
	var start_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	var worst_ms: float = 0.0
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() - start_ms < PERF_SECONDS * 1000.0:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, (now - last) / 1000.0)
		last = now
		frames += 1
	var seconds: float = (Time.get_ticks_msec() - start_ms) / 1000.0
	print("PERF students=%d frames=%d avg_fps=%.1f worst_frame_ms=%.1f sim=%s" % [
		Params.student_count, frames, frames / seconds, worst_ms, SimTime.format(runner.engine.now)])


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var index: int = args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback
