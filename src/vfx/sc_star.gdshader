shader_type spatial;
// Billboard impact star: a spiky cartoon burst with a white core and a
// coloured rim, popped open then hollowed out from the middle (no fade).
// Per instance: COLOR = rim colour; CUSTOM = (rotation, progress, spikes, size).
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix, shadows_disabled;
varying vec4 cd;
varying vec3 col;

void vertex() {
	cd = INSTANCE_CUSTOM;
	col = COLOR.rgb;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= cd.w;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) + cd.x;
	float lim = 0.32 + 0.68 * pow(abs(cos(ang * cd.z * 0.5)), 6.0);
	if (r > lim) discard;
	if (r < min(cd.y * 1.6, 1.0) * lim) discard;
	ALBEDO = r < lim * 0.55 ? vec3(1.0) : col;
}
