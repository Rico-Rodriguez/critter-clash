shader_type canvas_item;
// Corner map: explored ground from the baked base, unexplored as dark-teal
// parchment (never black), clipped to a disc in the corner view.
uniform sampler2D base_tex : filter_linear;
uniform sampler2D veil_tex : filter_linear;
uniform vec2 center_uv = vec2(0.5);
uniform vec2 span_uv = vec2(1.0);
uniform bool round_mask = true;
uniform vec2 px_size = vec2(160.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	vec2 uv = center_uv + p * span_uv;
	vec4 base = texture(base_tex, uv);
	float veil = texture(veil_tex, uv).a;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		veil = 1.0;
	}
	// Parchment: mottled dark teal with fibres, slightly lighter toward the middle.
	vec2 q = uv * vec2(90.0, 180.0);
	float mott = noise(q * 0.35) * 0.6 + noise(q * 1.3) * 0.3 + noise(q * 4.0) * 0.1;
	vec3 parch = mix(vec3(0.075, 0.15, 0.155), vec3(0.15, 0.24, 0.22), mott);
	parch *= 0.9 + 0.2 * (1.0 - length(p) * 1.4);
	vec3 col = mix(base.rgb, parch, veil);
	float a = 1.0;
	if (round_mask) {
		float d = length(p) * px_size.x;
		a = 1.0 - smoothstep(px_size.x * 0.5 - 1.5, px_size.x * 0.5, d);
		// Inner shadow under the rim.
		col *= 0.65 + 0.35 * smoothstep(px_size.x * 0.5, px_size.x * 0.5 - 14.0, d);
	}
	COLOR = vec4(col, a);
}
