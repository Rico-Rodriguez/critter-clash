shader_type spatial;
// Flat ground shapes on a plane: 0 shockwave ring (only as part of an
// impact, it thins out as it races), 1 scorch / crack decal (ragged edge,
// glowing cracks that cool, hard-edged erosion), 2 impact flash disk,
// 3 telegraph target ring (rim + fill that tightens to the moment of hit).
// Per instance: COLOR = colour (alpha = opacity);
// CUSTOM = (mode, progress, seed, glow hue; glow hue < 0 = white glow).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform sampler2D nz : repeat_enable, filter_linear;
varying vec4 cd;
varying vec4 col;

vec3 hsv(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	cd = INSTANCE_CUSTOM;
	col = COLOR;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	int mode = int(cd.x + 0.5);
	float prog = cd.y;
	float seed = cd.z;
	vec3 c2 = cd.w < 0.0 ? vec3(1.0, 1.0, 0.92) : hsv(vec3(cd.w, 0.85, 1.0));
	float a = 1.0;
	vec3 c = col.rgb;
	if (mode == 0) {
		// Shockwave: a thin white-hot band with a coloured outer lip.
		float th = mix(0.2, 0.015, prog);
		if (r > 1.0 || r < 1.0 - th) discard;
		c = r > 1.0 - th * 0.35 ? col.rgb : vec3(1.0, 1.0, 0.92);
	} else if (mode == 1) {
		float edge = texture(nz, vec2(ang / 6.2832 * 3.0 + seed, 0.3)).r;
		if (r > 0.55 + 0.45 * edge) discard;
		float d = texture(nz, UV * 1.7 + seed).r;
		if (d < prog) discard;
		a = 0.85;
		float crack = abs(sin(ang * 6.0 + texture(nz, UV * 0.8 + seed).r * 5.0));
		if (crack < 0.09 && r < 0.95 && r > 0.12) { c = mix(c2, col.rgb, clamp(prog * 3.0, 0.0, 1.0)); a = 1.0; }
		if (d < prog + 0.05) c = col.rgb * 0.6;
	} else if (mode == 2) {
		if (r > 1.0) discard;
		c = r < 0.6 ? mix(col.rgb, vec3(1.0, 1.0, 0.92), 0.8) : col.rgb;
		if (r < prog) discard;
	} else {
		if (r > 1.0) discard;
		if (r > 0.9) { c = col.rgb; } else { a = 0.22 + 0.3 * step(r, prog); }
	}
	ALBEDO = c;
	ALPHA = a * col.a;
}
