class_name InteriorBuilder
extends RefCounted
## Builds one furnished floor of a building for the cutaway view.
##
## "rooms" layout: a corridor down the long axis of the building with rooms on both
## sides, taken from the building's rooms in campus.json (lecture halls, tutorial rooms,
## labs), each furnished for its type. "canteen" and "library" fill the floor with a food
## court or a library instead. Every seat is recorded so seated students can be drawn.
##
## Work happens in a local frame: u runs along the building's longest wall, v across it.

const WALL_HEIGHT_M: float = 2.8
const CORRIDOR_M: float = 3.2
const OUTER_WALL_M: float = 0.5
## Width of each room type along the corridor (estimates).
const ROOM_WIDTH_M: Dictionary = {&"lecture_hall": 15.0, &"tutorial_room": 7.0, &"lab": 10.0}
const FLOOR_COLOURS: Dictionary = {
	&"lecture_hall": Color("3e5c86"), &"tutorial_room": Color("8b9099"), &"lab": Color("d8d6ce"),
	&"corridor": Color("e6e0d3"), &"canteen": Color("cdb995"), &"library": Color("8d6a50"),
}
const PARTITION: Color = Color("ece7dc")
const ROW_PITCH_M: float = 1.15
const SEAT_PITCH_M: float = 0.75
## Seats used by the canteen and library layouts (not rooms in campus.json).
const CANTEEN_SEATS: StringName = &"canteen"
const LIBRARY_SEATS: StringName = &"library"
## Open study areas fill floor space the rooms don't use; students between classes sit here.
const STUDY_SEATS: StringName = &"study"
const MIN_STUDY_AREA_M: float = 5.0
const SHUFFLE_SEED: int = 7
const STALL_NAMES: PackedStringArray = ["Nasi Lemak", "Chicken Rice", "Mee & Noodles", "Indian", "Western", "Drinks", "Malay Rice", "Desserts"]

## room id (or CANTEEN_SEATS / LIBRARY_SEATS) -> Array[Transform3D] of seats, facing the front.
var seats: Dictionary = {}

var _axis: Vector2 = Vector2.RIGHT
var _across: Vector2 = Vector2.DOWN
var _floor_y: float = 0.0
var _surfaces: Dictionary = {}  # Color -> SurfaceTool
var _props: Dictionary = {}  # model path -> Array[Transform3D]
var _root: Node3D


## Builds the floor at height `floor_y`. `rooms`: [{id, type, capacity}], layout: rooms/canteen/library.
func build(outline: PackedVector2Array, floor_y: float, rooms: Array[Dictionary], layout: String) -> Node3D:
	_root = Node3D.new()
	_root.name = "Interior"
	_floor_y = floor_y
	_axis = _longest_edge_dir(outline)
	_across = Vector2(-_axis.y, _axis.x)
	var inner: PackedVector2Array = MeshKit.inset(outline, OUTER_WALL_M)
	_slab(inner, FLOOR_COLOURS[&"corridor"], 0.02)
	_walls(inner, Color("efe9dd"), true)
	var box: Rect2 = _local_bounds(inner)
	match layout:
		"canteen":
			_canteen(inner, box)
		"library":
			_library(inner, box)
		_:
			_rooms(inner, box, rooms)
	_spread_shared_seats()
	_commit()
	return _root


