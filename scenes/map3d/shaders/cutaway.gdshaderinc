// Cutaway: anything above cut_height inside cut_rect (world x0, z0, x1, z1) is not drawn,
// so the floors above an interior can be lifted off. MaterialBank sets these uniforms.
uniform vec4 cut_rect = vec4(0.0);
uniform float cut_height = 100000.0;

varying vec3 cut_world_pos;

bool is_cut_away() {
	return cut_world_pos.y > cut_height
		&& cut_world_pos.x > cut_rect.x && cut_world_pos.x < cut_rect.z
		&& cut_world_pos.z > cut_rect.y && cut_world_pos.z < cut_rect.w;
}
