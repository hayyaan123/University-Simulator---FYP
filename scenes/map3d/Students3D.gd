class_name Students3D
extends MultiMeshInstance3D
## Draws every student as a small figure in the 3D map, with one MultiMesh.
##
## Same rules as MapView: a walking student moves along the real footpath route from
## Campus.path_points(), timed by the departure and arrival times the engine reports.
## Students inside a building (waiting or in class) are hidden and counted instead, so
## the building labels can show how many people are inside. Listens to EventBus only.

const SHADER: Shader = preload("res://scenes/map3d/shaders/students.gdshader")
## The 2D map's dot colours, lightened so they read on small lit figures.
const STATE_COLOURS: Dictionary = {
	Student.State.WAITING: Color("f2a51a"),
	Student.State.TRAVELLING: Color("3d8bff"),
	Student.State.IN_CLASS: Color("2fb873"),
}
const SKIN_TONES: Array[Color] = [Color("e9c7a6"), Color("c99872"), Color("9c6b47"), Color("6e4a32")]
const HAIR: Color = Color("2a211c")
const TROUSERS: Color = Color("3c4452")
## Figure height when the camera is close, and how much bigger it gets fully zoomed out.
const FIGURE_HEIGHT_M: float = 1.7
const FAR_SCALE: float = 4.5
## Note: the shirt colour travels in the instance custom data. The Compatibility renderer
## only passes custom data when instance colours are on too, so those are kept white.

## Grid cell size for the "is this point inside a building" lookup.
const INDOOR_CELL_M: float = 1.0

var _campus: Campus
var _frame: MapFrame
var _students: Array[Student] = []
var _now: float = 0.0
## student id -> {points: PackedVector2Array (metres), lengths: PackedFloat32Array, start: float, end: float}
var _walks: Dictionary = {}
var _index_of: Dictionary = {}  # student id -> instance index
var _indoor: OccupancyGrid
## Building id -> number of students inside it now. Refreshed every frame.
var occupancy: Dictionary = {}
var _hidden: Transform3D = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0.0, -100.0, 0.0))
var _material: ShaderMaterial


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.sim_time_changed.connect(_on_sim_time_changed)
	EventBus.student_departed.connect(_on_student_departed)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Call once per run, after the timetable is built.
## `indoor` are the outlines where students are out of sight (CampusWorld.indoor_outlines()).
func setup(campus: Campus, students: Array[Student], frame: MapFrame, bounds: Rect2, indoor: Array[PackedVector2Array]) -> void:
	_campus = campus
	_frame = frame
	_students = students
	_walks.clear()
	_index_of.clear()
	for i: int in range(students.size()):
		_index_of[students[i].id] = i
	_indoor = OccupancyGrid.new(bounds, INDOOR_CELL_M)
	for outline: PackedVector2Array in indoor:
		if outline.size() >= 3:
			_indoor.block_polygon(outline)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = figure_mesh()
	mm.instance_count = students.size()
	for i: int in range(students.size()):
		mm.set_instance_transform(i, _hidden)
		mm.set_instance_color(i, Color.WHITE)
	# Everyone starts hidden, so the automatic bounds would be tiny and the whole crowd
	# would be culled. Use the whole map instead.
	mm.custom_aabb = AABB(Vector3(bounds.position.x, -5.0, bounds.position.y), Vector3(bounds.size.x, 40.0, bounds.size.y))
	multimesh = mm


## Sets how big figures are drawn (1 = life size). MapView3D calls this as the camera zooms.
func set_zoom(zoom_amount: float) -> void:
	if _material != null:
		_material.set_shader_parameter("figure_scale", lerpf(1.0, FAR_SCALE, zoom_amount))


## Only walking students are touched each frame; everyone else stays hidden until they
## set off. With 5,000 students most are indoors at any moment, so this saves a lot.
func _process(_delta: float) -> void:
	if multimesh == null or _campus == null or not is_visible_in_tree():
		return
	for id: int in _walks.keys():
		var walk: Dictionary = _walks[id]
		var i: int = _index_of[id]
		if _now >= walk["end"]:
			_walks.erase(id)
			multimesh.set_instance_transform(i, _hidden)
		else:
			_place_walker(i, _students[i], walk)


## Recounts how many students are inside each building (into `occupancy`). Called a few
## times a second by MapView3D rather than every frame.
func count_occupancy() -> void:
	occupancy.clear()
	for student: Student in _students:
		if student.state == Student.State.WAITING or student.state == Student.State.IN_CLASS:
			occupancy[student.location] = int(occupancy.get(student.location, 0)) + 1


