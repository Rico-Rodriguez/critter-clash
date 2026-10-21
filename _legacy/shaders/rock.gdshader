shader_type spatial;
// Natural rock: world-space triplanar ambientCG Rock051 (albedo, normal,
// roughness) with moss settling on up-facing surfaces, or snow, or bare
// basalt. Breaks the flat-grey placeholder look of the low-poly kit rocks.

uniform sampler2D rock_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 rock_tint : source_color = vec3(0.62, 0.58, 0.54);
uniform float moss = 0.7;
uniform float snow = 0.0;
uniform float scale = 0.9;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 w = pow(abs(wnrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = wpos * scale;
	vec3 rock = tri(rock_color, p, w).rgb * rock_tint * 1.6;
	vec3 rn = tri(rock_normal, p, w).rgb;
	float rr = tri(rock_rough, p, w).r;
	// Cavity darkening from the texture's own luminance.
	float lum = dot(rock, vec3(0.3, 0.59, 0.11));
	rock *= 0.8 + lum * 0.5;
	float up = smoothstep(0.55, 0.9, wnrm.y);
	float breakup = tri(moss_color, p * 0.37 + 3.0, w).g;
	float mossw = clamp(up * moss * (0.6 + breakup * 0.9), 0.0, 1.0);
	// Moss only on the tops, with a crisp edge, so the stone shape reads.
	mossw = smoothstep(0.5, 0.62, mossw);
	vec3 m = tri(moss_color, p * 1.4, w).rgb * vec3(0.82, 0.95, 0.66);
	vec3 albedo = mix(rock, m, mossw);
	vec3 nm = mix(rn, tri(moss_normal, p * 1.4, w).rgb, mossw);
	float snoww = smoothstep(0.25, 0.55, up * snow + breakup * 0.2 * snow);
	albedo = mix(albedo, vec3(0.86, 0.9, 0.97), snoww);
	ALBEDO = albedo;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 2.2;
	ROUGHNESS = mix(mix(rr, 0.95, mossw), 0.6, snoww);
	SPECULAR = 0.35;
	AO = 1.0 - (1.0 - up) * 0.15;
}
