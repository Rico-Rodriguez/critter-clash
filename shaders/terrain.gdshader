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
// Biome surface: snow drifts over the turf (frost), or ash with glowing
// cracks (volcano). 0 leaves the meadow look.
uniform float snow = 0.0;
uniform float ash = 0.0;
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
	// Anti-tiling: a second, rotated and rescaled sample of each turf layer,
	// blended by low-frequency noise so no repeat lines up across the field.
	vec2 wr = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * w * 0.73 + 37.0;
	float swap = smoothstep(0.38, 0.62, fbm(w * 0.09 + 17.0));
	vec3 g = mix(texture(grass_color, uv_g).rgb, texture(grass_color, tile_uv(wr, 0.38)).rgb, swap);
	vec3 l = mix(texture(lush_color, uv_l).rgb, texture(lush_color, tile_uv(wr + 5.0, 0.31)).rgb, 1.0 - swap);
	vec3 grass = mix(g, l * vec3(1.08, 1.06, 0.92), patch);
	vec3 gn = mix(texture(grass_normal, uv_g).rgb, texture(lush_normal, uv_l).rgb, patch);
	// Sun-warmed and shaded patches, very low frequency.
	float warm = fbm(w * 0.05 + 9.0);
	grass *= mix(vec3(0.84, 0.92, 0.78), vec3(1.08, 1.04, 0.86), warm);
	// Macro albedo variation: broad darker/lusher swathes and olive-gold
	// meadow patches, so the field never reads as one flat green.
	float macro = fbm(w * 0.028 + 3.0);
	grass *= mix(0.78, 1.14, macro);
	float meadow_hue = smoothstep(0.45, 0.75, fbm(w * 0.06 + 41.0));
	grass = mix(grass, grass * vec3(1.12, 1.0, 0.7), meadow_hue * 0.35);
	float deep = smoothstep(0.5, 0.78, fbm(w * 0.08 + 61.0));
	grass = mix(grass, grass * vec3(0.7, 0.86, 0.74), deep * 0.4);
	// Paths: a ragged edge, a grassy shoulder, and dirt in the middle.
	float pd = path_dist(w);
	float edge = path_width * (0.75 + fbm(w * 1.3) * 0.5);
	float dirt_w = 1.0 - smoothstep(edge * 0.55, edge, pd);
	dirt_w = clamp(dirt_w + (fbm(w * 0.9 + 2.0) - 0.82) * 1.5, 0.0, 1.0);
	vec3 dirt = texture(dirt_color, uv_d).rgb * dirt_tint;
	vec3 dn = texture(dirt_normal, uv_d).rgb;
	float shoulder = smoothstep(edge * 1.6, edge * 0.8, pd) * (1.0 - dirt_w);
	grass *= 1.0 - shoulder * 0.16;
	// Clover: small dark rich clumps scattered through the turf.
	float clover = smoothstep(0.62, 0.74, fbm(w * 1.7 + 21.0)) * (1.0 - dirt_w);
	grass = mix(grass, grass * vec3(0.62, 0.82, 0.55), clover * 0.75);
	// Dry, sun-bleached tufts in broad drifts.
	float dry = smoothstep(0.58, 0.8, fbm(w * 0.22 + 13.0));
	grass = mix(grass, grass * vec3(1.16, 1.06, 0.74), dry * 0.3);
	// Bare dirt scuffs out in the field, away from the trails.
	float scuff = smoothstep(0.74, 0.8, fbm(w * 0.55 + 31.0)) * (0.6 + 0.4 * fbm(w * 4.0));
	dirt_w = max(dirt_w, scuff * 0.85);
	// Path wear: a compacted, darker tread down the middle of each trail.
	float tread = smoothstep(edge * 0.35, 0.0, pd);
	dirt *= 1.0 - tread * 0.18;
	vec3 albedo = mix(grass, dirt, dirt_w);
	// Soft ground occlusion in hollows and at the trail edges.
	float hollow = smoothstep(0.55, 0.2, fbm(w * 0.4 + 5.0));
	albedo *= 1.0 - hollow * 0.08 - shoulder * 0.05;
	albedo *= tint;
	if (snow > 0.0) {
		float drift = smoothstep(0.35, 0.65, fbm(w * 0.35 + 4.0) + (1.0 - dirt_w) * 0.25);
		vec3 white = vec3(0.86, 0.91, 1.0) * (0.86 + fbm(w * 3.0) * 0.18);
		albedo = mix(albedo, white, clamp(drift * snow + snow * 0.35, 0.0, 1.0));
	}
	vec3 glow = vec3(0.0);
	if (ash > 0.0) {
		// Dark basalt with grey ash drifts; thin glowing lava cracks with a
		// hot core and a deep red bleed, never a flat bright stripe.
		float lum = dot(albedo, vec3(0.3, 0.59, 0.11));
		vec3 basalt = vec3(0.075, 0.068, 0.07) * (0.7 + lum * 1.2);
		float drift = smoothstep(0.45, 0.75, fbm(w * 0.4 + 23.0));
		basalt = mix(basalt, vec3(0.26, 0.24, 0.23) * (0.8 + fbm(w * 3.0) * 0.4), drift * 0.55);
		albedo = mix(albedo, basalt, ash);
		float f = abs(fbm(w * 0.32 + 7.0) - 0.5);
		float f2 = abs(fbm(w * 0.7 + 19.0) - 0.5);
		float core = 1.0 - smoothstep(0.0, 0.006, f);
		float halo = 1.0 - smoothstep(0.0, 0.03, f);
		float fine = (1.0 - smoothstep(0.0, 0.004, f2)) * smoothstep(0.5, 0.7, fbm(w * 0.2 + 3.0));
		float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + w.x * 0.7 + w.y * 0.4);
		albedo = mix(albedo, vec3(0.03, 0.01, 0.01), halo * ash * 0.7);
		glow = (vec3(1.0, 0.42, 0.08) * (core + fine * 0.6) * 1.6 + vec3(0.7, 0.1, 0.02) * halo * 0.45) * ash * pulse;
	}
	ALBEDO = albedo;
	EMISSION = glow;
	NORMAL_MAP = mix(gn, dn, dirt_w);
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = mix(0.9, texture(dirt_rough, uv_d).r, dirt_w);
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
