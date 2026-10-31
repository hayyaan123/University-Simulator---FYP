class_name MapFrame
extends RefCounted
## Converts 2D map pixels (campus.json) into 3D world metres, so the 3D map lines up with
## the 2D map and the walking graph.
##
## 2D x maps to 3D x and 2D y maps to 3D z. One 3D unit is one metre. The origin is moved
## to the middle of the 2D view so the campus sits near (0, 0, 0).

## Middle of the 1600 x 900 view that campus.json is fitted into.
const VIEW_CENTRE_PX: Vector2 = Vector2(800.0, 450.0)

var metres_per_pixel: float = 1.0


func _init(metres_per_px: float = 1.0) -> void:
	metres_per_pixel = metres_per_px


## A map pixel as a ground-plane point in metres (x, z).
func to_plane(px: Vector2) -> Vector2:
	return (px - VIEW_CENTRE_PX) * metres_per_pixel


## A map pixel as a 3D point at a height in metres.
func to_world(px: Vector2, height_m: float = 0.0) -> Vector3:
	var plane: Vector2 = to_plane(px)
	return Vector3(plane.x, height_m, plane.y)


## A whole outline or polyline as ground-plane points.
func to_plane_points(points_px: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(points_px.size())
	for i: int in range(points_px.size()):
		result[i] = to_plane(points_px[i])
	return result


## Reads a JSON list of [x, y] pairs into map pixels.
static func points_from_json(list: Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for pair: Array in list:
		result.append(Vector2(float(pair[0]), float(pair[1])))
	return result
