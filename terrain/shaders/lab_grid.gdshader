// lab_grid.gdshader - white studio floor with a world-space metre grid.
// Unshaded so lighting never confuses a readability judgement: in the combat lab
// you are reading silhouettes, muzzle flashes and tracers, not lighting.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.92, 0.92, 0.90);
uniform vec3 line_color : source_color = vec3(0.62, 0.64, 0.66);
uniform vec3 major_color : source_color = vec3(0.35, 0.38, 0.42);
uniform float cell_size = 1.0;      // metres per minor cell
uniform float major_every = 5.0;    // a heavier line every N cells
uniform float line_width = 0.02;    // metres

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Screen-space-derivative-aware line so it does not alias into moire at range.
float grid_line(vec2 p, float spacing, float width) {
	vec2 g = abs(fract(p / spacing - 0.5) - 0.5) * spacing;
	vec2 fw = fwidth(p) * 1.5;
	vec2 l = smoothstep(vec2(width) + fw, vec2(width), g);
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	float minor = grid_line(p, cell_size, line_width);
	float major = grid_line(p, cell_size * major_every, line_width * 2.0);

	vec3 c = base_color;
	c = mix(c, line_color, minor);
	c = mix(c, major_color, major);
	ALBEDO = c;
}
