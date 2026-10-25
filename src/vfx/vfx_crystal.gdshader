shader_type spatial;
// Faceted cores: ice crystals, thorns, stone spikes and their shards. Flat
// facets from screen derivatives and a hard rim; no blur, no glow. One
// MultiMesh per shape. COLOR = element colour (pale end), CUSTOM.y = style
// (0 ice, 1 thorn, 2 stone, 3 void).
render_mode unshaded, cull_back, shadows_disabled;
varying vec3 wpos;
varying vec4 col;
varying float style;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	col = COLOR;
	style = INSTANCE_CUSTOM.y;
}
void fragment() {
	vec3 n = normalize(cross(dFdx(wpos), dFdy(wpos)));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float f = abs(dot(n, v));
	float facet = step(0.5, fract(dot(n, vec3(3.1, 1.7, 2.3))));
	vec3 pale = mix(col.rgb, vec3(1.0), style < 0.5 ? 0.5 : 0.15);
	vec3 deep = col.rgb * (style < 0.5 ? 0.45 : 0.35);
	vec3 c = mix(pale, deep, f * 0.8 + facet * 0.15);
	vec3 edge = style < 0.5 ? vec3(1.0) : (style > 2.5 ? mix(col.rgb, vec3(1.0), 0.4) : col.rgb * 1.2);
	c = mix(edge, c, step(0.22, f));
	ALBEDO = c;
}
