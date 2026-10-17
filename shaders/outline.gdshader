shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, ambient_light_disabled;

uniform float grow = 0.02;
uniform vec4 line_color : source_color = vec4(0.20, 0.12, 0.13, 1.0);

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
