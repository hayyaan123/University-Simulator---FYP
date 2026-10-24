@tool
class_name CampusWorld
extends Node3D
## The 3D campus, built from data/campus.json, data/campus_ground.json and data/campus_3d.json.
##
## Runs in the editor too (it's a tool script), so the campus can be looked at in Godot's
## 3D view. Built nodes are not saved into the scene: change the data, then tick "Rebuild".

signal built()

@export_file("*.json") var campus_path: String = "res://data/campus.json"
@export_file("*.json") var ground_path: String = "res://data/campus_ground.json"
@export_file("*.json") var looks_path: String = "res://data/campus_3d.json"
## Tick in the editor to rebuild after changing the data files.
@export var rebuild: bool = false:
	set(value):
		if value and is_inside_tree():
			build()

var frame: MapFrame
var bank: MaterialBank
## building id -> {centre: Vector3, top_m: float, outline: PackedVector2Array, name: String}
var buildings: Dictionary = {}
## Ground-plane bounds of the map, in metres.
var map_bounds: Rect2 = Rect2()
var _content: Node3D


func _ready() -> void:
	build()


## Throws away what was built and builds it again from the data files.
func build() -> void:
	if _content != null:
		_content.queue_free()
	var campus_data: Dictionary = _load_json(campus_path)
	var ground_data: Dictionary = _load_json(ground_path)
	var looks: Dictionary = _load_json(looks_path)
	if campus_data.is_empty():
		return
	frame = MapFrame.new(float(campus_data.get("metres_per_pixel", 1.0)))
	bank = MaterialBank.new()
	_content = Node3D.new()
	_content.name = "Built"
	add_child(_content)

	var ground: GroundBuilder = GroundBuilder.new(frame, bank)
	_content.add_child(ground.build(ground_data))
	map_bounds = ground.bounds()
	var builder: BuildingBuilder = BuildingBuilder.new(frame, bank, looks)
	_content.add_child(builder.build_campus(campus_data))
	buildings = builder.info
	_content.add_child(builder.build_scenery(ground_data))
	var props: PropScatter = PropScatter.new(frame, bank, campus_data, ground_data)
	for landmark: Dictionary in looks.get("landmarks", []):
		var p: Array = landmark.get("position_px", [0, 0])
		props.clear_zone(frame.to_plane(Vector2(p[0], p[1])), float(landmark.get("clear_radius_m", 0.0)))
	var overrides: Dictionary = looks.get("buildings", {})
	for id: String in overrides:
		if overrides[id].get("open_ground_floor", false):
			props.skip_hedges(id)
	_content.add_child(props.build())
	_content.add_child(_build_landmarks(looks.get("landmarks", [])))
	built.emit()


## Height of the tallest campus building roof over a ground-plane point (0 if none).
func roof_height_at(p: Vector2) -> float:
	var best: float = 0.0
	for id: StringName in buildings:
		var info: Dictionary = buildings[id]
		if info["top_m"] > best and Geometry2D.is_point_in_polygon(p, info["outline"]):
			best = info["top_m"]
	return best


## Outlines of where people are indoors (and so hidden from view). Covered walkways are
## outside these, so students walking under them stay visible.
func indoor_outlines() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for id: StringName in buildings:
		var info: Dictionary = buildings[id]
		var core: PackedVector2Array = info["core"]
		if not core.is_empty():
			result.append(MeshKit.inset(core, 1.5))
	return result


## The building whose pick body this collider belongs to, or &"" if none.
static func building_of(collider: Object) -> StringName:
	if collider != null and collider.has_meta(&"building_id"):
		return collider.get_meta(&"building_id")
	return &""


func _build_landmarks(list: Array) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Landmarks"
	for landmark: Dictionary in list:
		var path: String = landmark.get("scene", "")
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path)
		var node: Node3D = scene.instantiate()
		node.name = String(landmark.get("id", node.name)).to_pascal_case()
		var p: Array = landmark.get("position_px", [0, 0])
		node.position = frame.to_world(Vector2(p[0], p[1]))
		node.rotation_degrees.y = float(landmark.get("facing_deg", 0.0))
		root.add_child(node)
	return root


static func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		push_error("CampusWorld: missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CampusWorld: %s is not a JSON object" % path)
		return {}
	return parsed
