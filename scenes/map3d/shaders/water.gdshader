// Stylised lake water: moving ripples, a fresnel sky reflection and soft sparkles.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.13, 0.36, 0.42);
uniform vec3 shallow_color : source_color = vec3(0.27, 0.56, 0.58);
uniform vec3 sky_color : source_color = vec3(0.72, 0.84, 0.92);
uniform float night = 0.0;
uniform float ripple_scale = 0.18;
uniform float ripple_speed = 0.35;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * ripple_scale;
	float t = TIME * ripple_speed;
	float w = sin(p.x * 1.7 + t) * 0.5 + sin(p.y * 2.3 - t * 1.3) * 0.35 + sin((p.x + p.y) * 3.1 + t * 0.7) * 0.15;
	vec3 n = normalize(vec3(cos(p.x * 1.7 + t) * 0.12, 1.0, cos(p.y * 2.3 - t * 1.3) * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep_color, shallow_color, 0.5 + 0.25 * w);
	col = mix(col, sky_color * mix(1.0, 0.18, night), 0.35 + 0.5 * fres);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
