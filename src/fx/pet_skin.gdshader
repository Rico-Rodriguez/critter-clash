shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// A pet's coat and mutation, painted into the artist's own PBR (core/pet_skin.gd
// builds one material per source material and variant, filling these uniforms
// from the original StandardMaterial3D). With mutation 0, pattern 0 and no glow
// this is the same surface as the original. Marks are hard-edged (fwidth
// anti-aliased) and live in UV space so they stay glued to the body while it
// animates. No tint over the whole body: every effect is a masked overlay.

// --- the source material, unchanged -------------------------------------------
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform sampler2D tex_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_metal : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 rough_ch = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 metal_ch = vec4(1.0, 0.0, 0.0, 0.0);
uniform sampler2D tex_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 0.0;
uniform sampler2D tex_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 ao_ch = vec4(1.0, 0.0, 0.0, 0.0);
uniform float ao_on = 0.0;
uniform float ao_light = 0.0;
uniform float emit_on = 0.0;
uniform vec4 emit_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emit_energy = 1.0;
uniform float emit_mul = 0.0; // 1 = emission_operator MULTIPLY, 0 = ADD
uniform sampler2D tex_emit : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float alpha_on = 0.0;
uniform float scissor = 0.5;

// --- the variant ---------------------------------------------------------------
// mutation: 0 none, 1 gilded, 2 frostborn, 3 stormtouched, 4 voidborn, 5 emberheart, 6 verdant
// pattern: 0 plain, 1 spots, 2 stripes
uniform int mutation = 0;
uniform int pattern = 0;
uniform float glow_on = 0.0;
uniform vec3 mut_color : source_color = vec3(1.0);
uniform float pat_scale = 16.0;
instance uniform vec3 accent : source_color = vec3(1.0, 0.8, 0.3);

varying vec3 wnorm;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 5.3) * 0.3 + vnoise(p * 4.3 + 11.7) * 0.15;
}

// x: distance to the nearest cell point, y: gap to the second nearest (0 on a
// cell border, so a thin band of it is a crack), z: the cell's own random id.
vec3 voro(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 cid = ip;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + h22(ip + g) - fp;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				cid = ip + g;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec3(sqrt(f1), sqrt(f2) - sqrt(f1), h21(cid + 3.7));
}

// 1 where v < edge, with a one-pixel soft edge.
float cut(float v, float edge) {
	float aa = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(edge - aa, edge + aa, v);
}

