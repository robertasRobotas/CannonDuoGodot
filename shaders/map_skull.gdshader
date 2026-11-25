shader_type canvas_item;

// The boss's skull and crossbones: a ray-marched bone model (cranium, brow, sockets,
// nose, cheekbones, teeth, jaw) lit from the upper left. Rendered once into a small
// viewport by MapScreen and drawn from that texture.

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float smax(float a, float b, float k) {
	return -smin(-a, -b, k);
}

float ell(vec3 p, vec3 r) {
	float k0 = length(p / r);
	float k1 = length(p / (r * r));
	return k0 * (k0 - 1.0) / k1;
}

float rbox(vec3 p, vec3 b, float r) {
	vec3 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float cap(vec3 p, vec3 a, vec3 b, float r) {
	vec3 pa = p - a;
	vec3 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float bone(vec3 p) {
	vec3 a = vec3(-1.14, -1.0, -0.5);
	vec3 b = vec3(1.14, 0.42, -0.5);
	float d = cap(p, a, b, 0.085);
	vec3 side = normalize(vec3(a.y - b.y, b.x - a.x, 0.0)) * 0.1;
	d = smin(d, length(p - a - side) - 0.13, 0.06);
	d = smin(d, length(p - a + side) - 0.13, 0.06);
	d = smin(d, length(p - b - side) - 0.13, 0.06);
	d = smin(d, length(p - b + side) - 0.13, 0.06);
	return d;
}

// x: distance, y: material (0 bone, 1 teeth, 2 crossbones)
vec2 map(vec3 p) {
	float bones = min(bone(p), bone(vec3(-p.x, p.yz)));
	// The skull looks slightly down.
	float ca = cos(0.13);
	float sa = sin(0.13);
	vec3 q = vec3(abs(p.x), p.y * ca - p.z * sa, p.y * sa + p.z * ca);

	float d = ell(q - vec3(0.0, 0.44, 0.0), vec3(0.80, 0.76, 0.86));
	d = smin(d, ell(q - vec3(0.27, 0.24, 0.62), vec3(0.30, 0.10, 0.16)), 0.20);          // brow ridge
	d = smin(d, ell(q - vec3(0.0, -0.30, 0.40), vec3(0.36, 0.36, 0.30)), 0.14);          // upper jaw
	d = smin(d, ell(q - vec3(0.52, -0.14, 0.38), vec3(0.20, 0.10, 0.25)), 0.14);         // cheekbone
	d = smax(d, -ell(q - vec3(0.90, -0.02, 0.52), vec3(0.16, 0.30, 0.32)), 0.12);        // temple
	d = smax(d, -ell(q - vec3(0.31, 0.0, 0.78), vec3(0.235, 0.205, 0.52)), 0.06);      // eye socket
	vec3 n = q - vec3(0.062, -0.27, 0.70);
	n.xy = vec2(n.x * 0.92 - n.y * 0.39, n.x * 0.39 + n.y * 0.92);
	d = smax(d, -ell(n, vec3(0.068, 0.15, 0.34)), 0.03);                                 // nose
	d = smax(d, -ell(q - vec3(0.50, -0.50, 0.60), vec3(0.17, 0.20, 0.3)), 0.10);         // hollow under the cheek

	float jaw = ell(q - vec3(0.0, -0.88, 0.34), vec3(0.37, 0.15, 0.30));
	jaw = smin(jaw, ell(q - vec3(0.0, -0.99, 0.50), vec3(0.17, 0.09, 0.13)), 0.10);      // chin
	jaw = smin(jaw, cap(q, vec3(0.36, -0.86, 0.2), vec3(0.55, -0.32, 0.08), 0.075), 0.12);
	d = min(d, jaw);

	float arch = 0.66 - q.x * q.x * 1.4;
	float w = 0.105;
	float tx = q.x - (clamp(floor(q.x / w), 0.0, 2.0) + 0.5) * w;
	float teeth = rbox(vec3(tx, q.y + 0.63, q.z - arch + 0.02), vec3(0.034, 0.07, 0.03), 0.018);
	teeth = min(teeth, rbox(vec3(tx, q.y + 0.775, q.z - arch + 0.04), vec3(0.032, 0.055, 0.03), 0.018));

	vec2 res = vec2(d, 0.0);
	if (teeth < res.x) {
		res = vec2(teeth, 1.0);
	}
	if (bones < res.x) {
		res = vec2(bones, 2.0);
	}
	return res;
}

vec3 normal_at(vec3 p) {
	vec2 e = vec2(0.002, -0.002);
	return normalize(e.xyy * map(p + e.xyy).x + e.yyx * map(p + e.yyx).x + e.yxy * map(p + e.yxy).x + e.xxx * map(p + e.xxx).x);
}

vec4 shade_ray(vec2 uv) {
	vec3 ro = vec3(uv * 1.42, 3.0);
	vec3 rd = vec3(0.0, 0.0, -1.0);
	float t = 0.0;
	float near = 1e3;
	vec2 hit = vec2(0.0);
	bool found = false;
	for (int i = 0; i < 90; i++) {
		hit = map(ro + rd * t);
		near = min(near, hit.x);
		if (hit.x < 0.0015) {
			found = true;
			break;
		}
		t += hit.x * 0.9;
		if (t > 6.0) {
			break;
		}
	}
	if (!found) {
		// A dark rim so the bone reads on any backdrop.
		return vec4(0.10, 0.03, 0.02, smoothstep(0.05, 0.015, near) * 0.9);
	}
	vec3 p = ro + rd * t;
	vec3 nrm = normal_at(p);
	vec3 key = normalize(vec3(-0.55, 0.65, 0.6));
	// Ambient occlusion and a soft shadow from the key light.
	float ao = 0.0;
	float sca = 1.0;
	for (int i = 1; i <= 5; i++) {
		float h = 0.04 * float(i);
		ao += (h - map(p + nrm * h).x) * sca;
		sca *= 0.75;
	}
	ao = clamp(1.0 - 2.2 * ao, 0.0, 1.0);
	float sh = 1.0;
	float st = 0.03;
	for (int i = 0; i < 28; i++) {
		float h = map(p + key * st).x;
		sh = min(sh, 9.0 * h / st);
		st += clamp(h, 0.02, 0.15);
		if (sh < 0.01 || st > 2.5) {
			break;
		}
	}
	sh = clamp(sh, 0.0, 1.0);

	vec3 albedo = vec3(0.90, 0.85, 0.72);
	if (hit.y > 0.5 && hit.y < 1.5) {
		albedo = vec3(0.95, 0.92, 0.82);
	} else if (hit.y > 1.5) {
		albedo = vec3(0.84, 0.78, 0.64);
	}
	// Weathering: blotches, fine grain, and grime where the bone is hollow.
	float blot = vnoise(p * 3.5);
	float grain = vnoise(p * 28.0);
	albedo *= 0.82 + 0.22 * blot + 0.08 * grain;
	albedo = mix(albedo * vec3(0.55, 0.45, 0.33), albedo, smoothstep(0.1, 0.8, ao));
	// The sockets and the nose go dark with depth.
	float ca = cos(0.13);
	float sa = sin(0.13);
	vec3 q = vec3(abs(p.x), p.y * ca - p.z * sa, p.y * sa + p.z * ca);
	float socket = (1.0 - smoothstep(0.75, 1.0, length((q.xy - vec2(0.31, 0.0)) / vec2(0.235, 0.205)))) * smoothstep(0.74, 0.50, q.z);
	float nose = (1.0 - smoothstep(0.8, 1.1, length((q.xy - vec2(0.03, -0.27)) / vec2(0.13, 0.17)))) * smoothstep(0.70, 0.52, q.z);
	float pit = hit.y < 0.5 ? max(socket, nose) : 0.0;
	albedo *= mix(1.0, 0.10, pit);

	float diff = max(dot(nrm, key), 0.0) * sh;
	float fill = max(dot(nrm, normalize(vec3(0.6, -0.2, 0.7))), 0.0);
	vec3 col = albedo * (vec3(0.30, 0.31, 0.36) * ao + vec3(1.0, 0.95, 0.86) * diff * 0.85 + vec3(0.20, 0.17, 0.15) * fill * ao);
	col += vec3(1.0) * pow(max(dot(nrm, normalize(key + vec3(0.0, 0.0, 1.0))), 0.0), 40.0) * 0.12 * sh;
	return vec4(pow(col, vec3(0.8)), 1.0);
}

void fragment() {
	vec2 uv = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
	vec2 px = vec2(dFdx(UV.x), dFdy(UV.y));
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 o = (vec2(float(i % 2), float(i / 2)) - 0.5) * px;
		vec4 c = shade_ray(uv + o);
		acc += vec4(c.rgb * c.a, c.a);
	}
	acc *= 0.25;
	COLOR = vec4(acc.rgb / max(acc.a, 1e-4), acc.a);
}
