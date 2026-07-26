shader_type spatial;

// FP VIEWMODEL LENS (ADR-034): the gun renders through its own narrower FOV
// (real-scale mesh, no scale hack) and is depth-squashed into the nearest depth
// slice so it can never clip world geometry.
// - p[3][3] == 0 guards the perspective pass only; ortho shadow/depth passes
//   pass through untouched (viewmodel meshes also have cast_shadow OFF).
// - Reverse-Z (Godot 4.3+): near plane is z = w, so the squash mixes TOWARD w.

instance uniform float viewmodel_fov : hint_range(20.0, 120.0) = 60.0;

uniform vec4 albedo_col : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float roughness_val : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	mat4 p = PROJECTION_MATRIX;
	bool persp = p[3][3] == 0.0;
	if (persp) {
		float aspect = p[1][1] / p[0][0];
		float cotan = 1.0 / tan(radians(viewmodel_fov) * 0.5);
		p[1][1] = cotan;
		p[0][0] = cotan / aspect;
	}
	POSITION = p * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (persp) {
		POSITION.z = mix(POSITION.z, POSITION.w, 0.9);
	}
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_col;
	ALBEDO = tex.rgb;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
}
