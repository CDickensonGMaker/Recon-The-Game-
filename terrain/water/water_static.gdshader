shader_type spatial;
render_mode cull_back, depth_draw_always;

#include "res://terrain/water/water_common.gdshaderinc"

// Vertex COLOR contract, baked by water_system.gd:
//   R = shore proximity (0 at the waterline, 1 well inside the body)
//   G = depth, 0..1 over COMBINED_DEPTH_RANGE
//   B = 0 standing water | 0.02..0.98 flow heading as angle/TAU
// The mesh carries NO ARRAY_TANGENT, so this writes NORMAL directly and never
// NORMAL_MAP - a tangent-space normal would resolve against a zero tangent.
uniform vec3 col_shallow : source_color = vec3(0.29, 0.30, 0.21);
uniform vec3 col_deep : source_color = vec3(0.055, 0.085, 0.065);
uniform vec3 col_silt : source_color = vec3(0.27, 0.20, 0.115);
uniform vec3 col_sky : source_color = vec3(0.60, 0.66, 0.70);
uniform vec3 col_foam : source_color = vec3(0.72, 0.71, 0.62);

uniform float alpha_shallow : hint_range(0.0, 1.0) = 0.50;
uniform float alpha_deep : hint_range(0.0, 1.0) = 0.93;
uniform float sky_strength : hint_range(0.0, 1.0) = 0.30;
uniform float silt_show : hint_range(0.0, 1.0) = 0.55;

uniform float rough_calm : hint_range(0.0, 1.0) = 0.12;
uniform float rough_murky : hint_range(0.0, 1.0) = 0.28;

uniform float ripple_scale : hint_range(0.05, 2.0) = 0.45;
uniform float ripple_steepness : hint_range(0.0, 3.0) = 0.85;
uniform float flow_speed : hint_range(0.0, 1.0) = 0.30;
uniform float still_speed : hint_range(0.0, 0.5) = 0.05;
uniform vec2 still_drift = vec2(1.0, 0.3);

uniform float foam_strength : hint_range(0.0, 1.0) = 0.55;
uniform float shore_fade : hint_range(0.02, 1.0) = 0.30;
uniform float murk_scale : hint_range(0.5, 12.0) = 1.2;
uniform float world_uv_scale = 0.05;

varying vec3 v_world;
varying float v_depth;
varying float v_shore;
varying float v_flow;

// Three crossing sine trains with analytic derivatives -> a world-space normal.
// Cheaper than water_normal_from_height's finite differences (9 sine evals) and
// exact instead of approximate.
vec3 water_ripple_normal(vec2 p, vec2 flow, float t, float steep) {
	vec2 d1 = normalize(flow + vec2(0.35, -0.20));
	vec2 d2 = normalize(flow + vec2(-0.55, 0.40));
	vec2 d3 = normalize(vec2(flow.y, -flow.x) + flow * 0.25);

	float f1 = 1.90;
	float f2 = 3.70;
	float f3 = 0.85;
	float a1 = 0.55;
	float a2 = 0.26;
	float a3 = 0.80;

	float p1 = dot(p, d1) * f1 + t * 1.10;
	float p2 = dot(p, d2) * f2 + t * 1.75;
	float p3 = dot(p, d3) * f3 + t * 0.45;

	vec2 grad = d1 * (a1 * f1 * cos(p1))
			+ d2 * (a2 * f2 * cos(p2))
			+ d3 * (a3 * f3 * cos(p3));

	return normalize(vec3(-grad.x * steep, 1.0, -grad.y * steep));
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_shore = COLOR.r;
	v_depth = COLOR.g;
	v_flow = COLOR.b;
}

void fragment() {
	// Channels carry their own downstream heading; standing water drifts globally.
	float is_channel = step(0.001, v_flow);
	float ang = (v_flow - 0.02) / 0.96 * TAU;
	vec2 flow = mix(normalize(still_drift), vec2(cos(ang), sin(ang)), is_channel);
	float speed = mix(still_speed, flow_speed, is_channel);

	vec2 wuv = v_world.xz;

	vec3 n_world = water_ripple_normal(wuv * ripple_scale, flow, TIME * speed * 6.0, ripple_steepness);
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	vec2 uv1;
	vec2 uv2;
	water_flow_uvs(wuv * world_uv_scale, flow, speed * 0.15, TIME, uv1, uv2);
	float murk = (water_fbm(uv1 * murk_scale, 2) + water_fbm(uv2 * murk_scale, 2)) * 0.5;

	float d = clamp(v_depth, 0.0, 1.0);
	vec3 body = mix(col_shallow, col_deep, d);
	body = mix(body, col_silt, (1.0 - d) * silt_show * murk);
	body *= mix(0.88, 1.08, murk);

	// Grazing water is a mirror, head-on water is a window.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	fres = clamp(0.02 + 0.98 * fres, 0.0, 1.0);
	body = mix(body, col_sky, fres * sky_strength);

	float edge = 1.0 - smoothstep(0.0, shore_fade, v_shore);
	float fnoise = water_fbm(wuv * 0.55 + flow * (TIME * speed * 0.6), 2);
	float foam = smoothstep(0.30, 0.85, edge * (0.55 + fnoise * 0.9)) * foam_strength;
	body = mix(body, col_foam, foam);

	float a = mix(alpha_shallow, alpha_deep, d);
	a = mix(a, 1.0, fres * 0.85);
	a = max(a, foam * 0.9);
	a *= smoothstep(0.0, shore_fade, v_shore);

	ALBEDO = body;
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = clamp(mix(rough_calm, rough_murky, murk) + foam * 0.65, 0.0, 1.0);
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
