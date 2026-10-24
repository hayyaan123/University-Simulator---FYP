class_name MeshKit
extends RefCounted
## Geometry helpers for the 3D map: extruded footprints, flat caps and road ribbons.
##
## Points are ground-plane metres (Vector2 x, z). Every triangle is wound so it faces
## along the normal it is given, so callers never have to think about winding order.
##
## UV conventions used by the shaders:
## - Walls: UV.x = metres along the outline, UV.y = metres above the wall's base.
##   UV2.y = metres below the wall's top (for parapet bands).
## - Ribbons: UV.x = 0 on the left edge and 1 on the right, UV.y = metres along the line.
## - Caps: UV = world x, z in metres.

## Mitre joins longer than this many half-widths are cut short (stops spikes at sharp bends).
const MAX_MITRE: float = 2.5


## Adds one triangle facing along `normal`. Godot treats clockwise triangles as front faces.
static func add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3,
		uvs: PackedVector2Array = PackedVector2Array(), uv2s: PackedVector2Array = PackedVector2Array()) -> void:
	var order: PackedInt32Array = PackedInt32Array([0, 1, 2])
	if (b - a).cross(c - a).dot(normal) > 0.0:
		order = PackedInt32Array([0, 2, 1])
	var points: Array[Vector3] = [a, b, c]
	for i: int in order:
		st.set_normal(normal)
		# Always set both UV channels: meshes that share a material mix walls and caps,
		# and SurfaceTool needs every vertex to have the same attributes.
		st.set_uv(uvs[i] if not uvs.is_empty() else Vector2.ZERO)
		st.set_uv2(uv2s[i] if not uv2s.is_empty() else Vector2.ZERO)
		st.add_vertex(points[i])


## Signed area of an outline (positive when the points run clockwise on the map, where z points down).
static func signed_area(outline: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


## Total length of an outline, closing edge included.
static func perimeter(outline: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(outline.size()):
		total += outline[i].distance_to(outline[(i + 1) % outline.size()])
	return total


## Walls around an outline from base_m to top_m, facing outwards.
static func add_walls(st: SurfaceTool, outline: PackedVector2Array, base_m: float, top_m: float, inward: bool = false) -> void:
	var count: int = outline.size()
	if count < 2:
		return
	var winding: float = signf(signed_area(outline))
	var along: float = 0.0
	var height: float = top_m - base_m
	for i: int in range(count):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % count]
		var length: float = a.distance_to(b)
		if length < 0.001:
			continue
		var dir: Vector2 = (b - a) / length
		# The outward side of an edge depends on which way the outline runs.
		var out2: Vector2 = Vector2(dir.y, -dir.x) * winding
		if inward:
			out2 = -out2
		var normal: Vector3 = Vector3(out2.x, 0.0, out2.y)
		var a0: Vector3 = Vector3(a.x, base_m, a.y)
		var b0: Vector3 = Vector3(b.x, base_m, b.y)
		var a1: Vector3 = Vector3(a.x, top_m, a.y)
		var b1: Vector3 = Vector3(b.x, top_m, b.y)
		var u0: float = along
		var u1: float = along + length
		add_tri(st, a0, b0, b1, normal,
			PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, height)]),
			PackedVector2Array([Vector2(0.0, height), Vector2(0.0, height), Vector2(0.0, 0.0)]))
		add_tri(st, a0, b1, a1, normal,
			PackedVector2Array([Vector2(u0, 0.0), Vector2(u1, height), Vector2(u0, height)]),
			PackedVector2Array([Vector2(0.0, height), Vector2(0.0, 0.0), Vector2(0.0, 0.0)]))
		along += length


