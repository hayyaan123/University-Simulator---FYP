// Student figures drawn with one MultiMesh.
// INSTANCE_CUSTOM.rgb = shirt colour (by state), INSTANCE_CUSTOM.a = 1 while walking.
// Vertex COLOR.a = 1 on the shirt (tinted), 0 on skin, hair and trousers (kept as is).
shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Figures grow as the camera zooms out so they stay visible, like the dots on the 2D map.
uniform float figure_scale = 1.0;

varying vec3 shirt;
varying float shirt_mask;

void vertex() {
	float walking = INSTANCE_CUSTOM.a;
	float phase = float(INSTANCE_ID) * 1.618;
	VERTEX *= figure_scale;
	VERTEX.y += walking * abs(sin(TIME * 9.0 + phase)) * 0.07 * figure_scale;
	shirt = INSTANCE_CUSTOM.rgb;
	shirt_mask = COLOR.a;
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, shirt, shirt_mask);
	// A little glow on the shirt keeps figures readable in shade and from far away.
	EMISSION = shirt * shirt_mask * 0.35;
	ROUGHNESS = 0.85;
}
