shader_type spatial;
render_mode cull_disabled;
// Tiered armour and weapon look over a licensed PBR set (Gear3D).
// Metal is found from the source metallic map, so leather, cloth and wood
// keep their own colour while the plates go bare (boiled leather and padded
// cloth underlayer) -> dented iron -> blackened steel -> rune plate.
// Per-slot tiers: Gear3D tags each body vertex with its gear slot (helm,
// chest, pauldrons, gloves, boots, weapon, offhand, charm) in COLOR.r, and
// slot_tier[] picks that slot's tier, so each equipped piece shows alone.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 metal_ch = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 rough_ch = vec4(0.0, 1.0, 0.0, 0.0);
uniform float has_normal = 1.0;
uniform float normal_scale = 1.2;
uniform vec3 base_color = vec3(1.0);
uniform float metal_floor = 0.0;
uniform float rune = 0.0;
uniform vec3 rune_color : source_color = vec3(1.0, 0.3, 0.08);
uniform float rune_scale = 64.0;
uniform float rim_amount = 0.35;
uniform vec3 edge_glow : source_color = vec3(0.0);
uniform float blade_glow = 0.0; // emissive weapon edge (T3 main hand)
uniform float desat = 0.0;      // restyle bright storybook textures toward grim
uniform float flesh = 0.0;      // hide/skin heroes: seams follow sinew, not metal
uniform vec3 cool_rim : source_color = vec3(0.0); // hunt readability rim
uniform float seam_gain = 1.0;  // per-kit rune seam gain (busy albedo catches more)

// Slot -> tier. use_slots 0 = whole material at fixed_tier (props).
uniform float use_slots = 0.0;
uniform int fixed_tier = 0;
uniform int slot_tier[8];

// Per-tier finish (index = tier 0..3). Set by Gear3D.finish().
uniform vec3 t_metal_tint[4];
uniform vec3 t_soft_tint[4];
uniform float t_wear[4];
uniform float t_rough_mul[4];
uniform float t_rough_add[4];
uniform float t_gain[4];
uniform float t_groove[4];     // darken seams (T1 rivets, bare stitching)
uniform float t_edge_hi[4];    // brighten seam bevels (T2)
uniform vec3 t_edge_col[4];
uniform float t_edge_emit[4];  // self-lit bevel catchlight (T2)
uniform float t_metal_cap[4];
uniform float t_seam[4];       // emissive rune seams (T3)
uniform float t_leather[4];    // 1 = plate rendered as boiled leather/padding (bare)

varying flat int v_tier;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return 1.0 - smoothstep(w * 0.5, w, length(pa - ba * h));
}
float glyphs(vec2 uv) {
	vec2 g = uv * vec2(rune_scale, rune_scale * 0.6);
	vec2 c = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(c);
	if (h < 0.62) return 0.0;
	float w = 0.05;
	float v = seg(f, vec2(0.0, -0.36), vec2(0.0, 0.36), w);
	if (fract(h * 7.0) > 0.5) v = max(v, seg(f, vec2(0.0, 0.36), vec2(0.26, 0.1), w));
	if (fract(h * 13.0) > 0.45) v = max(v, seg(f, vec2(0.0, 0.0), vec2(-0.24, -0.22), w));
	if (fract(h * 29.0) > 0.6) v = max(v, seg(f, vec2(-0.2, 0.18), vec2(0.2, 0.18), w));
	if (fract(h * 41.0) > 0.7) v = max(v, seg(f, vec2(0.0, -0.1), vec2(0.24, -0.34), w));
	return v;
}

float broad_or(float hn, float b) { return hn > 0.5 ? mix(0.35, 1.0, b) : 1.0; }

void vertex() {
	if (use_slots > 0.5) {
		int s = clamp(int(COLOR.r * 7.0 + 0.5), 0, 7);
		v_tier = clamp(slot_tier[s], 0, 3);
	} else {
		v_tier = clamp(fixed_tier, 0, 3);
	}
}

