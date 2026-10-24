class_name BuildingBuilder
extends RefCounted
## Builds the campus buildings (from campus.json plus the looks in campus_3d.json) and
## the surrounding scenery buildings (from campus_ground.json).
##
## Meshes are merged by material, so the whole campus costs a few dozen draw calls.
## Each campus building also gets a StaticBody3D (with meta "building_id") so the camera
## can pick it.

## Assumed floor count when OSM has none and campus_3d.json doesn't say.
const DEFAULT_LEVELS: int = 3
const PARAPET_HEIGHT_M: float = 1.0
const PARAPET_THICKNESS_M: float = 0.35
const RAISED_COLUMN_SIZE_M: float = 0.8
## Columns under raised or open-ground-floor buildings are spaced about this far apart.
const COLUMN_SPACING_M: float = 7.0
## Depth of a covered ground-floor walkway (outer columns to the enclosed core).
const ARCADE_DEPTH_M: float = 4.0
## Compass names allowed for "open_ground_floor" -> ground-plane direction (+x east, +z south).
## "open_ground_floor": "through" means the whole ground floor is an open passage (only
## columns, no rooms), which people walk straight through.
const THROUGH: String = "through"
const COMPASS: Dictionary = {
	"north": Vector2(0.0, -1.0), "south": Vector2(0.0, 1.0),
	"east": Vector2(1.0, 0.0), "west": Vector2(-1.0, 0.0),
}
## Roof plant: one unit per this many square metres of roof, within a range.
const ROOF_M2_PER_UNIT: float = 220.0
const ROOF_UNITS_MIN: int = 2
const ROOF_UNITS_MAX: int = 12
const GLASS_TOWER_SIZE_M: float = 5.5
const GLASS_TOWER_EXTRA_M: float = 3.5
## Canopy roofs and covered areas without a floor count sit at this height.
const CANOPY_HEIGHT_M: float = 3.6
## The skybridge between B3 and B2 crosses at about the fourth floor (photos).
const SKYBRIDGE_BASE_M: float = 11.5
const SKYBRIDGE_HEIGHT_M: float = 3.6

## What the camera and labels need about each campus building, filled by build_campus().
## building id -> {centre: Vector3 (on the roof), top_m: float, outline: PackedVector2Array}
var info: Dictionary = {}

var _frame: MapFrame
var _bank: MaterialBank
var _looks: Dictionary
var _surfaces: Dictionary = {}  # Material -> SurfaceTool
var _roof_units: Array[Transform3D] = []
var _tanks: Array[Transform3D] = []
var _columns: Array[Transform3D] = []
var _bodies: Array[StaticBody3D] = []


func _init(frame: MapFrame, bank: MaterialBank, looks: Dictionary) -> void:
	_frame = frame
	_bank = bank
	_looks = looks


## Campus buildings. `campus_data` is the parsed campus.json.
func build_campus(campus_data: Dictionary) -> Node3D:
	_reset()
	var overrides: Dictionary = _looks.get("buildings", {})
	var kind_styles: Dictionary = _looks.get("kind_styles", {})
	var index: int = 0
	for building: Dictionary in campus_data.get("buildings", []):
		var id: String = building["id"]
		var config: Dictionary = overrides.get(id, {})
		if config.has("flat"):
			continue
		var outline: PackedVector2Array = _clean(_frame.to_plane_points(MapFrame.points_from_json(building["outline"])))
		if outline.size() < 3:
			continue
		var style: Dictionary = _style(kind_styles.get(building.get("kind", "teaching"), "teaching"))
		var levels: int = int(config.get("levels", building.get("levels", DEFAULT_LEVELS)))
		var floor_height: float = float(style.get("floor_height", 3.8))
		var base: float = float(config.get("base_m", 0.0))
		var top: float = base + maxf(1, levels) * floor_height
		var walkway: PackedInt32Array = _walkway_edges(outline, config.get("open_ground_floor", false))
		var core: PackedVector2Array = outline
		var ground_material: ShaderMaterial = _bank.facade(style, float(index))
		var material: ShaderMaterial = ground_material
		if not walkway.is_empty():
			# A covered walkway along some ground-floor sides: the facade starts one floor
			# up, held on columns, and the ground floor is a smaller core behind them.
			var upper: Dictionary = style.duplicate()
			upper["base_height"] = 0.0
			material = _bank.facade(upper, float(index))
			var through: bool = String(config.get("open_ground_floor", "")) == THROUGH
			core = _add_walkway(outline, walkway, base, base + floor_height, ground_material, through)
			base += floor_height
		_add_block(outline, base, top, material, String(config.get("roof", "flat")), not walkway.is_empty())
		_add_body(id, outline, 0.0, top)
		for tower: Array in config.get("glass_towers", []):
			_add_glass_tower(_frame.to_plane(Vector2(tower[0], tower[1])), top)
		info[StringName(id)] = {
			"centre": Vector3(MeshKit.centre_of(outline).x, top, MeshKit.centre_of(outline).y),
			"top_m": top, "outline": outline, "name": String(building.get("name", id)),
			"core": core,
			"floor_m": base,
			"interior": String(config.get("interior", "rooms")),
		}
		index += 1
	return _commit("CampusBuildings")


