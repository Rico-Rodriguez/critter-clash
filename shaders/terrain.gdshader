shader_type spatial;

// Meadow floor: two ambientCG grasses broken up by large soft patches, worn
// dirt paths that wind through the clearing, and dirt rings under props.
// Texture scale is about 2.5 m per tile, so the grass reads as turf from the
// hunt camera instead of a noisy smear.

uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lush_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lush_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform vec3 dirt_tint = vec3(1.0);
uniform vec2 world_span = vec2(70.0, 82.0);
uniform vec2 world_origin = vec2(0.0);
uniform float path_width = 1.25;

varying vec2 world_xz;

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

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.03 + 3.1) * 0.3 + noise(p * 4.1 + 7.7) * 0.15;
}

// Rotate the tile per large cell so repeats do not line up.
vec2 tile_uv(vec2 w, float scale) {
	return w * scale + vec2(0.37, 0.11) * floor(w * 0.05);
}

// Distance to the winding paths, in meters. World x runs 0..14.4 and z
// 0..25.6 across the playfield.
float path_dist(vec2 w) {
	float wob = (fbm(w * 0.35) - 0.5) * 1.1;
	// A long trail down the clearing.
	float a = abs(w.x - (7.2 + sin(w.y * 0.23 + 0.6) * 2.6 + wob));
	// A cross trail that bends over it.
	float b = abs(w.y - (13.0 + sin(w.x * 0.31 + 1.8) * 2.2 + wob * 0.8));
	// A spur toward the boss clearing.
	float c = abs(w.x - (3.4 + w.y * 0.18 + wob)) + max(w.y - 11.0, 0.0) * 4.0;
	return min(min(a, b), c);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float roll = noise(world_xz * 0.18);
	float worn = smoothstep(path_width * 1.4, 0.0, path_dist(world_xz));
	VERTEX.y += (roll - 0.5) * 0.12 - worn * 0.04;
}

void fragment() {
	vec2 w = world_xz;
	vec2 uv_g = tile_uv(w, 0.38);
	vec2 uv_l = tile_uv(w + 11.0, 0.31);
	vec2 uv_d = tile_uv(w, 0.33);
	float patch = smoothstep(0.35, 0.68, fbm(w * 0.12 + 4.0));
	vec3 g = texture(grass_color, uv_g).rgb;
	vec3 l = texture(lush_color, uv_l).rgb;
	vec3 grass = mix(g, l * vec3(1.08, 1.06, 0.92), patch);
	vec3 gn = mix(texture(grass_normal, uv_g).rgb, texture(lush_normal, uv_l).rgb, patch);
	// Sun-warmed and shaded patches, very low frequency.
	float warm = fbm(w * 0.05 + 9.0);
	grass *= mix(vec3(0.84, 0.92, 0.78), vec3(1.08, 1.04, 0.86), warm);
	// Paths: a ragged edge, a grassy shoulder, and dirt in the middle.
	float pd = path_dist(w);
	float edge = path_width * (0.75 + fbm(w * 1.3) * 0.5);
	float dirt_w = 1.0 - smoothstep(edge * 0.55, edge, pd);
	dirt_w = clamp(dirt_w + (fbm(w * 0.9 + 2.0) - 0.82) * 1.5, 0.0, 1.0);
	vec3 dirt = texture(dirt_color, uv_d).rgb * dirt_tint;
	vec3 dn = texture(dirt_normal, uv_d).rgb;
	float shoulder = smoothstep(edge * 1.6, edge * 0.8, pd) * (1.0 - dirt_w);
	grass *= 1.0 - shoulder * 0.16;
	vec3 albedo = mix(grass, dirt, dirt_w);
	ALBEDO = albedo * tint;
	NORMAL_MAP = mix(gn, dn, dirt_w);
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = mix(0.9, texture(dirt_rough, uv_d).r, dirt_w);
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
