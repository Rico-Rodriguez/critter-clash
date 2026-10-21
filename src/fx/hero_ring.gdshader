shader_type spatial;
// The circle under the player's hero: you always know where you are in the
// crowd. A soft ring with a faint fill, breathing slowly.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float intensity = 1.6;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	float ring = smoothstep(0.78, 0.9, r) * (1.0 - smoothstep(0.9, 1.0, r));
	float fill = (1.0 - smoothstep(0.0, 0.9, r)) * 0.12;
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp((ring * 0.9 + fill) * pulse, 0.0, 1.0);
}
