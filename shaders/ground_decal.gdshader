shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// One flat quad on the ground, -0.5..0.5 in UV space. It draws any mix of:
//   a soft contact shadow, a filled disc or lane, and an anti-aliased ring.
// Used for the hero's selection ring, critter contact shadows, and boss
// telegraphs. Edges use fwidth so they stay smooth at any zoom.

uniform vec4 ring_color : source_color = vec4(1.0, 0.84, 0.38, 0.95);
uniform float ring_radius = 0.42;
uniform float ring_width = 0.045;
uniform float ring_glow = 0.35;
uniform vec4 fill_color : source_color = vec4(0.0);
uniform float fill_progress = 1.0;
uniform float shadow_alpha = 0.0;
uniform float shadow_radius = 0.32;
uniform float pulse = 0.0;
// Scales the ring alone (not the shadow) so threat rings can fade in and out.
uniform float ring_fade = 1.0;
uniform bool lane = false;
// Rune circle: a hairline double ring with carved tick marks that slowly
// turns, instead of one bright band.
uniform bool rune = false;

float coverage(float dist, float width) {
	float aa = max(fwidth(dist), 0.0005) * 1.25;
	return 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, abs(dist));
}

void fragment() {
	vec2 p = UV - 0.5;
	float d;
	float r = ring_radius * (1.0 + pulse * 0.035 * sin(TIME * 5.0));
	if (lane) {
		// Box SDF; the quad is already stretched to the lane's length.
		vec2 q = abs(p) - vec2(r);
		d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) + r;
	} else {
		d = length(p);
	}
	vec4 col = vec4(0.0);
	// Soft contact shadow: a smooth falloff with no hard edge.
	float s = 1.0 - clamp(length(p) / max(shadow_radius, 0.001), 0.0, 1.0);
	s = s * s * (3.0 - 2.0 * s);
	col = vec4(vec3(0.0), shadow_alpha * s);
	// Fill grows from the center as the telegraph charges.
	if (fill_color.a > 0.0) {
		float aa = max(fwidth(d), 0.0005);
		float inside = 1.0 - smoothstep(r - aa, r + aa, d);
		float charge = 1.0 - smoothstep(r * fill_progress - aa, r * fill_progress + aa, d);
		float a = fill_color.a * inside * (0.45 + 0.55 * charge);
		col.rgb = mix(col.rgb, fill_color.rgb, a / max(col.a + a * (1.0 - col.a), 0.001));
		col.a = col.a + a * (1.0 - col.a);
	}
	if (rune && ring_color.a * ring_fade > 0.001) {
		float ang = atan(p.y, p.x) + TIME * 0.25;
		float outer = coverage(d - r, ring_width);
		float inner = coverage(d - r * 0.84, ring_width * 0.6);
		// 12 short ticks between the rings, every third a longer rune stroke.
		float seg = fract(ang / 6.2831853 * 12.0);
		float tick = coverage(seg - 0.5, 0.06) * step(r * 0.86, d) * step(d, r * 0.98);
		float major = coverage(fract(ang / 6.2831853 * 4.0) - 0.5, 0.025) * step(r * 0.78, d) * step(d, r * 1.06);
		float a = clamp(outer + inner * 0.7 + tick * 0.6 + major * 0.8, 0.0, 1.0) * ring_color.a * ring_fade;
		col.rgb = mix(col.rgb, ring_color.rgb, a / max(col.a + a * (1.0 - col.a), 0.001));
		col.a = col.a + a * (1.0 - col.a);
	} else if (ring_color.a * ring_fade > 0.001) {
		float line = coverage(d - r, ring_width);
		float halo = exp(-pow((d - r) / (ring_width * 2.2), 2.0)) * ring_glow;
		float a = clamp(line + halo * (1.0 - line), 0.0, 1.0) * ring_color.a * ring_fade;
		a *= 1.0 - pulse * 0.25 * (0.5 + 0.5 * sin(TIME * 4.0));
		col.rgb = mix(col.rgb, ring_color.rgb, a / max(col.a + a * (1.0 - col.a), 0.001));
		col.a = col.a + a * (1.0 - col.a);
	}
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
