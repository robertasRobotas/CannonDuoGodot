// Ground built from a heightfield (see Terrain): rock and turf blended by the vertex
// colour's alpha (1 = turf), tinted by its rgb. The rock is sampled triplanar, so steep
// faces do not smear; the turf is broken up with a second, coarse octave against tiling.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform float rock_scale = 0.14;
uniform float grass_scale = 0.07;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 vcol;

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vcol = COLOR;
}

void fragment() {
    vec3 w = abs(wnrm);
    w = w * w * w * w;
    w /= max(w.x + w.y + w.z, 0.0001);
    vec3 r = texture(rock, wpos.zy * rock_scale).rgb * w.x
        + texture(rock, wpos.xz * rock_scale).rgb * w.y
        + texture(rock, wpos.xy * rock_scale).rgb * w.z;
    vec3 g = texture(grass, wpos.zy * grass_scale).rgb * w.x
        + texture(grass, wpos.xz * grass_scale).rgb * w.y
        + texture(grass, wpos.xy * grass_scale).rgb * w.z;
    g *= 0.8 + 0.4 * texture(grass, wpos.xz * grass_scale * 0.11).g;
    // The textures are dark on their own: each lifted to a mid tone, so the tint rules.
    r = min(r * 1.5, vec3(1.0));
    g = min(g * 2.6, vec3(1.0));
    ALBEDO = min(mix(r, g, vcol.a) * vcol.rgb, vec3(1.0));
    ROUGHNESS = 0.95;
    SPECULAR = 0.15;
}
