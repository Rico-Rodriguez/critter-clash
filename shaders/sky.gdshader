shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, ambient_light_disabled;

varying float height_k;

uniform vec4 zenith : source_color = vec4(0.55, 0.74, 0.95, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.78, 0.58, 1.0);
uniform vec4 haze : source_color = vec4(0.96, 0.70, 0.55, 1.0);

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height_k = clamp(w.y / 28.0 + 0.15, 0.0, 1.0);
}

void fragment() {
	vec3 col = mix(haze.rgb, horizon.rgb, smoothstep(0.0, 0.42, height_k));
	col = mix(col, zenith.rgb, smoothstep(0.28, 0.95, height_k));
	ALBEDO = col;
}
