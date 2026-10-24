extends GutTest
## Geometry and lighting helpers used by the 3D map (scenes/map3d). These are the parts
## with rules worth checking; the rendering itself is checked by eye with
## tools/Screenshot3D.tscn.

# A 10 m square, clockwise on the map (z points south, down the screen).
var square: PackedVector2Array = PackedVector2Array([
	Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])


func test_map_frame_puts_the_view_centre_at_the_origin() -> void:
	var frame: MapFrame = MapFrame.new(0.5)
	assert_eq(frame.to_plane(MapFrame.VIEW_CENTRE_PX), Vector2.ZERO)
	assert_eq(frame.to_plane(MapFrame.VIEW_CENTRE_PX + Vector2(100, -40)), Vector2(50, -20))
	assert_eq(frame.to_world(MapFrame.VIEW_CENTRE_PX, 3.0), Vector3(0, 3, 0))


func test_area_and_perimeter_of_a_square() -> void:
	assert_almost_eq(absf(MeshKit.signed_area(square)), 100.0, 0.001)
	assert_almost_eq(MeshKit.perimeter(square), 40.0, 0.001)


func test_inset_shrinks_every_side() -> void:
	var inner: PackedVector2Array = MeshKit.inset(square, 1.0)
	assert_eq(inner.size(), 4)
	assert_almost_eq(absf(MeshKit.signed_area(inner)), 64.0, 0.01)
	assert_true(Geometry2D.is_point_in_polygon(Vector2(5, 5), inner))


func test_inset_works_for_either_winding() -> void:
	var reversed: PackedVector2Array = square.duplicate()
	reversed.reverse()
	assert_almost_eq(absf(MeshKit.signed_area(MeshKit.inset(reversed, 1.0))), 64.0, 0.01)


func test_inset_edges_moves_only_the_chosen_side() -> void:
	# Edge 0 runs along z = 0 (the north side). Move only that one in by 2 m.
	var core: PackedVector2Array = MeshKit.inset_edges(square, PackedFloat32Array([2.0, 0.0, 0.0, 0.0]))
	assert_almost_eq(absf(MeshKit.signed_area(core)), 80.0, 0.01)
	assert_almost_eq(core[0].y, 2.0, 0.001)
	assert_almost_eq(core[2].y, 10.0, 0.001)


func test_edges_facing_finds_the_north_side() -> void:
	var north: PackedInt32Array = MeshKit.edges_facing(square, Vector2(0, -1))
	assert_eq(north, PackedInt32Array([0]))


func test_walls_face_outwards() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.add_walls(st, square, 0.0, 3.0)
	var arrays: Array = st.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(vertices.size(), 4 * 6)
	var centre: Vector3 = Vector3(5, 0, 5)
	for i: int in range(vertices.size()):
		var out: Vector3 = vertices[i] - centre
		out.y = 0.0
		assert_gt(normals[i].dot(out), 0.0, "normal %d should point away from the middle" % i)


func test_ribbon_edges_are_the_right_width_apart() -> void:
	var line: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(20, 0)])
	var edges: Array[PackedVector2Array] = MeshKit.ribbon_edges(line, 6.0)
	assert_almost_eq(edges[0][0].distance_to(edges[1][0]), 6.0, 0.001)
	assert_almost_eq(edges[0][1].distance_to(edges[1][1]), 6.0, 0.001)


func test_sample_polyline_spaces_points_evenly() -> void:
	var line: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	var samples: Array[Dictionary] = MeshKit.sample_polyline(line, 10.0)
	assert_eq(samples.size(), 3)
	assert_almost_eq((samples[0]["point"] as Vector2).x, 5.0, 0.001)
	assert_almost_eq((samples[2]["point"] as Vector2).x, 25.0, 0.001)


func test_occupancy_grid_blocks_inside_a_polygon_only() -> void:
	var grid: OccupancyGrid = OccupancyGrid.new(Rect2(-20, -20, 40, 40), 1.0)
	grid.block_polygon(square)
	assert_false(grid.is_free(Vector2(5, 5)))
	assert_true(grid.is_free(Vector2(-10, -10)))
	assert_false(grid.is_free(Vector2(500, 500)), "outside the grid counts as taken")


func test_sun_is_up_by_day_and_down_at_night() -> void:
	var noon: float = (DayNight.SUNRISE_MINUTE + DayNight.SUNSET_MINUTE) * 0.5
	assert_almost_eq(DayNight.sun_elevation_deg(noon), DayNight.MAX_ELEVATION_DEG, 0.01)
	assert_almost_eq(DayNight.sun_elevation_deg(DayNight.SUNRISE_MINUTE), 0.0, 0.01)
	assert_lt(DayNight.sun_elevation_deg(SimTime.at(0, 0)), 0.0)
	assert_lt(DayNight.sun_elevation_deg(SimTime.at(0, 23)), 0.0)


func test_night_amount_blends_through_dusk() -> void:
	assert_eq(DayNight.night_amount(30.0), 0.0)
	assert_eq(DayNight.night_amount(-20.0), 1.0)
	assert_almost_eq(DayNight.night_amount(0.0), 0.5, 0.01)
