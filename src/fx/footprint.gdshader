shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A pooled footprint: a soft dark oval pressed into the path that fades out.
// MultiMesh colour = print colour + strength; custom.x = the time it was made.

uniform float now = 0.0;
uniform float life = 5.0;

varying float age;

void vertex() {
	age = now - INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// a boot: wide forefoot, narrower heel
	float narrow = mix(0.62, 1.0, smoothstep(-1.0, 0.6, p.y));
	float d = length(vec2(p.x / narrow, p.y * 0.92));
	float a = smoothstep(1.0, 0.7, d) * COLOR.a * (1.0 - smoothstep(life * 0.35, life, age));
	ALBEDO = COLOR.rgb;
	ALPHA = a;
}
