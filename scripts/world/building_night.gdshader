shader_type spatial;
// Night facade: dark walls with a procedural grid of lit windows. The grid is
// world-space (Kenney models have no usable UVs); buildings stand axis-aligned,
// so the across-face coordinate is simply z on x-facing walls and vice versa.
// Fractured chunks keep the shader: the rubble keeps a few lit windows.

uniform vec3 albedo : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 window_color : source_color = vec3(1.0, 0.82, 0.45);
uniform float window_density : hint_range(0.0, 1.0) = 0.55;
uniform float seed = 0.0;

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = albedo * 0.4;
	float emission = 0.0;
	if (abs(wnormal.y) < 0.4) {
		// Facade: pick the horizontal coordinate across the face.
		float u = abs(wnormal.x) > abs(wnormal.z) ? wpos.z : wpos.x;
		vec2 g = vec2(u / 2.4, wpos.y / 3.0);
		vec2 f = fract(g);
		vec2 win = step(vec2(0.18, 0.25), f) * step(f, vec2(0.82, 0.72));
		float lit = step(hash12(floor(g)), window_density);
		// A few windows switch off and on very slowly.
		float blink = mix(1.0, step(0.5, fract(TIME * 0.045 + hash12(floor(g) + 7.3))), 0.18);
		emission = win.x * win.y * lit * blink;
	}
	ALBEDO = col;
	EMISSION = window_color * emission * 1.7;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}