## Every non-campus building in the area. `ground_data` is the parsed campus_ground.json.
func build_scenery(ground_data: Dictionary) -> Node3D:
	_reset()
	var styles: Dictionary = _looks.get("scenery_styles", {})
	var default_levels: Dictionary = _looks.get("scenery_default_levels", {})
	var index: int = 0
	for building: Dictionary in ground_data.get("buildings", []):
		var kind: String = building.get("kind", "yes")
		var outline: PackedVector2Array = _clean(_frame.to_plane_points(MapFrame.points_from_json(building["outline"])))
		if outline.size() < 3:
			continue
		if kind == "roof":
			_add_canopy(outline, float(building.get("levels", 0)))
			continue
		if kind == "bridge":
			_add_skybridge(outline)
			continue
		var style: Dictionary = _style(styles.get(kind, "scenery"))
		var levels: int = int(building.get("levels", 0))
		if levels <= 0:
			levels = int(default_levels.get(kind, DEFAULT_LEVELS))
		var top: float = levels * float(style.get("floor_height", 3.4))
		# Share a few materials between scenery buildings so lit windows still vary.
		_add_block(outline, 0.0, top, _bank.facade(style, 100.0 + float(index % 4)), "flat")
		index += 1
	return _commit("SceneryBuildings")


## Pick bodies made by the last build_campus() call.
func bodies() -> Array[StaticBody3D]:
	return _bodies


## A building block: facade walls, parapet, roof, roof plant and (if raised) columns.
func _add_block(outline: PackedVector2Array, base: float, top: float, facade: Material, roof: String, has_walkway: bool = false) -> void:
	MeshKit.add_walls(_surface(facade), outline, base, top)
	var inner: PackedVector2Array = MeshKit.inset(outline, PARAPET_THICKNESS_M)
	var roof_level: float = top - PARAPET_HEIGHT_M * 0.8
	var trim: SurfaceTool = _surface(_bank.concrete)
	MeshKit.add_walls(trim, inner, roof_level, top, true)
	MeshKit.add_ring(trim, outline, inner, top)
	match roof:
		"green":
			MeshKit.add_cap(_surface(_bank.roof_green), inner, roof_level)
		"canopy":
			MeshKit.add_cap(_surface(_bank.roof), inner, roof_level)
			_add_canopy_roof(outline, top)
		_:
			MeshKit.add_cap(_surface(_bank.roof), inner, roof_level)
	if base > 0.0 and not has_walkway:
		MeshKit.add_cap(_surface(_bank.concrete), outline, base, false)
		_add_columns(outline, base)
	if top - base > 7.0 and roof != "canopy":
		_add_roof_plant(inner, roof_level)


## Which edges get a covered walkway: true or "through" = every edge, a compass name =
## edges facing that way, an array of names = several sides, false = none.
func _walkway_edges(outline: PackedVector2Array, setting: Variant) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if setting is bool or String(setting) == THROUGH:
		if setting is String or setting:
			for i: int in range(outline.size()):
				result.append(i)
		return result
	var names: Array = setting if setting is Array else [setting]
	for name: Variant in names:
		if COMPASS.has(String(name)):
			for i: int in MeshKit.edges_facing(outline, COMPASS[String(name)]):
				if not result.has(i):
					result.append(i)
	return result


