shader_type canvas_item;

// Menu backdrop: dark carved stone lit by a warm torch glow from above,
// cooler and darker toward the bottom, with a heavy vignette. Bleeds edge to
// edge behind every menu screen.

uniform sampler2D stone : repeat_enable, filter_linear_mipmap;
uniform vec2 px_size = vec2(720.0, 1560.0);
uniform vec4 warm : source_color = vec4(0.42, 0.27, 0.15, 1.0);
uniform vec4 base : source_color = vec4(0.10, 0.08, 0.07, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.03, 0.04, 1.0);
uniform float glow_y = 0.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * px_size;
	float s = texture(stone, p / 620.0).r;
	float s2 = texture(stone, p / 1900.0 + 0.37).r;
	// Large carved blocks: faint mortar lines on a staggered course.
	vec2 blk = vec2(240.0, 150.0);
	float row = floor(p.y / blk.y);
	vec2 b = vec2(mod(p.x + mod(row, 2.0) * blk.x * 0.5, blk.x), mod(p.y, blk.y));
	float edge = min(min(b.x, blk.x - b.x), min(b.y, blk.y - b.y));
	float mortar = 1.0 - smoothstep(1.0, 5.0, edge);
	float bevel = smoothstep(5.0, 10.0, edge) * (1.0 - smoothstep(10.0, 40.0, edge));
	vec3 c = mix(base.rgb, deep.rgb, smoothstep(0.25, 1.0, uv.y));
	c *= 0.65 + s * 0.6 + (s2 - 0.5) * 0.3;
	c *= 1.0 - mortar * 0.55;
	c += vec3(0.05, 0.04, 0.03) * bevel * step(b.y, blk.y * 0.5);
	// Torch glow pooled behind the upper content.
	vec2 d = (uv - vec2(0.5, glow_y)) * vec2(1.0, px_size.y / px_size.x * 0.6);
	float pool = exp(-dot(d, d) * 3.2);
	c += warm.rgb * pool * (0.55 + s * 0.5);
	// Faint drifting embers.
	vec2 ep = p / 90.0 + vec2(0.0, TIME * 0.35);
	vec2 cell = floor(ep);
	float h = hash(cell);
	vec2 f = fract(ep) - vec2(h, fract(h * 7.3));
	float ember = smoothstep(0.05, 0.0, length(f)) * step(0.93, h) * (1.0 - uv.y);
	c += vec3(1.0, 0.55, 0.2) * ember * 0.5;
	// Vignette.
	vec2 v = (uv - vec2(0.5, 0.45)) * vec2(1.3, 1.0);
	c *= clamp(1.0 - dot(v, v) * 1.1, 0.0, 1.0);
	c += (hash(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(c, 1.0);
}
