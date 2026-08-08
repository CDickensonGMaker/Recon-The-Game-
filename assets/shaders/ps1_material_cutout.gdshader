shader_type spatial;

// Cutout twin of ps1_material.gdshader, for alpha-scissored surfaces: foliage
// cards, grates, netting, wire. cull_disabled because a card is one-sided
// geometry read from both faces. Scissor only - no alpha blending, so these
// stay in the opaque pass and need no depth prepass and no sorting.
render_mode vertex_lighting, diffuse_lambert_wrap, specular_disabled, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_vertex_color = true;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

uniform vec2 snap_resolution = vec2(240.0, 180.0);
uniform float wobble_amount : hint_range(0.0, 1.0) = 1.0;
uniform float affine_amount : hint_range(0.0, 1.0) = 1.0;

varying vec2 affine_uv;
varying float affine_w;

void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

    vec4 snapped = clip;
    snapped.xyz /= snapped.w;
    vec2 grid = snap_resolution * 0.5;
    vec2 snap_xy = round(snapped.xy * grid) / grid;
    snapped.xy = mix(snapped.xy, snap_xy, wobble_amount);
    snapped.xyz *= snapped.w;
    POSITION = snapped;

    affine_w = mix(1.0, clip.w, affine_amount);
    affine_uv = UV * affine_w;
}

void fragment() {
    vec2 uv = affine_uv / affine_w;
    vec4 tex = texture(albedo_tex, uv);

    vec3 col = tex.rgb * albedo_color.rgb;
    float a = tex.a * albedo_color.a;
    if (use_vertex_color) {
        col *= COLOR.rgb;
        a *= COLOR.a;
    }

    ALBEDO = col;
    ALPHA = a;
    ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
}
