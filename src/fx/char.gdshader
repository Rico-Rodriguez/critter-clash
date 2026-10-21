shader_type spatial;
// Characters: the KayKit texture with a moonlit rim, a hit flash and an elite
// tint. Flash/tint are per-instance so every skeleton shares one material.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 rim_color : source_color = vec4(0.55, 0.68, 1.0, 1.0);
uniform float rim_strength = 0.5;
uniform float roughness = 0.78;
uniform vec4 eye_glow : source_color = vec4(0.0);

instance uniform float flash = 0.0;
instance uniform vec4 tint : source_color = vec4(0.0);

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(c, vec3(1.0), flash * 0.85);
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 e = rim_color.rgb * fr * rim_strength;
	e += tint.rgb * tint.a * (0.25 + fr * 2.2);
	e += vec3(1.0, 0.95, 0.9) * flash * 1.6;
	// KayKit skeleton eyes are the brightest warm texels: let them glow.
	float hot = smoothstep(0.82, 0.95, c.r) * smoothstep(0.55, 0.75, c.g) * (1.0 - smoothstep(0.35, 0.6, c.b));
	e += eye_glow.rgb * eye_glow.a * hot * 4.0;
	EMISSION = e;
}
