shader_type spatial;
// The locator under the player's hero (and the target / shrine markers): a
// thin, hard-edged band so you always know where you are in the crowd. It is
// a gameplay marker, not an effect: no fill, no pulse, no additive glow.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.35, 0.75, 1.0, 1.0);
uniform float intensity = 1.6;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float aa = fwidth(r) * 1.2;
	float band = smoothstep(0.84 - aa, 0.84, r) * (1.0 - smoothstep(0.93, 0.93 + aa, r));
	// Four short gaps make it read as a marker, not a glowing disc.
	float ang = atan(UV.y - 0.5, UV.x - 0.5);
	float gaps = step(0.12, abs(sin(ang * 2.0 + 0.785)));
	ALBEDO = color.rgb * min(intensity, 1.3);
	ALPHA = band * gaps * 0.85;
}
