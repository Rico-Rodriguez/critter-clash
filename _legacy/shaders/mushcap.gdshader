shader_type spatial;
// Painted giant-mushroom cap: deep plum top darkening to the crown, pale
// freckles, a warm rim band, and glowing gills underneath radiating from the
// stem. Rim light picks out the silhouette against the dusk.

uniform vec3 top_col : source_color = vec3(0.32, 0.08, 0.2);
uniform vec3 crown_col : source_color = vec3(0.14, 0.03, 0.1);
uniform vec3 rim_col : source_color = vec3(0.75, 0.32, 0.38);
uniform vec3 gill_col : source_color = vec3(0.2, 0.1, 0.24);
uniform vec3 glow_col : source_color = vec3(0.35, 0.95, 0.85);
uniform float glow = 1.4;
uniform vec3 rim_light : source_color = vec3(0.85, 0.55, 1.0);
uniform float radius = 0.22;

varying vec3 lp;
varying vec3 ln;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	float r = length(lp.xz) / radius;
	float ang = atan(lp.z, lp.x);
	float under = smoothstep(0.0, -0.35, ln.y);
	// Top: dark crown, plum body, warm band near the rim.
	vec3 cap = mix(crown_col, top_col, smoothstep(0.0, 0.7, r));
	cap = mix(cap, rim_col, smoothstep(0.78, 1.0, r) * 0.7);
	// Freckles.
	vec2 cell = vec2(ang * 4.0, r * 7.0);
	vec2 id = floor(cell);
	vec2 f = fract(cell) - 0.5;
	float spot = step(0.62, hash(id)) * smoothstep(0.22, 0.12, length(f));
	cap = mix(cap, vec3(0.92, 0.78, 0.82), spot * 0.9 * smoothstep(0.95, 0.4, r));
	// Gills: fine radial ribs, glowing toward the stem.
	float rib = 0.5 + 0.5 * sin(ang * 70.0);
	rib = smoothstep(0.25, 0.9, rib);
	vec3 gill = mix(gill_col * 0.5, gill_col * 1.4, rib);
	float gl = smoothstep(1.0, 0.25, r) * (0.55 + 0.45 * rib);
	ALBEDO = mix(cap, gill, under);
	ROUGHNESS = mix(0.5, 0.85, under);
	SPECULAR = 0.35;
	SSS_STRENGTH = 0.3;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_col * glow * gl * under + rim_light * fres * 0.35 * (1.0 - under);
}
