shader_type spatial;

// One baked blend of grass, dirt, and rock (ambientCG, CC0). The vertex
// height follows that same mix so the ground is not a flat card.

uniform sampler2D albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(7.0, 10.0);
uniform float height_scale = 0.45;
uniform vec3 tint = vec3(1.0);

void vertex() {
	vec2 uv = UV * uv_scale;
	float h = texture(height_tex, uv).r;
	VERTEX.y += h * height_scale;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	ALBEDO = texture(albedo, uv).rgb * tint;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = texture(rough_tex, uv).r;
	METALLIC = 0.0;
}
