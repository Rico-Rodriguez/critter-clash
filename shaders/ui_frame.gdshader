shader_type canvas_item;

// Premium UI frame: a beveled metal rim around a textured face, with a soft
// drop shadow and optional outer glow. Drawn on a plain rect; the box sits
// `margin` px inside it so the shadow and glow have room.

uniform vec2 px = vec2(200.0, 100.0);
uniform float margin = 10.0;
uniform float radius = 14.0;
// Forged look: cut corners (bevelled at 45 degrees) instead of soft rounds.
uniform float chamfer = 0.0;
uniform float frame = 7.0;
uniform vec4 face_top : source_color = vec4(0.16, 0.12, 0.09, 1.0);
uniform vec4 face_bot : source_color = vec4(0.08, 0.06, 0.05, 1.0);
uniform vec4 metal_hi : source_color = vec4(0.95, 0.80, 0.50, 1.0);
uniform vec4 metal_lo : source_color = vec4(0.36, 0.22, 0.10, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.3, 0.0);
uniform float press = 0.0;
uniform float sheen = 0.0;          // glossy enamel band (buttons)
uniform float bump_amt = 0.6;
uniform float detail_amt = 0.25;
uniform float detail_scale = 1.0;
uniform float studs = 1.0;          // corner rivets
uniform float shadow_alpha = 0.55;
uniform float time_glow = 0.0;      // animated shimmer on the rim
uniform sampler2D detail : repeat_enable, filter_linear_mipmap;
uniform sampler2D bump : repeat_enable, filter_linear_mipmap;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_box(vec2 p, vec2 b, float r) {
	if (chamfer <= 0.0) {
		return sd_round(p, b, r);
	}
	float c = min(chamfer, min(b.x, b.y));
	float d_box = sd_round(p, b, min(r, 2.0));
	float d_cut = (abs(p.x) + abs(p.y) - (b.x + b.y - c)) * 0.70710678;
	return max(d_box, d_cut);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * px;
	vec2 half_size = px * 0.5 - vec2(margin);
	vec2 c = px * 0.5;
	float rad = min(radius, min(half_size.x, half_size.y));
	float sink = press * 2.0;
	vec2 q = p - c - vec2(0.0, sink);
	float d = sd_box(q, half_size, rad);
	float aa = max(fwidth(d), 0.6);

	// Shadow and glow live outside the box.
	float sd = sd_box(p - c - vec2(0.0, 5.0 - press * 3.0), half_size, rad);
	float shadow = (1.0 - smoothstep(-2.0, margin * 0.95, sd)) * shadow_alpha * (1.0 - press * 0.5);
	float glow = (1.0 - smoothstep(0.0, margin, d)) * glow_color.a;
	vec4 outside = vec4(0.0, 0.0, 0.0, shadow);
	outside.rgb = mix(outside.rgb, glow_color.rgb, glow / max(glow + shadow, 0.001));
	outside.a = max(shadow, glow);

	// Gradient of the SDF for the bevel normal.
	vec2 e = vec2(0.5, 0.0);
	vec2 g = normalize(vec2(sd_box(q + e.xy, half_size, rad) - sd_box(q - e.xy, half_size, rad),
							sd_box(q + e.yx, half_size, rad) - sd_box(q - e.yx, half_size, rad)) + 1e-5);
	vec2 light = normalize(vec2(-0.45, -1.0));

	// Metal rim: a rounded ridge profile across the frame width.
	float t = clamp(-d / frame, 0.0, 1.0);
	float slope = cos(t * 3.14159);            // +1 outer edge, -1 inner edge
	float lit = dot(-g * slope, light) * (1.0 - press * 1.6);
	float brushed = hash(vec2(floor(p.y * 0.7), floor(p.x * 0.03))) * 0.08;
	vec3 metal = mix(metal_lo.rgb, metal_hi.rgb, clamp(0.5 + lit * 0.55, 0.0, 1.0));
	metal += pow(max(lit, 0.0), 6.0) * 0.45 * metal_hi.rgb;   // specular
	metal *= 0.92 + brushed;
	// Engraved grooves at both edges of the rim.
	float groove = smoothstep(0.0, 0.18, t) * smoothstep(1.0, 0.82, t);
	metal *= mix(0.45, 1.0, groove);
	float shimmer = time_glow > 0.0 ? smoothstep(0.96, 1.0, sin((p.x + p.y) * 0.02 - TIME * time_glow * 2.0)) * 0.35 : 0.0;
	metal += shimmer * metal_hi.rgb;

	// Face: vertical gradient, texture detail, leather bump, inner shadow.
	float fy = clamp((p.y - margin) / max(px.y - margin * 2.0, 1.0), 0.0, 1.0);
	vec3 face = mix(face_top.rgb, face_bot.rgb, fy);
	vec2 duv = p / 512.0 * detail_scale;
	float det = texture(detail, duv).r;
	face *= 1.0 + (det - 0.45) * detail_amt * 2.0;
	vec3 n = texture(bump, duv * 1.6).rgb * 2.0 - 1.0;
	float bl = dot(n.xy, -light) * bump_amt;
	face *= 1.0 + bl * 0.35;
	float inner = smoothstep(0.0, frame * 1.6, -d - frame);
	face *= mix(0.55 + press * 0.1, 1.0, inner);
	// Enamel sheen across the upper face (buttons).
	if (sheen > 0.0) {
		float band = smoothstep(0.62, 0.0, fy) * smoothstep(0.0, 0.08, fy);
		face += vec3(1.0) * band * sheen * 0.22 * (1.0 - press);
		face += face_top.rgb * smoothstep(0.7, 1.0, fy) * 0.25 * sheen;
	}

	vec3 col = mix(face, metal, smoothstep(-frame - aa, -frame + aa, d));
	// Fine dark line on the outermost edge.
	col *= mix(1.0, 0.25, smoothstep(-1.6, 0.0, d));

	// Corner rivets.
	if (studs > 0.0) {
		vec2 corner = half_size - vec2(frame * 0.5 + radius * 0.3);
		vec2 lq = abs(q) - corner;
		float r = frame * 0.42;
		float sdot = length(lq) - r;
		float dome = clamp(1.0 - length(lq) / r, 0.0, 1.0);
		vec3 stud = mix(metal_lo.rgb * 0.6, metal_hi.rgb * 1.15, clamp(0.5 + dot(normalize(lq + 1e-4), -light) * -0.5 + dome * 0.5, 0.0, 1.0));
		col = mix(col, stud, (1.0 - smoothstep(-aa, aa, sdot)) * studs);
	}

	// Dither to keep long gradients smooth.
	col += (hash(FRAGCOORD.xy) - 0.5) / 255.0;
	float inside = 1.0 - smoothstep(-aa, aa, d);
	COLOR = mix(outside, vec4(col, 1.0), inside);
}
