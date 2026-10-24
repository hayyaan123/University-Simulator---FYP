@tool
extends Node3D
## The cafeteria on the ground floor of Building 6, opening onto the courtyard between
## B6 and B5/B9: a shade awning along the wall, a "Cafeteria" sign, outdoor tables with
## umbrellas, and a drinks kiosk. The indoor food court is in interiors/CanteenHall.
##
## Local space: origin in the middle of the courtyard, -Z points at Building 6's wall.

## Distance from the origin to Building 6's east wall.
const WALL_Z_M: float = -10.0
const AWNING_SIZE: Vector3 = Vector3(18.0, 0.18, 5.0)
const AWNING_HEIGHT_M: float = 3.3
const TABLE_ROWS: int = 3
const TABLE_COLUMNS: int = 4
const TABLE_SPACING: Vector2 = Vector2(4.2, 3.8)
const UMBRELLA_COLOURS: Array[Color] = [Color("e07a2e"), Color("f2efe6"), Color("2f6db3")]


func _ready() -> void:
	var root: Node3D = LandmarkKit.fresh_root(self)
	_build_awning(root)
	_build_sign(root)
	_build_tables(root)
	_build_kiosk(root)


func _build_awning(root: Node3D) -> void:
	var fabric: StandardMaterial3D = LandmarkKit.material(Color("d9702b"), 0.85)
	var z: float = WALL_Z_M + AWNING_SIZE.z * 0.5
	LandmarkKit.box(root, AWNING_SIZE, Vector3(0.0, AWNING_HEIGHT_M, z), fabric)
	var post: StandardMaterial3D = LandmarkKit.material(Color("3a3d40"), 0.4)
	for x: float in [-8.5, -4.25, 0.0, 4.25, 8.5]:
		LandmarkKit.cylinder(root, 0.08, AWNING_HEIGHT_M, Vector3(x, AWNING_HEIGHT_M * 0.5, WALL_Z_M + AWNING_SIZE.z - 0.2), post)


func _build_sign(root: Node3D) -> void:
	var y: float = AWNING_HEIGHT_M + 1.2
	LandmarkKit.box(root, Vector3(7.0, 1.1, 0.15), Vector3(0.0, y, WALL_Z_M + 0.1), LandmarkKit.material(Color("1d2a3a"), 0.6))
	LandmarkKit.label(root, "CAFETERIA", Vector3(0.0, y, WALL_Z_M + 0.2), 72, Color("ffd07a"), 0.0, 0.012)


func _build_tables(root: Node3D) -> void:
	var start: Vector2 = Vector2(-(TABLE_COLUMNS - 1) * TABLE_SPACING.x * 0.5, WALL_Z_M + AWNING_SIZE.z + 2.0)
	for row: int in range(TABLE_ROWS):
		for column: int in range(TABLE_COLUMNS):
			var p: Vector3 = Vector3(start.x + column * TABLE_SPACING.x, 0.1, start.y + row * TABLE_SPACING.y)
			_add_table_set(root, p, row * TABLE_COLUMNS + column)
	# Long tables under the awning.
	for x: float in [-6.0, 0.0, 6.0]:
		root.add_child(ModelLibrary.instance(ModelLibrary.FURNITURE + "table.glb", 0.78, Vector3(x, 0.1, WALL_Z_M + 2.2)))
		for dx: float in [-1.0, 0.0, 1.0]:
			root.add_child(ModelLibrary.instance(ModelLibrary.FURNITURE + "chair.glb", 0.9, Vector3(x + dx, 0.1, WALL_Z_M + 3.2), PI))
			root.add_child(ModelLibrary.instance(ModelLibrary.FURNITURE + "chair.glb", 0.9, Vector3(x + dx, 0.1, WALL_Z_M + 1.2)))


## A round table, four chairs and an umbrella.
func _add_table_set(root: Node3D, p: Vector3, index: int) -> void:
	root.add_child(ModelLibrary.instance(ModelLibrary.FURNITURE + "tableRound.glb", 0.75, p))
	for k: int in range(4):
		var angle: float = k * PI * 0.5 + 0.4
		var seat: Vector3 = p + Vector3(sin(angle), 0.0, cos(angle)) * 1.0
		root.add_child(ModelLibrary.instance(ModelLibrary.FURNITURE + "chair.glb", 0.9, seat, angle + PI))
	var colour: Color = UMBRELLA_COLOURS[index % UMBRELLA_COLOURS.size()]
	LandmarkKit.cylinder(root, 0.05, 2.5, p + Vector3(0.0, 1.25, 0.0), LandmarkKit.material(Color("d0d0d0"), 0.4))
	LandmarkKit.cylinder(root, 1.6, 0.6, p + Vector3(0.0, 2.55, 0.0), LandmarkKit.material(colour, 0.8), 0.05, 8)


func _build_kiosk(root: Node3D) -> void:
	var p: Vector3 = Vector3(9.5, 0.0, 4.5)
	LandmarkKit.box(root, Vector3(3.0, 2.4, 2.2), p + Vector3(0.0, 1.2, 0.0), LandmarkKit.material(Color("f1ebdc"), 0.7))
	LandmarkKit.box(root, Vector3(3.4, 0.15, 3.0), p + Vector3(0.0, 2.6, -0.3), LandmarkKit.material(Color("2f6db3"), 0.7))
	LandmarkKit.box(root, Vector3(2.6, 0.9, 0.1), p + Vector3(0.0, 1.5, -1.12), LandmarkKit.material(Color("ffe2a8"), 0.5, 0.4))
	LandmarkKit.label(root, "DRINKS", p + Vector3(0.0, 2.15, -1.13), 48, Color("2f6db3"), PI, 0.01)
