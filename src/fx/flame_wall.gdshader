shader_type spatial;
// The wall of flame riding a fire burst: tongues licking up an open cylinder,
// white at the roots, red at the tips, shrinking as it spreads. UV.x goes
// round the cylinder, UV.y is 0 at the top and 1 at the ground.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform float progress = 0.0;
instance uniform float seed = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.12, 1.0);

// Value noise that wraps every `period` cells in x, so there is no seam where
// the cylinder closes.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wnoise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(mix(hash(vec2(x0, i.y)), hash(vec2(x1, i.y)), f.x), mix(hash(vec2(x0, i.y + 1.0)), hash(vec2(x1, i.y + 1.0)), f.x), f.y);
}

void fragment() {
	float h = 1.0 - UV.y;
	float k = progress;
	// Tongue height varies round the ring and flickers.
	float tongue = 0.25 + 0.75 * wnoise(vec2(UV.x * 14.0, seed + TIME * 2.2), 14.0);
	tongue *= 1.0 - k * 0.85;
	float rise = wnoise(vec2(UV.x * 28.0, h * 5.0 - TIME * 6.0 + seed), 28.0);
	float body = 1.0 - smoothstep(tongue * 0.45, tongue, h + (rise - 0.5) * 0.25);
	float side = 0.45 + 0.55 * pow(1.0 - abs(dot(NORMAL, VIEW)), 0.5);
	float fade = smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.55, 1.0, k));
	float heat = body * (0.6 + 0.6 * rise);
	vec3 col = mix(vec3(0.6, 0.08, 0.02), tint.rgb, smoothstep(0.1, 0.5, heat));
	col = mix(col, vec3(1.0, 0.95, 0.7), smoothstep(0.75, 1.0, 1.0 - h / max(tongue, 0.01)) * body);
	ALBEDO = col * 2.4;
	ALPHA = clamp(heat * side * fade, 0.0, 1.0);
}
