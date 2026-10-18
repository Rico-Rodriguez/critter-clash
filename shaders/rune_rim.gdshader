shader_type spatial;
// T3 rune plate: a faint additive fresnel edge over the untouched artist
// material. Kept below the bloom threshold so it reads crisp, not hazy.
render_mode blend_add, unshaded, depth_draw_never, cull_back;
uniform vec4 rune_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform float strength = 0.08;
uniform float power = 6.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), power);
	ALBEDO = rune_color.rgb * f * strength;
}
