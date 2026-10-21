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
	float mortar = 1.0 - smoothstep(1.5, 6.0, edge);
	// Per-block relief: a bevelled face lit from the torch above. The bevel
	// normal points toward the nearest block edge; faces turned to the light
	// catch it, the far sides fall into shadow.
	vec2 cid = vec2(floor((p.x + mod(row, 2.0) * blk.x * 0.5) / blk.x), row);
	float tone = hash(cid) * 0.22 - 0.08;
	vec2 to_edge = vec2(b.x < blk.x * 0.5 ? -1.0 : 1.0, b.y < blk.y * 0.5 ? -1.0 : 1.0);
	float ex = min(b.x, blk.x - b.x);
	float ey = min(b.y, blk.y - b.y);
	float bev_w = 14.0;
	vec2 bn = vec2(to_edge.x * (1.0 - smoothstep(0.0, bev_w, ex)), to_edge.y * (1.0 - smoothstep(0.0, bev_w, ey)));
	vec2 block_c = (vec2(cid.x * blk.x - mod(row, 2.0) * blk.x * 0.5 + blk.x * 0.5, row * blk.y + blk.y * 0.5)) / px_size;
	vec2 ldir = normalize((vec2(0.5, glow_y) - block_c) * vec2(1.0, px_size.y / px_size.x) + vec2(0.0001));
	float relief = dot(bn, ldir);
	vec3 c = mix(base.rgb, deep.rgb, smoothstep(0.2, 0.95, uv.y));
	c *= 0.65 + s * 0.6 + (s2 - 0.5) * 0.3;
	c *= 1.0 + tone;
	// Light falls off with distance from the torch: near blocks show their
	// relief strongly, far ones sink into the dark.
	vec2 dd = (uv - vec2(0.5, glow_y)) * vec2(1.0, px_size.y / px_size.x * 0.6);
	float near = exp(-dot(dd, dd) * 1.6);
	c *= 1.0 + relief * (0.35 + near * 0.55);
	c *= 1.0 - mortar * 0.7;
	// Mortar recess casts a thin shadow under each block's lower edge.
	c *= 1.0 - (1.0 - smoothstep(0.0, 9.0, blk.y - b.y)) * 0.25;
	// Torch glow pooled behind the upper content.
	vec2 d = dd;
	float pool = exp(-dot(d, d) * 3.2);
	c += warm.rgb * pool * (0.5 + s * 0.5) * (1.0 + relief * 0.4);
	// Overall falloff toward the floor.
	c *= mix(1.0, 0.55, smoothstep(0.45, 1.0, uv.y));
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
