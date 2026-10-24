// Stylised building facade: concrete walls with floor bands, ribbon windows in bays,
// stone ground floor and a parapet band. Windows light up at night.
// UV.x = metres along the wall, UV.y = metres above ground, UV2.y = metres below the top.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scenes/map3d/shaders/cutaway.gdshaderinc"

uniform vec3 wall_color : source_color = vec3(0.86, 0.80, 0.69);
uniform vec3 band_color : source_color = vec3(0.76, 0.70, 0.60);
uniform vec3 glass_color : source_color = vec3(0.50, 0.64, 0.58);
uniform vec3 frame_color : source_color = vec3(0.36, 0.39, 0.39);
uniform vec3 base_color : source_color = vec3(0.30, 0.31, 0.33);
uniform vec3 sky_tint : source_color = vec3(0.78, 0.86, 0.92);
uniform float floor_height = 3.8;
uniform float bay_width = 3.2;
// Window top and bottom as fractions of a floor.
uniform float sill = 0.30;
uniform float head = 0.82;
// Mullion width as a fraction of a bay.
uniform float mullion = 0.05;
// Every n-th bay is a solid pier, like the recessed bays on the real buildings.
uniform float pier_every = 3.0;
uniform float base_height = 4.2;
uniform float parapet = 1.0;
uniform float seed = 0.0;
// Share of windows that are lit at night.
uniform float lit_fraction = 0.6;
// 0 = full day, 1 = full night. Set by DayNight through MaterialBank.
uniform float night = 0.0;
uniform vec3 window_light : source_color = vec3(1.0, 0.82, 0.52);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	cut_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (is_cut_away()) {
		discard;
	}
	float u = UV.x;
	float h = UV.y;
	float from_top = UV2.y;
	float fl = floor(h / floor_height);
	float fv = fract(h / floor_height);
	float bay = floor(u / bay_width);
	float fu = fract(u / bay_width);

	bool in_base = h < base_height;
	bool in_parapet = from_top < parapet;
	bool pier = mod(bay, pier_every) < 0.5;

	vec3 col = wall_color;
	float rough = 0.85;
	float metal = 0.0;
	vec3 emit = vec3(0.0);

	// Floor band just below each sill.
	if (fv < sill * 0.5) {
		col = band_color;
	}
	float sill_line = 1.0 - smoothstep(0.0, 0.02, abs(fv - sill));

	float window = step(sill, fv) * step(fv, head) * step(mullion, fu) * step(fu, 1.0 - mullion);
	if (pier) {
		window = 0.0;
		col = mix(band_color, wall_color, 0.5);
	}

	if (in_base) {
		col = base_color;
		// Tall shopfront glass on the ground floor.
		float fv0 = h / base_height;
		window = step(0.06, fv0) * step(fv0, 0.86) * step(0.04, fu) * step(fu, 0.96);
	}
	if (in_parapet) {
		col = band_color * 0.92;
		window = 0.0;
	}

	if (window > 0.5) {
		// Glass: tint plus a sky reflection that grows at grazing angles.
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		float sky_band = smoothstep(0.0, 1.0, fv);
		col = mix(glass_color, sky_tint, 0.25 * sky_band + 0.45 * fres);
		col *= mix(1.0, 0.25, night);
		rough = 0.15;
		metal = 0.2;
		float lit = step(1.0 - lit_fraction, hash13(vec3(fl, bay, seed)));
		float warmth = 0.75 + 0.5 * hash13(vec3(bay, fl, seed + 7.0));
		emit = window_light * lit * night * warmth * 1.6;
	} else {
		col *= 1.0 - 0.18 * sill_line;
	}

	// Frame darkening around each window opening fakes its depth.
	float edge_u = min(abs(fu - mullion), abs(fu - (1.0 - mullion)));
	float edge_v = min(abs(fv - sill), abs(fv - head));
	float frame = (1.0 - smoothstep(0.0, 0.025, edge_u)) * step(sill, fv) * step(fv, head);
	frame = max(frame, (1.0 - smoothstep(0.0, 0.02, edge_v)) * step(mullion, fu) * step(fu, 1.0 - mullion));
	if (!in_base && !in_parapet && !pier) {
		col = mix(col, frame_color, frame * 0.7);
	}

	// Cheap ambient occlusion: walls darken towards the ground.
	col *= mix(0.62, 1.0, smoothstep(0.0, 3.0, h));

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
}
