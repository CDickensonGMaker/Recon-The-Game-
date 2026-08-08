shader_type spatial;

// PS1-style surface material for Godot 4.7
// - vertex_lighting  : lighting is computed per-vertex (Gouraud), the PS1 way.
// - specular_disabled: PS1 had no per-pixel specular.
// - Swap "vertex_lighting" for "unshaded" if you bake all light into
//   textures / vertex colors and want zero real-time lighting.
render_mode vertex_lighting, diffuse_lambert_wrap, specular_disabled, cull_back;

// --- Texture -----------------------------------------------------------
// filter_nearest = no bilinear (crunchy texels). repeat_enable = tiling.
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = true;   // multiply in baked vertex colors/AO

// --- Vertex wobble -----------------------------------------------------
// The virtual screen resolution the vertices snap to. Lower = chunkier
// wobble. 320x240 is "clean PS1"; 160x120 is heavy, gritty wobble.
uniform vec2 snap_resolution = vec2(240.0, 180.0);
uniform float wobble_amount : hint_range(0.0, 1.0) = 1.0; // 0 = off, 1 = full

// --- Affine texture warp ----------------------------------------------
// 0 = modern perspective-correct UVs, 1 = full PS1 texture "swim".
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

varying vec2 affine_uv;
varying float affine_w;

void vertex() {
    // Project the vertex to clip space ourselves.
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

    // --- Positional snapping (the PS1 vertex jitter) ---
    vec4 snapped = clip;
    snapped.xyz /= snapped.w;                 // to normalized device coords
    vec2 grid = snap_resolution * 0.5;        // NDC spans -1..1
    vec2 snap_xy = round(snapped.xy * grid) / grid;
    snapped.xy = mix(snapped.xy, snap_xy, wobble_amount);
    snapped.xyz *= snapped.w;                 // back to clip space
    POSITION = snapped;                       // override final position

    // --- Affine mapping setup ---
    // Pass UV*w and w so the perspective-correct rasterizer cancels out
    // to a screen-linear (affine) mapping. Blend toward w=1 to soften it.
    affine_w = mix(1.0, clip.w, affine_amount);
    affine_uv = UV * affine_w;
}

void fragment() {
    vec2 uv = affine_uv / affine_w;
    vec4 tex = texture(albedo_tex, uv);

    vec3 col = tex.rgb * albedo_color.rgb;
    float a = tex.a * albedo_color.a;
    if (use_vertex_color) {
        col *= COLOR.rgb;   // baked vertex color / vertex AO
        a *= COLOR.a;
    }

    ALBEDO = col;
    ALPHA = a;
    // For hard-edged PS1 cutouts (foliage, grates), uncomment:
    // ALPHA_SCISSOR_THRESHOLD = 0.5;
}
