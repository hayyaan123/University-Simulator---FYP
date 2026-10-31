class_name OccupancyGrid
extends RefCounted
## A coarse grid over the ground that marks where props must not go (roads, buildings,
## water, pitches). Checking a cell is much cheaper than testing every road and outline.

var cell_m: float
var origin: Vector2
var width: int
var height: int
var _cells: PackedByteArray


func _init(area: Rect2, cell_size_m: float) -> void:
	cell_m = cell_size_m
	origin = area.position
	width = int(ceil(area.size.x / cell_m)) + 1
	height = int(ceil(area.size.y / cell_m)) + 1
	_cells = PackedByteArray()
	_cells.resize(width * height)


## True when a point is free (and inside the grid).
func is_free(p: Vector2) -> bool:
	var c: Vector2i = _cell(p)
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return false
	return _cells[c.y * width + c.x] == 0


## Marks a polygon (grown by `margin_m`) as taken.
func block_polygon(outline: PackedVector2Array, margin_m: float = 0.0) -> void:
	var rect: Rect2 = MeshKit.bounds_of(outline).grow(margin_m + cell_m)
	var grown: PackedVector2Array = outline
	if margin_m > 0.0:
		grown = MeshKit.inset(outline, -margin_m)
	_for_cells(rect, func(centre: Vector2) -> bool: return Geometry2D.is_point_in_polygon(centre, grown))


## Marks a strip along a polyline as taken.
func block_polyline(points: PackedVector2Array, width_m: float) -> void:
	var half: float = width_m * 0.5
	for i: int in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var rect: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(half + cell_m)
		_for_cells(rect, func(centre: Vector2) -> bool:
			return centre.distance_to(Geometry2D.get_closest_point_to_segment(centre, a, b)) <= half)


## Marks a single spot (and a radius around it) as taken, so props don't overlap.
func block_circle(p: Vector2, radius_m: float) -> void:
	var rect: Rect2 = Rect2(p, Vector2.ZERO).grow(radius_m)
	_for_cells(rect, func(centre: Vector2) -> bool: return centre.distance_to(p) <= radius_m)


func _for_cells(rect: Rect2, test: Callable) -> void:
	var lo: Vector2i = _cell(rect.position)
	var hi: Vector2i = _cell(rect.end)
	for y: int in range(maxi(lo.y, 0), mini(hi.y + 1, height)):
		for x: int in range(maxi(lo.x, 0), mini(hi.x + 1, width)):
			var index: int = y * width + x
			if _cells[index] != 0:
				continue
			var centre: Vector2 = origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_m
			if test.call(centre):
				_cells[index] = 1


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / cell_m)), int(floor((p.y - origin.y) / cell_m)))
