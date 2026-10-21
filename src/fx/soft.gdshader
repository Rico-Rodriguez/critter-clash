shader_type spatial;
// Soft additive dot for particles (sparks, souls, embers, dust glow).
// Uses the particle's color; billboarded by the particle material.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensity = 2.0;
uniform float hardness = 2.2;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), hardness);
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
