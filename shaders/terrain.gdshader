shader_type spatial;

// Hunt floor: three 2K ambientCG ground materials (turf, mossy forest floor,
// packed dirt) blended by a noise splat and sharpened by each material's own
// height map, so transitions follow the grain of the ground (dirt shows in
// the gaps of the turf, moss creeps over the dirt) instead of a soft fade.
// Normal detail only, no parallax: cheap on mobile and stable at any angle.

uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform vec3 dirt_tint = vec3(1.0);
// Biome surface: snow drifts over the turf (frost), or ash with glowing
// cracks (volcano). 0 leaves the meadow look.
uniform float snow = 0.0;
uniform float ash = 0.0;
uniform vec2 world_span = vec2(70.0, 82.0);
uniform vec2 world_origin = vec2(0.0);
uniform float path_width = 1.25;
// Arena bounds in world xz (min.x, min.z, max.x, max.z): canopy shade
// gathers toward the edges where the tree line stands.
uniform vec4 arena = vec4(0.0, 0.0, 30.0, 50.0);
uniform float litter = 1.0;

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
	float a = abs(w.x - (11.2 + sin(w.y * 0.17 + 0.6) * 3.8 + wob));
	// A cross trail that bends over it.
	float b = abs(w.y - (24.0 + sin(w.x * 0.25 + 1.8) * 2.8 + wob * 0.8));
	// A spur toward the boss clearing.
	float c = abs(w.x - (5.0 + w.y * 0.2 + wob)) + max(w.y - 19.0, 0.0) * 4.0;
	return min(min(a, b), c);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float roll = noise(world_xz * 0.18);
	float worn = smoothstep(path_width * 1.4, 0.0, path_dist(world_xz));
	VERTEX.y += (roll - 0.5) * 0.12 - worn * 0.04;
}

// Height-weighted blend of three layers: weights in, normalised weights out.
vec3 height_blend(vec3 wgt, vec3 h) {
	vec3 sc = wgt + h * 0.4;
	float top = max(max(sc.x, sc.y), sc.z) - 0.34;
	vec3 b = max(sc - top, vec3(0.0)) * step(vec3(0.001), wgt);
	return b / max(b.x + b.y + b.z, 1e-4);
}

