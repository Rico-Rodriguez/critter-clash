shader_type spatial;
render_mode cull_back, specular_disabled, diffuse_lambert;

varying float vert_h;
varying vec3 world_pos;

uniform int shade_mode = 0;
uniform vec4 team_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.93, 0.82, 1.0);
uniform float rim_strength = 0.55;
uniform float flash = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.28, 1.0);
uniform float glow_energy = 2.4;
uniform float wind = 0.0;
uniform float alpha_mul = 1.0;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = w;
	vert_h = clamp(VERTEX.y, 0.0, 3.0);
	if (wind > 0.001) {
		float sway = sin(TIME * 1.35 + w.x * 0.55 + w.z * 0.37) * wind * vert_h;
		VERTEX.x += sway;
		VERTEX.z += cos(TIME * 1.05 + w.z * 0.45) * wind * vert_h * 0.35;
	}
}

void fragment() {
	vec3 col = COLOR.rgb;
	if (shade_mode == 1) {
		col = vec3(0.99, 0.97, 0.94);
	} else if (shade_mode == 2) {
		col = vec3(0.11, 0.07, 0.08);
	} else if (shade_mode == 3) {
		col = vec3(1.0);
	} else if (shade_mode == 4) {
		col = glow_color.rgb;
	} else if (shade_mode == 5) {
		col = vec3(0.97, 0.98, 1.0);
	} else if (shade_mode == 6) {
		col = glow_color.rgb;
	} else {
		col = COLOR.rgb * team_tint.rgb;
	}
	col = mix(col, vec3(1.0), clamp(flash, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
	ALPHA = alpha_mul;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.8);
	if (shade_mode == 4 || shade_mode == 3) {
		EMISSION = col * (shade_mode == 3 ? 1.4 : glow_energy);
	} else if (shade_mode == 5) {
		EMISSION = col * 0.45;
	} else if (shade_mode == 6) {
		EMISSION = col * 0.15;
	} else {
		EMISSION = rim_color.rgb * rim * rim_strength;
	}
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float band = floor(ndotl * 3.0) / 2.0;
	band = mix(0.46, 1.0, band);
	if (shade_mode >= 3 && shade_mode != 6) {
		DIFFUSE_LIGHT += vec3(0.0);
	} else {
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band;
	}
}
