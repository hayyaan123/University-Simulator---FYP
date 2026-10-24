class_name MapView3D
extends Node3D
## The 3D view of the campus: buildings, ground, props, lighting, camera and students.
##
## Like MapView, it only listens to EventBus and reads Campus; it never changes the
## simulation. It can also run on its own (open MapView3D.tscn and press F6) to look
## around the campus without a simulation.
##
## Click a building to see what's in it; click empty ground to close the panel.

## Where the camera starts: above the main gate, looking south over the campus.
const START_FOCUS_PX: Vector2 = Vector2(1000.0, 420.0)
const START_YAW_DEG: float = 200.0
const START_DISTANCE_M: float = 330.0
## A click that moves the mouse further than this is a drag, not a pick.
const CLICK_SLOP_PX: float = 6.0
const FOCUS_DISTANCE_M: float = 120.0
## Building labels hide when the camera is closer than this to them, and refresh this often.
const LABEL_HIDE_NEAR_M: float = 40.0
const LABEL_REFRESH_S: float = 0.25
const HIGHLIGHT_COLOR: Color = Color("2f8fe0")

var _campus: Campus
var _labels: Dictionary = {}  # StringName building id -> Label3D
var _selected: StringName = &""
var _highlight: MeshInstance3D
var _press_at: Vector2 = Vector2.ZERO
var _label_timer: float = 0.0

@onready var world: CampusWorld = $CampusWorld
@onready var camera_rig: CampusCamera = $CameraRig
@onready var day_night: DayNight = $DayNight
@onready var students: Students3D = $Students3D
@onready var info_panel: BuildingInfo = $UI/BuildingInfo
@onready var interior: InteriorView = $InteriorView


func _ready() -> void:
	camera_rig.bounds = world.map_bounds.grow(-40.0)
	camera_rig.roof_height = world.roof_height_at
	camera_rig.set_view(world.frame.to_world(START_FOCUS_PX), START_YAW_DEG, START_DISTANCE_M)
	info_panel.focus_requested.connect(_on_focus_requested)
	info_panel.closed.connect(func() -> void: _select(&""))
	info_panel.inside_requested.connect(_on_inside_requested)
	_build_labels()


## Call once per run, after the timetable is built (same as MapView.setup).
func setup(campus: Campus, student_list: Array[Student]) -> void:
	_campus = campus
	students.setup(campus, student_list, world.frame, world.map_bounds, world.indoor_outlines())
	info_panel.campus = campus


## Turns the 3D view on or off (the 2D map is shown instead when it's off).
func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	$UI.visible = active
	camera_rig.camera.current = active


## The 3D point for a map pixel, at ground level.
func world_point(px: Vector2) -> Vector3:
	return world.frame.to_world(px)


func _process(delta: float) -> void:
	students.set_zoom(camera_rig.zoom_amount())
	_label_timer -= delta
	if _label_timer <= 0.0:
		_label_timer = LABEL_REFRESH_S
		students.count_occupancy()
		_refresh_labels()
		if _selected != &"":
			_refresh_panel()


## High quality: sun shadows and glow on. Low quality is for weaker laptops (G toggles).
func set_high_quality(high: bool) -> void:
	($Sun as DirectionalLight3D).shadow_enabled = high
	($WorldEnvironment as WorldEnvironment).environment.glow_enabled = high


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_G:
		set_high_quality(not ($Sun as DirectionalLight3D).shadow_enabled)
		return
	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_press_at = button.position
	elif button.position.distance_to(_press_at) <= CLICK_SLOP_PX:
		_select(_pick(button.position))


## The campus building under a screen point, or &"" if none.
func _pick(screen: Vector2) -> StringName:
	var camera: Camera3D = camera_rig.camera
	var from: Vector3 = camera.project_ray_origin(screen)
	var to: Vector3 = from + camera.project_ray_normal(screen) * camera.far
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return CampusWorld.building_of(hit.get("collider"))


func _refresh_panel() -> void:
	var seated: int = -1
	if interior.is_open():
		seated = interior.refresh(students.all_students())
	info_panel.show_building(_selected, world.buildings[_selected], int(students.occupancy.get(_selected, 0)), seated)


func _select(id: StringName) -> void:
	if interior.is_open() and id != interior.building:
		interior.close()
		_show_labels(true)
	_selected = id
	if _highlight != null:
		_highlight.queue_free()
		_highlight = null
	if id == &"" or not world.buildings.has(id):
		info_panel.hide()
		return
	_highlight = _make_highlight(world.buildings[id]["outline"])
	add_child(_highlight)
	_refresh_panel()


## A glowing ring on the ground around the selected building.
func _make_highlight(outline: PackedVector2Array) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: PackedVector2Array = MeshKit.inset(outline, -1.2)
	var closed: PackedVector2Array = ring.duplicate()
	closed.append(ring[0])
	MeshKit.add_ribbon(st, closed, 1.4, 0.2)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = HIGHLIGHT_COLOR
	material.emission_enabled = true
	material.emission = HIGHLIGHT_COLOR
	material.emission_energy_multiplier = 1.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	return node


func _build_labels() -> void:
	for id: StringName in world.buildings:
		var info: Dictionary = world.buildings[id]
		var label: Label3D = Label3D.new()
		label.text = String(info["name"])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0006
		label.font_size = 28
		label.outline_size = 10
		label.outline_modulate = Color(0.08, 0.1, 0.13, 0.85)
		label.no_depth_test = true
		label.render_priority = 10
		label.position = (info["centre"] as Vector3) + Vector3(0.0, 6.0, 0.0)
		add_child(label)
		_labels[id] = label


func _refresh_labels() -> void:
	var eye: Vector3 = camera_rig.camera.global_position
	for id: StringName in _labels:
		var label: Label3D = _labels[id]
		label.visible = eye.distance_to(label.position) > LABEL_HIDE_NEAR_M and not interior.is_open()
		var inside: int = int(students.occupancy.get(id, 0))
		var name: String = String(world.buildings[id]["name"])
		label.text = name if inside == 0 else "%s\n%d inside" % [name, inside]


func _on_inside_requested(id: StringName) -> void:
	if interior.is_open():
		interior.close()
	elif world.buildings.has(id):
		var info: Dictionary = world.buildings[id]
		interior.open(id, info, _campus, world.bank)
		var size: Vector2 = MeshKit.bounds_of(info["outline"]).size
		camera_rig.focus_on(info["centre"], clampf(size.length() * 1.3, 45.0, 150.0))
	_show_labels(not interior.is_open())
	_refresh_panel()


## Opens the inside of a building straight away (used by the screenshot tool).
func look_inside(id: StringName) -> void:
	_select(id)
	if not interior.is_open():
		_on_inside_requested(id)


## Closes the inside view (if open) and the building panel.
func clear_selection() -> void:
	if interior.is_open():
		_on_inside_requested(interior.building)
	_select(&"")


func _show_labels(on: bool) -> void:
	for label_id: StringName in _labels:
		(_labels[label_id] as Label3D).visible = on


func _on_focus_requested(id: StringName) -> void:
	if world.buildings.has(id):
		camera_rig.focus_on(world.buildings[id]["centre"], FOCUS_DISTANCE_M)