## A flat polygon at a height, facing up (or down). Returns false if it can't be triangulated.
static func add_cap(st: SurfaceTool, outline: PackedVector2Array, height_m: float, facing_up: bool = true) -> bool:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		return false
	var normal: Vector3 = Vector3.UP if facing_up else Vector3.DOWN
	for t: int in range(0, indices.size(), 3):
		var pa: Vector2 = outline[indices[t]]
		var pb: Vector2 = outline[indices[t + 1]]
		var pc: Vector2 = outline[indices[t + 2]]
		add_tri(st, Vector3(pa.x, height_m, pa.y), Vector3(pb.x, height_m, pb.y), Vector3(pc.x, height_m, pc.y),
			normal, PackedVector2Array([pa, pb, pc]))
	return true


## Moves every point of an outline inwards by `distance` using mitred corners, keeping the
## same number of points (so a ring between the two outlines can be built edge by edge).
static func inset(outline: PackedVector2Array, distance: float) -> PackedVector2Array:
	var count: int = outline.size()
	var winding: float = signf(signed_area(outline))
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(count)
	for i: int in range(count):
		var prev: Vector2 = outline[(i - 1 + count) % count]
		var cur: Vector2 = outline[i]
		var next: Vector2 = outline[(i + 1) % count]
		var n1: Vector2 = _edge_inward(prev, cur, winding)
		var n2: Vector2 = _edge_inward(cur, next, winding)
		var bisector: Vector2 = (n1 + n2)
		if bisector.length_squared() < 0.0001:
			bisector = n1
		bisector = bisector.normalized()
		var cos_half: float = maxf(bisector.dot(n1), 1.0 / MAX_MITRE)
		result[i] = cur + bisector * (distance / cos_half)
	return result


## Moves chosen edges of an outline inwards, each by its own distance (0 leaves an edge
## where it is). Corners are where the moved edge lines meet. Same point count as the input.
static func inset_edges(outline: PackedVector2Array, distances: PackedFloat32Array) -> PackedVector2Array:
	var count: int = outline.size()
	var winding: float = signf(signed_area(outline))
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(count)
	for i: int in range(count):
		var prev_i: int = (i - 1 + count) % count
		var a0: Vector2 = outline[prev_i]
		var a1: Vector2 = outline[i]
		var b1: Vector2 = outline[(i + 1) % count]
		var n_a: Vector2 = _edge_inward(a0, a1, winding) * distances[prev_i]
		var n_b: Vector2 = _edge_inward(a1, b1, winding) * distances[i]
		var hit: Variant = Geometry2D.line_intersects_line(a0 + n_a, a1 - a0, a1 + n_b, b1 - a1)
		if hit == null or (hit as Vector2).distance_to(a1) > (absf(distances[prev_i]) + absf(distances[i])) * MAX_MITRE + 0.01:
			result[i] = a1 + n_a + n_b
		else:
			result[i] = hit
	return result


## Indexes of edges whose outward side faces a direction (within about 60 degrees).
## Edge i runs from point i to point i + 1. `facing` is a ground-plane direction.
static func edges_facing(outline: PackedVector2Array, facing: Vector2) -> PackedInt32Array:
	var winding: float = signf(signed_area(outline))
	var result: PackedInt32Array = PackedInt32Array()
	for i: int in range(outline.size()):
		var outward: Vector2 = -_edge_inward(outline[i], outline[(i + 1) % outline.size()], winding)
		if outward.dot(facing.normalized()) > 0.5:
			result.append(i)
	return result


## The flat ring between an outline and its inset copy (both with the same point count).
static func add_ring(st: SurfaceTool, outer: PackedVector2Array, inner: PackedVector2Array, height_m: float) -> void:
	var count: int = outer.size()
	for i: int in range(count):
		var j: int = (i + 1) % count
		var o0: Vector3 = Vector3(outer[i].x, height_m, outer[i].y)
		var o1: Vector3 = Vector3(outer[j].x, height_m, outer[j].y)
		var i0: Vector3 = Vector3(inner[i].x, height_m, inner[i].y)
		var i1: Vector3 = Vector3(inner[j].x, height_m, inner[j].y)
		add_tri(st, o0, o1, i1, Vector3.UP, PackedVector2Array([outer[i], outer[j], inner[j]]))
		add_tri(st, o0, i1, i0, Vector3.UP, PackedVector2Array([outer[i], inner[j], inner[i]]))


