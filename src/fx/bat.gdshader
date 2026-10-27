shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Bats circling high over the graveyard, all on the GPU: each instance sits at
// the centre of its loop (transform), custom = (phase, speed, loop radius).
// No CPU per frame; the wings flap in the vertex stage.

uniform vec4 tint : source_color = vec4(0.06, 0.045, 0.085, 1.0);

void vertex() {
	vec3 c = INSTANCE_CUSTOM.xyz;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float t = TIME * c.y + c.x;
	vec2 o = vec2(cos(t), sin(t) * 0.65) * c.z;
	vec2 d = vec2(-sin(t), cos(t) * 0.65);
	float yaw = atan(d.x, d.y);
	float flap = sin(TIME * 15.0 + c.x * 3.0);
	vec3 v = VERTEX;
	v.y += flap * abs(v.x) * 0.9;
	float cy = cos(yaw);
	float sy = sin(yaw);
	vec3 r = vec3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy) * s;
	vec3 world = origin + vec3(o.x, sin(t * 1.7) * 0.6, o.y) + r;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	ALBEDO = tint.rgb;
}
