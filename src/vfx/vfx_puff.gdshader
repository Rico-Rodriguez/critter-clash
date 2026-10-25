shader_type spatial;
// Continuous fire/goo/void/dust volume pieces, drawn as camera-facing cards.
// Every instance gets its own seed. The seed sets the card's rotation, spin,
// noise offset, scroll speed and start frame, so no two pieces look alike.
// mode 0, puff: a round billboard with a noise-eroded edge. Overlapping puffs
//   build sprays and jets.
// mode 1, ribbon: a strip along the instance X axis, turned to face the
//   camera. Width comes from the Y axis length and tapers toward the tail.
//   The noise scrolls along the strip.
// Per instance: COLOR = element colour, CUSTOM.x = seed, CUSTOM.y = style,
// CUSTOM.z = life progress 0..1.
// Styles: 0 fire, 1 goo, 2 void, 3 light, 4 dust, 5 plasma.
// Art lock: unshaded, alpha-scissor cut-out, no blending, glow or fog.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform int mode = 0;

varying vec4 col;
varying float seed;
varying float style;
varying float prog;

void vertex() {
	col = COLOR;
	seed = INSTANCE_CUSTOM.x;
	style = INSTANCE_CUSTOM.y;
	prog = INSTANCE_CUSTOM.z;
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 world;
	if (mode == 0) {
		float s = length(MODEL_MATRIX[0].xyz);
		float a = seed * 2.7 + TIME * (fract(seed * 7.13) - 0.5) * 2.0;
		vec2 v = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
		world = o + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * s;
	} else {
		vec3 ax = MODEL_MATRIX[0].xyz;
		float w = length(MODEL_MATRIX[1].xyz);
		vec3 side = normalize(cross(ax, cam - o) + vec3(1e-4, 0.0, 0.0));
		float taper = mix(0.35, 1.0, VERTEX.x + 0.5);  // head (+x) full, tail thin
		world = o + ax * VERTEX.x + side * VERTEX.y * w * taper;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float sp = style < 0.5 ? 1.3 : (style < 1.5 ? 0.35 : (style < 2.5 ? -0.8 : (style < 3.5 ? 1.8 : (style < 4.5 ? 0.25 : 2.6))));
	vec2 off = vec2(fract(seed * 3.17), fract(seed * 5.71)) * 7.0;
	float a;
	if (mode == 0) {
		vec2 c = UV - 0.5;
		float d = length(c) * 2.0;
		float n = texture(noise, UV * 0.9 + off + vec2(0.0, TIME * sp * 0.6)).r;
		float n2 = texture(noise, UV * 2.1 + off.yx + vec2(TIME * 0.3, TIME * sp)).r;
		a = (1.0 - d) * 1.25 + (n * 0.6 + n2 * 0.4 - 0.5) * 0.9 + 0.3 - prog * prog * 0.95;
	} else {
		float edge = abs(UV.y - 0.5) * 2.0;
		float n = texture(noise, vec2(UV.x * 1.5 - TIME * sp * 1.6, UV.y * 0.8) + off).r;
		float n2 = texture(noise, vec2(UV.x * 3.1 - TIME * sp * 2.4, UV.y * 1.7) + off.yx).r;
		a = (1.0 - edge) * 1.1 + (n * 0.6 + n2 * 0.4 - 0.5) * 1.0 + 0.2 - prog * 0.9 - (1.0 - UV.x) * 0.25;
	}
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 base = col.rgb;
	vec3 hot = mix(base, vec3(1.0, 0.97, 0.85), 0.7);
	vec3 rim = base * 0.5;
	if (style > 1.5 && style < 2.5) {
		hot = base * 0.12;
		base = base * 0.3;
		rim = mix(col.rgb, vec3(1.0), 0.35);
	} else if (style > 3.5 && style < 4.5) {
		hot = base * 1.08;
		rim = base * 0.65;
	}
	vec3 c = mix(base, hot, smoothstep(0.75, 1.05, a));
	c = mix(rim, c, step(0.58, a));
	ALBEDO = c;
}
