shader_type spatial;
// Flat expanding shockwave on a quad. progress 0..1 grows the ring to the
// quad edge and fades it.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensity = 2.0;
uniform float width = 0.12;
instance uniform float progress = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.4, 1.0);

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float rad = mix(0.15, 1.0, sqrt(progress));
	float w = width * (1.0 - progress * 0.5);
	float ring = smoothstep(rad - w, rad, r) * (1.0 - smoothstep(rad, rad + w * 0.35, r));
	float fill = (1.0 - smoothstep(0.0, rad, r)) * 0.18;
	float a = (ring + fill) * (1.0 - progress);
	ALBEDO = tint.rgb * intensity;
	ALPHA = clamp(a, 0.0, 1.0);
}
