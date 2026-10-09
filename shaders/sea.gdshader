shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, shadows_disabled;

// Waves on the GPU. sea.gd keeps the same function so the ship rides the water it sees.
uniform float amplitude = 0.1;
uniform float sea_time = 0.0;
uniform float storm = 0.0;
uniform float shore_z = 2.5;
uniform bool open_sea = false;
// The island's curved shoreline (same formula as Decor.shore_z), so waves calm along it.
uniform float shore_seed = 0.0;
uniform bool curved_shore = false;

float shore_at(float x) {
    if (!curved_shore) {
        return shore_z;
    }
    float p = shore_seed;
    float w = 3.0 * sin(x * 0.07 + p) + 1.7 * sin(x * 0.19 + p * 2.3) + 0.8 * sin(x * 0.41 + p * 0.7);
    w *= mix(0.55, 1.0, smoothstep(6.0, 20.0, abs(x)));
    return shore_z + w + max(0.0, -x - 26.0) * 0.5;
}
uniform vec3 deep_color : source_color = vec3(0.08, 0.30, 0.52);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.62, 0.74);
uniform vec3 sky_color : source_color = vec3(0.42, 0.60, 0.90);
uniform vec3 foam_color : source_color = vec3(0.98, 0.98, 0.96);
// Longer waves for big swells, so a ship can ride them instead of cutting through.
uniform float wave_len = 1.0;
// The player's hull footprint (x, z centre, half length, half width) and its waterline: the
// water surface is kept below the deck there, so the sea never shows inside the ship.
uniform vec4 hull = vec4(0.0, 0.0, 0.0, 0.0);
uniform float hull_floor = -100.0;

varying float crest;
varying vec3 world_pos;

// Travelling swell crests for the voyage levels (set by VoyageLevel each frame):
// x = crest line z, y = breaking-section centre x, z = breaking half width (0 = clean swell),
// w = crest height in metres. The ridge is real displaced water, not a sprite.
uniform int wave_crest_count = 0;
uniform vec4 wave_crests[6];
// Water streaming past the hull (metres per second): the chase levels' sense of speed.
uniform vec2 current = vec2(0.0, 0.0);
// Whirlpools: x, z centre, radius, depth. A real funnel in the surface, matched on the CPU.
uniform int sink_count = 0;
uniform vec4 sinks[4];

float sink_dip(vec2 q) {
    float dip = 0.0;
    for (int i = 0; i < sink_count; i++) {
        vec4 s = sinks[i];
        float d = distance(q, s.xy);
        float k = clamp(1.0 - d / s.z, 0.0, 1.0);
        dip += s.w * pow(k, 1.7);
    }
    return dip;
}

float crest_ridge(vec2 q) {
    float sum = 0.0;
    for (int i = 0; i < wave_crest_count; i++) {
        vec4 c = wave_crests[i];
        float d = q.y - c.x;
        // A steep face toward the ship, a long sloping back: a wave, not a bump.
        float sigma = d > 0.0 ? 2.3 : 3.6;
        float r = c.w * exp(-d * d / (sigma * sigma));
        if (c.z > 0.001) {
            // The breaking section rears up taller before it falls.
            r *= 1.0 + 0.22 * (1.0 - smoothstep(0.75, 1.1, abs(q.x - c.y) / c.z));
        }
        sum += r;
    }
    return sum;
}

// Peaked (trochoid-like) profile: sharp crests, wide troughs, like real wind sea.
float pw(float ph) {
    float s = 0.5 + 0.5 * sin(ph);
    return pow(s, 2.4) * 2.0 - 1.0;
}

