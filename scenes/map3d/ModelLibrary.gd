class_name ModelLibrary
extends RefCounted
## Loads the CC0 models in assets/third_party once each, merges every part of a model (a
## car's body and wheels, say) into one mesh, and recolours Kenney's teal foliage to
## tropical greens. Credits are in assets/third_party/CREDITS.md.

const NATURE: String = "res://assets/third_party/kenney_nature_kit/"
const CARS: String = "res://assets/third_party/kenney_car_kit/"
const ROADS: String = "res://assets/third_party/kenney_city_kit_roads/"
const FURNITURE: String = "res://assets/third_party/kenney_furniture_kit/"

## Kenney material name (plus "_palm" for palm trees) -> colour on our map.
const FOLIAGE_COLOURS: Dictionary = {
	"leafsGreen": Color("4f8a37"),
	"leafsGreen_palm": Color("74a83f"),
	"grass": Color("4c8a35"),
	"woodBark": Color("7d5f48"),
	"woodBark_palm": Color("9a8166"),
}

static var _models: Dictionary = {}  # path -> {mesh: ArrayMesh, base: Transform3D, size: Vector3}
static var _recoloured: Dictionary = {}  # String -> StandardMaterial3D


## {mesh, base, size} for a model, or {} if it is missing. `base` lifts the model so it
## stands on y = 0; `size` is its bounding box size in model units.
static func get_model(path: String) -> Dictionary:
	if _models.has(path):
		return _models[path]
	var result: Dictionary = {}
	if ResourceLoader.exists(path):
		var root: Node = (load(path) as PackedScene).instantiate()
		var mesh: ArrayMesh = _merged_mesh(root, path.get_file().contains("palm"))
		if mesh.get_surface_count() > 0:
			var aabb: AABB = mesh.get_aabb()
			result = {"mesh": mesh, "base": Transform3D(Basis(), Vector3(0.0, -aabb.position.y, 0.0)), "size": aabb.size}
		root.free()
	else:
		push_warning("ModelLibrary: missing model %s (run the Godot import first)" % path)
	_models[path] = result
	return result


## A MeshInstance3D of a model scaled so its height is `height_m`, standing at `position`.
static func instance(path: String, height_m: float, position: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var model: Dictionary = get_model(path)
	if model.is_empty():
		return node
	var size: Vector3 = model["size"]
	var scale: float = height_m / maxf(0.001, size.y)
	node.mesh = model["mesh"]
	node.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), position) * (model["base"] as Transform3D)
	return node


static func _merged_mesh(root: Node, is_palm: bool) -> ArrayMesh:
	var merged: ArrayMesh = ArrayMesh.new()
	for node: MeshInstance3D in _all_meshes(root):
		var to_root: Transform3D = _transform_to_root(node, root)
		for s: int in range(node.mesh.get_surface_count()):
			var st: SurfaceTool = SurfaceTool.new()
			st.append_from(node.mesh, s, to_root)
			st.set_material(_recolour(node.mesh.surface_get_material(s), is_palm))
			st.commit(merged)
	return merged


static func _recolour(material: Material, is_palm: bool) -> Material:
	if not (material is StandardMaterial3D):
		return material
	var name: String = material.resource_name
	var key: String = name + ("_palm" if is_palm else "")
	if not FOLIAGE_COLOURS.has(key):
		key = name
	if not FOLIAGE_COLOURS.has(key):
		return material
	if _recoloured.has(key):
		return _recoloured[key]
	var copy: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
	copy.albedo_color = FOLIAGE_COLOURS[key]
	copy.roughness = 0.9
	_recoloured[key] = copy
	return copy


static func _all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node)
	for child: Node in node.get_children():
		result.append_array(_all_meshes(child))
	return result


static func _transform_to_root(node: Node3D, root: Node) -> Transform3D:
	var result: Transform3D = Transform3D()
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
