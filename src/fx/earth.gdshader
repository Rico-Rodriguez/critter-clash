shader_type spatial;
// Turned earth on the ground where the dead come up: a ragged round blot of
// dark soil, lit like the ground under it. Lies on a quad just above the
// ground plane (depth_draw_never, so it can never fight the ground for depth).
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley, specular_disabled, shadows_disabled;

uniform vec4 soil : source_color = vec4(0.17, 0.12, 0.08, 1.0);
instance uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float n = vnoise(c * 4.0 + vec2(seed)) * 0.6 + vnoise(c * 11.0 - vec2(seed)) * 0.4;
	float blot = 1.0 - smoothstep(0.45 + n * 0.3, 0.8 + n * 0.2, r);
	float clods = vnoise(c * 26.0 + vec2(seed * 3.0));
	ALBEDO = soil.rgb * (0.7 + 0.6 * clods);
	ALPHA = clamp(blot * 0.92, 0.0, 1.0);
}
