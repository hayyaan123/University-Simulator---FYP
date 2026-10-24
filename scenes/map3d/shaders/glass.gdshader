// Curtain-wall glass for stair towers and skybridges: tinted panes in a thin grid,
// glowing softly at night. UV.x = metres along the wall, UV.y = metres up.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/map3d/shaders/cutaway.gdshaderinc"

uniform vec3 glass_color : source_color = vec3(0.20, 0.42, 0.45);
uniform vec3 frame_color : source_color = vec3(0.72, 0.75, 0.76);
uniform vec3 sky_tint : source_color = vec3(0.75, 0.86, 0.93);
uniform float pane_w = 1.5;
uniform float pane_h = 1.9;
uniform float night = 0.0;
uniform vec3 inner_light : source_color = vec3(0.95, 0.86, 0.66);
uniform float light_strength = 0.9;

void vertex() {
	cut_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (is_cut_away()) {
		discard;
	}
	vec2 pane = abs(fract(vec2(UV.x / pane_w, UV.y / pane_h)) - 0.5);
	float frame = step(0.46, max(pane.x, pane.y));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 glass = mix(glass_color, sky_tint, 0.2 + 0.5 * fres) * mix(1.0, 0.3, night);
	ALBEDO = mix(glass, frame_color, frame);
	ROUGHNESS = mix(0.1, 0.5, frame);
	METALLIC = mix(0.3, 0.6, frame);
	EMISSION = inner_light * night * light_strength * (1.0 - frame);
}
