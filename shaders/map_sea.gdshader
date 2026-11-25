shader_type canvas_item;

// The sea of the chart, seen from above: depth patches, three layers of drifting
// ripples from the water normal map, light on the slopes and sun glints.
uniform sampler2D normals : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise : repeat_enable, filter_linear;

varying vec2 px;

void vertex() {
	px = VERTEX;
}

void fragment() {
	float t = TIME;
	vec2 a = texture(normals, px / 640.0 + vec2(t * 0.010, t * 0.006)).xy * 2.0 - 1.0;
	vec2 b = texture(normals, vec2(px.y, -px.x) / 290.0 + vec2(-t * 0.013, t * 0.009)).xy * 2.0 - 1.0;
	vec2 c = texture(normals, px / 110.0 + vec2(t * 0.021, -t * 0.017)).xy * 2.0 - 1.0;
	vec2 n = a * 0.65 + b * 0.5 + c * 0.3;

	float big = texture(noise, px / 2300.0 + n * 0.004).r;
	float med = texture(noise, px / 760.0 + vec2(0.37, 0.11) + n * 0.012).r;
	float depth = big * 0.62 + med * 0.38;
	vec3 col = mix(vec3(0.012, 0.115, 0.25), vec3(0.03, 0.26, 0.42), smoothstep(0.22, 0.58, depth));
	col = mix(col, vec3(0.05, 0.38, 0.51), smoothstep(0.56, 0.84, depth) * 0.75);

	vec3 nn = normalize(vec3(n * 0.6, 1.0));
	vec3 to_light = normalize(vec3(-0.45, -0.6, 0.66));
	// Slopes that face the sun pick up sky, the far sides go darker.
	float slope = dot(nn.xy, to_light.xy);
	col += slope * vec3(0.10, 0.17, 0.19);
	col += pow(1.0 - nn.z, 1.5) * vec3(0.10, 0.16, 0.20);
	// Sun glints on the steepest ripples.
	vec3 hv = normalize(to_light + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(nn, hv), 0.0), 260.0);
	float sparkle = texture(noise, px / 37.0 + vec2(t * 0.05, -t * 0.03)).r;
	col += vec3(1.0, 0.97, 0.9) * spec * (0.35 + 1.3 * smoothstep(0.5, 0.8, sparkle));
	COLOR = vec4(col, 1.0);
}
