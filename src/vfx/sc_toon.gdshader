shader_type spatial;
// Supercell-style toon piece for the batched VFX layers (puffs, balls,
// debris, spikes): 3 hard colour bands from a fixed view-space key light and
// a hard-edged noise dissolve with a dark burn edge. Unlit, opaque, crisp.
// Per instance: COLOR.rgb = body; CUSTOM = (seed, erode, rim hue, rim value).
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;
uniform sampler2D nz : repeat_enable, filter_linear;
varying vec4 cd;
varying vec3 bodyc;

vec3 hsv(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	bodyc = COLOR.rgb;
}

void fragment() {
	vec3 key = normalize(vec3(-0.35, 0.5, 1.0));
	float f = dot(NORMAL, key);
	float n = texture(nz, UV * vec2(2.0, 1.0) + vec2(cd.x, cd.x * 0.7)).r;
	float erode = cd.y;
	if (erode > 0.001 && n < erode) discard;
	// Graded to sit beside the dark plate heroes: a bone-warm core instead of
	// near white, a deeper rim band, and a wider dark burn edge on dissolve.
	vec3 core = mix(bodyc, vec3(1.0, 0.9, 0.7), 0.62);
	vec3 rim = hsv(vec3(cd.z, 0.9, cd.w * 0.78));
	vec3 c = f > 0.78 ? core : (f > 0.3 ? bodyc : rim);
	if (erode > 0.001 && n < erode + 0.1) c = rim;
	ALBEDO = c;
}
