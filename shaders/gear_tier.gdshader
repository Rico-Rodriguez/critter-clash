shader_type spatial;
render_mode cull_disabled;
// Tiered armour and weapon look over a licensed PBR set (Gear3D).
// Metal is found from the source metallic map, so leather, cloth and wood
// keep their own colour while the plates go dented iron -> blackened steel
// -> rune-etched cursed plate. Runes live in UV space so they ride skinning.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 metal_ch = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 rough_ch = vec4(0.0, 1.0, 0.0, 0.0);
uniform float has_normal = 1.0;
uniform float normal_scale = 1.2;
uniform vec3 base_color = vec3(1.0);
uniform vec3 metal_tint = vec3(0.85);
uniform vec3 soft_tint = vec3(1.0);
uniform float metal_floor = 0.0;
uniform float metal_gain = 1.0;
uniform float rough_mul = 1.0;
uniform float rough_add = 0.0;
uniform float wear = 0.3;
uniform float rune = 0.0;
uniform vec3 rune_color : source_color = vec3(1.0, 0.3, 0.08);
uniform float rune_scale = 64.0;
uniform float rim_amount = 0.35;
uniform vec3 edge_glow : source_color = vec3(0.0);
// Plate seams, engraving and rivets are read from the normal map so every
// tier effect follows the real panel lines instead of noise.
uniform float groove = 0.0;     // darken seams (T1: rivets and panel lines pop)
uniform float edge_hi = 0.0;    // brighten seam bevels (T2: sharp edge highlights)
uniform float seam_glow = 0.0;  // emissive rune seams (T3)
uniform float blade_glow = 0.0; // emissive weapon edge (T3 main hand)
uniform float flesh = 0.0;      // hide/skin heroes: seams follow sinew, not metal
uniform vec3 cool_rim : source_color = vec3(0.0); // hunt readability rim

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
// Angular glyphs: each cell draws 2-4 strokes picked from its hash.
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

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * base_color;
	float metal = clamp(dot(texture(metal_tex, UV), metal_ch) + metal_floor, 0.0, 1.0);
	float rough = dot(texture(rough_tex, UV), rough_ch);
	float m = smoothstep(0.3, 0.65, metal);
	vec3 col = mix(base * soft_tint, base * metal_tint, m);
	// Wear: dents (soft dark blotches), scratches (bright streaks on metal),
	// grime and rust in the low spots of leather and iron.
	float dent = smoothstep(0.55, 0.85, vnoise(UV * 38.0));
	float scratch = smoothstep(0.9, 0.98, vnoise(vec2(UV.x * 260.0, UV.y * 18.0) + vnoise(UV * 9.0) * 4.0));
	float grime = vnoise(UV * 11.0);
	col *= 1.0 - wear * 0.28 * dent;
	col = mix(col, col + vec3(0.18) * m, wear * scratch);
	col = mix(col, col * vec3(0.72, 0.5, 0.36), wear * 0.45 * smoothstep(0.55, 0.9, grime));
	// Coarse mip: chainmail and fine weave average out, plate seams survive.
	vec3 nm = textureLod(normal_tex, UV, 1.6).rgb * 2.0 - 1.0;
	vec3 nf = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	float dev = has_normal > 0.5 ? length(nm.xy) : 0.0;
	vec3 nc = textureLod(normal_tex, UV, 4.0).rgb * 2.0 - 1.0;
	float broad = smoothstep(0.05, 0.14, length(nc.xy));
	// Painted bevels: albedo brighter than its blurred surroundings.
	vec3 ab = texture(albedo_tex, UV).rgb;
	vec3 ablur = textureLod(albedo_tex, UV, 3.0).rgb;
	float hp = dot(ab - ablur, vec3(0.333));
	float bevel = smoothstep(0.04, 0.11, hp);
	float seam = max(smoothstep(0.24, 0.48, dev) * (has_normal > 0.5 ? broad : 0.0), bevel * broad_or(has_normal, broad));
	float fine = has_normal > 0.5 ? smoothstep(0.25, 0.5, length(nf.xy)) : 0.0;
	float vfres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float mm = max(m, flesh);
	col *= 1.0 - groove * max(seam, fine * 0.6) * mm;
	col += edge_hi * (seam * 0.8 + fine * 0.25 + vfres * 0.35) * m * vec3(0.55, 0.57, 0.62);
	ALBEDO = col;
	METALLIC = clamp(metal * metal_gain, 0.0, 1.0);
	ROUGHNESS = clamp(rough * rough_mul + rough_add + wear * 0.12 * dent, 0.05, 1.0);
	if (has_normal > 0.5) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	float r = rune * glyphs(UV) * m;
	// One slow breath for the whole suit plus a soft wave running up the seams.
	float pulse = 0.62 + 0.38 * sin(TIME * 2.4) * 0.6 + 0.4 * sin(TIME * 3.1 - UV.y * 6.0) * 0.38;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float fres2 = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	EMISSION = rune_color * (r * 2.4 + seam_glow * seam * mm * 7.0) * pulse + edge_glow * fres
		+ rune_color * blade_glow * fres2 * (0.8 + 0.2 * sin(TIME * 4.0)) + mix(cool_rim, rune_color * 0.22 * pulse, step(0.01, seam_glow)) * fres;
	RIM = rim_amount;
	RIM_TINT = 0.35;
}
