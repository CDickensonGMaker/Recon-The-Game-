shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled, vertex_lighting, depth_prepass_alpha;

// JUNGLE FOLIAGE: WIND SWAY + PARTING
//
// Same idea as the PRC-25 whip (assets/shaders/antenna_sway.gdshader): bend the mesh in
// the VERTEX stage, anchored at the base, so it costs no bones, no nodes and no CPU.
// A blade of elephant grass is 8 tris; it can never afford a skeleton. But it can afford
// a sine.
//
// TWO THINGS MOVE IT:
//
// 1. WIND. Two octaves - a fast rustle riding a slow gust - so it never reads as a
//    metronome. The phase is derived from the vertex's WORLD position, which means every
//    plant in the field is out of step with its neighbours FOR FREE. No per-instance
//    uniform, no script, works under MultiMesh instancing where you cannot address
//    instances individually. Without this, a field of grass pulses in unison and looks
//    like a single object, which is the classic tell.
//
// 2. PARTING. Anything in `pushers` shoves the foliage AWAY from it, horizontally. This
//    is not decoration - it is INFORMATION. In a stealth game the player needs to read
//    "something is moving through that grass", and a VC crawling through elephant grass
//    100 m out should announce himself by the wake he leaves. It also stops the player's
//    own legs from clipping through blades he is standing in.
//
// ANCHORING: displacement scales with height above the plant's base, so the roots never
// move. Base height comes from the vertex COLOR's red channel (0 = root, 1 = tip) when
// the mesh has one - that is the robust way, because it survives any origin the artist
// chooses. If there is no vertex colour we fall back to local Y over `plant_height`.

group_uniforms Wind;
// Direction the wind blows, in world XZ. Length is ignored; use wind_strength.
uniform vec2 wind_dir = vec2(1.0, 0.35);
// Metres of tip travel at full gust.
uniform float wind_strength : hint_range(0.0, 1.0) = 0.16;
uniform float rustle_speed : hint_range(0.0, 8.0) = 2.6;
uniform float gust_speed : hint_range(0.0, 2.0) = 0.35;
// How much of the motion is the slow gust vs the fast rustle.
uniform float gust_mix : hint_range(0.0, 1.0) = 0.65;
// Bigger = neighbouring plants are more out of step with each other.
uniform float phase_scatter : hint_range(0.0, 4.0) = 1.4;

group_uniforms Anchor;
// 1.0 = whole plant leans stiffly. 2.0 = grass (root pinned, tip does the travel).
uniform float bend_power : hint_range(1.0, 3.0) = 1.8;
// Only used when the mesh has NO vertex colour.
uniform float plant_height = 1.0;
uniform bool use_vertex_color_height = true;

group_uniforms Parting;
// xyz = world position, w = radius. w <= 0 means "unused slot".
// Written by scripts/visuals/foliage_wind.gd via RenderingServer global uniforms.
global uniform vec4 foliage_pushers[8];
uniform float push_strength : hint_range(0.0, 1.5) = 0.55;

group_uniforms Surface;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;


void vertex() {
	// --- how far up the plant is this vertex? 0 at the root, 1 at the tip.
	float t;
	if (use_vertex_color_height) {
		t = clamp(COLOR.r, 0.0, 1.0);
	} else {
		t = clamp(VERTEX.y / max(plant_height, 0.0001), 0.0, 1.0);
	}
	float k = pow(t, bend_power);
	if (k <= 0.0001) {
		return;                       // the root does not move. Ever.
	}

	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// --- WIND. Phase off world position so no two plants march in step.
	float phase = (world_pos.x + world_pos.z) * phase_scatter;
	float rustle = sin(TIME * rustle_speed + phase);
	float gust = sin(TIME * gust_speed + phase * 0.31);
	// keep the gust one-sided-ish so it reads as air pushing, not the plant flapping
	gust = gust * 0.5 + 0.5;
	float amount = mix(rustle, rustle * gust, gust_mix) * wind_strength;

	vec2 dir = normalize(wind_dir + vec2(0.0001, 0.0));
	vec3 offset = vec3(dir.x, 0.0, dir.y) * amount;

	// --- PARTING. Anything close shoves the plant away from it.
	for (int i = 0; i < 8; i++) {
		vec4 p = foliage_pushers[i];
		if (p.w <= 0.0) {
			continue;
		}
		vec3 away = world_pos - p.xyz;
		away.y = 0.0;
		float d = length(away);
		if (d < p.w && d > 0.0001) {
			// hardest right at the body, easing to nothing at the radius
			float f = 1.0 - (d / p.w);
			f = f * f;
			offset += normalize(away) * f * push_strength;
		}
	}

	// bend, do not stretch: a plant pushed sideways also gets shorter.
	vec3 bent = vec3(offset.x, 0.0, offset.z) * k;
	VERTEX += bent;
	VERTEX.y -= length(bent.xz) * 0.25 * k;
}


void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	if (c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	// leaves are thin - let a little light through the back so the canopy is not a wall
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
