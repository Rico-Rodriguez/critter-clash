shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled, diffuse_lambert;

varying vec3 wpos;

void vertex() {
	float wave = sin(VERTEX.x * 2.4 + TIME * 1.5) * cos(VERTEX.z * 1.8 + TIME * 1.15);
	VERTEX.y += wave * 0.035;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	vec3 deep = vec3(0.08, 0.32, 0.52);
	vec3 shallow = vec3(0.38, 0.72, 0.78);
	vec3 col = mix(deep, shallow, fres);
	float spark = sin(wpos.x * 5.0 + wpos.z * 4.2 + TIME * 2.1);
	ALBEDO = col;
	EMISSION = shallow * fres * 0.1 + vec3(0.45, 0.75, 0.9) * clamp(spark, 0.0, 1.0) * fres * 0.05;
	ROUGHNESS = 0.18;
	ALPHA = 0.8;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = mix(0.58, 1.0, smoothstep(0.12, 0.62, ndotl));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
}
