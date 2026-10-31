@tool
extends Node3D
## The main entrance between Building 3 and Building 2: a flat white canopy with the
## "MONASH University" sign, a guardhouse with boom gates, flagpoles, red hexagon paving,
## the glass stair tower with the Monash crest, and the glass skybridge above.
##
## Local space: origin at the middle of the canopy, -Z points out to the road (north).
## Sizes come from photos (see docs/MAP_3D.md); they are estimates.

const CANOPY_SIZE: Vector3 = Vector3(18.0, 0.5, 10.0)
const CANOPY_HEIGHT_M: float = 4.6
const SIGN_SIZE: Vector3 = Vector3(12.5, 1.7, 0.4)
const GAP_HALF_WIDTH_M: float = 10.0  # B2's east wall to B3's west wall, halved
const SKYBRIDGE_BASE_M: float = 11.5
const TOWER_TOP_M: float = 30.0

const WHITE: Color = Color("efede6")
const STONE: Color = Color("4b4d52")
const PAVING_RED: Color = Color("b3563f")
const MONASH_BLUE: Color = Color("006dae")
const HEDGE_GREEN: Color = Color("3f7d34")
const HEDGE_RED: Color = Color("8e2f3a")


func _ready() -> void:
	var root: Node3D = LandmarkKit.fresh_root(self)
	_build_paving(root)
	_build_canopy(root)
	_build_guardhouse(root)
	_build_barriers(root)
	_build_flags(root)
	_build_planters(root)
	_build_tower(root)
	_build_skybridge(root)


func _build_paving(root: Node3D) -> void:
	LandmarkKit.box(root, Vector3(34.0, 0.06, 9.0), Vector3(0.0, 0.08, -9.5), LandmarkKit.material(PAVING_RED, 0.95))
	LandmarkKit.box(root, Vector3(GAP_HALF_WIDTH_M * 2.0, 0.06, 16.0), Vector3(0.0, 0.085, 2.0), LandmarkKit.material(Color("8f8c86"), 0.9))


func _build_canopy(root: Node3D) -> void:
	var white: StandardMaterial3D = LandmarkKit.material(WHITE, 0.6)
	LandmarkKit.box(root, CANOPY_SIZE, Vector3(0.0, CANOPY_HEIGHT_M + CANOPY_SIZE.y * 0.5, -1.0), white)
	for x: float in [-7.5, -2.5, 2.5, 7.5]:
		for z: float in [-5.0, 3.0]:
			LandmarkKit.cylinder(root, 0.18, CANOPY_HEIGHT_M, Vector3(x, CANOPY_HEIGHT_M * 0.5, z), LandmarkKit.material(Color("c9ccce"), 0.4))
	# The sign board on the road side of the canopy.
	var sign_z: float = -1.0 - CANOPY_SIZE.z * 0.5 - SIGN_SIZE.z * 0.5
	var sign_y: float = CANOPY_HEIGHT_M + SIGN_SIZE.y * 0.5 + 0.2
	LandmarkKit.box(root, SIGN_SIZE, Vector3(0.0, sign_y, sign_z), white)
	LandmarkKit.label(root, "MONASH University", Vector3(0.6, sign_y, sign_z - SIGN_SIZE.z * 0.5 - 0.02), 110, Color("1d2430"), PI, 0.0105)
	# The crest: a small blue shield to the left of the words (seen from the road).
	LandmarkKit.box(root, Vector3(0.9, 1.1, 0.1), Vector3(5.4, sign_y, sign_z - SIGN_SIZE.z * 0.5 - 0.05), LandmarkKit.material(MONASH_BLUE, 0.5))


func _build_guardhouse(root: Node3D) -> void:
	var glass: StandardMaterial3D = LandmarkKit.material(Color("6c9aa3"), 0.15)
	LandmarkKit.box(root, Vector3(3.0, 0.35, 5.0), Vector3(0.0, 0.25, -1.0), LandmarkKit.material(Color("b9b4aa")))
	LandmarkKit.box(root, Vector3(2.4, 2.6, 3.0), Vector3(0.0, 1.7, -1.0), glass)
	LandmarkKit.box(root, Vector3(2.8, 0.25, 3.4), Vector3(0.0, 3.1, -1.0), LandmarkKit.material(WHITE, 0.6))


## Red-and-white boom gates for the way in and the way out.
func _build_barriers(root: Node3D) -> void:
	var red: StandardMaterial3D = LandmarkKit.material(Color("c8332f"), 0.5)
	var white: StandardMaterial3D = LandmarkKit.material(WHITE, 0.5)
	for side: float in [-1.0, 1.0]:
		var post: Vector3 = Vector3(side * 1.9, 0.6, -4.2 if side < 0.0 else 2.2)
		LandmarkKit.box(root, Vector3(0.45, 1.2, 0.45), post, LandmarkKit.material(Color("d9d6cf")))
		for i: int in range(6):
			var stripe: Vector3 = post + Vector3(side * (0.55 + i * 0.6), 0.45, 0.0)
			LandmarkKit.box(root, Vector3(0.6, 0.12, 0.12), stripe, red if i % 2 == 0 else white)


