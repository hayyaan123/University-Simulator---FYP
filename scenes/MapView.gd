class_name MapView
extends Node2D
## Draws the campus and every student on it.
##
## Listens to EventBus only and never changes the simulation. Students are drawn with
## one MultiMesh (one dot per student), so thousands of students stay cheap to draw.
## A walking student moves along the real footpath route from Campus.path_points(),
## timed by the departure and arrival times the engine reports.

const COLOR_BACKGROUND: Color = Color("eef2ef")
const COLOR_SCENERY: Color = Color("d9dedb")
const COLOR_PATH: Color = Color("b9c4bf")
const COLOR_INDOOR_PATH: Color = Color("c9b8d6")
const COLOR_OUTLINE: Color = Color("50605a")
const COLOR_LABEL: Color = Color("17201d")
const BUILDING_COLORS: Dictionary = {
	&"teaching": Color("9cc3dc"),
	&"library": Color("a8d5b5"),
	&"link": Color("c9b8d6"),
	&"sports": Color("ecd98f"),
	&"transport": Color("eeb0a8"),
	&"residence": Color("f2cf9c"),
	&"parking": Color("cfd3d1"),
}
const STATE_COLORS: Dictionary = {
	Student.State.WAITING: Color("d98e04"),
	Student.State.TRAVELLING: Color("1f5fbf"),
	Student.State.IN_CLASS: Color("1f8f5c"),
}
const DOT_SIZE_PX: float = 5.0
## Spacing of the spots inside a building where waiting or seated students are drawn.
const SPOT_SPACING_PX: float = 5.0
const LABEL_FONT_SIZE: int = 13

var _campus: Campus
var _students: Array[Student] = []
var _now: float = 0.0
## student id -> {points: PackedVector2Array, lengths: PackedFloat32Array, start: float, end: float}
var _walks: Dictionary = {}
## building id -> PackedVector2Array of spots inside its outline
var _spots: Dictionary = {}
var _dots: MultiMeshInstance2D


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.sim_time_changed.connect(_on_sim_time_changed)
	EventBus.student_departed.connect(_on_student_departed)
	_dots = MultiMeshInstance2D.new()
	_dots.texture = _make_dot_texture()
	add_child(_dots)


## Call once per run, after the timetable is built.
func setup(campus: Campus, students: Array[Student]) -> void:
	_campus = campus
	_students = students
	_walks.clear()
	_spots.clear()
	for id: StringName in campus.building_ids():
		_spots[id] = _spots_inside(campus.building_outline(id), campus.building_position(id))
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(DOT_SIZE_PX, DOT_SIZE_PX)
	multimesh.mesh = quad
	multimesh.instance_count = students.size()
	_dots.multimesh = multimesh
	queue_redraw()


func _process(_delta: float) -> void:
	if _campus == null or _dots.multimesh == null:
		return
	var multimesh: MultiMesh = _dots.multimesh
	for i: int in range(_students.size()):
		var student: Student = _students[i]
		var walking: bool = _walks.has(student.id)
		if walking and _now >= _walks[student.id]["end"]:
			_walks.erase(student.id)
			walking = false
		if walking:
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, _walk_position(_walks[student.id])))
			multimesh.set_instance_color(i, STATE_COLORS[Student.State.TRAVELLING])
		elif student.state == Student.State.OFF_CAMPUS:
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
		else:
			var spot: Vector2 = _spot_for(student)
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, spot))
			multimesh.set_instance_color(i, STATE_COLORS.get(student.state, COLOR_OUTLINE))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BACKGROUND)
	if _campus == null:
		return
	for outline: PackedVector2Array in _campus.scenery_outlines():
		draw_colored_polygon(outline, COLOR_SCENERY)
	for path: Dictionary in _campus.paths_for_drawing():
		var points: PackedVector2Array = path["points"]
		if path["indoor"]:
			for i: int in range(points.size() - 1):
				draw_dashed_line(points[i], points[i + 1], COLOR_INDOOR_PATH, 2.0, 6.0)
		else:
			draw_polyline(points, COLOR_PATH, 3.0, true)
	var font: Font = ThemeDB.fallback_font
	for id: StringName in _campus.building_ids():
		var outline: PackedVector2Array = _campus.building_outline(id)
		if outline.size() >= 3:
			draw_colored_polygon(outline, BUILDING_COLORS.get(_campus.building_kind(id), COLOR_SCENERY))
			var closed: PackedVector2Array = outline.duplicate()
			closed.append(outline[0])
			draw_polyline(closed, COLOR_OUTLINE, 1.0, true)
		draw_string(font, _campus.building_position(id) + Vector2(-40, 5), String(id),
			HORIZONTAL_ALIGNMENT_CENTER, 80, LABEL_FONT_SIZE, COLOR_LABEL)


