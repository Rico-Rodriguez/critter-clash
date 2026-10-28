shader_type spatial;
// The floor of a zone that has terrain cells (Rimehollow, Cinder Mire). One
// draw for the whole floor: the zone's dry ground, and on top of it whatever
// each 2 m cell says it is. Two small textures carry the cells (see
// src/hunt/terrain_view.gd):
//   lay_a  R ice (also thin ice and ice wall)  G thin ice  B open water  A bog
//   lay_b  R burning  G ash  B crack or fire warning 0..1  A ash freshness
// Edges are the cell grid pushed about with noise and then cut hard, so a
// shoreline reads crisp and is not a blurry blend. Unmodified PBR: no fog,
// no tint wash, no bloom. Ice and water get a real specular highlight.
render_mode diffuse_burley;

uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_b : filter_linear_mipmap, repeat_enable;
uniform sampler2D lay_a : filter_linear, repeat_disable;
uniform sampler2D lay_b : filter_linear, repeat_disable;
uniform vec4 cell_rect = vec4(-22.0, -31.0, 44.0, 52.0); // x, z, w, h of the cell textures
uniform vec4 base_a : source_color = vec4(0.72, 0.78, 0.86, 1.0);
uniform vec4 base_b : source_color = vec4(0.80, 0.85, 0.92, 1.0);
uniform float base_rough = 0.85;
uniform vec4 ice_a : source_color = vec4(0.66, 0.84, 0.96, 1.0);
uniform vec4 ice_b : source_color = vec4(0.82, 0.93, 1.0, 1.0);
uniform vec4 crack_col : source_color = vec4(0.30, 0.50, 0.72, 1.0);
uniform vec4 water_col : source_color = vec4(0.04, 0.22, 0.38, 1.0);
uniform vec4 water_deep : source_color = vec4(0.015, 0.09, 0.19, 1.0);
uniform vec4 bog_col : source_color = vec4(0.028, 0.024, 0.02, 1.0);
uniform vec4 ash_col : source_color = vec4(0.13, 0.12, 0.115, 1.0);
uniform vec4 ember_col : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 dark : source_color = vec4(0.02, 0.025, 0.03, 1.0);
uniform vec4 bounds = vec4(-22.0, -30.0, 22.0, 22.0); // min x, min z, max x, max z
uniform float edge_fade = 7.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cut(float v, float w) {
	return smoothstep(0.5 - w, 0.5 + w, v);
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_a, p * 0.045).r;
	float n2 = texture(noise_b, p * 0.05).r;
	float n3 = texture(noise_b, p * 0.2).r;
	float nc = texture(noise_b, p * 0.035 + vec2(0.37, 0.11)).r;
	float nd = texture(noise_b, p * 0.09 + vec2(0.71, 0.53)).r;

	vec3 col = mix(base_a.rgb, base_b.rgb, smoothstep(0.35, 0.75, n1)) * (0.88 + 0.24 * n3);
	float rough = base_rough;
	float spec = 0.3;
	vec3 emit = vec3(0.0);
	vec3 nrm = vec3(0.5 + (n3 - 0.5) * 0.25, 0.5 + (n2 - 0.5) * 0.25, 1.0);

	vec2 uv = (p - cell_rect.xy) / cell_rect.zw;
	vec4 A = texture(lay_a, uv);
	vec4 B = texture(lay_b, uv);
	float jit = (n2 - 0.5) * 0.55 + (n3 - 0.5) * 0.07;

	// Ice: clear and glossy, with long cracks where the noise crosses one value.
	float ice = cut(A.r + jit, 0.05);
	if (ice > 0.0) {
		vec3 ic = mix(ice_a.rgb, ice_b.rgb, smoothstep(0.3, 0.8, n1 + (n3 - 0.5) * 0.12));
		float ridge = 1.0 - smoothstep(0.0, 0.028, abs(nc - 0.5));
		float fine = 1.0 - smoothstep(0.0, 0.02, abs(nd - 0.5));
		ic = mix(ic, crack_col.rgb, clamp(ridge * 0.75 + fine * 0.12, 0.0, 1.0));
		col = mix(col, ic, ice);
		rough = mix(rough, 0.09 + 0.2 * ridge, ice);
		spec = mix(spec, 0.9, ice);
		nrm = mix(nrm, vec3(0.5 + (n3 - 0.5) * 0.08, 0.5 + (n2 - 0.5) * 0.08, 1.0), ice);
	}
	// Thin ice: darker, a web of cracks, and a white flicker once it is about to go.
	float thin = cut(A.g + jit, 0.05) * ice;
	if (thin > 0.0) {
		float web = 1.0 - smoothstep(0.0, 0.05, abs(nd - 0.5));
		float web2 = 1.0 - smoothstep(0.0, 0.04, abs(nc - 0.46));
		vec3 tc = mix(vec3(0.40, 0.58, 0.76), crack_col.rgb * 0.7, clamp(web + web2, 0.0, 1.0));
		float going = B.b * (0.5 + 0.5 * sin(TIME * 22.0));
		tc = mix(tc, vec3(0.95, 0.98, 1.0), going * (web + web2 * 0.5 + 0.25));
		col = mix(col, tc, thin);
	}
	// Open water: deep blue and glossy, with a slow ripple (no sky to mirror here, so its colour is its own).
	float wat = cut(A.b + jit * 0.8, 0.05);
	if (wat > 0.0) {
		float rip = texture(noise_b, p * 0.1 + vec2(TIME * 0.03, TIME * 0.02)).r;
		col = mix(col, mix(water_deep.rgb, water_col.rgb, smoothstep(0.25, 0.75, rip)), wat);
		rough = mix(rough, 0.03, wat);
		spec = mix(spec, 1.0, wat);
		nrm = mix(nrm, vec3(0.5 + (rip - 0.5) * 0.35, 0.5 + (n3 - 0.5) * 0.2, 1.0), wat);
	}
	// Bog: black tar, glossy, with lighter swirls. Burning and ash sit on top of it.
	float bog = cut(A.a + jit, 0.05);
	if (bog > 0.0) {
		float sw = smoothstep(0.35, 0.8, texture(noise_b, p * 0.06 + vec2(TIME * 0.01, 0.0)).r);
		col = mix(col, bog_col.rgb * (0.8 + 0.7 * sw), bog);
		rough = mix(rough, 0.16 + 0.25 * (1.0 - sw), bog);
		spec = mix(spec, 0.8, bog);
	}
	float ash = cut(B.g + jit * 0.8, 0.05);
	if (ash > 0.0) {
		float crk = 1.0 - smoothstep(0.0, 0.035, abs(nc - 0.5));
		col = mix(col, ash_col.rgb * (0.7 + 0.6 * n3), ash);
		rough = mix(rough, 0.95, ash);
		spec = mix(spec, 0.2, ash);
		emit += ember_col.rgb * crk * ash * B.a * (0.9 + 0.3 * sin(TIME * 3.0 + n1 * 20.0));
	}
	float burn = cut(B.r + jit * 0.8, 0.05);
	if (burn > 0.0) {
		float lava = smoothstep(0.25, 0.7, texture(noise_b, p * 0.11 + vec2(TIME * 0.05, -TIME * 0.04)).r);
		col = mix(col, vec3(0.05, 0.03, 0.025), burn);
		rough = mix(rough, 0.6, burn);
		emit += ember_col.rgb * burn * (0.35 + 1.1 * lava) * (0.85 + 0.25 * sin(TIME * 9.0 + n1 * 30.0));
	}
	// A warned cell: a pulse of orange on the bog, so the front is readable a step ahead.
	float warn = B.b * (1.0 - burn) * bog;
	emit += ember_col.rgb * warn * (0.25 + 0.3 * sin(TIME * 10.0)) * smoothstep(0.35, 0.65, n3 + 0.25);

	float ex = max(bounds.x - p.x, p.x - bounds.z);
	float ez = max(bounds.y - p.y, p.y - bounds.w);
	float out_d = max(max(ex, ez), 0.0);
	col = mix(col, dark.rgb, smoothstep(0.0, edge_fade, out_d));
	emit *= 1.0 - smoothstep(0.0, edge_fade, out_d);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emit;
	NORMAL_MAP = nrm;
}
