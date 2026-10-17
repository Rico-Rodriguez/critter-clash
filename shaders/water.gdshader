shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled, diffuse_lambert;

varying vec3 wpos;
varying float shore;

void vertex() {
	float wave = sin(VERTEX.x * 2.8 + TIME * 1.6) * cos(VERTEX.z * 2.1 + TIME * 1.25);
	VERTEX.y += wave * 0.045;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore = smoothstep(0.72, 1.55, abs(VERTEX.z));
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 deep = vec3(0.04, 0.28, 0.52);
	vec3 shallow = vec3(0.20, 0.62, 0.72);
	vec3 col = mix(deep, shallow, fres * 0.85);
	float spark = sin(wpos.x * 6.0 + TIME * 2.4) * sin(wpos.z * 5.0 - TIME * 1.7);
	float rip = sin(wpos.x * 3.2 + wpos.z * 2.4 + TIME * 1.3);
	col += vec3(0.05, 0.12, 0.14) * rip * 0.25;
	float foam_wave = 0.55 + 0.45 * sin(wpos.x * 9.0 + TIME * 2.2);
	float foam = shore * smoothstep(0.35, 0.85, foam_wave);
	col = mix(col, vec3(0.92, 0.97, 0.95), foam * 0.9);
	ALBEDO = col;
	EMISSION = vec3(0.15, 0.45, 0.55) * fres * 0.18 + vec3(0.85, 0.95, 0.9) * foam * 0.25;
	ROUGHNESS = mix(0.08, 0.45, foam);
	ALPHA = mix(0.86, 0.97, foam);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = mix(0.45, 1.0, smoothstep(0.15, 0.7, ndotl));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
}
