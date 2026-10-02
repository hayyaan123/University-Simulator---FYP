extends GutTest
## Campus loading and shortest paths.

const REAL_CAMPUS: String = "res://data/campus.json"

# A -- 100 m -- W1 -- 100 m -- B, plus a long direct A -- B path of 500 m,
# and an indoor link B -- C of 30 m. Shortest A -> C is 230 m via W1 and B.
var small: Dictionary = {
	"entrance": "A",
	"buildings": [
		{"id": "A", "position": [0, 0], "kind": "transport"},
		{"id": "B", "position": [200, 0]},
		{"id": "C", "position": [200, 30]},
	],
	"waypoints": [{"id": "W1", "position": [100, 0]}],
	"rooms": [
		{"id": "B-LT1", "building": "B", "capacity": 200, "type": "lecture_hall"},
		{"id": "C-T1", "building": "C", "capacity": 30, "type": "tutorial_room"},
	],
	"paths": [
		{"from": "A", "to": "W1", "distance_m": 100},
		{"from": "W1", "to": "B", "distance_m": 100, "points": [[150, -10]]},
		{"from": "A", "to": "B", "distance_m": 500},
		{"from": "B", "to": "C", "distance_m": 30, "indoor": true},
	],
}


func before_each() -> void:
	Params.reset_to_defaults()


func after_all() -> void:
	Params.reset_to_defaults()


func _load_small() -> Campus:
	var campus: Campus = Campus.new()
	assert_eq(campus.load_from_dict(small), OK)
	return campus


func test_shortest_distance_uses_the_shorter_route() -> void:
	var campus: Campus = _load_small()
	assert_almost_eq(campus.distance_m(&"A", &"B"), 200.0, 0.001)
	assert_almost_eq(campus.distance_m(&"A", &"C"), 230.0, 0.001)
	assert_almost_eq(campus.distance_m(&"C", &"A"), 230.0, 0.001, "paths work both ways")
	assert_eq(campus.distance_m(&"B", &"B"), 0.0)


func test_path_between_lists_every_node() -> void:
	var campus: Campus = _load_small()
	assert_eq(campus.path_between(&"A", &"C"), [&"A", &"W1", &"B", &"C"] as Array[StringName])


func test_path_points_include_bends_in_the_right_direction() -> void:
	var campus: Campus = _load_small()
	var there: PackedVector2Array = campus.path_points(&"A", &"B")
	assert_eq(there, PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(150, -10), Vector2(200, 0)]))
	var back: PackedVector2Array = campus.path_points(&"B", &"A")
	assert_eq(back[1], Vector2(150, -10), "bends are reversed when walking the other way")


func test_travel_minutes_uses_walking_speed() -> void:
	var campus: Campus = _load_small()
	var expected: float = campus.distance_m(&"A", &"B") / FixedSettings.WALKING_SPEED_M_PER_MIN
	assert_gt(expected, 0.0)
	assert_almost_eq(campus.travel_minutes(&"A", &"B"), expected, 0.001)


func test_rooms() -> void:
	var campus: Campus = _load_small()
	assert_eq(campus.room_building(&"C-T1"), &"C")
	assert_eq(campus.room_capacity(&"B-LT1"), 200)
	assert_eq(campus.rooms_of_type(&"lecture_hall"), [&"B-LT1"] as Array[StringName])


func test_unreachable_building_is_an_error() -> void:
	var broken: Dictionary = small.duplicate(true)
	broken["buildings"].append({"id": "D", "position": [500, 500]})
	var campus: Campus = Campus.new()
	assert_eq(campus.load_from_dict(broken), ERR_INVALID_DATA)


func test_real_campus_loads_and_every_building_is_reachable() -> void:
	var campus: Campus = Campus.new()
	assert_eq(campus.load_from_file(REAL_CAMPUS), OK)
	assert_eq(campus.entrance_id(), &"SB5")
	assert_gt(campus.building_ids().size(), 10)
	assert_gt(campus.rooms_of_type(&"lecture_hall").size(), 0)
	for id: StringName in campus.building_ids():
		var d: float = campus.distance_m(campus.entrance_id(), id)
		assert_false(is_inf(d), "%s reachable" % id)
		assert_lt(d, 1000.0, "%s is within 1 km of the entrance" % id)
