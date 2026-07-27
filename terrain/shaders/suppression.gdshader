// suppression.gdshader - full-screen "under heavy fire" + "you are hurt" overlay.
// Two uniforms 0..1:
//   amount - suppression: colour drains toward grey, dark vignette closes in,
//            frame dims. The Hell Let Loose "get down" read.
//   hurt   - pain: the vignette tints blood red-brown and deepens as HP drops
//            (no HP bar by design - THIS is the health display), plus the hit
//            pulse the player script spikes on each wound.
shader_type canvas_item;
render_mode unshaded;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
// filter_linear, NOT filter_linear_mipmap: the fragment samples at LOD 0 only, and
// the mipmap hint makes Godot build the full mip chain of the screen copy each frame.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// Desaturate toward luminance (suppression only).
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), amount * 0.85);

	vec2 d = SCREEN_UV - vec2(0.5);
	float vig = smoothstep(0.35, 0.85, length(d));

	// Suppression vignette: dark, pressing in.
	col *= 1.0 - vig * amount * 0.9;

	// Hurt vignette: blood at the edges, deeper red the lower you are.
	vec3 blood = vec3(0.35, 0.03, 0.02);
	float hv = smoothstep(0.25, 0.8, length(d)) * hurt;
	col = mix(col, blood, hv * 0.75);
	// Centre desaturation + dim only when badly wounded (>60% lost).
	float grave = max(hurt - 0.6, 0.0) * 2.5;
	col = mix(col, vec3(lum) * 0.85, grave * 0.35);

	// Slight overall dim so even the centre feels pressed.
	col *= 1.0 - amount * 0.18;

	COLOR = vec4(col, 1.0);
}
