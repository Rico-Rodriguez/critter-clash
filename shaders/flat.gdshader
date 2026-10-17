shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, shadows_disabled, ambient_light_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float energy = 1.0;

void fragment() {
	ALBEDO = albedo.rgb;
	EMISSION = albedo.rgb * energy;
	ALPHA = albedo.a;
}
