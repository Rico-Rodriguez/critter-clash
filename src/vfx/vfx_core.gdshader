shader_type spatial;
// Procedural element core: noise-distorted shape with a hard alpha-scissor
// dissolve and a crisp burning rim at the cut. One MultiMesh per shape (ball,
// wall), so every live core of that shape is a single draw call.
// Per instance: COLOR = element colour, CUSTOM.x = seed, CUSTOM.y = style,
// CUSTOM.z = life progress 0..1.
// Styles: 0 fire, 1 goo, 2 void, 3 light, 4 dust, 5 plasma.
// Art lock: unshaded, cut-out (no blending), no glow, no fog, no tint.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform int mode = 0;  // 0 ball, 1 wall

varying vec4 col;
varying float seed;
varying float style;
varying float prog;

void vertex() {
	col = COLOR;
	seed = INSTANCE_CUSTOM.x;
	style = INSTANCE_CUSTOM.y;
	prog = INSTANCE_CUSTOM.z;
	if (mode == 0) {
		float wob = style > 0.5 && style < 1.5 ? 0.5 : 0.3;
		float n = textureLod(noise, UV * vec2(2.0, 1.0) + vec2(seed + TIME * 0.3, -TIME * 1.1), 0.0).r;
		VERTEX += NORMAL * (n - 0.5) * wob;
	}
}

void fragment() {
	float sp = style < 0.5 ? 1.3 : (style < 1.5 ? 0.35 : (style < 2.5 ? -0.8 : (style < 3.5 ? 1.8 : (style < 4.5 ? 0.25 : 2.6))));
	vec2 sc = mode == 0 ? vec2(2.0, 1.0) : vec2(6.0, 1.0);
	if (style > 2.5 && style < 3.5) {
		sc.x *= 2.5;  // light: tall streaks
	}
	vec2 uv = UV * sc + vec2(seed, 0.0);
	float n = texture(noise, uv + vec2(0.0, TIME * sp)).r;
	float n2 = texture(noise, uv * 2.3 + vec2(TIME * 0.2, TIME * sp * 1.7)).r;
	float v = n * 0.65 + n2 * 0.35;
	if (mode == 1) {
		v = v * 1.3 - (1.0 - UV.y) * 0.9 + 0.25;  // tongues: solid base, torn top
	}
	float a = v + 0.5 - prog * prog * 1.1;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 base = col.rgb;
	vec3 hot = mix(base, vec3(1.0), 0.65);
	vec3 rim = base * 0.45;
	if (style > 1.5 && style < 2.5) {  // void: dark heart, bright edge
		hot = base * 0.1;
		base = base * 0.3;
		rim = mix(col.rgb, vec3(1.0), 0.35);
	} else if (style > 3.5 && style < 4.5) {  // dust: matte, no hot core
		hot = base * 1.1;
		rim = base * 0.6;
	}
	vec3 c = mix(base, hot, smoothstep(0.65, 0.95, a));
	c = mix(rim, c, step(0.57, a));
	ALBEDO = c;
}
