shader_type spatial;
// Soft alpha-blended puff for dust, grave dirt and ground mist.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float n = texture(noise, UV * 0.7 + vec2(custom.x * 3.7, custom.y * 1.3)).r;
	float a = clamp(1.0 - d, 0.0, 1.0);
	a = smoothstep(0.0, 0.8, a) * (0.55 + 0.45 * n);
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