## Shuffles the seats people pick freely (canteen, library, study areas), so a small
## crowd spreads across the floor instead of filling one corner. Fixed seed: drawing only.
func _spread_shared_seats() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SHUFFLE_SEED
	for key: StringName in [CANTEEN_SEATS, LIBRARY_SEATS, STUDY_SEATS]:
		var list: Array = seats.get(key, [])
		for i: int in range(list.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var swap: Variant = list[i]
			list[i] = list[j]
			list[j] = swap


# --- Room layout -------------------------------------------------------------------------

func _rooms(inner: PackedVector2Array, box: Rect2, rooms: Array[Dictionary]) -> void:
	var mid_v: float = box.get_center().y
	var strips: Array[Vector2] = [Vector2(box.position.y, mid_v - CORRIDOR_M * 0.5), Vector2(mid_v + CORRIDOR_M * 0.5, box.end.y)]
	var cursor: Array[float] = [box.position.x, box.position.x]
	var side: int = 0
	for room: Dictionary in rooms:
		var width: float = float(ROOM_WIDTH_M.get(room["type"], 8.0))
		if cursor[side] + width > box.end.x:
			side = 1 - side
			if cursor[side] + width > box.end.x:
				break
		var strip: Vector2 = strips[side]
		var rect: Rect2 = Rect2(cursor[side], strip.x, width, strip.y - strip.x)
		cursor[side] += width
		# The front of the room (screen, lectern) is the wall away from the corridor.
		_add_room(inner, rect, room, side == 0)
		side = 1 - side
	seats[STUDY_SEATS] = [] as Array[Transform3D]
	for k: int in range(2):
		var strip: Vector2 = strips[k]
		if box.end.x - cursor[k] >= MIN_STUDY_AREA_M:
			var area: Rect2 = Rect2(cursor[k], strip.x, box.end.x - cursor[k], strip.y - strip.x)
			_table_grid(inner, area, STUDY_SEATS, 3.0, true)


func _add_room(inner: PackedVector2Array, rect: Rect2, room: Dictionary, front_is_low_v: bool) -> void:
	var shape: PackedVector2Array = _clip(_rect_points(rect), inner)
	if shape.size() < 3 or absf(MeshKit.signed_area(shape)) < 12.0:
		return
	var kind: StringName = room["type"]
	_slab(shape, FLOOR_COLOURS.get(kind, FLOOR_COLOURS[&"tutorial_room"]), 0.04)
	_walls(shape, PARTITION, false)
	_walls(shape, PARTITION, true)
	var id: StringName = room["id"]
	seats[id] = [] as Array[Transform3D]
	var usable: Rect2 = rect.grow(-0.8)
	match kind:
		&"lecture_hall":
			_lecture_hall(usable, id, front_is_low_v, int(room["capacity"]))
		&"lab":
			_lab(usable, id, front_is_low_v)
		_:
			_tutorial(usable, id, front_is_low_v)
	var centre: Vector2 = rect.get_center()
	var label: Label3D = LandmarkKit.label(_root, String(id), _world(centre, WALL_HEIGHT_M + 1.0), 40, Color.WHITE)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0006
	label.outline_size = 8
	label.no_depth_test = true


## Rows of seats facing a lectern and screen at the front.
func _lecture_hall(r: Rect2, id: StringName, front_low: bool, capacity: int) -> void:
	var front_v: float = r.position.y if front_low else r.end.y
	var facing: float = -1.0 if front_low else 1.0
	_screen(Vector2(r.get_center().x, front_v), facing, minf(r.size.x * 0.6, 6.0))
	_put_model(ModelLibrary.FURNITURE + "table.glb", Vector2(r.get_center().x, front_v - facing * 1.6), 0.0, 1.0)
	var row_v: float = front_v - facing * 3.2
	var placed: int = 0
	while (row_v - r.position.y) * (r.end.y - row_v) >= 0.0 and placed < capacity:
		_box(Vector2(r.get_center().x, row_v + facing * 0.45), Vector2(r.size.x - 1.0, 0.45), 0.75, Color("b98d5f"))
		var u: float = r.position.x + 0.6
		while u < r.end.x - 0.4 and placed < capacity:
			_seat(id, Vector2(u, row_v), facing, "chair.glb")
			placed += 1
			u += SEAT_PITCH_M
		row_v -= facing * ROW_PITCH_M


## Group tables with chairs around them, and a whiteboard at the front.
func _tutorial(r: Rect2, id: StringName, front_low: bool) -> void:
	var front_v: float = r.position.y if front_low else r.end.y
	var facing: float = -1.0 if front_low else 1.0
	_screen(Vector2(r.get_center().x, front_v), facing, minf(r.size.x * 0.7, 4.0))
	var start: Vector2 = Vector2(r.position.x + 1.6, front_v - facing * 2.6)
	var v: float = start.y
	while (v - r.position.y) * (r.end.y - v) >= 0.0:
		var u: float = start.x
		while u < r.end.x - 1.2:
			_box(Vector2(u, v), Vector2(1.6, 1.2), 0.74, Color("d9d2c3"))
			for offset: Vector2 in [Vector2(-0.45, 0.9), Vector2(0.45, 0.9), Vector2(-0.45, -0.9), Vector2(0.45, -0.9)]:
				_seat(id, Vector2(u, v) + offset, signf(-offset.y), "chairDesk.glb")
			u += 3.0
		v -= facing * 3.0


## Rows of computer desks.
func _lab(r: Rect2, id: StringName, front_low: bool) -> void:
	var front_v: float = r.position.y if front_low else r.end.y
	var facing: float = -1.0 if front_low else 1.0
	_screen(Vector2(r.get_center().x, front_v), facing, minf(r.size.x * 0.6, 5.0))
	var v: float = front_v - facing * 2.2
	while (v - r.position.y) * (r.end.y - v) >= 0.0:
		var u: float = r.position.x + 0.7
		while u < r.end.x - 0.6:
			_box(Vector2(u, v + facing * 0.45), Vector2(1.1, 0.6), 0.74, Color("e8e4dc"))
			_put_model(ModelLibrary.FURNITURE + "computerScreen.glb", Vector2(u, v + facing * 0.55), _yaw_for(facing), 0.45, 0.74)
			_seat(id, Vector2(u, v), facing, "chairDesk.glb")
			u += 1.25
		v -= facing * 1.9


# --- Canteen and library -----------------------------------------------------------------

func _canteen(inner: PackedVector2Array, box: Rect2) -> void:
	_slab(inner, FLOOR_COLOURS[&"canteen"], 0.04)
	seats[CANTEEN_SEATS] = [] as Array[Transform3D]
	# Food stalls along one long wall, each with a counter, a hood and a lit sign.
	var stall_v: float = box.end.y - 1.6
	var u: float = box.position.x + 2.5
	var index: int = 0
	while u < box.end.x - 2.5:
		var p: Vector2 = Vector2(u, stall_v)
		if Geometry2D.is_point_in_polygon(_plane(p), inner):
			_box(p, Vector2(3.6, 0.8), 1.0, Color("f0ece4"))
			_box(p + Vector2(0.0, 1.0), Vector2(3.6, 0.6), 1.9, Color("b9b2a6"))
			_box(p + Vector2(0.0, 0.9), Vector2(3.8, 0.12), 0.6, Color(0.95, 0.62, 0.22), 2.4)
			var sign_text: String = STALL_NAMES[index % STALL_NAMES.size()]
			var label: Label3D = LandmarkKit.label(_root, sign_text, _world(p + Vector2(0.0, 0.82), 2.7), 36, Color("2b1d10"), _yaw_for(-1.0), 0.006)
			label.double_sided = true
			index += 1
		u += 4.5
	_table_grid(inner, Rect2(box.position.x, box.position.y, box.size.x, box.size.y - 5.0), CANTEEN_SEATS, 3.4)


func _library(inner: PackedVector2Array, box: Rect2) -> void:
	_slab(inner, FLOOR_COLOURS[&"library"], 0.04)
	seats[LIBRARY_SEATS] = [] as Array[Transform3D]
	var split: float = box.position.x + box.size.x * 0.45
	# Bookshelf rows in one half...
	var v: float = box.position.y + 1.5
	while v < box.end.y - 1.0:
		var u: float = box.position.x + 1.2
		while u < split - 1.0:
			if Geometry2D.is_point_in_polygon(_plane(Vector2(u, v)), inner):
				_put_model(ModelLibrary.FURNITURE + "bookcaseClosedWide.glb", Vector2(u, v), _yaw_for(1.0), 2.0)
			u += 1.6
		v += 2.6
	# ...study tables with laptops in the other, and a front desk between them.
	_box(Vector2(split + 1.0, box.get_center().y), Vector2(1.0, 4.0), 1.05, Color("5d4636"))
	_table_grid(inner, Rect2(split + 3.0, box.position.y, box.end.x - split - 3.0, box.size.y), LIBRARY_SEATS, 3.0, true)


## A grid of tables with four chairs each, filling an area.
func _table_grid(inner: PackedVector2Array, area: Rect2, key: StringName, pitch: float, laptops: bool = false) -> void:
	var v: float = area.position.y + pitch * 0.6
	while v < area.end.y - pitch * 0.4:
		var u: float = area.position.x + pitch * 0.6
		while u < area.end.x - pitch * 0.4:
			var p: Vector2 = Vector2(u, v)
			if Geometry2D.is_point_in_polygon(_plane(p), MeshKit.inset(inner, 1.0)):
				_box(p, Vector2(1.4, 1.4), 0.74, Color("d6c7aa") if not laptops else Color("b48a63"))
				for offset: Vector2 in [Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
					for du: float in [-0.35, 0.35]:
						_seat(key, p + offset + Vector2(du, 0.0), signf(-offset.y), "chair.glb")
				if laptops:
					_put_model(ModelLibrary.FURNITURE + "laptop.glb", p, 0.0, 0.25, 0.74)
			u += pitch
		v += pitch


# --- Pieces ------------------------------------------------------------------------------

## A chair at a local point, facing along +v (facing > 0) or -v; records the seat.
func _seat(key: StringName, p: Vector2, facing: float, model: String) -> void:
	var yaw: float = _yaw_for(facing)
	_put_model(ModelLibrary.FURNITURE + model, p, yaw, 0.9)
	var list: Array[Transform3D] = seats[key]
	list.append(Transform3D(Basis(Vector3.UP, yaw), _world(p, 0.0)))


## A screen or whiteboard on the front wall.
func _screen(p: Vector2, facing: float, width: float) -> void:
	_box(p + Vector2(0.0, facing * 0.15), Vector2(width, 0.1), 1.6, Color("1d2733"), 0.0, 0.9)


## A box standing on the floor (a table top, a counter...). With `lift`, it floats that high.
func _box(p: Vector2, size: Vector2, height: float, colour: Color, glow: float = 0.0, lift: float = 0.0) -> void:
	var mat: StandardMaterial3D = LandmarkKit.material(colour, 0.7, glow)
	# Turn the box so its x side runs along the building's long axis.
	var yaw: float = atan2(-_axis.y, _axis.x)
	var node: MeshInstance3D = LandmarkKit.box(_root, Vector3(size.x, height, size.y), _world(p, lift + height * 0.5), mat, yaw)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _put_model(path: String, p: Vector2, yaw: float, height: float, lift: float = 0.0) -> void:
	var model: Dictionary = ModelLibrary.get_model(path)
	if model.is_empty():
		return
	var size: Vector3 = model["size"]
	var scale: float = height / maxf(0.001, size.y)
	var t: Transform3D = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), _world(p, lift)) * (model["base"] as Transform3D)
	if not _props.has(path):
		_props[path] = [] as Array[Transform3D]
	(_props[path] as Array[Transform3D]).append(t)


