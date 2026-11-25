shader_type canvas_item;

// One island of the chart, seen from above. A noise height field gives the coastline;
// from the sea inwards: clear shallows over sand, surf, beach, vegetation with tree
// canopy, rock and a peak (snow or lava). Lit from the upper left like the sea.
uniform sampler2D noise : repeat_enable, filter_linear;
uniform sampler2D sand_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D land_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 size_px = vec2(600.0, 400.0);
uniform float radius = 160.0;
uniform vec2 seed = vec2(0.0);
uniform vec3 sand_col = vec3(0.93, 0.84, 0.62);
uniform vec3 low_col = vec3(0.42, 0.62, 0.25);
uniform vec3 high_col = vec3(0.16, 0.42, 0.16);
uniform vec3 rock_col = vec3(0.5, 0.47, 0.42);
uniform vec3 peak_col = vec3(1.0);
uniform float rock = 0.6;
uniform float peak = 0.0;
uniform float glow = 0.0;    // the peak shines (lava)
uniform float trees = 0.5;
uniform float sink = 0.0;    // lowers the land: a reef with a few rocks above water

float fbm(vec2 u) {
	return texture(noise, u).r * 0.68 + texture(noise, u * 2.7 + 0.31).r * 0.32;
}

float height(vec2 p) {
	vec2 q = p / (radius * vec2(1.3, 0.85));
	float n = fbm(p / radius * 0.17 + seed);
	return 0.7 - length(q) + (n - 0.5) * 0.85 - sink;
}

float lum(vec3 c) {
	return dot(c, vec3(0.333));
}

void fragment() {
	vec2 p = (UV - 0.5) * size_px;
	float t = TIME;
	float s = height(p);
	float e = 3.0;
	vec2 grad = vec2(height(p + vec2(e, 0.0)) - s, height(p + vec2(0.0, e)) - s) / e * radius;
	float fine = texture(noise, p / 90.0 + seed * 3.0).r;
	float fine2 = texture(noise, p / 55.0 - seed * 2.0 + vec2(t * 0.01, 0.0)).r;
	vec2 to_light = normalize(vec2(-0.6, -0.8));

	vec3 sand = sand_col * (0.5 + 1.0 * lum(texture(sand_tex, p / 230.0 + seed).rgb));

	// Water: clear over the sand at the shore, fading out to the open sea.
	float dep = clamp(-s / 0.5, 0.0, 1.0);
	vec3 water = mix(vec3(0.45, 0.90, 0.80), vec3(0.06, 0.50, 0.66), smoothstep(0.0, 0.7, dep));
	water = mix(water, sand * vec3(0.72, 0.96, 0.90), smoothstep(-0.11, 0.0, s) * 0.6);
	float wa = (1.0 - dep * dep) * (1.0 - dep) * 0.95;
	// Surf: bands rolling in, broken up by noise, and a steady line of foam at the beach.
	float wave = sin(s * 44.0 - t * 1.5 + fine * 6.0);
	float foam = smoothstep(0.5, 1.0, wave) * smoothstep(-0.24, -0.04, s) * smoothstep(0.42, 0.7, fine2) * 0.8;
	foam = max(foam, smoothstep(-0.045, -0.008, s) * (0.65 + 0.35 * sin(t * 1.3 + fine * 9.0)));
	water = mix(water, vec3(1.0), foam * 0.92);
	wa = max(wa, foam * 0.9);

	// Land.
	vec3 land = sand * mix(0.70, 1.0, smoothstep(0.0, 0.05, s));
	float g = smoothstep(0.07, 0.13, s + (fine - 0.5) * 0.07);
	vec3 veg = mix(low_col, high_col, smoothstep(0.12, 0.5, s)) * (0.62 + 0.8 * lum(texture(land_tex, p / 170.0 + seed).rgb));
	float canopy = texture(noise, p / 44.0 + seed * 7.0).r;
	float canopy_lit = canopy - texture(noise, (p + to_light * 4.0) / 44.0 + seed * 7.0).r;
	float tr = smoothstep(0.50, 0.60, canopy + (trees - 0.5) * 0.6) * smoothstep(0.12, 0.2, s) * step(0.01, trees);
	veg = mix(veg, high_col * (0.45 + 0.75 * canopy), tr);
	float rk = smoothstep(0.42, 0.62, s + (fine - 0.5) * 0.18) * rock;
	veg = mix(veg, rock_col * (0.65 + 0.7 * fine), rk);
	tr *= 1.0 - rk;
	float pk = smoothstep(0.68, 0.84, s + (fine - 0.5) * 0.12) * peak;
	veg = mix(veg, peak_col, pk);
	land = mix(land, veg, g);
	// Relief: slopes facing the light are bright, the lee side is in shade.
	float shade = 1.0 - dot(grad, to_light) * 0.42 * smoothstep(0.0, 0.15, s);
	shade += canopy_lit * 7.0 * tr;
	land *= clamp(shade, 0.45, 1.5);
	land += peak_col * pk * glow * (0.5 + 0.3 * sin(t * 2.0 + fine * 10.0));

	float on_land = smoothstep(-0.006, 0.006, s);
	vec3 col = mix(water, land, on_land);
	float alpha = mix(wa, 1.0, on_land);
	vec2 edge = abs(UV - 0.5) * 2.0;
	alpha *= smoothstep(1.0, 0.82, max(edge.x, edge.y));
	COLOR = vec4(col, alpha);
}
