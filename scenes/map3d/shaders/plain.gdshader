// A flat colour that supports the cutaway (for parapets, columns, roof plant and steel).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/map3d/shaders/cutaway.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.74, 0.71, 0.66);
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float night = 0.0;

void vertex() {
	cut_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (is_cut_away()) {
		discard;
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
