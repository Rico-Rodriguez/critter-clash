shader_type canvas_item;
render_mode blend_mix, unshaded;

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float v = smoothstep(0.42, 1.15, length(p * vec2(0.78, 0.92)));
	COLOR = vec4(0.08, 0.04, 0.03, v * 0.55);
}
