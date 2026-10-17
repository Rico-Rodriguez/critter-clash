shader_type spatial;

// Grass, dirt, and rock splatted with noise. Two UV scales and a slow color
// shift keep a photo texture from reading as a tiled grid.

uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform vec2 world_span = vec2(70.0, 82.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 sample2(sampler2D tex, vec2 uv) {
	vec2 alt = uv * vec2(1.73, -1.41) + vec2(0.17, 0.43);
	float blend = noise(uv * 3.7);
	return mix(texture(tex, uv).rgb, texture(tex, alt).rgb, mix(0.35, 0.65, blend));
}

void vertex() {
	vec2 world = UV * world_span;
	float roll = noise(world * 0.035);
	VERTEX.y += (roll - 0.5) * 0.14;
}

void fragment() {
	vec2 world = UV * world_span;
	float region = noise(world * 0.04);
	float mid = noise(world * 0.13 + 2.2);
	float detail = noise(world * 0.31 + 7.4);
	float rock_w = smoothstep(0.7, 0.92, region * 0.3 + mid * 0.7);
	float dirt_w = smoothstep(0.5, 0.8, mid * 0.65 + detail * 0.35) * (1.0 - rock_w);
	float grass_w = max(1.0 - rock_w - dirt_w, 0.0);
	float sum_w = max(grass_w + dirt_w + rock_w, 0.001);
	grass_w /= sum_w;
	dirt_w /= sum_w;
	rock_w /= sum_w;
	vec2 uv_g = world * 0.14;
	vec2 uv_d = world * 0.11;
	vec2 uv_r = world * 0.09;
	vec3 albedo = sample2(grass_color, uv_g) * grass_w;
	albedo += sample2(dirt_color, uv_d) * dirt_w;
	albedo += sample2(rock_color, uv_r) * rock_w;
	vec3 nrm = sample2(grass_normal, uv_g) * grass_w;
	nrm += sample2(dirt_normal, uv_d) * dirt_w;
	nrm += sample2(rock_normal, uv_r) * rock_w;
	float rough = sample2(grass_rough, uv_g).r * grass_w;
	rough += sample2(dirt_rough, uv_d).r * dirt_w;
	rough += sample2(rock_rough, uv_r).r * rock_w;
	float canopy = noise(world * 0.2 + 1.7);
	float dapple = mix(0.84, 1.12, smoothstep(0.28, 0.8, canopy));
	float broad = mix(0.9, 1.1, region);
	vec3 earth = mix(vec3(0.92, 1.04, 0.8), vec3(1.06, 1.0, 0.88), noise(world * 0.018));
	ALBEDO = albedo * tint * dapple * broad * earth * 0.9;
	NORMAL_MAP = nrm;
	ROUGHNESS = clamp(rough, 0.45, 1.0);
	METALLIC = 0.0;
}
