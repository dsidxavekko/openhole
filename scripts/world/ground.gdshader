shader_type spatial;
// Ground with procedural roads and circular cut-outs for every hole.
// All edges are anti-aliased with fwidth() so nothing shimmers at a distance.

const int MAX_HOLES = 16;

uniform vec4 holes[MAX_HOLES];        // x, z, radius, unused
uniform vec4 hole_colors[MAX_HOLES];  // rim colors (linear rgb)
uniform int hole_count = 0;

uniform float half_extent = 132.0;
uniform float block_size = 30.0;
uniform float pitch = 42.0;
uniform float road = 12.0;
uniform float sidewalk = 3.0;
uniform vec3 grass_color : source_color = vec3(0.42, 0.62, 0.32);
uniform vec3 walk_color : source_color = vec3(0.78, 0.78, 0.76);
uniform vec3 road_color : source_color = vec3(0.30, 0.31, 0.34);
uniform vec3 line_color : source_color = vec3(0.95, 0.92, 0.75);
uniform vec3 outside_color : source_color = vec3(0.38, 0.55, 0.36);

// Battle zone: x, z, radius; radius <= 0 disables it.
uniform vec3 zone = vec3(0.0, 0.0, 0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 inside [a, b], 0 outside, smooth over one pixel.
float band(float x, float a, float b, float w) {
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

vec3 city_color(vec2 p) {
	vec2 w = max(fwidth(p), vec2(0.001));
	// Layout along each axis: road, block, road, block, ..., road.
	vec2 m = mod(p + vec2(half_extent), pitch);
	// Distance-to-edge masks (1 = road on that axis).
	float rx = 1.0 - band(m.x, road, pitch, w.x);
	float rz = 1.0 - band(m.y, road, pitch, w.y);
	float is_road = max(rx, rz);

	vec2 b = m - vec2(road);
	float inner_x = band(b.x, sidewalk, block_size - sidewalk, w.x);
	float inner_z = band(b.y, sidewalk, block_size - sidewalk, w.y);
	vec3 block_col = mix(walk_color, grass_color, inner_x * inner_z);

	// Dashed centre lines, faded out where they would be thinner than a pixel.
	float lw = 0.12;
	float lx = band(m.x, road * 0.5 - lw, road * 0.5 + lw, w.x) * (1.0 - rz);
	float lz = band(m.y, road * 0.5 - lw, road * 0.5 + lw, w.y) * (1.0 - rx);
	float dash_x = band(mod(p.y, 4.0), 0.0, 2.0, w.y);
	float dash_z = band(mod(p.x, 4.0), 0.0, 2.0, w.x);
	float fade = 1.0 - smoothstep(0.08, 0.25, max(w.x, w.y));
	float line = max(lx * dash_x, lz * dash_z) * fade;
	vec3 road_col = mix(road_color, line_color, line);

	vec3 col = mix(block_col, road_col, is_road);
	float outside = max(smoothstep(half_extent - w.x, half_extent + w.x, abs(p.x)),
		smoothstep(half_extent - w.y, half_extent + w.y, abs(p.y)));
	return mix(col, outside_color, outside);
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 col = city_color(p);
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) break;
		vec4 h = holes[i];
		float d = distance(p, h.xy);
		if (d < h.z) discard;
		float aa = max(fwidth(d), 0.001);
		float rim = 0.06 + h.z * 0.06;
		float t = 1.0 - smoothstep(h.z + rim - aa, h.z + rim + aa, d);
		col = mix(col, hole_colors[i].rgb, t);
	}
	if (zone.z > 0.0) {
		float zd = distance(p, zone.xy);
		float aa = max(fwidth(zd), 0.001);
		float outside = smoothstep(zone.z - aa, zone.z + aa, zd);
		float edge = band(zd, zone.z - 0.6, zone.z, aa);
		col = mix(col, vec3(0.85, 0.15, 0.2), 0.45 * outside);
		col = mix(col, vec3(1.0, 0.3, 0.3), edge);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
