// vegetation_sway.gdshader - PSX-cheap wind for palms, vines and grass fans.
//
// Vertex-displacement sway masked by painted vertex colors (batch-painted by
// tools/make_jungle_vegetation.py):
//   COLOR.r - master sway mask: 0 at trunk base (roots stay planted) rising
//             to ~1 at frond tips. Slow trunk-lean frequency rides this.
//   COLOR.g - flutter mask: frond tips + vine ends only. Fast frequency.
// Phase comes from the instance's world origin (MODEL_MATRIX[3] - folded per
// instance by MultiMesh) so the jungle never sways in unison.
//
// No PBR - lambert diffuse, no specular, nearest filter, alpha scissor:
// the ground_clutter.gd / PSX recipe as a ShaderMaterial. cull_disabled so
// the grass star-fans and palm fronds read from both sides.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.4;

uniform float wind_strength : hint_range(0.0, 2.0) = 0.35; // metres at mask=1
uniform float wind_speed : hint_range(0.0, 4.0) = 1.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);                    // world XZ
uniform float flutter_strength : hint_range(0.0, 0.5) = 0.06;
uniform float flutter_speed : hint_range(0.0, 16.0) = 5.0;

void vertex() {
	// Shadow maps don't need the sway animated - skip the wind math in the shadow
	// pass (4.7 IN_SHADOW_PASS): foliage casts a resting shadow, vertex work saved.
	if (!IN_SHADOW_PASS) {
		vec3 origin = MODEL_MATRIX[3].xyz; // per-instance world origin
		float phase = origin.x * 0.37 + origin.z * 0.53;
		vec2 wdir = normalize(wind_dir + vec2(1e-4));

		// slow trunk lean: two detuned sines read as gusts, not a metronome
		float t = TIME * wind_speed + phase;
		float lean = sin(t) * 0.64 + sin(t * 0.313 + 1.7) * 0.36;
		vec3 sway = vec3(wdir.x, 0.0, wdir.y) * (lean * wind_strength * COLOR.r);

		// fast frond flutter: per-vertex phase so tips shimmer independently
		float f = sin(TIME * flutter_speed + phase
			+ VERTEX.x * 2.3 + VERTEX.y * 1.1 + VERTEX.z * 1.9);
		sway += vec3(wdir.x, -0.5, wdir.y) * (f * flutter_strength * COLOR.g);

		// world-space wind -> model space (transpose rotation, re-normalised so
		// instance scale never squares into the amplitude)
		float amp = length(sway);
		if (amp > 1e-6) {
			vec3 model_dir = normalize((vec4(sway, 0.0) * MODEL_MATRIX).xyz);
			VERTEX += model_dir * amp;
		}
	}
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_tint;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 1.0;
}
