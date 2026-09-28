shader_type spatial;
render_mode cull_disabled;

// Cloth flag: ripples travel away from the pole (UV.x = 0) and grow toward the free end.
// kind 0: pirate black with a white skull and crossbones; 1: Valora, blue with a gold crown.
uniform int kind = 0;
uniform float phase = 0.0;
uniform float wind = 1.0;

void vertex() {
    float k = UV.x;
    VERTEX.z += sin(UV.x * 7.0 - TIME * 7.0 * wind + phase) * 0.09 * k * wind;
    VERTEX.y += sin(UV.x * 5.0 - TIME * 6.0 * wind + phase) * 0.025 * k;
}

void fragment() {
    vec3 c;
    if (kind == 1) {
        // Valora: royal blue with a gold crown.
        c = vec3(0.10, 0.22, 0.58);
        vec2 p = UV - vec2(0.5, 0.5);
        float band = step(abs(p.y - 0.06), 0.06) * step(abs(p.x), 0.2);
        float spikes = step(abs(p.y + 0.06), 0.08) * step(abs(fract((p.x + 0.2) * 5.0) - 0.5), 0.2 - (p.y + 0.14) * 1.2) * step(abs(p.x), 0.2);
        c = mix(c, vec3(0.98, 0.78, 0.2), clamp(band + spikes, 0.0, 1.0));
    } else {
        c = vec3(0.05, 0.05, 0.06);
        vec2 p = (UV - vec2(0.5, 0.45)) * vec2(1.7, 1.0);
        float skull = step(length(p - vec2(0.0, -0.06)), 0.13);
        float jaw = step(abs(p.x), 0.08) * step(abs(p.y - 0.08), 0.05);
        float eyes = step(length(p - vec2(-0.05, -0.07)), 0.035) + step(length(p - vec2(0.05, -0.07)), 0.035);
        vec2 q = (UV - vec2(0.5, 0.62)) * vec2(1.7, 1.0);
        float bones = step(abs(q.x - q.y * 1.4), 0.025) + step(abs(q.x + q.y * 1.4), 0.025);
        bones *= step(abs(q.x), 0.22);
        float white = clamp(skull + jaw + bones - eyes, 0.0, 1.0);
        c = mix(c, vec3(0.95, 0.94, 0.9), white);
    }
    ALBEDO = c;
    ROUGHNESS = 0.9;
}
