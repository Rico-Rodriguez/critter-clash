shader_type spatial;
render_mode cull_disabled;

// Fine grass cards. Black texels are the card background, not leaves.
// Blades shrink away around the hero and sway from the tip.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 hero = vec3(0.0);
uniform float clear_radius = 1.45;
uniform float fade_radius = 2.35;

varying vec3 world_pos;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(origin.xz, hero.xz);
	float keep = smoothstep(clear_radius, fade_radius, dist);
	float height = clamp(VERTEX.y, 0.0, 1.4);
	float sway = sin(TIME * 1.7 + origin.x * 0.9 + origin.z * 0.55) * 0.2 * height;
	float sway_z = cos(TIME * 1.25 + origin.z * 0.8) * 0.11 * height;
	vec3 blown = VERTEX;
	blown.x += sway;
	blown.z += sway_z;
	vec3 v = mix(vec3(0.0, VERTEX.y * 0.04, 0.0), blown, keep);
	world_pos = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	VERTEX = v;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	float luma = max(tex.r, max(tex.g, tex.b));
	if (luma < 0.12) {
		discard;
	}
	float blade = fract(sin(dot(floor(world_pos.xz * 0.55), vec2(127.1, 311.7))) * 43758.5453);
	float patch = fract(sin(dot(floor(world_pos.xz * 0.11), vec2(19.1, 73.4))) * 23421.63);
	vec3 vary = mix(vec3(0.58, 0.92, 0.46), vec3(1.05, 0.88, 0.5), blade);
	vary *= mix(0.84, 1.14, patch);
	ALBEDO = tex.rgb * vary;
	ROUGHNESS = 0.88;
}
