shader_type canvas_item;

// Layered menu backdrop: a deep royal-blue vertical blend, a warm spotlight
// behind the title area, a faint embossed diamond lattice, slow light rays,
// and a vignette. Bleeds edge to edge behind every menu screen.

uniform vec4 top_color : source_color = vec4(0.20, 0.52, 0.93, 1.0);
uniform vec4 mid_color : source_color = vec4(0.09, 0.29, 0.66, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.03, 0.10, 0.30, 1.0);
uniform vec4 glow_color : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform vec2 px_size = vec2(720.0, 1560.0);
uniform float glow_y = 0.24;

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * px_size;
	vec3 c = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.5, uv.y));
	c = mix(c, bottom_color.rgb, smoothstep(0.45, 1.0, uv.y));
	vec2 d = (uv - vec2(0.5, glow_y)) * vec2(1.0, px_size.y / px_size.x * 0.55);
	float spot = exp(-dot(d, d) * 5.0);
	c += glow_color.rgb * spot * 0.22;
	// Embossed diamond lattice.
	vec2 q = p / 58.0;
	vec2 r = vec2(q.x + q.y, q.x - q.y);
	vec2 f = fract(r) - 0.5;
	float edge = max(abs(f.x), abs(f.y));
	float aa = fwidth(edge) * 1.5;
	float groove = smoothstep(0.5 - aa * 2.0, 0.5 - aa * 0.5, edge);
	float light = smoothstep(0.0, 0.5, f.x + f.y) * 0.5;
	c *= 1.0 - groove * 0.07;
	c += vec3(0.04, 0.06, 0.1) * light * (1.0 - groove) * 0.5;
	float chk = mod(floor(r.x) + floor(r.y), 2.0);
	c *= 1.0 + (chk - 0.5) * 0.04;
	// Slow rays from above the title.
	float ang = atan(uv.x - 0.5, uv.y + 0.35);
	float rays = smoothstep(0.55, 1.0, 0.5 + 0.5 * sin(ang * 22.0 + TIME * 0.12));
	c += glow_color.rgb * rays * 0.035 * (1.0 - smoothstep(0.0, 0.75, uv.y));
	// Vignette.
	vec2 v = (uv - 0.5) * vec2(1.25, 0.9);
	c *= 1.0 - dot(v, v) * 0.85;
	// Dither by half an 8-bit step so the long gradients don't band.
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) / 255.0;
	COLOR = vec4(c, 1.0);
}
