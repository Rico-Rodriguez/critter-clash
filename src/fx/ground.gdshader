shader_type spatial;
// The barrow ground: mossy grass broken by trodden dirt, darker toward the
// edge of the clearing so the playfield is lit and the outside sinks to black.
render_mode diffuse_burley, specular_disabled;

uniform sampler2D noise_a : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_b : filter_linear_mipmap, repeat_enable;
uniform vec4 grass_a : source_color = vec4(0.13, 0.19, 0.12, 1.0);
uniform vec4 grass_b : source_color = vec4(0.20, 0.27, 0.15, 1.0);
uniform vec4 dirt : source_color = vec4(0.25, 0.20, 0.15, 1.0);
uniform vec4 dark : source_color = vec4(0.02, 0.025, 0.03, 1.0);
uniform vec4 bounds = vec4(-22.0, -30.0, 22.0, 22.0); // min x, min z, max x, max z
uniform float edge_fade = 7.0;
uniform sampler2D path_mask : filter_linear, repeat_disable;
uniform vec4 path_rect = vec4(-30.0, -38.0, 60.0, 68.0); // x, z, w, h of the mask

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_a, p * 0.045).r;
	float n2 = texture(noise_b, p * 0.21).r;
	float n3 = texture(noise_b, p * 0.9).r;
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.35, 0.75, n1));
	g *= 0.85 + 0.3 * n3;
	vec2 muv = (p - path_rect.xy) / path_rect.zw;
	float path = texture(path_mask, muv).r;
	float d = smoothstep(0.45, 0.65, path + (n2 - 0.5) * 0.35);
	d = max(d, smoothstep(0.78, 0.92, n2 * 0.6 + n1 * 0.5));
	vec3 col = mix(g, dirt.rgb * (0.8 + 0.4 * n3), d);
	// Outside the clearing the ground falls into darkness.
	float ex = max(bounds.x - p.x, p.x - bounds.z);
	float ez = max(bounds.y - p.y, p.y - bounds.w);
	float out_d = max(max(ex, ez), 0.0);
	col = mix(col, dark.rgb, smoothstep(0.0, edge_fade, out_d));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	NORMAL_MAP = vec3(0.5 + (n3 - 0.5) * 0.25, 0.5 + (n2 - 0.5) * 0.25, 1.0);
}