func _place_walker(i: int, student: Student, walk: Dictionary) -> void:
	var pose: Array = _walk_pose(walk)
	var p: Vector2 = pose[0]
	if not _indoor.is_free(p):
		# Walking through an indoor link between buildings: out of sight.
		multimesh.set_instance_transform(i, _hidden)
		return
	var dir: Vector2 = pose[1]
	var basis: Basis = Basis(Vector3.UP, atan2(dir.x, dir.y))
	# A small sideways offset per student keeps a crowd from walking in single file.
	var side: Vector2 = Vector2(-dir.y, dir.x) * (float(hash(student.id) % 7) - 3.0) * 0.35
	multimesh.set_instance_transform(i, Transform3D(basis, Vector3(p.x + side.x, 0.08, p.y + side.y)))
	var colour: Color = STATE_COLOURS[Student.State.TRAVELLING]
	multimesh.set_instance_custom_data(i, Color(colour.r, colour.g, colour.b, 1.0))


## Where a walking student is now, and which way they face: [Vector2 position, Vector2 direction].
func _walk_pose(walk: Dictionary) -> Array:
	var points: PackedVector2Array = walk["points"]
	var lengths: PackedFloat32Array = walk["lengths"]
	var fraction: float = clampf(inverse_lerp(walk["start"], walk["end"], _now), 0.0, 1.0)
	var target: float = fraction * lengths[lengths.size() - 1]
	for i: int in range(1, points.size()):
		if lengths[i] >= target:
			var segment: float = lengths[i] - lengths[i - 1]
			var t: float = 0.0 if segment <= 0.0 else (target - lengths[i - 1]) / segment
			return [points[i - 1].lerp(points[i], t), (points[i] - points[i - 1]).normalized()]
	return [points[points.size() - 1], Vector2.DOWN]


## The students on the map (empty before setup).
func all_students() -> Array[Student]:
	return _students


## A low-poly figure: legs, a shirt (tinted per student), a head and hair. About 1.7 m tall.
static func figure_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin: Color = SKIN_TONES[1]
	_prism(st, 0.16, 0.13, 0.0, 0.8, 6, Color(TROUSERS, 0.0))
	_prism(st, 0.2, 0.24, 0.8, 1.4, 6, Color(1.0, 1.0, 1.0, 1.0))
	_prism(st, 0.11, 0.12, 1.4, 1.62, 6, Color(skin, 0.0))
	_prism(st, 0.13, 0.04, 1.62, FIGURE_HEIGHT_M + 0.02, 6, Color(HAIR, 0.0))
	return st.commit()


## A tapered six-sided prism with a cap on top, coloured with a vertex colour.
static func _prism(st: SurfaceTool, r_bottom: float, r_top: float, y0: float, y1: float, sides: int, colour: Color) -> void:
	st.set_color(colour)
	for k: int in range(sides):
		var a0: float = TAU * k / sides
		var a1: float = TAU * (k + 1) / sides
		var b0: Vector3 = Vector3(cos(a0) * r_bottom, y0, sin(a0) * r_bottom)
		var b1: Vector3 = Vector3(cos(a1) * r_bottom, y0, sin(a1) * r_bottom)
		var t0: Vector3 = Vector3(cos(a0) * r_top, y1, sin(a0) * r_top)
		var t1: Vector3 = Vector3(cos(a1) * r_top, y1, sin(a1) * r_top)
		var mid: float = (a0 + a1) * 0.5
		var normal: Vector3 = Vector3(cos(mid), 0.25, sin(mid)).normalized()
		MeshKit.add_tri(st, b0, b1, t1, normal)
		MeshKit.add_tri(st, b0, t1, t0, normal)
		MeshKit.add_tri(st, Vector3(0.0, y1, 0.0), t0, t1, Vector3.UP)


func _on_run_started(_seed: int) -> void:
	if multimesh != null:
		for id: int in _walks:
			multimesh.set_instance_transform(_index_of[id], _hidden)
	_walks.clear()
	_now = 0.0


func _on_sim_time_changed(time: float) -> void:
	_now = time


func _on_student_departed(student: Student, from_building: StringName, to_building: StringName, arrive_time: float) -> void:
	if _campus == null or arrive_time <= _now:
		return
	var points: PackedVector2Array = _frame.to_plane_points(_campus.path_points(from_building, to_building))
	if points.size() < 2:
		return
	var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
	for i: int in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i - 1].distance_to(points[i]))
	# The signal fires mid-frame, so work out the real departure time from the walk length.
	var start: float = arrive_time - _campus.travel_minutes(from_building, to_building)
	if _index_of.has(student.id):
		_walks[student.id] = {"points": points, "lengths": lengths, "start": start, "end": arrive_time}
