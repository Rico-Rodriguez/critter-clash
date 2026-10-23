shader_type canvas_item;
// Slowly turning light rays behind a featured item, fading out from the middle.
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float rays = 12.0;
uniform float speed = 0.45;
uniform float strength = 0.35;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float a = atan(p.y, p.x) + TIME * speed;
	float r = length(p) * 2.0;
	float beam = smoothstep(0.35, 1.0, 0.5 + 0.5 * sin(a * rays));
	float fade = (1.0 - smoothstep(0.1, 1.0, r)) * smoothstep(0.0, 0.15, r);
	float core = (1.0 - smoothstep(0.0, 0.55, r)) * 0.5;
	COLOR = vec4(tint.rgb * strength * (beam * fade + core), 1.0);
}
