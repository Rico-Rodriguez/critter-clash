shader_type spatial;
// A swing arc. UV.x runs along the arc (0 = start, 1 = end of the swing),
// UV.y across it (0 = inner edge, 1 = outer). `progress` sweeps the bright
// head through the arc and fades the trail behind it.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float intensity = 2.5;
instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float head = progress * 1.25;
	float along = UV.x;
	float trail = smoothstep(head - 0.75, head, along) * (1.0 - smoothstep(head, head + 0.04, along));
	float edge = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	float core = pow(edge, 2.0) * trail;
	float fade = 1.0 - smoothstep(0.7, 1.0, progress);
	vec3 c = color.rgb * tint.rgb;
	ALBEDO = c * intensity;
	ALPHA = clamp(core * fade, 0.0, 1.0);
}
