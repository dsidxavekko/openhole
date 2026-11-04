shader_type spatial;
// Night facade: dark walls with a procedural grid of lit windows. The grid is
// world-space (Kenney models have no usable UVs); buildings stand axis-aligned,
// so the across-face coordinate is simply z on x-facing walls and vice versa.
// Fractured chunks keep the shader: the rubble keeps a few lit windows.
// World-space math stays highp: the fragment default mediump on mobile GPUs
// corrupts coordinates near the map edge into random window flicker.

uniform vec3 albedo : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 window_color : source_color = vec3(1.0, 0.82, 0.45);
uniform float window_density : hint_range(0.0, 1.0) = 0.55;
uniform float seed = 0.0;

varying highp vec3 wpos;
varying highp vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Highp through the whole hash: mediump fract() of values in the tens of
// thousands collapses to garbage on mobile GPUs.
float hash12(highp vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = albedo * 0.4;
	float emission = 0.0;
	if (abs(wnormal.y) < 0.4) {
		// Facade: pick the horizontal coordinate across the face.
		highp float u = abs(wnormal.x) > abs(wnormal.z) ? wpos.z : wpos.x;
		highp vec2 g = vec2(u / 2.4, wpos.y / 3.0);
		vec2 f = fract(vec2(g));
		vec2 win = step(vec2(0.18, 0.25), f) * step(f, vec2(0.82, 0.72));
		float h = hash12(floor(g));
		float lit = step(h, window_density);
		// A few windows switch off and on very slowly (same hash, different mix).
		float blink = mix(1.0, step(0.5, fract(TIME * 0.045 + h * 13.7)), 0.18);
		emission = win.x * win.y * lit * blink;
	}
	ALBEDO = col;
	EMISSION = window_color * emission * 1.7;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}