func _slab(shape: PackedVector2Array, colour: Color, lift: float) -> void:
	MeshKit.add_cap(_surface(colour), shape, _floor_y + lift)


func _walls(shape: PackedVector2Array, colour: Color, inward: bool) -> void:
	MeshKit.add_walls(_surface(colour), shape, _floor_y, _floor_y + WALL_HEIGHT_M, inward)


func _surface(colour: Color) -> SurfaceTool:
	if not _surfaces.has(colour):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[colour] = st
	return _surfaces[colour]


func _commit() -> void:
	for colour: Color in _surfaces:
		var mat: StandardMaterial3D = LandmarkKit.material(colour, 0.85)
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = (_surfaces[colour] as SurfaceTool).commit()
		node.material_override = mat
		_root.add_child(node)
	for path: String in _props:
		var transforms: Array[Transform3D] = _props[path]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ModelLibrary.get_model(path)["mesh"]
		mm.instance_count = transforms.size()
		for i: int in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(node)


# --- Local frame helpers -----------------------------------------------------------------

## Yaw that turns a Kenney chair (facing -Z) to face along +v (facing > 0) or -v.
func _yaw_for(facing: float) -> float:
	var dir: Vector2 = _across * facing
	return atan2(-dir.x, -dir.y)


func _plane(local: Vector2) -> Vector2:
	return _axis * local.x + _across * local.y


