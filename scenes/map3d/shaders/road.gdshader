// Roads and paths. UV.x runs 0..1 across the strip and UV.y is metres along it.
// COLOR.rgb is the surface colour. COLOR.a picks the markings:
// 0 = none (paths), 0.5 = edge lines only, 1 = edge lines and a dashed centre line.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 line_color : source_color = vec3(0.93, 0.93, 0.88);
uniform vec3 centre_color : source_color = vec3(0.95, 0.83, 0.35);
uniform float dash_m = 3.0;
uniform float gap_m = 4.0;
// Line width as a fraction of the road width.
uniform float edge_line = 0.035;
uniform float centre_line = 0.025;

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = COLOR.rgb;
	float marks = COLOR.a;
	float across = UV.x;
	float along = UV.y;
	// Asphalt grain.
	col *= 0.94 + 0.08 * hash12(floor(world_pos.xz * 4.0));

	if (marks > 0.25) {
		float edge = step(across, edge_line * 2.0) * step(edge_line, across)
			+ step(1.0 - edge_line * 2.0, across) * step(across, 1.0 - edge_line);
		col = mix(col, line_color, clamp(edge, 0.0, 1.0) * 0.85);
	}
	if (marks > 0.75) {
		float dash = step(mod(along, dash_m + gap_m), dash_m);
		float centre = step(abs(across - 0.5), centre_line) * dash;
		col = mix(col, centre_color, centre * 0.9);
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
