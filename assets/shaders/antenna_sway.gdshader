shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, vertex_lighting;

// PRC-25 WHIP ANTENNA SWAY
//
// A 1.07 m steel whip on a running man's back does not swing like a rigid rod on a
// hinge - it BENDS, and it bends more the further you get from where it is clamped.
// So this is a vertex shader, not a bone chain:
//
//   * the base is PINNED (t = 0, no displacement) - it is bolted to the radio
//   * the tip whips (t = 1, full displacement)
//   * everything between bends on a curve, so the whip reads as springy metal
//
// Costs no bones, no extra nodes, and no CPU beyond one Vector2 per frame. The rig is
// 41 bones already; this buys secondary motion without touching it.
//
// `sway` is the TIP DISPLACEMENT IN METRES, in the antenna's own local space, and is
// written every physics frame by scripts/visuals/antenna_sway.gd.

uniform vec2 sway = vec2(0.0, 0.0);

// The whip runs along local +Y in Godot (Blender's +Z becomes Godot's +Y on export).
// These describe where the whip starts and how long it is, so the bend curve is
// anchored to the real geometry rather than guessed.
uniform float base_y = 0.0;
uniform float whip_len = 1.07;

// 1.0 = the whole rod leans (stiff). 2.0 = a proper whip - the base barely moves and
// the last third does most of the travel. 3.0 = a fishing rod.
uniform float bend_power : hint_range(1.0, 3.0) = 2.0;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness_v : hint_range(0.0, 1.0) = 0.45;
uniform float metallic_v : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float t = clamp((VERTEX.y - base_y) / max(whip_len, 0.0001), 0.0, 1.0);
	float k = pow(t, bend_power);
	VERTEX.x += sway.x * k;
	VERTEX.z += sway.y * k;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	ALBEDO = c.rgb;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
}
