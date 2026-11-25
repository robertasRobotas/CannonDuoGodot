shader_type canvas_item;

// The bank of cloud over uncharted water at the bottom of the chart, seen from above:
// billowing cumulus that thickens downward, lit from the upper left like the islands.
// Each billow's flank toward the light is bright, the shade behind it blue-grey; thin
// haze at the edge, and the bank's shadow on the sea. Gradient noise, computed here.
uniform vec2 size_px = vec2(1179.0, 1000.0);
uniform float edge = 120.0;   // where the bank begins, in px from the top of the rect

vec2 grad(vec2 i) {
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad(i), f);
	float b = dot(grad(i + vec2(1, 0)), f - vec2(1, 0));
	float c = dot(grad(i + vec2(0, 1)), f - vec2(0, 1));
	float d = dot(grad(i + vec2(1, 1)), f - vec2(1, 1));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);   // about -0.7..0.7
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * gnoise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// The cloud's height: billows with smaller heaps on them, pushed up with depth below the
// edge, drifting slowly.
float height(vec2 px, float t) {
	vec2 p = px / 300.0 + vec2(t * 0.02, 0.0);
	float n = fbm(p);
	float ramp = smoothstep(edge - 40.0, edge + 300.0, px.y);
	return n * 0.9 - 0.32 + ramp * 0.62 + smoothstep(edge + 180.0, edge + 340.0, px.y) * 0.4;
}

void fragment() {
	vec2 px = UV * size_px;
	float t = TIME;
	float h = height(px, t);
	float d = smoothstep(-0.02, 0.10, h);          // opacity: soft at the edge
	vec2 L = normalize(vec2(-0.6, -0.8));
	float rise = h - height(px + L * 14.0, t);
	float blocked = height(px + L * 60.0, t) - h;
	float lit = 0.6 + rise * 7.0 - max(blocked, 0.0) * 1.6;
	lit += smoothstep(0.08, 0.4, h) * 0.25;          // the thick tops are brightest
	lit = clamp(lit, 0.0, 1.0);
	vec3 fold = vec3(0.56, 0.63, 0.75);
	vec3 top = vec3(1.0, 0.99, 0.97);
	vec3 col = mix(fold, top, smoothstep(0.05, 1.0, lit));
	col = mix(vec3(0.62, 0.74, 0.86), col, smoothstep(0.0, 0.8, d));
	float hs = height(px - L * 80.0, t);
	float shadow = smoothstep(-0.02, 0.12, hs) * (1.0 - d) * 0.4;
	vec3 outc = mix(vec3(0.0, 0.03, 0.08), col, d);
	COLOR = vec4(outc, d + shadow * (1.0 - d));
}
