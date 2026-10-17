shader_type spatial;
render_mode cull_back, specular_disabled, diffuse_lambert;

void fragment() {
	ALBEDO = COLOR.rgb;
	float heat = clamp(COLOR.a, 0.0, 1.0);
	EMISSION = vec3(1.0, 0.38, 0.06) * heat * 1.7;
	ROUGHNESS = 0.94;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = floor(ndotl * 3.0) / 2.0;
	band = mix(0.5, 1.0, band);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
}
