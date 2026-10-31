class_name PropScatter
extends RefCounted
## Places trees, hedges, parked cars and street lamps around the campus, using the
## Kenney CC0 models in assets/third_party (credits in assets/third_party/CREDITS.md).
##
## Every prop type is one MultiMesh, so thousands of props stay cheap. Positions come
## from a generator with a fixed seed: the same map always gets the same props (this is
## drawing only, not simulation randomness).

const NATURE: String = ModelLibrary.NATURE
const CARS: String = ModelLibrary.CARS
const ROADS: String = ModelLibrary.ROADS
const SEED: int = 20261025
const GRID_CELL_M: float = 2.0

## Model -> height in metres (trees, lamps) used to scale the Kenney models.
const PALMS: Dictionary = {"tree_palmTall": 11.0, "tree_palmDetailedTall": 12.0, "tree_palm": 9.0, "tree_palmBend": 9.0}
const BROADLEAF: Dictionary = {"tree_default": 10.0, "tree_detailed": 11.0, "tree_fat": 9.0, "tree_oak": 12.0}
const BUSHES: Dictionary = {"plant_bushLarge": 1.9, "plant_bush": 1.5, "plant_bushDetailed": 1.6}
## Car model -> length in metres.
const CAR_MODELS: Dictionary = {
	"sedan": 4.6, "suv": 4.7, "hatchback-sports": 4.2, "taxi": 4.6, "van": 5.0,
	"sedan-sports": 4.5, "suv-luxury": 4.9,
}
const LAMP_MODEL: String = "light-square"
const LAMP_HEIGHT_M: float = 6.5
## How far the lamp's arm reaches out over the road (the Kenney model's arm, scaled).
const LAMP_ARM_M: float = 2.0

const WOOD_SPACING_M: float = 8.0
const STREET_TREE_SPACING_M: float = 15.0
const PATH_TREE_SPACING_M: float = 13.0
const CAMPUS_FILL_M2_PER_TREE: float = 260.0
const HEDGE_SPACING_M: float = 3.2
const LAMP_SPACING_M: float = 26.0
const CAR_SLOT_M: Vector2 = Vector2(2.8, 5.6)
const CAR_AISLE_M: float = 6.5
const PARKED_SHARE: float = 0.72
## Roads that get a row of trees on each side.
const STREET_KINDS: PackedStringArray = ["secondary", "tertiary", "residential", "unclassified", "secondary_link"]
const PATH_KINDS: PackedStringArray = ["footway", "pedestrian", "path"]

var _frame: MapFrame
var _bank: MaterialBank
var _campus: Dictionary
var _ground: Dictionary
var _grid: OccupancyGrid
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _placed: Dictionary = {}  # model path -> Array[Transform3D]
var _lamp_heads: Array[Vector3] = []
var _clear_zones: Array[Dictionary] = []  # {centre: Vector2, radius: float}
var _no_hedges: PackedStringArray = PackedStringArray()


func _init(frame: MapFrame, bank: MaterialBank, campus_data: Dictionary, ground_data: Dictionary) -> void:
	_frame = frame
	_bank = bank
	_campus = campus_data
	_ground = ground_data
	_rng.seed = SEED


## No hedges around this building (an open ground floor people walk into). Call before build().
func skip_hedges(building_id: String) -> void:
	_no_hedges.append(building_id)


## Keeps props out of a circle (around a landmark, say). Call before build().
func clear_zone(centre: Vector2, radius_m: float) -> void:
	_clear_zones.append({"centre": centre, "radius": radius_m})


func build() -> Node3D:
	_build_grid()
	_place_lamps()
	_place_cars()
	_place_hedges()
	_place_street_trees()
	_place_path_trees()
	_place_wood_trees()
	_place_campus_fill()
	return _commit()


## Positions of lamp heads (for night glow), filled by build().
func lamp_heads() -> Array[Vector3]:
	return _lamp_heads


func _build_grid() -> void:
	var b: Array = _ground.get("bounds", [0, 0, 1600, 900])
	var a: Vector2 = _frame.to_plane(Vector2(b[0], b[1]))
	var c: Vector2 = _frame.to_plane(Vector2(b[2], b[3]))
	_grid = OccupancyGrid.new(Rect2(a, c - a).abs(), GRID_CELL_M)
	for building: Dictionary in _campus.get("buildings", []):
		if building.get("kind", "") != "parking":
			_grid.block_polygon(_plane(building["outline"]), 2.5)
	for building: Dictionary in _ground.get("buildings", []):
		_grid.block_polygon(_plane(building["outline"]), 2.0)
	for area: Dictionary in _ground.get("areas", []):
		if area["kind"] in ["water", "pool", "pitch", "parking"]:
			_grid.block_polygon(_plane(area["outline"]), 1.0)
	for road: Dictionary in _ground.get("roads", []):
		if not road.get("bridge", false):
			_grid.block_polyline(_plane(road["points"]), float(road["width_m"]) + 2.0)
	for zone: Dictionary in _clear_zones:
		_grid.block_circle(zone["centre"], zone["radius"])


