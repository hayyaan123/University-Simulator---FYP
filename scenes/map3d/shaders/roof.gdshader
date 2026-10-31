// Flat roofs: grey membrane panels with faint seams and weathering, so big roofs read as
// surfaces rather than blank white shapes from above. UV = world x, z in metres.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/map3d/shaders/cutaway.gdshaderinc"

uniform vec3 roof_color : source_color = vec3(0.50, 0.50, 0.48);
uniform vec3 seam_color : source_color = vec3(0.40, 0.40, 0.39);
uniform float panel_m = 4.0;
uniform float night = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), s.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), s.x), s.y);
}

void vertex() {
	cut_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (is_cut_away()) {
		discard;
	}
	vec2 p = UV;
	vec2 cell = abs(fract(p / panel_m) - 0.5);
	float seam = step(0.485, max(cell.x, cell.y));
	float weather = value_noise(p * 0.08) * 0.6 + value_noise(p * 0.4) * 0.4;
	vec3 col = roof_color * (0.9 + 0.16 * weather);
	col = mix(col, seam_color, seam * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