func _on_run_started(_seed: int) -> void:
	_walks.clear()
	_now = 0.0


func _on_sim_time_changed(time: float) -> void:
	_now = time


func _on_student_departed(student: Student, from_building: StringName, to_building: StringName, arrive_time: float) -> void:
	if _campus == null or arrive_time <= _now:
		return
	var points: PackedVector2Array = _campus.path_points(from_building, to_building)
	if points.size() < 2:
		return
	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i - 1].distance_to(points[i]))
	# The signal fires mid-frame, so work out the real departure time from the walk length.
	var start: float = arrive_time - _campus.travel_minutes(from_building, to_building)
	_walks[student.id] = {"points": points, "lengths": lengths, "start": start, "end": arrive_time}


## Where a walking student is now, by the fraction of the walk time that has passed.
func _walk_position(walk: Dictionary) -> Vector2:
	var points: PackedVector2Array = walk["points"]
	var lengths: PackedFloat32Array = walk["lengths"]
	var fraction: float = clampf(inverse_lerp(walk["start"], walk["end"], _now), 0.0, 1.0)
	var target: float = fraction * lengths[lengths.size() - 1]
	for i: int in range(1, points.size()):
		if lengths[i] >= target:
			var segment: float = lengths[i] - lengths[i - 1]
			var t: float = 0.0 if segment <= 0.0 else (target - lengths[i - 1]) / segment
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


## A fixed spot inside the student's building, so a crowd fills the building.
## Picked by a hash of the id (not the run's RNG) because it only affects drawing.
func _spot_for(student: Student) -> Vector2:
	var spots: PackedVector2Array = _spots.get(student.location, PackedVector2Array())
	if spots.is_empty():
		return _campus.building_position(student.location)
	return spots[hash(student.id) % spots.size()]


## Grid points inside an outline (or just the centre if the outline is missing or tiny).
static func _spots_inside(outline: PackedVector2Array, centre: Vector2) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	if outline.size() >= 3:
		var bounds: Rect2 = Rect2(outline[0], Vector2.ZERO)
		for point: Vector2 in outline:
			bounds = bounds.expand(point)
		var y: float = bounds.position.y + SPOT_SPACING_PX / 2.0
		while y < bounds.end.y:
			var x: float = bounds.position.x + SPOT_SPACING_PX / 2.0
			while x < bounds.end.x:
				if Geometry2D.is_point_in_polygon(Vector2(x, y), outline):
					spots.append(Vector2(x, y))
				x += SPOT_SPACING_PX
			y += SPOT_SPACING_PX
	if spots.is_empty():
		spots.append(centre)
	return spots


func _make_dot_texture() -> Texture2D:
	var size: int = 16
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre: Vector2 = Vector2(size - 1, size - 1) / 2.0
	for y: int in range(size):
		for x: int in range(size):
			var inside: float = clampf(size / 2.0 - Vector2(x, y).distance_to(centre), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, inside))
	return ImageTexture.create_from_image(image)