## A flat strip of a given width along a polyline, facing up. `heights` (one per point)
## lifts the strip, for bridges and ramps; leave it empty for a strip on the ground.
static func add_ribbon(st: SurfaceTool, points: PackedVector2Array, width_m: float, height_m: float,
		heights: PackedFloat32Array = PackedFloat32Array()) -> void:
	var edges: Array[PackedVector2Array] = ribbon_edges(points, width_m)
	var left: PackedVector2Array = edges[0]
	var right: PackedVector2Array = edges[1]
	var along: float = 0.0
	for i: int in range(points.size() - 1):
		var h0: float = height_m + (heights[i] if not heights.is_empty() else 0.0)
		var h1: float = height_m + (heights[i + 1] if not heights.is_empty() else 0.0)
		var step: float = points[i].distance_to(points[i + 1])
		var l0: Vector3 = Vector3(left[i].x, h0, left[i].y)
		var r0: Vector3 = Vector3(right[i].x, h0, right[i].y)
		var l1: Vector3 = Vector3(left[i + 1].x, h1, left[i + 1].y)
		var r1: Vector3 = Vector3(right[i + 1].x, h1, right[i + 1].y)
		var uv: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, along), Vector2(1.0, along), Vector2(1.0, along + step), Vector2(0.0, along + step)])
		add_tri(st, l0, r0, r1, Vector3.UP, PackedVector2Array([uv[0], uv[1], uv[2]]))
		add_tri(st, l0, r1, l1, Vector3.UP, PackedVector2Array([uv[0], uv[2], uv[3]]))
		along += step


## Left and right edge points of a strip along a polyline, with mitred joins.
static func ribbon_edges(points: PackedVector2Array, width_m: float) -> Array[PackedVector2Array]:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	var half: float = width_m * 0.5
	var count: int = points.size()
	for i: int in range(count):
		var d_in: Vector2 = (points[i] - points[maxi(i - 1, 0)]).normalized()
		var d_out: Vector2 = (points[mini(i + 1, count - 1)] - points[i]).normalized()
		if i == 0:
			d_in = d_out
		if i == count - 1:
			d_out = d_in
		var n_in: Vector2 = Vector2(-d_in.y, d_in.x)
		var n_out: Vector2 = Vector2(-d_out.y, d_out.x)
		var mitre: Vector2 = (n_in + n_out)
		if mitre.length_squared() < 0.0001:
			mitre = n_out
		mitre = mitre.normalized()
		var scale: float = 1.0 / maxf(mitre.dot(n_out), 1.0 / MAX_MITRE)
		left.append(points[i] + mitre * half * scale)
		right.append(points[i] - mitre * half * scale)
	return [left, right]


## Total length of a polyline.
static func polyline_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## Evenly spaced points (and the direction there) along a polyline, starting half a step in.
static func sample_polyline(points: PackedVector2Array, spacing_m: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next_at: float = spacing_m * 0.5
	var along: float = 0.0
	for i: int in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var length: float = a.distance_to(b)
		while next_at <= along + length and length > 0.0:
			var t: float = (next_at - along) / length
			result.append({"point": a.lerp(b, t), "dir": (b - a) / length})
			next_at += spacing_m
		along += length
	return result


## Distance from a point to a polyline.
static func distance_to_polyline(p: Vector2, points: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in range(1, points.size()):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, points[i - 1], points[i])
		best = minf(best, p.distance_to(closest))
	return best


## Axis-aligned bounds of a set of points.
static func bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		rect = rect.expand(p)
	return rect


## Average of the outline's points (good enough for label and badge placement).
static func centre_of(outline: PackedVector2Array) -> Vector2:
	var total: Vector2 = Vector2.ZERO
	for p: Vector2 in outline:
		total += p
	return total / maxf(1.0, float(outline.size()))


static func _edge_inward(a: Vector2, b: Vector2, winding: float) -> Vector2:
	var dir: Vector2 = (b - a).normalized()
	return Vector2(-dir.y, dir.x) * winding
