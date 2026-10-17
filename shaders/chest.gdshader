shader_type spatial;
render_mode cull_disabled;
// Restyles the CC0 Kenney chest: its flat colour atlas only says which faces
// are boards (orange) and which are bands (blue-grey). Boards become oiled
// planks, bands forged metal, both sampled in object space so the low-poly
// model reads like a hand-built strongbox.

uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D wood_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D wood_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D wood_rgh : hint_roughness_r, repeat_enable, filter_linear_mipmap;
uniform sampler2D metal_nrm : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D metal_rgh : hint_roughness_r, repeat_enable, filter_linear_mipmap;
uniform vec3 wood_tint : source_color = vec3(0.62, 0.42, 0.3);
uniform vec3 band_col : source_color = vec3(0.22, 0.21, 0.2);
uniform float band_metal = 0.85;
uniform float band_rough = 0.5;
uniform vec3 glow_col : source_color = vec3(0.0);
uniform float flash = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xy) * w.z + texture(t, p.xz) * w.y;
}

void fragment() {
	vec3 a = texture(atlas, UV).rgb;
	float wood = step(a.b + 0.2, a.r);
	vec3 w = pow(abs(ln), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// Planks run along the chest's width.
	vec3 p = lp * vec3(0.38, 0.9, 0.9);
	vec3 wc = tri(wood_tex, p, w).rgb;
	float wr = tri(wood_rgh, p, w).r;
	vec3 wn = tri(wood_nrm, p, w).rgb;
	vec3 mp = lp * 3.0;
	float mr = tri(metal_rgh, mp, w).r;
	vec3 mn = tri(metal_nrm, mp, w).rgb;
	// Darken worn edges of the bands, brighten the tops.
	float top = clamp(ln.y, 0.0, 1.0);
	vec3 band = band_col * (0.8 + 0.35 * top) * (0.7 + 0.6 * mr);
	ALBEDO = mix(band, wc * wood_tint * 1.6, wood);
	METALLIC = mix(band_metal, 0.0, wood);
	ROUGHNESS = mix(band_rough * (0.7 + 0.6 * mr), 0.55 + 0.35 * wr, wood);
	NORMAL_MAP = mix(mn, wn, wood);
	NORMAL_MAP_DEPTH = mix(1.6, 1.6, wood);
	SPECULAR = 0.5;
	EMISSION = glow_col + vec3(1.0, 0.75, 0.4) * flash * 0.1;
}