float wave_height(vec2 q, float t) {
    vec2 p = (q + current * t) / wave_len;
    float h;
    if (open_sea) {
        // Directional trains all travelling +z (the way the swell runs at the ship).
        h = pw(p.y * 0.32 - t * 1.25) * 0.95
          + pw((p.y * 0.21 + p.x * 0.07) - t * 0.9) * 0.55
          + pw((p.y * 0.55 - p.x * 0.13) - t * 2.0) * 0.28
          + sin(p.x * 0.4 + t * 0.8) * 0.22;
        h *= amplitude;
    } else {
        float w1 = sin(p.x * 0.35 + t * 1.1);
        float w2 = sin((p.x + p.y) * 0.21 - t * 0.8) * 0.6;
        float w3 = sin(p.y * 0.5 + t * 1.6) * 0.35;
        float w4 = sin((p.x * 0.6 - p.y * 0.4) + t * 1.9) * 0.25;
        float chop = storm > 0.4 ? sin(p.x * 1.3 - t * 3.2) * 0.12 * storm : 0.0;
        float s = shore_at(q.x);
        float fade = smoothstep(s + 0.5, s + 5.0 + amplitude * 6.0, q.y);
        h = amplitude * fade * (w1 + w2 + w3 + w4 + chop);
    }
    return h + crest_ridge(q) - sink_dip(q);
}

void vertex() {
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float h = wave_height(wp.xz, sea_time);
    vec2 d = abs(wp.xz - hull.xy);
    if (d.x < hull.z && d.y < hull.w) {
        h = min(h, hull_floor - wp.y);
    }
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
    float sz = shore_at(world_pos.x);
    float depth_mix = open_sea ? 0.7 : clamp((world_pos.z - sz) / 10.0, 0.0, 1.0);
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
    // The travelling crests: churning white water on the breaking section, a thin broken
    // lip of foam along the rest of the crest line.
    if (wave_crest_count > 0) {
        // Two layers of tumbling texture so the white water churns instead of
        // reading as a solid white slab.
        float churn_t = texture(normal_map, world_pos.xz * 0.07 + vec2(sea_time * 0.06, -sea_time * 0.13)).g;
        float churn_f = texture(normal_map, world_pos.xz * 0.17 + vec2(-sea_time * 0.11, sea_time * 0.21)).r;
        float lip = 0.0;
        float wall = 0.0;
        for (int i = 0; i < wave_crest_count; i++) {
            vec4 c = wave_crests[i];
            float d = world_pos.z - c.x;
            lip += exp(-d * d / 1.7) * min(c.w * 0.5, 1.0);
            if (c.z > 0.001) {
                float inside = 1.0 - smoothstep(0.82, 1.06, abs(world_pos.x - c.y) / c.z);
                // Brightest at the lip, torn into streaks down the face.
                wall += inside * exp(-d * d / 7.0) * (d > 0.0 ? 1.0 : 0.55);
            }
        }
        foam += clamp(lip, 0.0, 0.55) * (0.35 + 0.65 * streaks);
        foam += clamp(wall, 0.0, 0.92) * (0.35 + 0.45 * churn_t) * (0.55 + 0.45 * churn_f);
    }
    // Whirlpools: the water darkens into the throat, white spiral streaks race around it.
    for (int i = 0; i < sink_count; i++) {
        vec4 sk = sinks[i];
        vec2 rel = world_pos.xz - sk.xy;
        float d = length(rel);
        if (d < sk.z * 1.25) {
            float k = clamp(1.0 - d / sk.z, 0.0, 1.0);
            float ang = atan(rel.y, rel.x);
            float spiral = 0.5 + 0.5 * sin(ang * 3.0 + log(max(d, 0.4)) * 9.0 - sea_time * 5.0);
            base = mix(base, base * 0.45, k * k);
            foam += smoothstep(0.35, 1.0, spiral) * (0.25 + 0.55 * k) * smoothstep(1.25, 0.9, d / sk.z);
            foam += smoothstep(0.75, 1.0, k) * 0.6;
        }
    }
    // Thin foam line along the shore.
    if (!open_sea) {
        foam += smoothstep(1.6, 0.0, abs(world_pos.z - sz - 0.9)) * 0.45;
    }
    ALBEDO = mix(base, foam_color, clamp(foam, 0.0, 1.0));
    ROUGHNESS = 0.16;
    SPECULAR = 0.4;
    METALLIC = 0.0;
}
