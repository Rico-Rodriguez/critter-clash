shader_type canvas_item;

// Art window for banners and medallions: rounded-rect (or circle) mask with
// AA edges, a dark fade along the bottom for text, optional desaturation
// and darkening for locked content, and a soft inner vignette.

uniform vec2 px = vec2(600.0, 220.0);
uniform float radius = 10.0;
uniform float circle = 0.0;
uniform float fade_from = 0.55;
uniform vec4 fade_color : source_color = vec4(0.05, 0.035, 0.025, 1.0);
uniform float fade_alpha = 0.9;
uniform float desat = 0.0;
uniform float darken = 0.0;

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = UV * px - px * 0.5;
	float d = circle > 0.5 ? length(p) - min(px.x, px.y) * 0.5 : sd_box(p, px * 0.5, min(radius, min(px.x, px.y) * 0.5));
	float aa = max(fwidth(d), 0.75);
	float mask = 1.0 - smoothstep(-aa, aa, d);
	vec3 c = tex.rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(l) * vec3(0.9, 0.88, 0.85), desat);
	c *= 1.0 - darken;
	float f = smoothstep(fade_from, 1.0, UV.y) * fade_alpha;
	c = mix(c, fade_color.rgb, f);
	vec2 v = UV - 0.5;
	c *= 1.0 - dot(v, v) * 0.5;
	COLOR = vec4(c, tex.a * mask * COLOR.a);
}
