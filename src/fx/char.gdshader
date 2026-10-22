shader_type spatial;
// Characters: the KayKit texture, graded darker and dirtier (desaturated,
// mud at the hem, soot on undersides), with a moonlit rim, a hit flash and an
// elite tint. Flash/tint are per-instance so every skeleton shares one material.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 rim_color : source_color = vec4(0.55, 0.68, 1.0, 1.0);
uniform float rim_strength = 0.5;
uniform float roughness = 0.78;
uniform vec4 eye_glow : source_color = vec4(0.0);

// The grit pass: tune these to taste. desat 0 = KayKit's own palette.
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float desat = 0.24;
uniform float darken = 0.84;
uniform float grime = 0.6;
uniform vec4 grime_color : source_color = vec4(0.11, 0.08, 0.055, 1.0);

varying vec3 lpos;

instance uniform float flash = 0.0;
instance uniform vec4 tint : source_color = vec4(0.0);
// Gear dye: rgb is the material color (bronze, mithril, dragonhide...), a is how
// much of it replaces the texture while keeping its light and dark detail.
instance uniform vec4 dye : source_color = vec4(0.0);
// Gear grade, set from the material tier (GearDB.grade): x polish (clean,
// glossy, a rim in the dye's color), y shimmer (a band of light sweeping up
// the piece), z veins (glowing lines through it, pulsing), w hue shift of the
// veins toward white-hot. Bronze is all zeros; Dragon has everything.
instance uniform vec4 grade = vec4(0.0);
// The color the grade glows in: the dye at full brightness, or a line's own
// (Eldritch robes burn violet, black dragonhide a dark green).
instance uniform vec4 accent : source_color = vec4(1.0);

void vertex() {
	lpos = VERTEX; // skinned, in the model's local space: y = height above the feet
}

void fragment() {
	vec3 c0 = texture(albedo_tex, UV).rgb;
	float luma = dot(c0, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(c0, vec3(luma), desat) * darken;
	c = mix(c, dye.rgb * (0.18 + luma * 1.35) * darken, dye.a);
	// Dirt: blotches, a muddy hem, and soot on surfaces that face the ground.
	float n = texture(grime_tex, lpos.xz * 0.9 + vec2(lpos.y * 0.6, lpos.y * 0.35)).r;
	float hem = 1.0 - smoothstep(0.0, 0.7, lpos.y);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float under = clamp(0.5 - wn.y * 0.5, 0.0, 1.0);
	float dirt = clamp((smoothstep(0.45, 0.8, n) * 0.7 + hem * 0.6 + under * 0.35) * grime, 0.0, 0.85);
	// Fine gear is kept clean.
	dirt *= 1.0 - grade.x * 0.85;
	c = mix(c, grime_color.rgb * (0.7 + 0.6 * n), dirt);
	ALBEDO = mix(c, vec3(1.0), flash * 0.85);
	ROUGHNESS = mix(mix(roughness, 0.42, grade.x), 0.95, dirt);
	SPECULAR = mix(0.3, 0.5, grade.x);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 e = rim_color.rgb * fr * rim_strength;
	// Sheen in the metal's own color, so mithril reads blue, not white.
	vec3 gc = accent.rgb * 0.85;
	e += gc * fr * grade.x * 0.6;
	if (grade.y > 0.0) {
		float band = fract(lpos.y * 0.55 + lpos.x * 0.25 - TIME * 0.32);
		e += gc * smoothstep(0.12, 0.0, abs(band - 0.5) - 0.02) * grade.y * (0.3 + 0.5 * luma);
	}
	if (grade.z > 0.0) {
		// Broad molten seams: a low-frequency contour of the grime noise.
		float v = texture(grime_tex, lpos.xy * 0.75 + vec2(lpos.z * 0.45, 0.0)).r;
		float vein = smoothstep(0.05, 0.0, abs(v - 0.55));
		float pulse = 0.6 + 0.4 * sin(TIME * 2.2 + lpos.y * 2.5);
		e += mix(accent.rgb * 1.6, vec3(1.0, 0.75, 0.4), grade.w) * vein * grade.z * pulse * 1.8;
	}
	e += tint.rgb * tint.a * (0.25 + fr * 2.2);
	e += vec3(1.0, 0.95, 0.9) * flash * 1.6;
	// KayKit skeleton eyes are the brightest warm texels: let them glow.
	float hot = smoothstep(0.82, 0.95, c0.r) * smoothstep(0.55, 0.75, c0.g) * (1.0 - smoothstep(0.35, 0.6, c0.b));
	e += eye_glow.rgb * eye_glow.a * hot * 4.0;
	EMISSION = e;
}
