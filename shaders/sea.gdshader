shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, shadows_disabled;

// Waves on the GPU. sea.gd keeps the same function so the ship rides the water it sees.
uniform float amplitude = 0.1;
uniform float sea_time = 0.0;
uniform float storm = 0.0;
uniform float shore_z = 2.5;
uniform bool open_sea = false;
uniform vec3 deep_color : source_color = vec3(0.08, 0.30, 0.52);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.62, 0.74);
uniform vec3 sky_color : source_color = vec3(0.42, 0.60, 0.90);
uniform vec3 foam_color : source_color = vec3(0.98, 0.98, 0.96);

varying float crest;
varying vec3 world_pos;

float wave_height(vec2 p, float t) {
    float w1 = sin(p.x * 0.35 + t * 1.1);
    float w2 = sin((p.x + p.y) * 0.21 - t * 0.8) * 0.6;
    float w3 = sin(p.y * 0.5 + t * 1.6) * 0.35;
    float w4 = sin((p.x * 0.6 - p.y * 0.4) + t * 1.9) * 0.25;
    float chop = storm > 0.4 ? sin(p.x * 1.3 - t * 3.2) * 0.12 * storm : 0.0;
    float fade = open_sea ? 1.0 : smoothstep(shore_z + 0.5, shore_z + 4.0, p.y);
    return amplitude * fade * (w1 + w2 + w3 + w4 + chop);
}

void vertex() {
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float h = wave_height(wp.xz, sea_time);
    VERTEX.y += h;
    float e = 0.4;
    float hx = wave_height(wp.xz + vec2(e, 0.0), sea_time) - wave_height(wp.xz - vec2(e, 0.0), sea_time);
    float hz = wave_height(wp.xz + vec2(0.0, e), sea_time) - wave_height(wp.xz - vec2(0.0, e), sea_time);
    NORMAL = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
    crest = clamp(h / max(amplitude, 0.001), -1.0, 1.0);
    world_pos = wp;
}

// Detail normals (three.js waternormals.jpg), two layers scrolling across each other.
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float ripple_strength = 0.55;

vec3 ripple_normal(vec2 p, float t) {
    vec2 uv1 = p * 0.045 + vec2(t * 0.012, t * 0.008);
    vec2 uv2 = p * 0.11 + vec2(-t * 0.018, t * 0.014);
    vec3 a = texture(normal_map, uv1).xyz * 2.0 - 1.0;
    vec3 b = texture(normal_map, uv2).xyz * 2.0 - 1.0;
    vec3 n = a + b * 0.6;
    // Tangent space (x, y along the surface, z up) to world (y up).
    return normalize(vec3(n.x, n.z, n.y));
}

void fragment() {
    float depth_mix = open_sea ? 0.7 : clamp((world_pos.z - shore_z) / 10.0, 0.0, 1.0);
    vec3 base = mix(shallow_color, deep_color, depth_mix);
    // Ripples on top of the swell normal, in view space.
    vec3 rn = ripple_normal(world_pos.xz, sea_time);
    vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz + vec3(rn.x, 0.0, rn.z) * (ripple_strength + storm * 0.6));
    NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
    // Glassy look: the sky shows in the water at grazing angles.
    float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
    base = mix(base, sky_color, fres * 0.15);
    // Crest foam broken into streaks by the detail texture, never whole white sheets.
    float streaks = smoothstep(0.55, 0.85, texture(normal_map, world_pos.xz * 0.02 + vec2(sea_time * 0.01, 0.0)).r);
    float foam = smoothstep(0.7, 1.0, crest) * streaks * (0.25 + 0.5 * storm);
    // Thin foam line along the shore.
    if (!open_sea) {
        foam += smoothstep(1.6, 0.0, abs(world_pos.z - shore_z - 0.9)) * 0.45;
    }
    ALBEDO = mix(base, foam_color, clamp(foam, 0.0, 1.0));
    ROUGHNESS = 0.16;
    SPECULAR = 0.4;
    METALLIC = 0.0;
}
