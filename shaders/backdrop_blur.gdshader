shader_type canvas_item;

// Home pedestal backdrop: a disc blur that grows toward the top of the frame
// (the far glade) and stays light near the plinth, then darkens it. `mask`
// is a silhouette render of the hero alone; inside it the frame stays sharp
// and undimmed, so the hero pops off a defocused, darker glade.
uniform sampler2D mask : filter_linear;
uniform float max_radius = 7.0;
uniform float min_radius = 1.4;
uniform float darken = 0.76;

void fragment() {
	float r = mix(max_radius, min_radius, smoothstep(0.25, 0.8, UV.y));
	vec2 px = TEXTURE_PIXEL_SIZE * r;
	vec4 acc = texture(TEXTURE, UV) * 0.16;
	float wsum = 0.16;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;
		vec2 d = vec2(cos(a), sin(a));
		acc += texture(TEXTURE, UV + d * px) * 0.07;
		acc += texture(TEXTURE, UV + d * px * 0.5 + vec2(-d.y, d.x) * px * 0.2) * 0.07;
		wsum += 0.14;
	}
	vec3 soft = acc.rgb / wsum * darken;
	vec3 sharp = texture(TEXTURE, UV).rgb;
	float m = smoothstep(0.1, 0.9, texture(mask, UV).a);
	COLOR = vec4(mix(soft, sharp, m), 1.0);
}
