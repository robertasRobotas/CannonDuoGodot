shader_type spatial;
render_mode fog_disabled;

// One of the Kraken's hooked fangs (VmKraken._tooth_mesh, drawn with a MultiMesh):
// dark gum at the root, stained yellow ivory up the shaft, a pale glossy point.
// `shade` is how deep in the throat the ring stands (0 at the lip, 1 deep).
uniform float shade = 0.0;

varying float k;
varying vec3 lp;

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
	k = UV.x;
	lp = VERTEX;
}

void fragment() {
	float stain = vnoise(vec2(k * 9.0, UV.y * 6.0 + shade * 13.0));
	vec3 ivory = mix(vec3(0.46, 0.38, 0.24), vec3(0.80, 0.75, 0.62), smoothstep(0.1, 0.9, k));
	ivory *= 0.75 + 0.3 * stain;
	vec3 col = mix(vec3(0.30, 0.07, 0.09), ivory, smoothstep(0.02, 0.14, k));
	// Fine lengthwise grooves.
	float groove = 0.5 + 0.5 * sin(UV.y * 6.2831853 * 7.0);
	col *= 0.92 + 0.08 * groove;
	col *= mix(1.0, 0.08, shade);
	ALBEDO = col;
	ROUGHNESS = mix(0.5, 0.18, k);
	SPECULAR = 0.6 * (1.0 - shade * 0.7);
	// A little light gets through the thin point.
	BACKLIGHT = vec3(0.5, 0.35, 0.25) * smoothstep(0.7, 1.0, k) * (1.0 - shade);
}
