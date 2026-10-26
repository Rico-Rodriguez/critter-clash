shader_type spatial;
// Loot beam, Supercell style: a solid light column in hard bands. It has a
// white core, a rarity-coloured shell, and chevrons that climb the column.
// It steps out in flat tiers toward the top. Unlit, mixed (not additive),
// no soft falloff, no bloom.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
instance uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.3, 1.0);
instance uniform float strength = 1.0;

varying float face;

void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	face = abs(n.z);
}

void fragment() {
	float up = 1.0 - UV.y;
	// Flat tiers: full, then two lighter steps, then gone.
	float tier = up < 0.55 ? 1.0 : (up < 0.78 ? 0.7 : (up < 0.93 ? 0.42 : 0.0));
	if (tier <= 0.0) discard;
	vec3 white = vec3(1.0, 0.99, 0.94);
	vec3 col;
	float a;
	if (face > 0.82) { col = mix(tint.rgb, white, 0.35); a = 0.85; }
	else if (face > 0.45) { col = tint.rgb; a = 0.6; }
	else { col = tint.rgb * 0.7; a = 0.35; }
	// Chevrons climbing the column.
	float ch = fract(UV.y * 5.0 + abs(UV.x - 0.5) * 1.4 + TIME * 0.9);
	if (ch < 0.16) { col = mix(col, white, 0.7); a = min(a + 0.2, 1.0); }
	ALBEDO = col;
	ALPHA = a * tier * clamp(strength, 0.0, 1.0);
}
