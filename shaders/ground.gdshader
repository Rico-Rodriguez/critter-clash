shader_type spatial;
render_mode cull_back, specular_disabled, diffuse_lambert;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = COLOR.rgb;
	vec2 cell = floor(wpos.xz * 7.5);
	float n = hash(cell);
	float fine = hash(floor(wpos.xz * 22.0));
	float blades = smoothstep(0.62, 0.95, n) * smoothstep(0.2, 0.8, fine);
	col = mix(col * 0.82, col * vec3(0.75, 1.18, 0.62), blades * 0.55);
	float grit = (fine - 0.5) * 0.08;
	col += grit;
	float heat = clamp(COLOR.a, 0.0, 1.0);
	float crack = smoothstep(0.35, 0.85, heat);
	col = mix(col, vec3(0.22, 0.08, 0.05), crack * 0.35);
	ALBEDO = col;
	EMISSION = vec3(1.0, 0.28, 0.04) * crack * 2.8 + vec3(1.0, 0.72, 0.2) * crack * crack * 1.6;
	ROUGHNESS = mix(0.92, 0.55, crack);
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = smoothstep(0.05, 0.28, ndotl);
	band = mix(0.32, 1.0, band);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
}
