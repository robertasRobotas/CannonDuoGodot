shader_type spatial;

// Island ground: sand near the water, the island's own ground inland, blended by vertex colour
// (r = sand, g = wet), textured in world space so it never stretches over dunes and hills.
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D land_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 sand_tint : source_color = vec3(1.0);
uniform vec3 land_tint : source_color = vec3(1.0);
uniform float sand_scale = 0.4;
uniform float land_scale = 0.3;

varying vec3 wpos;

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 sand = texture(sand_tex, wpos.xz * sand_scale).rgb * sand_tint;
    vec3 land = texture(land_tex, wpos.xz * land_scale).rgb * land_tint;
    // Break the sand line up with the texture itself so it is never a clean edge.
    float edge = clamp(COLOR.r + (texture(land_tex, wpos.xz * 0.05).g - 0.5) * 0.6, 0.0, 1.0);
    vec3 c = mix(land, sand, smoothstep(0.35, 0.65, edge));
    c *= mix(1.0, 0.62, COLOR.g);          // wet sand is darker
    ALBEDO = c;
    ROUGHNESS = mix(0.95, 0.35, COLOR.g);
}