func _world(local: Vector2, height: float) -> Vector3:
	var p: Vector2 = _plane(local)
	return Vector3(p.x, _floor_y + height, p.y)


func _local_bounds(shape: PackedVector2Array) -> Rect2:
	var rect: Rect2 = Rect2(Vector2(shape[0].dot(_axis), shape[0].dot(_across)), Vector2.ZERO)
	for p: Vector2 in shape:
		rect = rect.expand(Vector2(p.dot(_axis), p.dot(_across)))
	return rect


func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([_plane(r.position), _plane(Vector2(r.end.x, r.position.y)), _plane(r.end), _plane(Vector2(r.position.x, r.end.y))])


## The largest piece of `shape` that lies inside `inner`.
static func _clip(shape: PackedVector2Array, inner: PackedVector2Array) -> PackedVector2Array:
	var best: PackedVector2Array = PackedVector2Array()
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(shape, inner):
		if absf(MeshKit.signed_area(piece)) > absf(MeshKit.signed_area(best)):
			best = piece
	return best


static func _longest_edge_dir(outline: PackedVector2Array) -> Vector2:
	var best: Vector2 = Vector2.RIGHT
	var best_length: float = 0.0
	for i: int in range(outline.size()):
		var edge: Vector2 = outline[(i + 1) % outline.size()] - outline[i]
		if edge.length() > best_length:
			best_length = edge.length()
			best = edge.normalized()
	return best
