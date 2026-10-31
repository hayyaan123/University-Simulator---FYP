class_name CampusCamera
extends Node3D
## Management-game camera for the 3D map.
##
## Controls: WASD or arrow keys pan, Q/E rotate, mouse wheel zooms, right-drag pans,
## middle-drag rotates. Zooming out tilts the view towards top-down; zooming in tilts it
## towards the horizon. Movement is smoothed.

const MIN_DISTANCE_M: float = 25.0
const MAX_DISTANCE_M: float = 650.0
## Camera tilt below the horizon when fully zoomed in and fully zoomed out.
const PITCH_CLOSE_DEG: float = 28.0
const PITCH_FAR_DEG: float = 62.0
const PAN_SPEED: float = 1.1  # screen heights per second
const ROTATE_SPEED_DEG: float = 90.0
const ZOOM_STEP: float = 1.15
const DRAG_ROTATE_DEG_PER_PX: float = 0.3
## How quickly the camera catches up with its target (higher is snappier).
const SMOOTHING: float = 10.0

## Clearance kept between the camera and any roof below it.
const ROOF_CLEARANCE_M: float = 4.0

## The focus point is kept inside these ground-plane bounds (metres).
var bounds: Rect2 = Rect2(-400.0, -400.0, 800.0, 800.0)
## Returns the roof height (metres) under a ground-plane point, so the camera never ends
## up inside a building. Set by MapView3D; when empty, only the ground is checked.
var roof_height: Callable = Callable()

var _focus: Vector3 = Vector3.ZERO
var _yaw_deg: float = 0.0
var _distance: float = 300.0
var _target_focus: Vector3 = Vector3.ZERO
var _target_yaw_deg: float = 0.0
var _target_distance: float = 300.0
var _panning: bool = false
var _rotating: bool = false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	_keyboard(delta)
	var k: float = 1.0 - exp(-SMOOTHING * delta)
	_focus = _focus.lerp(_target_focus, k)
	_yaw_deg = lerpf(_yaw_deg, _target_yaw_deg, k)
	_distance = lerpf(_distance, _target_distance, k)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_target_distance = clampf(_target_distance / ZOOM_STEP, MIN_DISTANCE_M, MAX_DISTANCE_M)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_target_distance = clampf(_target_distance * ZOOM_STEP, MIN_DISTANCE_M, MAX_DISTANCE_M)
			MOUSE_BUTTON_RIGHT:
				_panning = button.pressed
			MOUSE_BUTTON_MIDDLE:
				_rotating = button.pressed
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if _panning:
			var metres_per_px: float = _distance * 1.6 / maxf(1.0, get_viewport().get_visible_rect().size.y)
			_pan(-motion.relative * metres_per_px)
		elif _rotating:
			_target_yaw_deg -= motion.relative.x * DRAG_ROTATE_DEG_PER_PX


## Jumps straight to a view (no smoothing). Used by the screenshot tool and on start-up.
func set_view(focus: Vector3, yaw_deg: float, distance_m: float) -> void:
	_target_focus = Vector3(focus.x, 0.0, focus.z)
	_target_yaw_deg = yaw_deg
	_target_distance = clampf(distance_m, MIN_DISTANCE_M, MAX_DISTANCE_M)
	_focus = _target_focus
	_yaw_deg = yaw_deg
	_distance = _target_distance
	if is_inside_tree():
		_apply()


## Glides to look at a point from a given distance.
func focus_on(point: Vector3, distance_m: float) -> void:
	_target_focus = Vector3(point.x, 0.0, point.z)
	_target_distance = clampf(distance_m, MIN_DISTANCE_M, MAX_DISTANCE_M)


## 0 when fully zoomed in, 1 when fully zoomed out.
func zoom_amount() -> float:
	return inverse_lerp(MIN_DISTANCE_M, MAX_DISTANCE_M, _distance)


func _keyboard(delta: float) -> void:
	var move: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if move != Vector2.ZERO:
		_pan(move.normalized() * _distance * PAN_SPEED * delta)
	if Input.is_key_pressed(KEY_Q):
		_target_yaw_deg += ROTATE_SPEED_DEG * delta
	if Input.is_key_pressed(KEY_E):
		_target_yaw_deg -= ROTATE_SPEED_DEG * delta


## Moves the focus by a screen-relative amount in metres (x right, y down the screen).
func _pan(amount: Vector2) -> void:
	var yaw: float = deg_to_rad(_target_yaw_deg)
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	_target_focus += right * amount.x - forward * amount.y
	_target_focus.x = clampf(_target_focus.x, bounds.position.x, bounds.end.x)
	_target_focus.z = clampf(_target_focus.z, bounds.position.y, bounds.end.y)


func _apply() -> void:
	if camera == null:
		return
	var pitch: float = deg_to_rad(lerpf(PITCH_CLOSE_DEG, PITCH_FAR_DEG, zoom_amount()))
	var yaw: float = deg_to_rad(_yaw_deg)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _distance
	var eye: Vector3 = _focus + offset
	if roof_height.is_valid():
		var roof: float = roof_height.call(Vector2(eye.x, eye.z))
		eye.y = maxf(eye.y, roof + ROOF_CLEARANCE_M)
	camera.global_position = eye
	camera.look_at(_focus, Vector3.UP)
