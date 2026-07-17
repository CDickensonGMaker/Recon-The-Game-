shader_type spatial;
render_mode cull_back, depth_draw_always;

#include "res://terrain/water/water_common.gdshaderinc"

// Vietnam creeks/rivers, PS2 look: a scrolling murky sheet, flat palette tint,
// no fresnel / normal maps / specular. Vertex COLOR.g = depth, COLOR.r = shore.
uniform float flow_speed : hint_range(0.0, 0.5) = 0.04;
uniform float murk_scale : hint_range(0.5, 12.0) = 5.0;
uniform float world_uv_scale = 0.05;
uniform vec2 flow_dir = vec2(1.0, 0.3);
uniform float shore_fade_m : hint_range(0.5, 6.0) = 2.5;

varying vec2 v_world_uv;
varying float v_depth;
varying float v_shore;

void vertex() {
	v_world_uv = VERTEX.xz * world_uv_scale;
	v_depth = COLOR.g;
	v_shore = COLOR.r * 10.0;
}

void fragment() {
	vec2 uv1;
	vec2 uv2;
	water_flow_uvs(v_world_uv, normalize(flow_dir), flow_speed, TIME, uv1, uv2);
	float murk = (water_fbm(uv1 * murk_scale, 3) + water_fbm(uv2 * murk_scale, 3)) * 0.5;

	vec4 shallow = water_color_creek();
	vec4 deep = water_color_river_deep();
	float t = clamp(v_depth, 0.0, 1.0);
	vec3 base = mix(shallow.rgb, deep.rgb, t);
	base *= mix(0.70, 1.12, murk);

	ALBEDO = base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ALPHA = mix(shallow.a, deep.a, t) * water_shore_blend(v_shore, shore_fade_m);
}
