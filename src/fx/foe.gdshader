shader_type spatial;
// Foreign-rig foes and bosses (Quaternius, Blender kits): the model's own PBR,
// kept clean (art lock: no grime, no desaturation, no rim unless asked). It
// only adds what combat needs: the per-instance hit flash and elite tint.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform bool use_vcol = false;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform float normal_scale = 1.0;
// glTF packs roughness in G and metallic in B of one texture.
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_mr = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform sampler2D emission_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool use_emission_tex = false;
uniform float emission_energy = 1.0;
uniform vec4 rim_color : source_color = vec4(0.55, 0.68, 1.0, 1.0);
uniform float rim_strength = 0.0;

instance uniform float flash = 0.0;
instance uniform vec4 tint : source_color = vec4(0.0);

void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vcol) {
		c *= COLOR;
	}
	ALBEDO = mix(c.rgb, vec3(1.0), flash * 0.85);
	float r = roughness;
	float m = metallic;
	if (use_mr) {
		vec3 t = texture(mr_tex, UV).rgb;
		r *= t.g;
		m *= t.b;
	}
	ROUGHNESS = r;
	METALLIC = m;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	vec3 e = emission_color.rgb * emission_energy;
	if (use_emission_tex) {
		e *= texture(emission_tex, UV).rgb;
	}
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	e += rim_color.rgb * fr * rim_strength;
	e += tint.rgb * tint.a * (0.06 + fr * 1.4);
	e += vec3(1.0, 0.95, 0.9) * flash * 1.6;
	EMISSION = e;
}
