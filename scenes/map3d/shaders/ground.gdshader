// Ground and flat areas (grass, paving, parking, pitches). The base colour comes from the
// vertex colour; a soft world-space noise breaks up large flat areas.
// COLOR.a picks the pattern: 0 = plain, 0.25 = grass, 0.5 = paving tiles, 0.75 = parking bays.
shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform float night = 0.0;
uniform vec3 grass_dark : source_color = vec3(0.30, 0.47, 0.22);

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = COLOR.rgb;
	float pattern = COLOR.a;
	vec2 p = world_pos.xz;
	float n = value_noise(p * 0.05) * 0.6 + value_noise(p * 0.21) * 0.3 + value_noise(p * 1.3) * 0.1;

	if (pattern > 0.1 && pattern < 0.4) {
		// Grass: patches of darker green.
		col = mix(col, grass_dark, smoothstep(0.35, 0.8, n) * 0.55);
		col *= 0.92 + 0.16 * value_noise(p * 3.0);
	} else if (pattern >= 0.4 && pattern < 0.6) {
		// Paving: faint tile joints.
		vec2 tile = abs(fract(p / 1.2) - 0.5);
		float joint = step(0.47, max(tile.x, tile.y));
		col *= (1.0 - 0.07 * joint) * (0.95 + 0.1 * n);
	} else if (pattern >= 0.6) {
		col *= 0.93 + 0.12 * n;
	} else {
		col *= 0.95 + 0.1 * n;
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
