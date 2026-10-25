shader_type spatial;
// A solid speed streak behind a projectile: a hard-edged tapered wedge,
// white at the head into the colour toward the tip. Opaque, unlit, no glow.
render_mode unshaded, cull_disabled, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.4, 1.0);

void fragment() {
	float w = 1.0 - UV.y;
	if (abs(UV.x - 0.5) * 2.0 > w * w) discard;
	ALBEDO = UV.y < 0.22 ? vec3(1.0, 0.98, 0.9) : tint.rgb;
}
