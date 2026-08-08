shader_type canvas_item;

// PS1-style color crush + ordered dithering, drawn as a fullscreen pass by
// the PsxLook autoload (scripts/autoload/psx_look.gd) on a NEGATIVE
// CanvasLayer: at that point the screen texture holds only the 3D render,
// so HUD/menus (layer >= 0) stay crisp. See PS1_SETUP.md.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// The virtual low-res grid. PsxLook keeps this at the 3D internal
// resolution (scaling_3d_scale) so the snap re-chunks the bilinear upscale
// into hard texels and the dither aligns to them, not to window pixels.
uniform vec2 internal_resolution = vec2(480.0, 270.0);

// Per-channel color levels. PS1 was 15-bit color = 5 bits/channel = 32.
// Drop to 16 or 8 for heavier banding.
uniform float color_steps = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

// 4x4 Bayer ordered-dither matrix.
const float bayer[16] = {
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
};

void fragment() {
    vec2 cell = floor(SCREEN_UV * internal_resolution);
    vec2 uv = (cell + 0.5) / internal_resolution;
    vec3 col = texture(screen_tex, uv).rgb;

    ivec2 pix = ivec2(mod(cell, 4.0));
    float threshold = (bayer[pix.x + pix.y * 4] + 0.5) / 16.0 - 0.5;

    col += (threshold * dither_strength) / color_steps;   // dither...
    col = floor(col * color_steps + 0.5) / color_steps;   // ...then quantize

    COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
