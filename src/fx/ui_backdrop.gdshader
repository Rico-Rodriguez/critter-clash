shader_type canvas_item;
// Slow living backdrop for menu pages: a vertical gradient with drifting mist
// and a vignette. Cheap: four octaves of value noise on a full-screen rect.
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.10, 0.07, 0.13, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.04, 0.03, 0.06, 1.0);
uniform vec4 mist_color : source_color = vec4(0.45, 0.30, 0.55, 1.0);
uniform float mist = 0.10;
uniform float speed = 0.025;
uniform float aspect = 0.5625;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y) * 3.0;
	float t = TIME * speed;
	float m = fbm(p + vec2(t, -t * 0.6) + fbm(p * 0.7 - vec2(0.0, t)) * 0.8);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);
	col += mist_color.rgb * mist * smoothstep(0.35, 0.85, m);
	float v = length((UV - vec2(0.5, 0.45)) * vec2(1.1, 0.9));
	col *= 1.0 - 0.45 * smoothstep(0.35, 0.85, v);
	COLOR = vec4(col, 1.0);
}