void fragment() {
	int T = v_tier;
	vec3 base = texture(albedo_tex, UV).rgb * base_color;
	float metal = clamp(dot(texture(metal_tex, UV), metal_ch) + metal_floor, 0.0, 1.0);
	float rough = dot(texture(rough_tex, UV), rough_ch);
	float m = smoothstep(0.3, 0.65, metal);
	float wear = t_wear[T];
	float lth = t_leather[T];
	// Bare: the plate becomes dark boiled leather over a padded gambeson.
	// Value from the source albedo keeps the panel shapes; hue goes warm brown.
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	float grain = vnoise(UV * 420.0) * 0.6 + vnoise(UV * 90.0) * 0.4;
	vec3 leather = vec3(0.17, 0.1, 0.055) * (0.45 + 0.8 * lum) * (0.82 + 0.36 * grain) * t_metal_tint[T];
	vec3 metal_col = mix(base * t_metal_tint[T], leather, lth);
	vec3 col = mix(base * t_soft_tint[T], metal_col, m);
	float dent = smoothstep(0.55, 0.85, vnoise(UV * 38.0));
	float scratch = smoothstep(0.9, 0.98, vnoise(vec2(UV.x * 260.0, UV.y * 18.0) + vnoise(UV * 9.0) * 4.0));
	float grime = vnoise(UV * 11.0);
	col *= 1.0 - wear * 0.28 * dent;
	col = mix(col, col + vec3(0.18) * m * (1.0 - lth), wear * scratch);
	col = mix(col, col * vec3(0.72, 0.5, 0.36), wear * 0.45 * smoothstep(0.55, 0.9, grime));
	vec3 nm = textureLod(normal_tex, UV, 1.6).rgb * 2.0 - 1.0;
	vec3 nf = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	float dev = has_normal > 0.5 ? length(nm.xy) : 0.0;
	vec3 nc = textureLod(normal_tex, UV, 4.0).rgb * 2.0 - 1.0;
	float broad = smoothstep(0.05, 0.14, length(nc.xy));
	vec3 ab = texture(albedo_tex, UV).rgb;
	vec3 ablur = textureLod(albedo_tex, UV, 3.0).rgb;
	float hp = dot(ab - ablur, vec3(0.333));
	float bevel = smoothstep(0.04, 0.11, hp);
	float seam = max(smoothstep(0.24, 0.48, dev) * (has_normal > 0.5 ? broad : 0.0), bevel * broad_or(has_normal, broad));
	float fine = has_normal > 0.5 ? smoothstep(0.25, 0.5, length(nf.xy)) : 0.0;
	float vfres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))), desat);
	float mm = max(m, flesh);
	col *= 1.0 - t_groove[T] * max(seam, fine * 0.6) * mm;
	float edge_mask = (seam * 0.8 + fine * 0.25 + vfres * 0.35) * m;
	col += t_edge_hi[T] * edge_mask * t_edge_col[T];
	ALBEDO = col;
	METALLIC = min(clamp(metal * t_gain[T], 0.0, 1.0), t_metal_cap[T]);
	ROUGHNESS = clamp(rough * t_rough_mul[T] + t_rough_add[T] + wear * 0.12 * dent, 0.05, 1.0);
	// Leather and padding: a soft waxed sheen, never a white plastic gloss.
	ROUGHNESS = mix(ROUGHNESS, max(ROUGHNESS, 0.68), lth * m);
	SPECULAR = mix(0.5, 0.22, lth * m);
	if (has_normal > 0.5) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	float r = rune * glyphs(UV) * m;
	float pulse = 0.62 + 0.38 * sin(TIME * 2.4) * 0.6 + 0.4 * sin(TIME * 3.1 - UV.y * 6.0) * 0.38;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float fres2 = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float sg = t_seam[T] * seam_gain;
	EMISSION = rune_color * (r * 2.4 + sg * seam * mm * 7.0) * pulse + edge_glow * fres
		+ rune_color * blade_glow * fres2 * (0.8 + 0.2 * sin(TIME * 4.0)) + mix(cool_rim, rune_color * 0.22 * pulse, step(0.01, sg)) * fres;
	EMISSION += t_edge_col[T] * t_edge_emit[T] * (seam * 0.7 + vfres * 0.6) * m;
	RIM = rim_amount;
	RIM_TINT = 0.35;
}
