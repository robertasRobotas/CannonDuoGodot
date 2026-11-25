shader_type spatial;
render_mode cull_disabled, fog_disabled;   // fog would grey out the black of the throat

// The Kraken's mouth: a thick lip of the beast's mottled hide rolling over into a wet,
// folded gullet that narrows and goes black down the throat. The gullet swallows in slow
// waves. Mesh (VmKraken._mouth_mesh): UV.x = 0 on the outer skirt .. 1 at the bottom of
// the throat, UV.y = angle / TAU; VERTEX y is the height in the mouth's own space.

uniform vec3 hide_col : source_color = vec3(0.24, 0.07, 0.08);
uniform vec3 spot_col : source_color = vec3(0.09, 0.02, 0.04);
uniform vec3 lip_col : source_color = vec3(0.36, 0.08, 0.10);
uniform vec3 gullet_col : source_color = vec3(0.62, 0.20, 0.22);
uniform float lip_u = 0.34;   // where the crest of the lip is along UV.x

varying float u;
varying float ang;
varying float y;

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
	u = UV.x;
	ang = UV.y;
	y = VERTEX.y;
	// Swallowing: rings of contraction running down the gullet.
	float inner = smoothstep(lip_u + 0.05, lip_u + 0.2, u);
	float wave = sin(VERTEX.y * 0.7 + TIME * 1.8);
	VERTEX.xz *= 1.0 - inner * 0.04 * wave;
}

void fragment() {
	float a = ang * 6.2831853;
	float inner = smoothstep(lip_u - 0.02, lip_u + 0.1, u);
	float depth = max(-y, 0.0);

	// Outside: the hide, mottled like the arms, wrinkled toward the lip.
	vec2 hp = vec2(ang * 40.0, u * 16.0);
	float spots = smoothstep(0.55, 0.75, vnoise(hp * 0.7) * 0.7 + vnoise(hp * 2.3) * 0.3);
	vec3 hide = mix(hide_col, spot_col, spots * 0.8) * (0.88 + 0.24 * vnoise(hp * 2.5));
	float crest = exp(-pow((u - lip_u) / 0.06, 2.0));
	hide = mix(hide, lip_col * (0.8 + 0.4 * vnoise(hp * 2.0)), crest);

	// Inside: deep folds running down the throat, ridged across, slick and glistening.
	float folds = 0.5 + 0.5 * sin(a * 18.0 + sin(y * 0.4) * 1.5 + vnoise(vec2(a * 3.0, y * 0.3)) * 2.0);
	float ridges = 0.5 + 0.5 * sin(y * 4.2 + vnoise(vec2(a * 8.0, y)) * 3.0);
	vec3 gullet = gullet_col * (0.55 + 0.45 * folds) * (0.85 + 0.25 * ridges);
	gullet = mix(gullet, vec3(0.85, 0.55, 0.45), smoothstep(0.9, 1.0, folds) * 0.25);
	// Light dies down the throat.
	gullet *= exp(-depth * 0.22);

	vec3 col = mix(hide, gullet, inner);
	ALBEDO = col;
	ROUGHNESS = mix(0.6, 0.16, inner);
	SPECULAR = mix(0.3, 0.7, inner);
	vec2 bump = vec2(cos(a * 18.0 + sin(y * 0.4) * 1.5) * 0.35, cos(y * 4.2) * 0.25) * inner;
	bump += vec2(vnoise(hp * 1.5) - 0.5, vnoise(hp * 1.5 + 7.0) - 0.5) * 0.3 * (1.0 - inner);
	NORMAL_MAP = vec3(bump * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	// The throat's far end is a void: no light comes back from it.
	float voidk = smoothstep(5.0, 11.0, depth) * inner;
	ALBEDO *= 1.0 - voidk;
	SPECULAR *= 1.0 - voidk;
}
