shader_type spatial;
// Burnt ground left by fire: a ragged dark blot with embers glowing in its
// cracks that cool first, then the blot fades. progress 0..1 over its life.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float progress = 0.0;
instance uniform float seed = 0.0;

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
	float n = fbm(c * 5.0 + vec2(seed));
	float blot = 1.0 - smoothstep(0.35 + n * 0.4, 0.85 + n * 0.15, r);
	float cracks = smoothstep(0.6, 0.68, fbm(c * 12.0 - vec2(seed))) * blot;
	float glow = cracks * (1.0 - smoothstep(0.0, 0.45, progress));
	float fade = 1.0 - smoothstep(0.4, 1.0, progress);
	ALBEDO = mix(vec3(0.035, 0.025, 0.02), vec3(1.0, 0.42, 0.08) * 2.5, glow);
	ALPHA = clamp(blot * 0.7 * fade + glow, 0.0, 1.0);
}
