shader_type spatial;
// Gear sparks and motes: a crisp four-point star with a white core and a
// coloured rim. Alpha-cut (no soft blob), unlit, billboarded per particle.
render_mode unshaded, cull_disabled, shadows_disabled;

void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
	MODELVIEW_MATRIX = mv;
}

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float d = sqrt(p.x) + sqrt(p.y);
	if (d > 1.0) discard;
	ALBEDO = d < 0.55 ? vec3(1.0, 0.99, 0.94) : COLOR.rgb;
}
