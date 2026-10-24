shader_type spatial;
// Ground warnings. shape 0 = circle, 1 = cone (half angle in `cone`, facing +Y
// of the quad), 2 = rectangle (a lane). The rim is a thin, hard-edged strip
// texture themed to the element (cracked fire edge, frost rime, thorns...),
// sampled along the perimeter; a flat fill grows with `progress` and the
// attack lands when it reaches the rim. Outline = where, fill = when.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.18, 0.1, 1.0);
uniform sampler2D edge : source_color, filter_linear_mipmap, repeat_enable;
// World size of one strip tile along the rim, in quad units (scaled by size).
uniform float band = 0.14;
instance uniform float progress = 0.0;
instance uniform float shape = 0.0;
instance uniform float cone = 0.6;
instance uniform float fade = 1.0;
instance uniform float size = 1.0;

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0; // -1..1
	float inside;
	float d_edge; // distance in from the nearest rim, quad units
	float along;  // perimeter coordinate, world metres
	float r;
	if (shape < 0.5) {
		r = length(q);
		inside = step(r, 1.0);
		d_edge = 1.0 - r;
		along = (atan(q.y, q.x) + 3.14159) * size;
	} else if (shape < 1.5) {
		vec2 f = vec2(q.x, -q.y);
		r = length(f);
		float ang = abs(atan(f.x, f.y));
		inside = step(r, 1.0) * step(ang, cone);
		float d_arc = 1.0 - r;
		float d_side = sin(cone - ang) * r;
		d_edge = min(d_arc, d_side);
		along = d_arc < d_side ? atan(f.x, f.y) * size : r * size;
	} else {
		r = 1.0 - (q.y * 0.5 + 0.5);
		inside = step(abs(q.x), 1.0) * step(abs(q.y), 1.0);
		d_edge = 1.0 - abs(q.x);
		along = q.y * size * 4.0;
	}
	float bw = band / max(size, 0.5) * 2.2;
	vec4 e = texture(edge, vec2(along * 0.9, clamp(d_edge / bw, 0.0, 1.0)));
	float rim = e.a * step(d_edge, bw);
	float filled = step(r, progress) * inside;
	vec3 fill_col = color.rgb;
	float a_fill = inside * 0.12 + filled * 0.3;
	ALBEDO = mix(fill_col, e.rgb * mix(vec3(1.0), color.rgb, 0.35), rim);
	ALPHA = clamp(max(a_fill, rim * 0.95) * inside * fade, 0.0, 1.0);
}
