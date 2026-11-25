shader_type spatial;
render_mode cull_back;

// A Kraken's arm: wet, mottled red-brown skin on the back, pale flesh on the inner side
// with two staggered rows of suckers (raised rims, dark cups) that shrink toward the tip.
// The arm writhes: the same offset is applied on the CPU for hit tests (VmKraken._writhe).
//
// Mesh layout (VmKraken._tentacle_mesh): UV.x = 0 at the root .. 1 at the tip, UV.y = the
// angle round the arm / TAU with 0 on the inner (sucker) side; UV2.x = length in arm radii.

uniform float t_arm = 0.0;
uniform float phase = 0.0;
uniform float bruise = 0.0;     // 1 when the arm has been hit
uniform float water_y = -1000.0; // the sea's height at the arm, for the foam where it breaks the surface
uniform vec3 back_col : source_color = vec3(0.26, 0.08, 0.09);
uniform vec3 spot_col : source_color = vec3(0.10, 0.03, 0.05);
uniform vec3 belly_col : source_color = vec3(0.80, 0.60, 0.55);

varying float s;
varying float around;
varying float q;
varying vec3 obj_pos;
varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	s = UV.x;
	around = UV.y;
	q = UV2.x;
	obj_pos = VERTEX;
	float k = s;
	VERTEX.x += 1.6 * pow(k, 2.0) * sin(0.8 * t_arm + phase + 1.0 - 2.5 * k);
	VERTEX.z += 2.2 * pow(k, 1.6) * sin(1.1 * t_arm + phase - 3.0 * k);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = around * 6.2831853;
	float inner = smoothstep(-0.05, 0.4, cos(a));          // the sucker side
	float side = sin(a);

	// Back: mottled with dark spots and fine wrinkles across the arm.
	vec2 sp = vec2(q * 1.6, around * 7.0);
	float spots = smoothstep(0.55, 0.75, vnoise(sp * 1.3) * 0.7 + vnoise(sp * 4.1) * 0.3);
	float wrinkle = 0.5 + 0.5 * sin(q * 9.0 + vnoise(sp * 2.0) * 9.0 + around * 3.0);
	vec3 back = mix(back_col, spot_col, spots * 0.8);
	back *= 0.85 + 0.3 * vnoise(sp * 9.0);
	back = mix(back, back_col * 1.6 + vec3(0.06, 0.02, 0.03), smoothstep(0.8, 1.0, wrinkle) * 0.12);

	// Inner side: suckers in a zigzag of two rows, spaced in arm radii so they shrink with
	// it. h() is the relief: a raised rim round a deep cup.
	float row = side > 0.0 ? 0.0 : 0.5;
	float cell = q * 1.3 + row;
	vec2 sv = vec2(fract(cell) - 0.5, (abs(side) - 0.34) * 1.7 * sign(side));
	float d = length(sv);
	float on = step(0.03, s) * step(s, 0.96) * inner;
	float rim = smoothstep(0.44, 0.34, d) - smoothstep(0.30, 0.22, d);
	float cup = smoothstep(0.25, 0.13, d);
	float e = 0.02;
	float h1 = smoothstep(0.44, 0.33, d + e) - 0.9 * smoothstep(0.27, 0.15, d + e);
	float h0 = smoothstep(0.44, 0.33, d - e) - 0.9 * smoothstep(0.27, 0.15, d - e);
	vec2 slope = d > 0.001 ? -sv / d * (h1 - h0) / (2.0 * e) : vec2(0.0);
	vec3 belly = belly_col * (0.85 + 0.2 * vnoise(sp * 6.0));
	belly = mix(belly, belly_col * 1.15, rim * on * 0.5);
	belly = mix(belly, vec3(0.30, 0.10, 0.12), cup * on * 0.85);

	vec3 col = mix(back, belly, inner);
	col = mix(col, col * vec3(0.55, 0.6, 0.75) + vec3(0.02, 0.05, 0.08), bruise);
	// Where it breaks the surface: churned white water clinging round it, a dark wet band
	// above that, and the green-blue of the sea below.
	float above = world_pos.y - water_y;
	float fn = vnoise(vec2(around * 18.0, TIME * 1.5)) * 0.6 + vnoise(vec2(around * 45.0, world_pos.y * 3.0 - TIME * 3.0)) * 0.4;
	float foam = smoothstep(1.6, 0.2, above + fn * 0.9) * smoothstep(-0.8, -0.1, above);
	col *= mix(1.0, 0.65, smoothstep(3.5, 0.5, above));
	col = mix(col, vec3(0.05, 0.16, 0.22), smoothstep(-0.1, -0.9, above));
	col = mix(col, vec3(0.9, 0.94, 0.96), foam * 0.9);
	ALBEDO = col;

	// Wet: glossy back, the cups drier and the rims catching the light.
	ROUGHNESS = mix(0.2, 0.34, inner) + cup * on * 0.35 + spots * 0.08;
	SPECULAR = 0.6;
	vec2 wr = vec2(cos(q * 9.0 + vnoise(sp * 2.0) * 9.0 + around * 3.0), 0.0) * 0.12 * (1.0 - inner);
	vec2 bump = slope * on * 0.09 + wr;
	NORMAL_MAP = vec3(bump * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	AO = 1.0 - cup * on * 0.6;
	// Thin skin glows a little toward the tip against the light.
	RIM = 0.35;
	RIM_TINT = 0.6;
}
