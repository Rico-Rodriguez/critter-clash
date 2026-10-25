shader_type spatial;
// The same toon bands for single meshes (projectile heads, the Hellfire
// Wisp, spinning blades, meteors, souls): per-instance core/body/rim colours.
// `wobble` > 0 makes a ball churn (fire cores), all hard-edged.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;
instance uniform vec4 core : source_color = vec4(1.0, 0.97, 0.75, 1.0);
instance uniform vec4 body : source_color = vec4(1.0, 0.62, 0.12, 1.0);
instance uniform vec4 rim : source_color = vec4(0.85, 0.2, 0.06, 1.0);
instance uniform float wobble = 0.0;

void vertex() {
	if (wobble > 0.0) {
		float w = sin(VERTEX.y * 9.0 + TIME * 14.0) * cos(VERTEX.x * 7.0 - TIME * 11.0);
		VERTEX += NORMAL * w * wobble;
	}
}

void fragment() {
	vec3 key = normalize(vec3(-0.35, 0.5, 1.0));
	float f = dot(NORMAL, key);
	ALBEDO = f > 0.72 ? core.rgb : (f > 0.25 ? body.rgb : rim.rgb);
}
