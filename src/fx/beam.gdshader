shader_type spatial;
// Loot pillar of light: a cylinder fading up and at its sides, with a slow
// shimmer climbing it. Color is per instance (rarity).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensity = 1.6;
instance uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.3, 1.0);
instance uniform float strength = 1.0;

void fragment() {
	float up = 1.0 - UV.y;
	float v = pow(1.0 - up, 1.6);
	float side = pow(abs(dot(NORMAL, VIEW)), 1.5);
	float shimmer = 0.75 + 0.25 * sin(UV.y * 18.0 + TIME * 4.0);
	ALBEDO = tint.rgb * intensity;
	ALPHA = clamp(v * side * shimmer * strength * 0.85, 0.0, 1.0);
}