## Builds the ground floor of a building with a covered walkway on some edges: the core
## (set back on those edges) with the ground-floor facade, columns along the walkway, and
## the ceiling above it. With `through`, there is no core: the ground floor is an open
## passage on a grid of columns. Returns the core outline (empty when there is none).
func _add_walkway(outline: PackedVector2Array, edges: PackedInt32Array, base: float, ceiling: float,
		facade: Material, through: bool) -> PackedVector2Array:
	var basis: Basis = Basis().scaled(Vector3(RAISED_COLUMN_SIZE_M * 0.7, ceiling - base, RAISED_COLUMN_SIZE_M * 0.7))
	MeshKit.add_cap(_surface(_bank.concrete), outline, ceiling, false)
	var core: PackedVector2Array = PackedVector2Array()
	if through:
		_add_column_grid(outline, basis, (base + ceiling) * 0.5)
	else:
		var distances: PackedFloat32Array = PackedFloat32Array()
		distances.resize(outline.size())
		for i: int in edges:
			distances[i] = ARCADE_DEPTH_M
		core = MeshKit.inset_edges(outline, distances)
		MeshKit.add_walls(_surface(facade), core, base, ceiling)
	var ref: PackedVector2Array = core if not core.is_empty() else MeshKit.inset(outline, ARCADE_DEPTH_M)
	for i: int in edges:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var inward: Vector2 = (ref[i] - a + ref[(i + 1) % outline.size()] - b) * 0.5
		var edge: PackedVector2Array = PackedVector2Array([a + inward.normalized() * 0.6, b + inward.normalized() * 0.6])
		var count: int = maxi(1, int(round(a.distance_to(b) / COLUMN_SPACING_M)))
		for k: int in range(count + 1):
			var q: Vector2 = edge[0].lerp(edge[1], float(k) / count)
			_columns.append(Transform3D(basis, Vector3(q.x, (base + ceiling) * 0.5, q.y)))
	return core


## Columns on a regular grid inside an outline (for an open ground floor).
func _add_column_grid(outline: PackedVector2Array, basis: Basis, y: float) -> void:
	var safe: PackedVector2Array = MeshKit.inset(outline, ARCADE_DEPTH_M)
	var bounds: Rect2 = MeshKit.bounds_of(safe)
	var x: float = bounds.position.x + COLUMN_SPACING_M * 0.5
	while x < bounds.end.x:
		var z: float = bounds.position.y + COLUMN_SPACING_M * 0.5
		while z < bounds.end.y:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), safe):
				_columns.append(Transform3D(basis, Vector3(x, y, z)))
			z += COLUMN_SPACING_M
		x += COLUMN_SPACING_M


## A wide, thin roof slab sticking out past the walls (the BRT station).
func _add_canopy_roof(outline: PackedVector2Array, top: float) -> void:
	var wide: PackedVector2Array = MeshKit.inset(outline, -2.0)
	var st: SurfaceTool = _surface(_bank.steel)
	MeshKit.add_cap(st, wide, top + 1.2)
	MeshKit.add_cap(st, wide, top + 0.9, false)
	MeshKit.add_walls(st, wide, top + 0.9, top + 1.2)


## Columns just inside the outline, at the corners and along the edges.
func _add_columns(outline: PackedVector2Array, base: float) -> void:
	var inner: PackedVector2Array = MeshKit.inset(outline, 0.8)
	var ring: PackedVector2Array = inner.duplicate()
	ring.append(inner[0])
	var points: PackedVector2Array = inner.duplicate()
	for sample: Dictionary in MeshKit.sample_polyline(ring, COLUMN_SPACING_M):
		points.append(sample["point"])
	var basis: Basis = Basis().scaled(Vector3(RAISED_COLUMN_SIZE_M, base, RAISED_COLUMN_SIZE_M))
	for q: Vector2 in points:
		_columns.append(Transform3D(basis, Vector3(q.x, base * 0.5, q.y)))


## AC units and water tanks on the roof. Positions come from a generator seeded by the
## outline, so the same building always gets the same roof (this is drawing only, not
## simulation randomness).
func _add_roof_plant(inner: PackedVector2Array, roof_level: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(inner)
	var area: float = absf(MeshKit.signed_area(inner))
	var count: int = clampi(int(area / ROOF_M2_PER_UNIT), ROOF_UNITS_MIN, ROOF_UNITS_MAX)
	var bounds: Rect2 = MeshKit.bounds_of(inner)
	var safe: PackedVector2Array = MeshKit.inset(inner, 2.0)
	var placed: int = 0
	for attempt: int in range(count * 8):
		if placed >= count:
			break
		var p: Vector2 = Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if not Geometry2D.is_point_in_polygon(p, safe):
			continue
		if rng.randf() < 0.3:
			var r: float = rng.randf_range(0.9, 1.4)
			var tank_h: float = rng.randf_range(1.8, 2.6)
			_tanks.append(Transform3D(Basis().scaled(Vector3(r, tank_h, r)), Vector3(p.x, roof_level + tank_h * 0.5, p.y)))
		else:
			var size: Vector3 = Vector3(rng.randf_range(2.0, 4.5), rng.randf_range(1.2, 2.2), rng.randf_range(1.5, 3.0))
			var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, 0.2)).scaled(size)
			_roof_units.append(Transform3D(basis, Vector3(p.x, roof_level + size.y * 0.5, p.y)))
		placed += 1


