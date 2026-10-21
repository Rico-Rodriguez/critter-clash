shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform float grow = 0.035;
uniform vec4 line_color : source_color = vec4(1.0, 0.91, 0.62, 1.0);

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
