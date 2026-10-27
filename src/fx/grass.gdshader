shader_type spatial;
// Wind-swayed, trampled grass. The same texture, roughness and instance tint
// as the stock material (lit by the normal PBR path); only the vertices move:
// tufts ripple in slow gusts, and bend away from the hero and nearby foes.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float wind = 0.10;
uniform vec4 push0 = vec4(0.0);
uniform vec4 push1 = vec4(0.0);
uniform vec4 push2 = vec4(0.0);
uniform vec4 push3 = vec4(0.0);

varying vec4 tint;

vec2 away(vec2 at, vec4 p) {
	// p.xz = position, p.w = radius; 0 radius = unused
	vec2 d = at - p.xz;
	float l = length(d);
	float k = (1.0 - smoothstep(p.w * 0.25, p.w, l)) * step(0.01, p.w);
	return (d / max(l, 0.05)) * k;
}

void vertex() {
	tint = COLOR;
	float h = clamp(VERTEX.y / 0.5, 0.0, 1.0);
	float w = h * h;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = origin.x * 0.31 + origin.z * 0.23;
	float gust = sin(TIME * 1.6 + ph) * 0.6 + sin(TIME * 3.3 + ph * 2.1) * 0.4;
	vec2 off = vec2(gust * wind, gust * wind * 0.35);
	vec2 pu = away(origin.xz, push0) + away(origin.xz, push1) + away(origin.xz, push2) + away(origin.xz, push3);
	off += pu * 0.34;
	vec3 woff = vec3(off.x, -length(pu) * 0.10 * h, off.y) * w;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * woff;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb;
	ROUGHNESS = 0.6;
	METALLIC = 0.0;
}
