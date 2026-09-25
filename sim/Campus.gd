class_name Campus
extends RefCounted
## The campus map: buildings, rooms and the walking paths between buildings.
##
## SimEngine only depends on the public methods below. The file format is in
## docs/DATA_FORMATS.md (campus.json).
##
## Sprint 1 task (see docs/ROADMAP.md): load campus.json, build the path graph and
## pre-compute shortest walking distances between every pair of buildings
## (Dijkstra from each building), so distance_m() is a dictionary lookup.

## Id of the building where students enter and leave campus.
var _entrance_id: StringName = &"ENTRANCE"


## Loads campus.json. Returns OK or an error code.
func load_from_file(path: String) -> Error:
	push_error("Campus.load_from_file is not implemented yet (%s)" % path)
	return ERR_UNAVAILABLE


func entrance_id() -> StringName:
	return _entrance_id


## Shortest walking distance in metres between two buildings (0 if same building).
func distance_m(from_building: StringName, to_building: StringName) -> float:
	push_error("Campus.distance_m is not implemented yet (%s -> %s)" % [from_building, to_building])
	return 0.0


## Buildings along the shortest path, including both ends. Used by MapView to draw walking students.
func path_between(from_building: StringName, to_building: StringName) -> Array[StringName]:
	return [from_building, to_building]


func building_ids() -> Array[StringName]:
	return []


## Position of a building on the map, in pixels.
func building_position(building_id: StringName) -> Vector2:
	return Vector2.ZERO


func room_building(room_id: StringName) -> StringName:
	return &""


func room_capacity(room_id: StringName) -> int:
	return 0


## Walking time in minutes between two buildings at the current walking speed.
## Subclasses and tests may override this; SimEngine only calls this method.
func travel_minutes(from_building: StringName, to_building: StringName) -> float:
	if from_building == to_building:
		return 0.0
	return distance_m(from_building, to_building) / maxf(Params.walking_speed_m_per_min, 1.0)
