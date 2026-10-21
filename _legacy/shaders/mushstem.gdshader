shader_type spatial;
// Giant-mushroom stem: pale lilac with vertical fibres, darkening into the
// soil, glowing faintly just below the gills.

uniform vec3 stem_col : source_color = vec3(0.46, 0.38, 0.5);
uniform vec3 glow_col : source_color = vec3(0.35, 0.95, 0.85);
uniform float height = 0.55;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float h = clamp(lp.y / height, 0.0, 1.0);
	float fib = 0.5 + 0.5 * sin(atan(lp.z, lp.x) * 22.0 + sin(lp.y * 40.0) * 0.6);
	vec3 c = stem_col * (0.8 + 0.25 * fib);
	c *= mix(0.35, 1.0, smoothstep(0.0, 0.35, h));
	ALBEDO = c;
	ROUGHNESS = 0.8;
	SSS_STRENGTH = 0.25;
	EMISSION = glow_col * smoothstep(0.75, 1.0, h) * 0.35;
}
