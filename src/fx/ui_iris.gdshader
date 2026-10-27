shader_type canvas_item;
// A screen change: a dark curtain that closes like an iris toward `center`
// and opens again. `closed` 0 is clear, 1 is fully covered.

uniform float closed : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 view_size = vec2(720.0, 1280.0);
uniform vec4 cover : source_color = vec4(0.01, 0.01, 0.02, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.78, 0.36, 1.0);

void fragment() {
	vec2 p = (UV - center) * vec2(view_size.x / view_size.y, 1.0);
	float d = length(p);
	float r = (1.0 - closed) * 1.7 - 0.05;
	float body = smoothstep(r, r + 0.012, d);
	// A thin warm edge on the curtain as it moves, gone when fully open or shut.
	float edge = exp(-pow((d - r - 0.012) / 0.02, 2.0)) * smoothstep(0.0, 0.1, closed) * smoothstep(1.0, 0.9, closed);
	vec3 col = mix(cover.rgb, rim.rgb, edge * 0.55);
	COLOR = vec4(col, max(body, edge * 0.5) * step(-0.05, r));
}
