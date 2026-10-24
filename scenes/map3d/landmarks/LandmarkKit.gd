class_name LandmarkKit
extends RefCounted
## Small helpers for building landmarks out of boxes, cylinders and text.
## Sizes and positions are in metres in the landmark's own space.

static var _materials: Dictionary = {}  # String -> StandardMaterial3D


## A flat-coloured material, shared by colour (and glow).
static func material(color: Color, roughness: float = 0.8, glow: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s|%s|%s" % [color.to_html(), roughness, glow]
	if _materials.has(key):
		return _materials[key]
	var made: StandardMaterial3D = StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = roughness
	if glow > 0.0:
		made.emission_enabled = true
		made.emission = color
		made.emission_energy_multiplier = glow
	_materials[key] = made
	return made


static func box(parent: Node3D, size: Vector3, centre: Vector3, mat: Material, yaw: float = 0.0) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	parent.add_child(node)
	return node


static func cylinder(parent: Node3D, radius: float, height: float, centre: Vector3, mat: Material,
		top_radius: float = -1.0, sides: int = 12) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mesh.material = mat
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = centre
	parent.add_child(node)
	return node


## Text on a wall or sign. Faces +Z unless turned with `yaw`.
static func label(parent: Node3D, text: String, centre: Vector3, height_px: int, color: Color,
		yaw: float = 0.0, pixel_size: float = 0.01) -> Label3D:
	var node: Label3D = Label3D.new()
	node.text = text
	node.font_size = height_px
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_size = 0
	node.double_sided = false
	node.shaded = true
	node.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	parent.add_child(node)
	return node


## Clears what a landmark built last time and gives it a fresh container.
static func fresh_root(owner: Node3D) -> Node3D:
	var old: Node = owner.get_node_or_null(^"Built")
	if old != null:
		old.free()
	var root: Node3D = Node3D.new()
	root.name = "Built"
	owner.add_child(root)
	return root
