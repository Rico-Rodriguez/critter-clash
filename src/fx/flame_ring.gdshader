shader_type spatial;
// A burst of fire on the ground: a ragged front of flame racing out across a
// quad, the ground behind it burning and cooling. progress 0..1 over its life.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float progress = 0.0;
instance uniform float seed = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.12, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	vec2 dir = c / max(length(c), 0.0001);
	float k = progress;
	float front = mix(0.12, 0.92, 1.0 - pow(1.0 - k, 2.4));
	// The front is torn by noise around the circle, so it reads as flame.
	float n = fbm(dir * 2.6 + vec2(seed, -seed) + vec2(0.0, TIME * 0.8));
	float edge = front + (n - 0.5) * 0.22;
	float band = smoothstep(edge - 0.34, edge - 0.03, r) * (1.0 - smoothstep(edge - 0.03, edge + 0.05, r));
	// Behind the front the ground still burns, flowing outward and cooling.
	float flow = fbm(c * 7.0 - dir * TIME * 2.5 + vec2(seed));
	float inner = (1.0 - smoothstep(0.0, edge, r)) * smoothstep(0.35, 0.8, flow) * (1.0 - k);
	float heat = band * (0.55 + 0.9 * n) + inner * 0.8;
	float fade = 1.0 - smoothstep(0.5, 1.0, k);
	vec3 col = mix(vec3(0.55, 0.06, 0.02), tint.rgb, smoothstep(0.15, 0.55, heat));
	col = mix(col, vec3(1.0, 0.93, 0.62), smoothstep(0.7, 1.1, heat));
	ALBEDO = col * 2.6;
	ALPHA = clamp(heat * fade, 0.0, 1.0);
}
