shader_type spatial;
// Ground decal for element effects (scorch, frost rime, poison pool, holy
// glyph, shadow sigil, cracked stone). A hard-edged authored texture: it pops
// in over the first 8% of its life, holds, then fades. No glow, no blur.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float pop = smoothstep(0.0, 0.08, progress);
	vec2 uv = (UV - vec2(0.5)) / mix(0.7, 1.0, pop) + vec2(0.5);
	vec4 c = texture(tex, uv);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a * tint.a * inside * pop * (1.0 - smoothstep(0.6, 1.0, progress));
}
