shader_type canvas_item;

// PS1-style color crush + ordered dithering.
// Put this on the TextureRect that displays your low-res SubViewport
// (see PS1_SETUP.md). It reads that TextureRect's texture via TEXTURE.

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
    vec3 col = texture(TEXTURE, UV).rgb;

    // Align the dither grid to the LOW-RES texels, not the upscaled window,
    // so the pattern stays chunky and stable.
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));
    ivec2 pix = ivec2(mod(UV * tex_size, 4.0));
    float threshold = (bayer[pix.x + pix.y * 4] + 0.5) / 16.0 - 0.5;

    col += (threshold * dither_strength) / color_steps;   // dither...
    col = floor(col * color_steps + 0.5) / color_steps;   // ...then quantize

    COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
