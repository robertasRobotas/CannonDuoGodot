shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// The flat far-water plane under the animated patch: plain deep colour, with holes cut
// where whirlpool funnels dig below it, so nothing flat shows inside a throat.
uniform vec3 color : source_color = vec3(0.10, 0.32, 0.54);
uniform int hole_count = 0;
uniform vec4 holes[4];

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    for (int i = 0; i < hole_count; i++) {
        if (distance(world_pos.xz, holes[i].xy) < holes[i].z * 0.72) {
            discard;
        }
    }
    ALBEDO = color;
    ROUGHNESS = 0.25;
    SPECULAR = 0.4;
}
