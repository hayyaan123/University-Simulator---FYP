class_name Campus
extends RefCounted
## The campus map: buildings, rooms and the walking paths between them.
##
## SimEngine only calls entrance_id() and travel_minutes(). The file format is in
## docs/DATA_FORMATS.md (campus.json).
##
## The walking network is a graph. Its nodes are buildings plus waypoints (path
## junctions), and its links are paths with a length in metres. On load, Dijkstra
## runs once from every building, so distance_m() and path_between() are lookups.

## Id of the building where students enter and leave campus.
var _entrance_id: StringName = &"ENTRANCE"
var _entrances: Array[StringName] = []
var _building_ids: Array[StringName] = []
var _buildings: Dictionary = {}      # StringName -> {name, kind, levels, outline: PackedVector2Array}
var _rooms: Dictionary = {}          # StringName -> {building: StringName, capacity: int, type: StringName}
var _scenery: Array[PackedVector2Array] = []

# Graph, by node index.
var _node_ids: Array[StringName] = []
var _node_index: Dictionary = {}     # StringName -> int
var _node_pos: PackedVector2Array = PackedVector2Array()
var _adjacent: Array[Array] = []     # node index -> Array of [neighbour index, edge index]
var _edges: Array[Dictionary] = []   # {a: int, b: int, distance_m: float, indoor: bool, points: PackedVector2Array}

# Shortest paths from each building: building id -> {dist: PackedFloat64Array, prev: PackedInt32Array}.
var _shortest: Dictionary = {}


