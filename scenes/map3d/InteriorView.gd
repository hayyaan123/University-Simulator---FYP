class_name InteriorView
extends Node3D
## Looks inside one building: lifts off the floors above (the cutaway), builds a
## furnished floor with InteriorBuilder, and seats the students who are in class there.
## Read-only, like the rest of the 3D map.

## How far above the floor the building is cut, so the room walls stay visible.
const CUT_ABOVE_FLOOR_M: float = InteriorBuilder.WALL_HEIGHT_M + 0.3
## Seated figures are drawn shorter than standing ones.
const SEATED_SCALE: Vector3 = Vector3(1.0, 0.76, 1.0)
const ROOM_ORDER: Array[StringName] = [&"lecture_hall", &"lab", &"tutorial_room"]

var building: StringName = &""
var _builder: InteriorBuilder
var _content: Node3D
var _figures: MultiMeshInstance3D
var _bank: MaterialBank
var _layout: String = "rooms"


## Opens a building. `info` is a CampusWorld.buildings entry.
func open(id: StringName, info: Dictionary, campus: Campus, bank: MaterialBank) -> void:
	close()
	building = id
	_bank = bank
	_layout = String(info.get("interior", "rooms"))
	var floor_y: float = float(info.get("floor_m", 0.0))
	_builder = InteriorBuilder.new()
	_content = _builder.build(info["outline"], floor_y, _rooms_of(id, campus), _layout)
	add_child(_content)
	_figures = _make_figures()
	add_child(_figures)
	var area: Rect2 = MeshKit.bounds_of(info["outline"]).grow(0.3)
	bank.set_cutaway(area, floor_y + CUT_ABOVE_FLOOR_M)


func close() -> void:
	if _content != null:
		_content.queue_free()
		_figures.queue_free()
		_content = null
		_figures = null
	if _bank != null:
		_bank.clear_cutaway()
	building = &""


func is_open() -> bool:
	return building != &""


## Puts each student who is in this building into a seat: in their class's room when in
## class, in the canteen or library when waiting there. Returns how many are seated.
func refresh(students: Array[Student]) -> int:
	if _figures == null:
		return 0
	var used: Dictionary = {}  # seat key -> int
	var placed: int = 0
	var mm: MultiMesh = _figures.multimesh
	for student: Student in students:
		if student.location != building or placed >= mm.instance_count:
			continue
		var key: StringName = _seat_key(student)
		var list: Array = _builder.seats.get(key, [])
		var n: int = int(used.get(key, 0))
		if n >= list.size():
			continue
		used[key] = n + 1
		var seat: Transform3D = list[n]
		mm.set_instance_transform(placed, Transform3D(seat.basis.scaled(SEATED_SCALE), seat.origin))
		var colour: Color = Students3D.STATE_COLOURS.get(student.state, Color.WHITE)
		mm.set_instance_custom_data(placed, Color(colour.r, colour.g, colour.b, 0.0))
		placed += 1
	mm.visible_instance_count = placed
	return placed


func _seat_key(student: Student) -> StringName:
	if student.state == Student.State.IN_CLASS and student.target_session != null:
		return student.target_session.room_id
	if _layout == "canteen":
		return InteriorBuilder.CANTEEN_SEATS
	if _layout == "library":
		return InteriorBuilder.LIBRARY_SEATS
	return InteriorBuilder.STUDY_SEATS


func _make_figures() -> MultiMeshInstance3D:
	var total: int = 0
	for key: Variant in _builder.seats:
		total += (_builder.seats[key] as Array).size()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true  # needed for custom data on the Compatibility renderer
	mm.use_custom_data = true
	mm.mesh = Students3D.figure_mesh()
	mm.instance_count = total
	for i: int in range(total):
		mm.set_instance_color(i, Color.WHITE)
	mm.visible_instance_count = 0
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = mm
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = Students3D.SHADER
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The building's rooms from campus.json, biggest kinds first so they get the space.
static func _rooms_of(id: StringName, campus: Campus) -> Array[Dictionary]:
	var rooms: Array[Dictionary] = []
	if campus == null:
		return rooms
	for kind: StringName in ROOM_ORDER:
		for room: StringName in campus.rooms_of_type(kind):
			if campus.room_building(room) == id:
				rooms.append({"id": room, "type": kind, "capacity": campus.room_capacity(room)})
	return rooms
