shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, shadows_disabled, ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(0.16, 0.10, 0.12, 0.35);

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float d = length(p);
	float a = smoothstep(1.0, 0.35, d) * albedo.a;
	ALBEDO = albedo.rgb;
	ALPHA = a;
}