func _add_glass_tower(centre: Vector2, top: float) -> void:
	var half: float = GLASS_TOWER_SIZE_M * 0.5
	var outline: PackedVector2Array = PackedVector2Array([
		centre + Vector2(-half, -half), centre + Vector2(half, -half),
		centre + Vector2(half, half), centre + Vector2(-half, half)])
	var tower_top: float = top + GLASS_TOWER_EXTRA_M
	MeshKit.add_walls(_surface(_bank.glass), outline, 0.0, tower_top)
	MeshKit.add_cap(_surface(_bank.concrete), MeshKit.inset(outline, -0.3), tower_top)


## A flat roof on posts (covered areas, building=roof in OSM).
func _add_canopy(outline: PackedVector2Array, levels: float) -> void:
	var height: float = CANOPY_HEIGHT_M if levels <= 0.0 else minf(levels * 3.0, 6.5)
	var st: SurfaceTool = _surface(_bank.steel)
	MeshKit.add_cap(st, outline, height + 0.25)
	MeshKit.add_cap(st, outline, height, false)
	MeshKit.add_walls(st, outline, height, height + 0.25)
	for p: Vector2 in outline:
		_columns.append(Transform3D(Basis().scaled(Vector3(0.3, height, 0.3)), Vector3(p.x, height * 0.5, p.y)))


## The glass bridge between two buildings, high above the main gate.
func _add_skybridge(outline: PackedVector2Array) -> void:
	var top: float = SKYBRIDGE_BASE_M + SKYBRIDGE_HEIGHT_M
	MeshKit.add_walls(_surface(_bank.glass), outline, SKYBRIDGE_BASE_M, top)
	MeshKit.add_cap(_surface(_bank.concrete), outline, top)
	MeshKit.add_cap(_surface(_bank.concrete), outline, SKYBRIDGE_BASE_M, false)


func _add_body(id: String, outline: PackedVector2Array, base: float, top: float) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.add_walls(st, outline, base, top)
	MeshKit.add_cap(st, outline, top)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = st.commit().create_trimesh_shape()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Pick_%s" % id
	body.set_meta(&"building_id", StringName(id))
	body.add_child(shape)
	_bodies.append(body)


func _style(name: String) -> Dictionary:
	var styles: Dictionary = _looks.get("styles", {})
	return styles.get(name, styles.get("scenery", {}))


func _surface(material: Material) -> SurfaceTool:
	if not _surfaces.has(material):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[material] = st
	return _surfaces[material]


func _commit(node_name: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = node_name
	var i: int = 0
	for material: Material in _surfaces:
		var st: SurfaceTool = _surfaces[material]
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Mesh%d" % i
		instance.mesh = st.commit()
		instance.material_override = material
		root.add_child(instance)
		i += 1
	root.add_child(_multimesh(_roof_units, _box_mesh(_bank.plain(Color("c9cccb"), 0.8)), "RoofUnits"))
	root.add_child(_multimesh(_tanks, _tank_mesh(_bank.plain(Color("e3e1d8"), 0.6)), "WaterTanks"))
	root.add_child(_multimesh(_columns, _box_mesh(_bank.plain(Color("cfc9bd"), 0.8)), "Columns"))
	for body: StaticBody3D in _bodies:
		root.add_child(body)
	return root


func _reset() -> void:
	_surfaces.clear()
	_roof_units.clear()
	_tanks.clear()
	_columns.clear()
	_bodies.clear()


## Drops repeated points and the closing point, which break triangulation.
static func _clean(outline: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline:
		if result.is_empty() or result[result.size() - 1].distance_to(p) > 0.05:
			result.append(p)
	if result.size() > 1 and result[0].distance_to(result[result.size() - 1]) <= 0.05:
		result.remove_at(result.size() - 1)
	return result


static func _multimesh(transforms: Array[Transform3D], mesh: Mesh, node_name: String) -> MultiMeshInstance3D:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance


static func _box_mesh(material: Material) -> BoxMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	return box


static func _tank_mesh(material: Material) -> CylinderMesh:
	var tank: CylinderMesh = CylinderMesh.new()
	tank.top_radius = 1.0
	tank.bottom_radius = 1.0
	tank.height = 1.0
	tank.radial_segments = 12
	tank.material = material
	return tank
