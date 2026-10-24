@tool
class_name DayNight
extends Node
## Moves the sun and colours the sky, light and fog by the time of day, and switches on
## window and street lights at night.
##
## In the running sim it follows EventBus.sim_time_changed. In the editor (and when the
## 3D map runs on its own) it shows `preview_minute`.

## Sunrise and sunset in Kuala Lumpur, which barely change over the year (about 07:05 to
## 07:25 and 19:10 to 19:30). Source: timeanddate.com, Kuala Lumpur sun times.
const SUNRISE_MINUTE: float = 7.0 * 60.0 + 15.0
const SUNSET_MINUTE: float = 19.0 * 60.0 + 20.0
## Highest sun angle we show. The real noon sun is almost overhead in Malaysia, which
## flattens the shadows, so we cap it for a more readable map.
const MAX_ELEVATION_DEG: float = 65.0
## The sun passes a little to the south of overhead (most of the year at 3° N).
const SOUTH_TILT_DEG: float = 18.0
const MOON_ELEVATION_DEG: float = 55.0

## Colours at a few sun elevations (degrees). Each row: elevation, sky top, horizon,
## sun colour, sun energy, ambient energy.
const KEYS: Array = [
	[-12.0, Color("070d1c"), Color("16213a"), Color("7d93c9"), 0.14, 0.2],
	[-4.0, Color("1d2a4f"), Color("6b5a73"), Color("9aa6d6"), 0.12, 0.35],
	[2.0, Color("4a6aa6"), Color("f0a46c"), Color("ff9a55"), 0.6, 0.5],
	[10.0, Color("5d8ccc"), Color("f3c99a"), Color("ffcf94"), 1.05, 0.6],
	[30.0, Color("4f8fd6"), Color("c4dbe9"), Color("fff1dc"), 1.12, 0.62],
	[90.0, Color("3f86d8"), Color("bcd6e8"), Color("fff6e8"), 1.15, 0.62],
]

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment
@export var world: CampusWorld
## Minute of the day shown in the editor or when no simulation is running (630 = 10:30).
@export_range(0.0, 1440.0, 1.0) var preview_minute: float = 630.0:
	set(value):
		preview_minute = value
		if is_inside_tree():
			apply_minute(value)
## When no simulation is running, advance the clock this many minutes per real second.
@export var demo_minutes_per_second: float = 0.0

var _minute: float = 630.0
var _following_sim: bool = false


func _ready() -> void:
	if world != null and not world.built.is_connected(_on_world_built):
		world.built.connect(_on_world_built)
	# Looked up by path, not by the EventBus name, so this tool script also compiles in the
	# editor and in tools/screenshot_3d.gd, where autoloads aren't registered.
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if not Engine.is_editor_hint() and bus != null:
		bus.connect(&"sim_time_changed", _on_sim_time_changed)
	apply_minute(preview_minute)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _following_sim or demo_minutes_per_second == 0.0:
		return
	apply_minute(fposmod(_minute + demo_minutes_per_second * delta, SimTime.MINUTES_PER_DAY))


## Sets the lighting for a minute of the day (0..1440).
func apply_minute(minute_of_day: float) -> void:
	_minute = minute_of_day
	var elevation: float = sun_elevation_deg(minute_of_day)
	var night: float = night_amount(elevation)
	var look: Array = _look_at_elevation(elevation)
	if sun != null:
		_place_sun(minute_of_day, elevation)
		sun.light_color = look[2]
		sun.light_energy = look[3]
		sun.shadow_opacity = lerpf(0.85, 0.35, night)
	if environment != null and environment.environment != null:
		_colour_sky(environment.environment, look)
	if world != null and world.bank != null:
		world.bank.set_night(night)


## Sun height above the horizon in degrees for a minute of the day (negative at night).
static func sun_elevation_deg(minute_of_day: float) -> float:
	var day_length: float = SUNSET_MINUTE - SUNRISE_MINUTE
	var t: float = (minute_of_day - SUNRISE_MINUTE) / day_length
	if t >= 0.0 and t <= 1.0:
		return sin(t * PI) * MAX_ELEVATION_DEG
	# At night, a gentle dip below the horizon that is deepest at midnight-ish.
	var night_length: float = SimTime.MINUTES_PER_DAY - day_length
	var into_night: float = fposmod(minute_of_day - SUNSET_MINUTE, SimTime.MINUTES_PER_DAY) / night_length
	return -sin(into_night * PI) * 30.0


## 0 in daylight, 1 at night, blended through dusk and dawn.
static func night_amount(elevation_deg: float) -> float:
	return 1.0 - smoothstep(-6.0, 6.0, elevation_deg)


func _place_sun(minute_of_day: float, elevation: float) -> void:
	var day_length: float = SUNSET_MINUTE - SUNRISE_MINUTE
	var t: float = clampf((minute_of_day - SUNRISE_MINUTE) / day_length, 0.0, 1.0)
	var height: float = elevation
	var azimuth: float = lerpf(0.0, PI, t)  # 0 = east (+x), PI = west (-x)
	if elevation < 0.0:
		# Moonlight from high in the sky, so the night map is still readable.
		height = MOON_ELEVATION_DEG
		azimuth = PI * 0.35
	var h: float = deg_to_rad(maxf(height, 4.0))
	var tilt: float = deg_to_rad(SOUTH_TILT_DEG)
	var to_sun: Vector3 = Vector3(cos(azimuth) * cos(h), sin(h), sin(tilt) * cos(h)).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)


func _colour_sky(env: Environment, look: Array) -> void:
	var sky_material: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky_material != null:
		sky_material.sky_top_color = look[0]
		sky_material.sky_horizon_color = look[1]
		sky_material.ground_horizon_color = look[1]
		sky_material.ground_bottom_color = (look[1] as Color).darkened(0.5)
	env.ambient_light_energy = look[4]
	env.fog_light_color = (look[1] as Color).lerp(look[0], 0.3)


## Blends the KEYS rows around an elevation. Returns [sky top, horizon, sun colour, sun energy, ambient].
static func _look_at_elevation(elevation: float) -> Array:
	for i: int in range(1, KEYS.size()):
		var hi: Array = KEYS[i]
		if elevation <= float(hi[0]) or i == KEYS.size() - 1:
			var lo: Array = KEYS[i - 1]
			var t: float = clampf(inverse_lerp(float(lo[0]), float(hi[0]), elevation), 0.0, 1.0)
			return [
				(lo[1] as Color).lerp(hi[1], t), (lo[2] as Color).lerp(hi[2], t),
				(lo[3] as Color).lerp(hi[3], t), lerpf(lo[4], hi[4], t), lerpf(lo[5], hi[5], t),
			]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3], KEYS[0][4], KEYS[0][5]]


func _on_world_built() -> void:
	apply_minute(_minute)


func _on_sim_time_changed(time: float) -> void:
	_following_sim = true
	apply_minute(SimTime.minute_of_day(time))