func _build_flags(root: Node3D) -> void:
	var pole: StandardMaterial3D = LandmarkKit.material(Color("d7d9db"), 0.3)
	var colours: Array[Color] = [Color("cc0001"), MONASH_BLUE, Color("cc0001"), Color("ffcc00")]
	for i: int in range(colours.size()):
		var x: float = 11.5 + i * 2.2
		LandmarkKit.cylinder(root, 0.07, 10.0, Vector3(x, 5.0, -11.5), pole)
		LandmarkKit.box(root, Vector3(1.8, 1.0, 0.04), Vector3(x + 0.95, 9.3, -11.5), LandmarkKit.material(colours[i], 0.7))


## Low planters with green and maroon hedges, like the ones in front of the gate.
func _build_planters(root: Node3D) -> void:
	var kerb: StandardMaterial3D = LandmarkKit.material(Color("cfcac0"))
	for x: float in [-13.0, 13.0]:
		LandmarkKit.box(root, Vector3(7.0, 0.5, 2.2), Vector3(x, 0.25, -6.0), kerb)
		LandmarkKit.box(root, Vector3(6.6, 0.55, 0.9), Vector3(x, 0.75, -6.5), LandmarkKit.material(HEDGE_RED, 0.95))
		LandmarkKit.box(root, Vector3(6.6, 0.75, 0.9), Vector3(x, 0.85, -5.5), LandmarkKit.material(HEDGE_GREEN, 0.95))
	root.add_child(ModelLibrary.instance(ModelLibrary.NATURE + "tree_palmDetailedTall.glb", 9.0, Vector3(-15.0, 0.0, -9.0)))
	root.add_child(ModelLibrary.instance(ModelLibrary.NATURE + "tree_palmTall.glb", 8.0, Vector3(16.0, 0.0, -8.0), 1.2))


## The tall glass stair tower on Building 2's corner, with the crest near the top.
func _build_tower(root: Node3D) -> void:
	var centre: Vector3 = Vector3(-GAP_HALF_WIDTH_M - 2.4, TOWER_TOP_M * 0.5, 5.0)
	LandmarkKit.box(root, Vector3(5.2, TOWER_TOP_M, 5.2), centre, LandmarkKit.material(Color("2f5a63"), 0.15))
	LandmarkKit.box(root, Vector3(5.8, 0.6, 5.8), Vector3(centre.x, TOWER_TOP_M + 0.3, centre.z), LandmarkKit.material(Color("c9c3b6")))
	LandmarkKit.box(root, Vector3(1.0, TOWER_TOP_M, 5.4), Vector3(centre.x + 2.6, TOWER_TOP_M * 0.5, centre.z), LandmarkKit.material(STONE))
	var crest_y: float = TOWER_TOP_M - 3.5
	LandmarkKit.box(root, Vector3(2.6, 3.2, 0.2), Vector3(centre.x, crest_y, centre.z - 2.7), LandmarkKit.material(Color("d9d4c8")))
	LandmarkKit.box(root, Vector3(2.0, 2.4, 0.15), Vector3(centre.x, crest_y, centre.z - 2.85), LandmarkKit.material(MONASH_BLUE, 0.5))
	LandmarkKit.box(root, Vector3(1.6, 0.35, 0.1), Vector3(centre.x, crest_y + 0.2, centre.z - 2.95), LandmarkKit.material(Color("f2c230"), 0.5))


## The glass skybridge joining Building 3 and Building 2 above the gate.
func _build_skybridge(root: Node3D) -> void:
	var glass: StandardMaterial3D = LandmarkKit.material(Color("4f8a8c"), 0.1)
	var frame: StandardMaterial3D = LandmarkKit.material(Color("c8cdd0"), 0.4)
	var y: float = SKYBRIDGE_BASE_M
	LandmarkKit.box(root, Vector3(GAP_HALF_WIDTH_M * 2.0 + 1.0, 3.2, 4.6), Vector3(0.0, y + 1.6, 7.0), glass)
	LandmarkKit.box(root, Vector3(GAP_HALF_WIDTH_M * 2.0 + 1.4, 0.5, 5.0), Vector3(0.0, y - 0.25, 7.0), frame)
	LandmarkKit.box(root, Vector3(GAP_HALF_WIDTH_M * 2.0 + 1.4, 0.4, 5.0), Vector3(0.0, y + 3.4, 7.0), frame)