func _place_lamps() -> void:
	for road: Dictionary in _ground.get("roads", []):
		var kind: String = road["kind"]
		if road.get("bridge", false) or not (kind in STREET_KINDS or kind in PATH_KINDS):
			continue
		var points: PackedVector2Array = _plane(road["points"])
		var offset: float = float(road["width_m"]) * 0.5 + 0.8
		var side: float = 1.0
		for sample: Dictionary in MeshKit.sample_polyline(points, LAMP_SPACING_M):
			var dir: Vector2 = sample["dir"]
			var normal: Vector2 = Vector2(-dir.y, dir.x) * side
			var p: Vector2 = sample["point"] + normal * offset
			side = -side
			if not _grid.is_free(p):
				continue
			# The model's arm points along its -Z; turn it to reach back over the road.
			var yaw: float = atan2(normal.x, normal.y)
			_put(ROADS + LAMP_MODEL + ".glb", p, yaw, LAMP_HEIGHT_M)
			_lamp_heads.append(Vector3(p.x - normal.x * LAMP_ARM_M, LAMP_HEIGHT_M - 0.35, p.y - normal.y * LAMP_ARM_M))
			_grid.block_circle(p, 1.5)


func _place_cars() -> void:
	var names: Array = CAR_MODELS.keys()
	for area: Dictionary in _ground.get("areas", []):
		if area["kind"] != "parking":
			continue
		var outline: PackedVector2Array = _plane(area["outline"])
		var safe: PackedVector2Array = MeshKit.inset(outline, 2.5)
		var axis: Vector2 = _longest_edge_dir(outline)
		var across: Vector2 = Vector2(-axis.y, axis.x)
		var centre: Vector2 = MeshKit.centre_of(outline)
		var reach: float = MeshKit.bounds_of(outline).size.length()
		var row_pitch: float = CAR_SLOT_M.y * 2.0 + CAR_AISLE_M
		var row: float = -reach
		while row < reach:
			for half: int in range(2):
				var row_offset: float = row + half * CAR_SLOT_M.y
				var t: float = -reach
				while t < reach:
					var p: Vector2 = centre + axis * t + across * row_offset
					if Geometry2D.is_point_in_polygon(p, safe) and _rng.randf() < PARKED_SHARE:
						var name: String = names[_rng.randi() % names.size()]
						var yaw: float = atan2(across.x, across.y) + (PI if half == 1 else 0.0)
						_put_car(CARS + name + ".glb", p, yaw, CAR_MODELS[name])
					t += CAR_SLOT_M.x
			row += row_pitch


func _place_hedges() -> void:
	for building: Dictionary in _campus.get("buildings", []):
		if building.get("kind", "") in ["parking", "transport", "link"] or _no_hedges.has(building["id"]):
			continue
		var outline: PackedVector2Array = MeshKit.inset(_plane(building["outline"]), -1.6)
		var ring: PackedVector2Array = outline.duplicate()
		ring.append(outline[0])
		for sample: Dictionary in MeshKit.sample_polyline(ring, HEDGE_SPACING_M):
			var p: Vector2 = sample["point"]
			if _rng.randf() < 0.75 and _free_for_hedge(p):
				var bush: String = _pick(BUSHES)
				_put(NATURE + bush + ".glb", p, _rng.randf() * TAU, float(BUSHES[bush]) * _rng.randf_range(0.8, 1.3))


func _place_street_trees() -> void:
	for road: Dictionary in _ground.get("roads", []):
		if road.get("bridge", false) or not (road["kind"] in STREET_KINDS):
			continue
		var points: PackedVector2Array = _plane(road["points"])
		var offset: float = float(road["width_m"]) * 0.5 + 3.2
		for sample: Dictionary in MeshKit.sample_polyline(points, STREET_TREE_SPACING_M):
			var dir: Vector2 = sample["dir"]
			for side: float in [1.0, -1.0]:
				var p: Vector2 = sample["point"] + Vector2(-dir.y, dir.x) * side * offset
				_try_tree(p, PALMS if road["kind"].begins_with("secondary") else BROADLEAF, 3.0)


func _place_path_trees() -> void:
	for road: Dictionary in _ground.get("roads", []):
		if road.get("bridge", false) or not (road["kind"] in PATH_KINDS):
			continue
		var points: PackedVector2Array = _plane(road["points"])
		for sample: Dictionary in MeshKit.sample_polyline(points, PATH_TREE_SPACING_M):
			var dir: Vector2 = sample["dir"]
			var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
			var p: Vector2 = sample["point"] + Vector2(-dir.y, dir.x) * side * (float(road["width_m"]) * 0.5 + 2.5)
			_try_tree(p, PALMS, 2.5)


