shader_type spatial;
// Enemy attack warnings drawn on the ground. shape 0 = circle, 1 = cone
// (half angle in `cone`, facing +Y of the quad), 2 = rectangle (a lane).
// The fill grows from the center with `progress`; when it reaches the rim
// the attack lands. Read at a glance: outline = where, fill = when.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.18, 0.1, 1.0);
instance uniform float progress = 0.0;
instance uniform float shape = 0.0;
instance uniform float cone = 0.6;
instance uniform float fade = 1.0;

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0; // -1..1
	float r;
	float inside;
	float rim;
	if (shape < 0.5) {
		r = length(q);
		inside = 1.0 - smoothstep(0.97, 1.0, r);
		rim = smoothstep(0.9, 0.96, r) * inside;
	} else if (shape < 1.5) {
		vec2 f = vec2(q.x, -q.y);
		r = length(f);
		float ang = abs(atan(f.x, f.y));
		float in_ang = 1.0 - smoothstep(cone - 0.02, cone, ang);
		inside = (1.0 - smoothstep(0.97, 1.0, r)) * in_ang;
		rim = max(smoothstep(0.9, 0.96, r), smoothstep(cone - 0.08, cone - 0.02, ang)) * inside;
	} else {
		r = 1.0 - (q.y * 0.5 + 0.5); // fill runs along the lane
		inside = (1.0 - smoothstep(0.92, 1.0, abs(q.x))) * (1.0 - smoothstep(0.98, 1.0, abs(q.y)));
		rim = smoothstep(0.78, 0.9, abs(q.x)) * inside;
	}
	float filled = (1.0 - smoothstep(progress - 0.02, progress, r)) * inside;
	float a = inside * 0.16 + rim * 0.75 + filled * 0.42;
	ALBEDO = color.rgb * (1.0 + filled * 0.6);
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
