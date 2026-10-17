shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// One shared material per minion model. It folds what used to be three
// separate draws per surface into one: the painted PBR body, the rim light,
// and the dark ink silhouette (a fresnel edge instead of an inverted-hull
// second pass). Per-critter state (hit flash) rides on instance uniforms,
// so every minion of a model shares this material.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
// The owl's parts are merged into one mesh; their flat colours live in COLOR.
uniform bool use_vcol = false;
uniform sampler2D grain_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grain_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_grain = true;
uniform float grain_scale = 5.0;
uniform float roughness = 0.6;
uniform float specular = 0.45;
uniform float rim = 0.55;
uniform float rim_tint = 0.35;
uniform float sss = 0.0;
uniform float clearcoat = 0.0;
uniform vec4 ink_color : source_color = vec4(0.23, 0.04, 0.03, 1.0);
uniform float ink = 0.95;
uniform float ink_edge = 0.56;

instance uniform float flash = 0.0;

varying vec3 tri_pos;
varying vec3 tri_w;

void vertex() {
	tri_pos = VERTEX * grain_scale;
	vec3 w = pow(abs(NORMAL), vec3(4.0));
	tri_w = w / max(w.x + w.y + w.z, 0.0001);
}

vec4 triplanar(sampler2D tex) {
	return texture(tex, tri_pos.zy) * tri_w.x + texture(tex, tri_pos.xz) * tri_w.y + texture(tex, tri_pos.xy) * tri_w.z;
}

void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vcol) {
		c.rgb *= COLOR.rgb;
	}
	if (use_grain) {
		c.rgb *= triplanar(grain_tex).rgb;
		NORMAL_MAP = triplanar(grain_nrm).rgb;
		NORMAL_MAP_DEPTH = 0.6;
	}
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = smoothstep(ink_edge, ink_edge + 0.22, f) * ink;
	ALBEDO = mix(c.rgb, ink_color.rgb, edge);
	ROUGHNESS = mix(roughness, 1.0, edge);
	SPECULAR = specular * (1.0 - edge);
	RIM = rim * (1.0 - edge);
	RIM_TINT = rim_tint;
	if (sss > 0.0) {
		SSS_STRENGTH = sss;
	}
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.35;
	EMISSION = vec3(1.0, 0.6, 0.4) * flash;
}