func _place_wood_trees() -> void:
	for area: Dictionary in _ground.get("areas", []):
		if area["kind"] != "wood":
			continue
		var outline: PackedVector2Array = _plane(area["outline"])
		var bounds: Rect2 = MeshKit.bounds_of(outline)
		var y: float = bounds.position.y
		while y < bounds.end.y:
			var x: float = bounds.position.x
			while x < bounds.end.x:
				var p: Vector2 = Vector2(x, y) + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
				if Geometry2D.is_point_in_polygon(p, outline):
					_try_tree(p, BROADLEAF if _rng.randf() < 0.8 else PALMS, 3.0)
				x += WOOD_SPACING_M
			y += WOOD_SPACING_M


func _place_campus_fill() -> void:
	for area: Dictionary in _ground.get("areas", []):
		if area["kind"] != "campus":
			continue
		var outline: PackedVector2Array = _plane(area["outline"])
		var bounds: Rect2 = MeshKit.bounds_of(outline)
		var count: int = int(absf(MeshKit.signed_area(outline)) / CAMPUS_FILL_M2_PER_TREE)
		for i: int in range(count):
			var p: Vector2 = Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), _rng.randf_range(bounds.position.y, bounds.end.y))
			if Geometry2D.is_point_in_polygon(p, outline):
				_try_tree(p, PALMS if _rng.randf() < 0.45 else BROADLEAF, 3.5)


func _try_tree(p: Vector2, kinds: Dictionary, spacing_m: float) -> void:
	if not _grid.is_free(p):
		return
	var name: String = _pick(kinds)
	_put(NATURE + name + ".glb", p, _rng.randf() * TAU, float(kinds[name]) * _rng.randf_range(0.8, 1.2))
	_grid.block_circle(p, spacing_m)


func _free_for_hedge(p: Vector2) -> bool:
	# Hedges hug buildings, so only check that they stay off roads and water.
	for road: Dictionary in _ground.get("roads", []):
		if road.get("bridge", false):
			continue
		var points: PackedVector2Array = _plane(road["points"])
		var rect: Rect2 = MeshKit.bounds_of(points).grow(float(road["width_m"]))
		if rect.has_point(p) and MeshKit.distance_to_polyline(p, points) < float(road["width_m"]) * 0.5 + 0.6:
			return false
	return true


## Records one prop, scaled so its height matches `size_m`.
func _put(path: String, p: Vector2, yaw: float, size_m: float) -> void:
	var model: Dictionary = ModelLibrary.get_model(path)
	if model.is_empty():
		return
	var size: Vector3 = model["size"]
	var scale: float = size_m / maxf(0.001, size.y)
	_record(path, model, p, yaw, scale)


func _put_car(path: String, p: Vector2, yaw: float, length_m: float) -> void:
	var model: Dictionary = ModelLibrary.get_model(path)
	if model.is_empty():
		return
	var size: Vector3 = model["size"]
	_record(path, model, p, yaw, length_m / maxf(0.001, maxf(size.x, size.z)))


func _record(path: String, model: Dictionary, p: Vector2, yaw: float, scale: float) -> void:
	var placement: Transform3D = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), Vector3(p.x, 0.0, p.y))
	if not _placed.has(path):
		_placed[path] = [] as Array[Transform3D]
	var list: Array[Transform3D] = _placed[path]
	list.append(placement * (model["base"] as Transform3D))


func _commit() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Props"
	for path: String in _placed:
		var transforms: Array[Transform3D] = _placed[path]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = ModelLibrary.get_model(path)["mesh"]
		multimesh.instance_count = transforms.size()
		for i: int in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = path.get_file().get_basename().to_pascal_case()
		instance.multimesh = multimesh
		# Only trees cast shadows; small props aren't worth the cost on laptop GPUs.
		if not path.get_file().begins_with("tree_"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	root.add_child(_lamp_glow())
	return root


## Small glowing blocks at each lamp head, lit by the night setting in MaterialBank.
func _lamp_glow() -> MultiMeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.7, 0.25, 0.7)
	box.material = _bank.lamp_glow
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = _lamp_heads.size()
	for i: int in range(_lamp_heads.size()):
		multimesh.set_instance_transform(i, Transform3D(Basis(), _lamp_heads[i]))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "LampGlow"
	instance.multimesh = multimesh
	return instance


func _pick(kinds: Dictionary) -> String:
	var names: Array = kinds.keys()
	return names[_rng.randi() % names.size()]


func _plane(points_json: Array) -> PackedVector2Array:
	return _frame.to_plane_points(MapFrame.points_from_json(points_json))


static func _longest_edge_dir(outline: PackedVector2Array) -> Vector2:
	var best: Vector2 = Vector2.RIGHT
	var best_length: float = 0.0
	for i: int in range(outline.size()):
		var edge: Vector2 = outline[(i + 1) % outline.size()] - outline[i]
		if edge.length() > best_length:
			best_length = edge.length()
			best = edge.normalized()
	return best
