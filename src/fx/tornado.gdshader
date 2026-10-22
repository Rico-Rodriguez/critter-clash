shader_type spatial;
// The Barbarian's whirlwind as a column of fire: streaks spiralling up a
// cone, hottest near the ground, faded at both ends. Color per instance.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.15, 1.0);
instance uniform float fade = 1.0;

void fragment() {
	float u = UV.x;
	float v = UV.y; // 0 at the top of the cone, 1 at the ground
	float a = smoothstep(0.25, 1.0, sin((u * 5.0 + v * 2.2 - TIME * 3.0) * 6.2832));
	float b = smoothstep(0.6, 1.0, sin((u * 9.0 - v * 1.4 - TIME * 4.6) * 6.2832)) * 0.6;
	float ends = smoothstep(0.0, 0.3, v) * smoothstep(1.0, 0.75, v);
	float side = 0.4 + 0.6 * pow(1.0 - abs(dot(NORMAL, VIEW)), 0.6);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.9, 0.55), v * 0.7) * 2.2;
	ALPHA = clamp(max(a, b) * ends * side * fade * 0.6, 0.0, 1.0);
}