void fragment() {
	vec2 w = world_xz;
	// Anti-tiling: every layer is sampled twice, the second time rotated and
	// rescaled, mixed by low-frequency noise so no repeat lines up.
	vec2 wr = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * w * 0.73 + 37.0;
	float swap = smoothstep(0.38, 0.62, fbm(w * 0.09 + 17.0));
	vec2 ug1 = tile_uv(w, 0.25);
	vec2 ug2 = tile_uv(wr, 0.25);
	vec2 uf1 = tile_uv(w + 11.0, 0.22);
	vec2 uf2 = tile_uv(wr + 5.0, 0.22);
	vec2 ud1 = tile_uv(w, 0.28);
	vec2 ud2 = tile_uv(wr + 23.0, 0.26);
	vec3 g_col = mix(texture(grass_color, ug1).rgb, texture(grass_color, ug2).rgb, swap);
	vec3 g_n = mix(texture(grass_normal, ug1).rgb, texture(grass_normal, ug2).rgb, swap);
	vec2 g_d = mix(texture(grass_data, ug1).rg, texture(grass_data, ug2).rg, swap);
	vec3 f_col = mix(texture(forest_color, uf1).rgb, texture(forest_color, uf2).rgb, 1.0 - swap);
	vec3 f_n = mix(texture(forest_normal, uf1).rgb, texture(forest_normal, uf2).rgb, 1.0 - swap);
	vec2 f_d = mix(texture(forest_data, uf1).rg, texture(forest_data, uf2).rg, 1.0 - swap);
	float dswap = smoothstep(0.4, 0.6, fbm(w * 0.15 + 71.0));
	vec3 d_col = mix(texture(dirt_color, ud1).rgb, texture(dirt_color, ud2).rgb, dswap) * dirt_tint;
	vec3 d_n = mix(texture(dirt_normal, ud1).rgb, texture(dirt_normal, ud2).rgb, dswap);
	vec2 d_d = mix(texture(dirt_data, ud1).rg, texture(dirt_data, ud2).rg, dswap);

	// Turf colour grading: broad sun-warmed, olive and deep swathes.
	float warm = fbm(w * 0.05 + 9.0);
	g_col *= mix(vec3(0.88, 0.94, 0.82), vec3(1.06, 1.03, 0.9), warm);
	float macro = fbm(w * 0.028 + 3.0);
	g_col *= mix(0.84, 1.1, macro);
	float meadow_hue = smoothstep(0.45, 0.75, fbm(w * 0.06 + 41.0));
	g_col = mix(g_col, g_col * vec3(1.08, 1.0, 0.8), meadow_hue * 0.14);
	float dry = smoothstep(0.5, 0.85, fbm(w * 0.45 + 13.0));
	g_col = mix(g_col, g_col * vec3(1.08, 1.04, 0.84), dry * 0.12);

	// Forest floor graded darker and browner so it reads as shaded humus.
	// Cool brown humus with mossy green creeping through, not olive.
	f_col *= vec3(0.66, 0.66, 0.56);
	float moss = smoothstep(0.35, 0.75, fbm(w * 0.7 + 61.0));
	f_col = mix(f_col, f_col * vec3(0.82, 1.08, 0.78), moss * 0.55);
	// Splat weights. Forest floor: noise patches, the band along every
	// trail, and the shaded margin under the tree line.
	float ex = min(w.x - arena.x, arena.z - w.x);
	float ez = min(w.y - arena.y, arena.w - w.y);
	float edge_d = min(ex, ez);
	float canopy = 1.0 - smoothstep(1.5, 8.0, edge_d);
	float pd = path_dist(w);
	float edge = path_width * (0.75 + fbm(w * 1.3) * 0.5);
	// Multi-octave patch mask: small, broken drifts of litter with soft
	// borders instead of big blotches.
	float pn = fbm(w * 0.22 + 4.0) * 0.55 + fbm(w * 0.6 + 19.0) * 0.3 + fbm(w * 1.7 + 2.0) * 0.15;
	float patch = smoothstep(0.52, 0.72, pn);
	float trail_band = smoothstep(edge * 1.7, edge * 0.9, pd) * smoothstep(0.35, 0.6, fbm(w * 0.4 + 8.0));
	float wf = clamp(max(max(patch * 0.85, trail_band * 0.7), canopy * 0.8) * (0.35 + 0.65 * litter), 0.0, 1.0);
	// Dirt: the trails themselves, scuffs and bare patches out in the field.
	// Trail edges get a grass-overgrowth fringe: fine tufts eat into the
	// dirt so the border is ragged and soft rather than a clean line.
	float tuft = fbm(w * 2.6 + 3.0) * 0.65 + fbm(w * 6.0 + 9.0) * 0.35;
	float wd = 1.0 - smoothstep(edge * 0.25, edge * 1.05, pd + (tuft - 0.45) * edge * 0.9);
	float scuff = smoothstep(0.7, 0.82, fbm(w * 0.55 + 31.0));
	float bare = smoothstep(0.64, 0.8, fbm(w * 0.18 + 47.0));
	wd = clamp(max(wd, max(scuff * 0.7, bare * 0.8)), 0.0, 1.0);
	vec3 wgt = vec3(1.0 - max(wf, wd) * 0.85, wf * (1.0 - wd * 0.6), wd);
	vec3 bw = height_blend(wgt, vec3(g_d.y, f_d.y, d_d.y));
	float dirt_w = bw.z;

	// Path wear: a compacted, darker tread down the middle of each trail.
	float tread = smoothstep(edge * 0.35, 0.0, pd);
	d_col *= 1.0 - tread * 0.16;
	vec3 albedo = g_col * bw.x + f_col * bw.y + d_col * bw.z;
	// Grassy shoulder darkening where turf meets the trail.
	float shoulder = smoothstep(edge * 1.6, edge * 0.8, pd) * bw.x;
	albedo *= 1.0 - shoulder * 0.12;
	// Soft ground occlusion in hollows and at the trail edges.
	float hollow = smoothstep(0.55, 0.2, fbm(w * 0.4 + 5.0));
	albedo *= 1.0 - hollow * 0.08 - shoulder * 0.05;
	albedo *= tint;
	// Canopy shade: heavy under the tree line at the arena edges, plus
	// soft dappled cloud shadow drifting across the whole clearing.
	float dapple = smoothstep(0.42, 0.62, fbm(w * 0.32 + vec2(TIME * 0.06, TIME * 0.025)));
	float drift = smoothstep(0.5, 0.7, fbm(w * 0.05 + vec2(TIME * 0.02, 0.0)));
	float shade = clamp(canopy * (0.55 + dapple * 0.45) + drift * 0.16 + dapple * 0.12, 0.0, 1.0);
	// Shade goes cool (sky-lit blue-green), not just darker.
	albedo *= mix(vec3(1.0), vec3(0.5, 0.58, 0.66), shade);
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
	// Detail layer: the same materials again at ~4x frequency, as an albedo
	// modulation and a second normal layer, so close-up ground stays crisp.
	vec2 uv_det = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * w * 1.1;
	float det = dot(texture(grass_color, uv_det).rgb, vec3(0.333)) / 0.3;
	float fdet = dot(texture(forest_color, uv_det * 0.9).rgb, vec3(0.333)) / 0.32;
	float ddet = dot(texture(dirt_color, uv_det * 0.8).rgb, vec3(0.333)) / 0.4;
	albedo *= clamp(det * bw.x + fdet * bw.y + ddet * bw.z, 0.6, 1.4) * 0.25 + 0.75;
	vec3 base_n = (g_n * bw.x + f_n * bw.y + d_n * bw.z) * 2.0 - 1.0;
	vec3 det_n = (texture(grass_normal, uv_det).rgb * bw.x + texture(forest_normal, uv_det * 0.9).rgb * bw.y + texture(dirt_normal, uv_det * 0.8).rgb * bw.z) * 2.0 - 1.0;
	vec3 nn = normalize(vec3(base_n.xy + det_n.xy * 0.5, base_n.z * det_n.z));
	ALBEDO = albedo;
	EMISSION = glow;
	NORMAL_MAP = nn * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.4;
	ROUGHNESS = clamp(g_d.x * bw.x + f_d.x * bw.y + d_d.x * bw.z, 0.55, 1.0);
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
