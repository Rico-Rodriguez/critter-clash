shader_type canvas_item;
// Overlay for chunky buttons and featured cards: a soft top highlight plus a
// diagonal shine band that sweeps across every `period` seconds. Laid over the
// control as a ColorRect, clipped to its rounded corners.
render_mode blend_add, unshaded;

uniform vec2 rect_size = vec2(200.0, 80.0);
uniform float radius = 18.0;
uniform float gloss = 0.16;
uniform float sweep = 0.55;
uniform float period = 3.2;
uniform float offset = 0.0;

float rounded(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	float inside = 1.0 - smoothstep(-1.0, 0.5, rounded(p, rect_size * 0.5, radius));
	// The upper third catches the light.
	float top = gloss * smoothstep(0.5, 0.0, UV.y) * smoothstep(0.0, 0.08, UV.y);
	// The band runs left to right across the first ~40% of each cycle.
	float t = fract((TIME + offset) / period);
	float pos = mix(-0.4, 1.4, smoothstep(0.0, 0.4, t));
	float x = UV.x + (UV.y - 0.5) * rect_size.y / rect_size.x * 0.6;
	float band = sweep * (1.0 - smoothstep(0.0, 0.09, abs(x - pos)));
	COLOR = vec4(vec3(1.0, 0.97, 0.88) * (top + band), 1.0) * inside;
}