void vertex() {
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	vec4 a = texture(tex_albedo, uv) * albedo;
	vec3 alb = a.rgb;
	float rough = roughness * dot(texture(tex_rough, uv), rough_ch);
	float met = metallic * dot(texture(tex_metal, uv), metal_ch);
	vec3 emi = vec3(0.0);
	if (emit_on > 0.5) {
		vec3 et = texture(tex_emit, uv).rgb;
		emi = (emit_mul > 0.5 ? emit_col.rgb * et : emit_col.rgb + et) * emit_energy;
	}
	vec2 p = uv * pat_scale;
	float up = clamp(wnorm.y, 0.0, 1.0);

	// --- coat ---
	if (pattern == 1) {
		vec3 v = voro(p * 0.8);
		float on = step(v.z, 0.62);
		float rad = 0.2 + 0.14 * h21(vec2(v.z * 91.0, 4.0));
		float dot_m = on * cut(v.x, rad);
		float ring = on * cut(v.x, rad + 0.07) * (1.0 - dot_m);
		alb = mix(alb, accent * 0.28, ring);
		alb = mix(alb, accent, dot_m);
	} else if (pattern == 2) {
		vec2 q = p * 0.5;
		float w = q.x + 0.9 * sin(q.y * 0.9 + sin(q.x * 0.6) * 2.0) + 0.7 * voro(q * 0.45).x;
		float band = abs(fract(w) - 0.5) * 2.0;
		float broke = step(0.18, vnoise(q * 0.8 + 9.0));
		float st = broke * cut(band, 0.34);
		float edge = broke * cut(band, 0.46) * (1.0 - st);
		alb = mix(alb, accent * 0.25, edge);
		alb = mix(alb, accent, st);
	}
	if (glow_on > 0.5) {
		vec3 v = voro(p * 1.25 + 7.0);
		float fk = step(v.z, 0.42) * cut(v.x, 0.15);
		alb = mix(alb, accent * 0.5, fk);
		emi += accent * 2.2 * fk;
		float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
		emi += accent * rim * 0.7;
	}

	// --- mutation ---
	if (mutation == 1) {
		// Gilded: beaten gold plates with dark seams.
		vec3 v = voro(p * 0.5);
		float on = step(v.z, 0.5) * (1.0 - cut(v.y, 0.035));
		float bevel = smoothstep(0.0, 0.16, v.y);
		vec3 gold = mut_color * (0.78 + 0.22 * h21(vec2(v.z * 57.0, 1.0))) * mix(0.45, 1.15, bevel);
		alb = mix(alb, gold, on);
		met = mix(met, 0.9, on);
		rough = mix(rough, 0.3, on);
	} else if (mutation == 2) {
		// Frostborn: rime crystals crusting the upward-facing surfaces.
		vec3 v = voro(p * 1.5);
		float cover = 0.12 + 1.05 * up + 0.25 * (vnoise(p * 0.4) - 0.5);
		float on = step(v.z, cover) * cut(v.x, 0.5);
		vec3 ice = mix(mut_color * 0.8, vec3(1.0), 0.3 + 0.6 * h21(vec2(v.z * 31.0, 2.0)));
		float edge = step(v.z, cover) * cut(v.x, 0.62) * (1.0 - on);
		alb = mix(alb, mut_color * 0.3, edge);
		alb = mix(alb, ice, on);
		met = mix(met, 0.0, on);
		rough = mix(rough, 0.22, on);
	} else if (mutation == 3) {
		// Stormtouched: thin white-blue arcs of lightning that glow.
		vec2 q = p * 1.0;
		q += 0.45 * vec2(sin(q.y * 2.7), sin(q.x * 3.1));
		vec3 v = voro(q);
		float reach = step(0.42, vnoise(p * 0.3 + 2.0));
		float core = reach * cut(v.y, 0.03);
		float arc = reach * cut(v.y, 0.075);
		float halo = reach * cut(v.y, 0.2);
		alb *= 1.0 - 0.45 * halo * (1.0 - arc);
		alb = mix(alb, mut_color, arc);
		emi += mut_color * 3.0 * arc + vec3(1.0) * 3.0 * core;
	} else if (mutation == 4) {
		// Voidborn: obsidian blots, violet-lit at the edge, with a few stars.
		float n = fbm(p * 0.33 + 1.7) + 0.1 * (vnoise(p * 5.0) - 0.5);
		float aa = max(fwidth(n), 1e-4);
		float bl = smoothstep(0.55 - aa, 0.55 + aa, n);
		float inner = smoothstep(0.6 - aa, 0.6 + aa, n);
		float rimm = bl * (1.0 - inner);
		alb = mix(alb, vec3(0.025, 0.015, 0.045), bl);
		met = mix(met, 0.35, bl);
		rough = mix(rough, 0.14, bl);
		emi += mut_color * 2.2 * rimm;
		vec3 v = voro(p * 3.0 + 4.0);
		float star = bl * inner * step(v.z, 0.16) * cut(v.x, 0.12);
		emi += mix(mut_color, vec3(1.0), 0.6) * 2.5 * star;
	} else if (mutation == 5) {
		// Emberheart: charred skin split by molten cracks.
		vec3 v = voro(p * 0.65);
		float reach = step(0.28, vnoise(p * 0.22 + 6.0));
		float crack = reach * cut(v.y, 0.075);
		float core = reach * cut(v.y, 0.03);
		float char_m = reach * cut(v.y, 0.24);
		alb = mix(alb, alb * 0.22, char_m * (1.0 - crack));
		alb = mix(alb, vec3(0.05, 0.02, 0.01), crack);
		rough = mix(rough, 0.95, char_m);
		emi += mix(mut_color, vec3(1.0, 0.85, 0.35), core) * 2.6 * crack;
	} else if (mutation == 6) {
		// Verdant: moss and leaf freckles growing up from the ground.
		float n = fbm(p * 0.45 + 3.1) + 0.2 * (up - 0.4) + 0.14 * (vnoise(p * 6.0) - 0.5);
		float thr = 0.58;
		float aa = max(fwidth(n), 1e-4);
		float ms = smoothstep(thr - aa, thr + aa, n);
		vec3 moss = mix(vec3(0.07, 0.2, 0.045), mut_color * 0.55, vnoise(p * 5.0));
		vec3 v = voro(p * 2.6);
		float leaf = ms * step(v.z, 0.45) * cut(v.x, 0.3);
		moss = mix(moss, mut_color, leaf * 0.9);
		alb = mix(alb, moss, ms);
		met = mix(met, 0.0, ms);
		rough = mix(rough, 1.0, ms);
	}

	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	METALLIC = clamp(met, 0.0, 1.0);
	SPECULAR = specular;
	if (normal_scale > 0.0) {
		NORMAL_MAP = texture(tex_normal, uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	if (ao_on > 0.5) {
		AO = dot(texture(tex_ao, uv), ao_ch);
		AO_LIGHT_AFFECT = ao_light;
	}
	EMISSION = emi;
	if (alpha_on > 0.5) {
		ALPHA = a.a;
		ALPHA_SCISSOR_THRESHOLD = scissor;
	}
}
