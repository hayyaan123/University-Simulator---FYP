class_name MaterialBank
extends RefCounted
## Every material the 3D map uses, made once and shared, so DayNight can switch them all
## between day and night in one call.

const FACADE_SHADER: Shader = preload("res://scenes/map3d/shaders/facade.gdshader")
const GROUND_SHADER: Shader = preload("res://scenes/map3d/shaders/ground.gdshader")
const ROAD_SHADER: Shader = preload("res://scenes/map3d/shaders/road.gdshader")
const WATER_SHADER: Shader = preload("res://scenes/map3d/shaders/water.gdshader")
const GLASS_SHADER: Shader = preload("res://scenes/map3d/shaders/glass.gdshader")
const ROOF_SHADER: Shader = preload("res://scenes/map3d/shaders/roof.gdshader")
const PLAIN_SHADER: Shader = preload("res://scenes/map3d/shaders/plain.gdshader")
## Shaders that include cutaway.gdshaderinc.
const CUT_SHADERS: Array[Shader] = [FACADE_SHADER, ROOF_SHADER, GLASS_SHADER, PLAIN_SHADER]
## A cut height high enough that nothing is cut.
const NO_CUT_M: float = 100000.0

## Facade uniforms that a style in campus_3d.json may set (as "#rrggbb" or a number).
const FACADE_KEYS: PackedStringArray = [
	"wall_color", "band_color", "glass_color", "frame_color", "base_color",
	"floor_height", "bay_width", "sill", "head", "pier_every", "base_height", "lit_fraction",
]

var ground: ShaderMaterial
var road: ShaderMaterial
var water: ShaderMaterial
var glass: ShaderMaterial
var roof: ShaderMaterial
var roof_green: ShaderMaterial
var concrete: ShaderMaterial
var steel: ShaderMaterial
var lamp_glow: StandardMaterial3D
var _night_materials: Array[ShaderMaterial] = []
var _facades: Dictionary = {}  # String style key -> ShaderMaterial


func _init() -> void:
	ground = _shader(GROUND_SHADER)
	road = _shader(ROAD_SHADER)
	water = _shader(WATER_SHADER)
	glass = _shader(GLASS_SHADER)
	roof = _shader(ROOF_SHADER)
	roof_green = _shader(ROOF_SHADER)
	roof_green.set_shader_parameter("roof_color", Color("6f9a5c"))
	roof_green.set_shader_parameter("seam_color", Color("5d8550"))
	concrete = plain(Color("bdb6a9"), 0.9)
	steel = plain(Color("8d9497"), 0.5, 0.5)
	lamp_glow = _flat(Color("fff1c9"), 0.4)
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("ffd88a")
	lamp_glow.emission_energy_multiplier = 0.0


## A facade material for a style (a Dictionary from campus_3d.json). Styles with the same
## values and seed share one material.
func facade(style: Dictionary, seed: float) -> ShaderMaterial:
	var key: String = "%s|%s" % [JSON.stringify(style), seed]
	if _facades.has(key):
		return _facades[key]
	var material: ShaderMaterial = _shader(FACADE_SHADER)
	for name: String in FACADE_KEYS:
		if style.has(name):
			var value: Variant = style[name]
			material.set_shader_parameter(name, Color(value) if value is String else float(value))
	material.set_shader_parameter("seed", seed)
	_facades[key] = material
	return material


## A flat-coloured material that supports the cutaway, shared by colour.
func plain(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> ShaderMaterial:
	var key: String = "plain|%s|%s|%s" % [color.to_html(), roughness, metallic]
	if _facades.has(key):
		return _facades[key]
	var material: ShaderMaterial = _shader(PLAIN_SHADER)
	material.set_shader_parameter("albedo", color)
	material.set_shader_parameter("roughness", roughness)
	material.set_shader_parameter("metallic", metallic)
	_facades[key] = material
	return material


## Hides everything above `height_m` inside `area` (ground-plane metres), to look inside a building.
func set_cutaway(area: Rect2, height_m: float) -> void:
	var rect: Vector4 = Vector4(area.position.x, area.position.y, area.end.x, area.end.y)
	for material: ShaderMaterial in _night_materials:
		if material.shader in CUT_SHADERS:
			material.set_shader_parameter("cut_rect", rect)
			material.set_shader_parameter("cut_height", height_m)


func clear_cutaway() -> void:
	set_cutaway(Rect2(), NO_CUT_M)


## 0 = day, 1 = night. Fades window lights, glass glow and lamps.
func set_night(amount: float) -> void:
	for material: ShaderMaterial in _night_materials:
		material.set_shader_parameter("night", amount)
	lamp_glow.emission_energy_multiplier = 4.0 * amount


func _shader(shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	_night_materials.append(material)
	return material


static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