## Loads campus.json. Returns OK or an error code.
func load_from_file(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Campus: can't open %s" % path)
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Campus: %s is not a JSON object" % path)
		return ERR_PARSE_ERROR
	return load_from_dict(parsed)


## Loads campus data that is already parsed (used by load_from_file and by tests).
func load_from_dict(data: Dictionary) -> Error:
	_clear()
	for building: Dictionary in data.get("buildings", []):
		var id: StringName = StringName(building["id"])
		_building_ids.append(id)
		_buildings[id] = {
			"name": String(building.get("name", id)),
			"kind": StringName(building.get("kind", "teaching")),
			"levels": int(building.get("levels", 1)),
			"outline": _to_points(building.get("outline", [])),
		}
		_add_node(id, _to_vector(building["position"]))
	for waypoint: Dictionary in data.get("waypoints", []):
		_add_node(StringName(waypoint["id"]), _to_vector(waypoint["position"]))
	for room: Dictionary in data.get("rooms", []):
		var building_id: StringName = StringName(room["building"])
		if not _buildings.has(building_id):
			push_error("Campus: room %s is in unknown building %s" % [room["id"], building_id])
			return ERR_INVALID_DATA
		_rooms[StringName(room["id"])] = {
			"building": building_id,
			"capacity": int(room["capacity"]),
			"type": StringName(room.get("type", "tutorial_room")),
		}
	for path: Dictionary in data.get("paths", []):
		var err: Error = _add_edge(path)
		if err != OK:
			return err
	for outline: Array in data.get("scenery", []):
		_scenery.append(_to_points(outline))

	_entrance_id = StringName(data.get("entrance", "ENTRANCE"))
	for id: Variant in data.get("entrances", [_entrance_id]):
		_entrances.append(StringName(id))
	if not _buildings.has(_entrance_id):
		push_error("Campus: entrance %s is not a building" % _entrance_id)
		return ERR_INVALID_DATA

	_compute_shortest_paths()
	for id: StringName in _building_ids:
		if is_inf(distance_m(_entrance_id, id)):
			push_error("Campus: building %s can't be reached from the entrance" % id)
			return ERR_INVALID_DATA
	return OK


func entrance_id() -> StringName:
	return _entrance_id


## All places students can arrive at or leave from (the first one is entrance_id()).
func entrances() -> Array[StringName]:
	return _entrances.duplicate()


## Shortest walking distance in metres between two buildings (0 if same building, INF if unreachable).
func distance_m(from_building: StringName, to_building: StringName) -> float:
	if from_building == to_building:
		return 0.0
	if not _shortest.has(from_building) or not _node_index.has(to_building):
		push_error("Campus: unknown building %s or %s" % [from_building, to_building])
		return INF
	var dist: PackedFloat64Array = _shortest[from_building]["dist"]
	return dist[_node_index[to_building]]


## Nodes (buildings and waypoints) along the shortest path, including both ends.
func path_between(from_building: StringName, to_building: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for index: int in _path_indices(from_building, to_building):
		result.append(_node_ids[index])
	return result


## The shortest walking route as map points (pixels), including the bends inside each path.
## MapView uses this to move walking students along the real footpaths.
func path_points(from_building: StringName, to_building: StringName) -> PackedVector2Array:
	var indices: PackedInt32Array = _path_indices(from_building, to_building)
	var points: PackedVector2Array = PackedVector2Array()
	if indices.is_empty():
		return points
	points.append(_node_pos[indices[0]])
	for i: int in range(1, indices.size()):
		var edge: Dictionary = _edges[_edge_between(indices[i - 1], indices[i])]
		var bends: PackedVector2Array = edge["points"]
		if edge["a"] != indices[i - 1]:
			bends = _reversed(bends)
		points.append_array(bends)
		points.append(_node_pos[indices[i]])
	return points


func building_ids() -> Array[StringName]:
	return _building_ids.duplicate()


## Position of a building (or waypoint) on the map, in pixels.
func building_position(building_id: StringName) -> Vector2:
	if not _node_index.has(building_id):
		push_error("Campus: unknown building %s" % building_id)
		return Vector2.ZERO
	return _node_pos[_node_index[building_id]]


func building_name(building_id: StringName) -> String:
	return _buildings[building_id]["name"]


## teaching, library, link, sports, transport, residence or parking.
func building_kind(building_id: StringName) -> StringName:
	return _buildings[building_id]["kind"]


func building_outline(building_id: StringName) -> PackedVector2Array:
	return _buildings[building_id]["outline"]


func room_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_rooms.keys())
	return result


## Rooms of one type (lecture_hall, tutorial_room or lab), in file order.
func rooms_of_type(room_type: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _rooms:
		if _rooms[id]["type"] == room_type:
			result.append(id)
	return result


func room_building(room_id: StringName) -> StringName:
	return _rooms[room_id]["building"] if _rooms.has(room_id) else &""


func room_capacity(room_id: StringName) -> int:
	return _rooms[room_id]["capacity"] if _rooms.has(room_id) else 0


func room_type(room_id: StringName) -> StringName:
	return _rooms[room_id]["type"] if _rooms.has(room_id) else &""


## Every path as map points, for drawing: [{points: PackedVector2Array, indoor: bool}].
func paths_for_drawing() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: Dictionary in _edges:
		var points: PackedVector2Array = PackedVector2Array([_node_pos[edge["a"]]])
		points.append_array(edge["points"])
		points.append(_node_pos[edge["b"]])
		result.append({"points": points, "indoor": edge["indoor"]})
	return result


## Outlines of other buildings in the area (not simulated, drawn for context).
func scenery_outlines() -> Array[PackedVector2Array]:
	return _scenery.duplicate()


## Walking time in minutes between two buildings at the current walking speed.
## Subclasses and tests may override this; SimEngine only calls this method.
func travel_minutes(from_building: StringName, to_building: StringName) -> float:
	if from_building == to_building:
		return 0.0
	return distance_m(from_building, to_building) / FixedSettings.WALKING_SPEED_M_PER_MIN


func _clear() -> void:
	_entrances.clear()
	_building_ids.clear()
	_buildings.clear()
	_rooms.clear()
	_scenery.clear()
	_node_ids.clear()
	_node_index.clear()
	_node_pos = PackedVector2Array()
	_adjacent.clear()
	_edges.clear()
	_shortest.clear()


func _add_node(id: StringName, position: Vector2) -> void:
	_node_index[id] = _node_ids.size()
	_node_ids.append(id)
	_node_pos.append(position)
	_adjacent.append([])


func _add_edge(path: Dictionary) -> Error:
	var from_id: StringName = StringName(path["from"])
	var to_id: StringName = StringName(path["to"])
	if not _node_index.has(from_id) or not _node_index.has(to_id):
		push_error("Campus: path %s -> %s uses an unknown building or waypoint" % [from_id, to_id])
		return ERR_INVALID_DATA
	var distance: float = float(path["distance_m"])
	if distance < 0.0:
		push_error("Campus: path %s -> %s has a negative distance" % [from_id, to_id])
		return ERR_INVALID_DATA
	var a: int = _node_index[from_id]
	var b: int = _node_index[to_id]
	var edge_index: int = _edges.size()
	_edges.append({
		"a": a, "b": b, "distance_m": distance,
		"indoor": bool(path.get("indoor", false)),
		"points": _to_points(path.get("points", [])),
	})
	_adjacent[a].append([b, edge_index])
	_adjacent[b].append([a, edge_index])
	return OK


func _compute_shortest_paths() -> void:
	_shortest.clear()
	for id: StringName in _building_ids:
		_shortest[id] = _dijkstra(_node_index[id])


## Dijkstra with a binary heap. Returns {dist, prev} over every node.
func _dijkstra(source: int) -> Dictionary:
	var count: int = _node_ids.size()
	var dist: PackedFloat64Array = PackedFloat64Array()
	var prev: PackedInt32Array = PackedInt32Array()
	dist.resize(count)
	prev.resize(count)
	dist.fill(INF)
	prev.fill(-1)
	dist[source] = 0.0
	var heap: MinHeap = MinHeap.new()
	heap.push(0.0, source)
	while not heap.is_empty():
		var top: Array = heap.pop()
		var node: int = top[1]
		if top[0] > dist[node]:
			continue  # A shorter route to this node was already found.
		for link: Array in _adjacent[node]:
			var next: int = link[0]
			var candidate: float = dist[node] + float(_edges[link[1]]["distance_m"])
			if candidate < dist[next]:
				dist[next] = candidate
				prev[next] = node
				heap.push(candidate, next)
	return {"dist": dist, "prev": prev}


func _path_indices(from_building: StringName, to_building: StringName) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if not _shortest.has(from_building) or not _node_index.has(to_building):
		push_error("Campus: unknown building %s or %s" % [from_building, to_building])
		return result
	var prev: PackedInt32Array = _shortest[from_building]["prev"]
	var node: int = _node_index[to_building]
	var source: int = _node_index[from_building]
	while node != -1:
		result.append(node)
		if node == source:
			break
		node = prev[node]
	if result[result.size() - 1] != source:
		return PackedInt32Array()  # Unreachable.
	result.reverse()
	return result


## Index of the shortest edge between two neighbouring nodes.
func _edge_between(a: int, b: int) -> int:
	var best: int = -1
	for link: Array in _adjacent[a]:
		if link[0] == b and (best == -1 or _edges[link[1]]["distance_m"] < _edges[best]["distance_m"]):
			best = link[1]
	return best


static func _to_vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


static func _to_points(values: Array) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for value: Array in values:
		points.append(_to_vector(value))
	return points


static func _reversed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	result.reverse()
	return result


## Small binary min-heap of (priority, id) pairs. Priorities are kept as 64-bit floats
## so a distance never compares as larger than itself.
class MinHeap:
	var _priorities: PackedFloat64Array = PackedFloat64Array()
	var _ids: PackedInt32Array = PackedInt32Array()

	func push(priority: float, id: int) -> void:
		_priorities.append(priority)
		_ids.append(id)
		var i: int = _ids.size() - 1
		while i > 0:
			var parent: int = (i - 1) / 2
			if _priorities[parent] <= _priorities[i]:
				break
			_swap(i, parent)
			i = parent

	## Removes the smallest pair and returns it as [priority, id].
	func pop() -> Array:
		var top: Array = [_priorities[0], _ids[0]]
		var last: int = _ids.size() - 1
		_swap(0, last)
		_priorities.resize(last)
		_ids.resize(last)
		var i: int = 0
		while true:
			var smallest: int = i
			for child: int in [2 * i + 1, 2 * i + 2]:
				if child < last and _priorities[child] < _priorities[smallest]:
					smallest = child
			if smallest == i:
				break
			_swap(i, smallest)
			i = smallest
		return top

	func is_empty() -> bool:
		return _ids.is_empty()

	func _swap(a: int, b: int) -> void:
		var priority: float = _priorities[a]
		_priorities[a] = _priorities[b]
		_priorities[b] = priority
		var id: int = _ids[a]
		_ids[a] = _ids[b]
		_ids[b] = id
