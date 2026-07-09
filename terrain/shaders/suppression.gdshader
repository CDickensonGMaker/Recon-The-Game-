// suppression.gdshader - full-screen "under heavy fire" overlay.
// Driven by one uniform 0..1. As it rises: colour drains toward grey, a dark
// vignette closes in from the edges, and the whole frame dims a touch. This is
// the Hell Let Loose "get down, you're being shot at" read.
shader_type canvas_item;
render_mode unshaded;

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// Desaturate toward luminance.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), amount * 0.85);

	// Vignette: darken the edges, hardest near full suppression.
	vec2 d = SCREEN_UV - vec2(0.5);
	float vig = smoothstep(0.35, 0.85, length(d));
	col *= 1.0 - vig * amount * 0.9;

	// Slight overall dim so even the centre feels pressed.
	col *= 1.0 - amount * 0.18;

	COLOR = vec4(col, 1.0);
}
