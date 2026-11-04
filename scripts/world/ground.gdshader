shader_type spatial;
// Ground with procedural roads and circular cut-outs for every hole.
// All edges are anti-aliased with fwidth() so nothing shimmers at a distance.
// World-space math stays highp: the fragment default mediump on mobile GPUs
// turns coordinates near the map edge into blotchy, wandering noise.

const int MAX_HOLES = 16;

uniform vec4 holes[MAX_HOLES];        // x, z, radius, unused
uniform vec4 hole_colors[MAX_HOLES];  // rim colors (linear rgb), a = pattern id (Skins.Pattern)
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

varying highp vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 inside [a, b], 0 outside, smooth over one pixel.
float band(float x, float a, float b, float w) {
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

// Highp through the whole hash: mediump fract() of values in the tens of
// thousands collapses to garbage on mobile GPUs.
float hash12(highp vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(highp vec2 p) {
	highp vec2 i = floor(p);
	highp vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

// rgb = surface colour.
vec3 city_color(highp vec2 p) {
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
	float grass = inner_x * inner_z;

	// Sidewalk: tile joints every 1.6 m.
	vec3 walk_c = walk_color * (1.0 - 0.10 * max(step(0.93, fract(b.x * 0.625)),
		step(0.93, fract(b.y * 0.625))));
	// Grass: patchiness with occasional dirt spots.
	float gn = vnoise(p * 0.5);
	vec3 grass_c = grass_color * (0.84 + 0.32 * gn);
	float dirt = step(0.92, hash12(floor(p / 5.0))) * clamp(gn * 1.4 - 0.2, 0.0, 1.0);
	grass_c = mix(grass_c, grass_color * vec3(1.05, 0.82, 0.55), dirt * 0.55);
	vec3 block_col = mix(walk_c, grass_c, grass);

	// Asphalt: wear noise, sparse manholes and darker repair patches.
	float wear = vnoise(p * 0.21);
	vec3 road_c = road_color * (0.9 + 0.18 * wear);
	vec2 cell = floor(p / 7.0);
	float mh = hash12(cell + 3.7);
	vec2 mo = (vec2(hash12(cell + 1.3), hash12(cell + 2.6)) - 0.5) * 4.6;
	float md = length(mod(p, 7.0) - 3.5 + mo);
	road_c = mix(road_c, road_c * 0.45, step(0.8, mh) * smoothstep(0.85, 0.6, md));
	float patch = step(0.86, hash12(floor(p / 11.0) + 9.1));
	road_c *= 1.0 + patch * (wear - 0.5) * 0.16;

	// Zebra bars on the four approaches of every crossing.
	float zeb = rx * (band(m.y, 0.5, 2.1, w.y) + band(m.y, road - 2.1, road - 0.5, w.y))
			* step(fract(p.y / 1.7), 0.5)
		+ rz * (band(m.x, 0.5, 2.1, w.x) + band(m.x, road - 2.1, road - 0.5, w.x))
			* step(fract(p.x / 1.7), 0.5);
	zeb = clamp(zeb, 0.0, 1.0) * is_road;

	// Dashed centre lines, faded out where they would be thinner than a pixel.
	float lw = 0.12;
	float lx = band(m.x, road * 0.5 - lw, road * 0.5 + lw, w.x) * (1.0 - rz);
	float lz = band(m.y, road * 0.5 - lw, road * 0.5 + lw, w.y) * (1.0 - rx);
	float dash_x = band(mod(p.y, 4.0), 0.0, 2.0, w.y);
	float dash_z = band(mod(p.x, 4.0), 0.0, 2.0, w.x);
	float fade = 1.0 - smoothstep(0.08, 0.25, max(w.x, w.y));
	float line = max(lx * dash_x, lz * dash_z) * fade;
	float marks = clamp(line * 0.9 + zeb * 0.7, 0.0, 1.0);
	vec3 road_col = mix(road_c, line_color, marks);

	vec3 col = mix(block_col, road_col, is_road);
	float outside = max(smoothstep(half_extent - w.x, half_extent + w.x, abs(p.x)),
		smoothstep(half_extent - w.y, half_extent + w.y, abs(p.y)));
	return mix(col, outside_color, outside);
}

vec3 hsv_rgb(float h) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return pow(k, vec3(2.2));
}

// Rim colour at offset q from the hole centre; u is 0..1 across the rim.
vec3 rim_color(vec3 c, int pattern, vec2 q, float u, float r) {
	float ang = atan(q.y, q.x);
	if (pattern == 1) {        // stripes, slowly turning
		float s = smoothstep(0.42, 0.5, abs(fract(ang / TAU * 16.0 + TIME * 0.25) - 0.5) * 2.0);
		return mix(c, c * 0.35, s);
	} else if (pattern == 2) { // dots
		float n = max(10.0, floor(r * 6.0));
		float cell = fract(ang / TAU * n + TIME * 0.1) - 0.5;
		float dd = length(vec2(cell * 2.2, (u - 0.5) * 2.0));
		return mix(c * 0.45, min(c * 1.4 + 0.15, vec3(1.0)), 1.0 - smoothstep(0.45, 0.6, dd));
	} else if (pattern == 3) { // rainbow
		return hsv_rgb(fract(ang / TAU + TIME * 0.15));
	} else if (pattern == 4) { // pulse
		return mix(c * 0.4, min(c * 1.5 + 0.1, vec3(1.0)), 0.5 + 0.5 * sin(TIME * 5.0));
	} else if (pattern == 5) { // shimmer: a bright highlight running around
		float hl = smoothstep(0.8, 1.0, cos(ang - TIME * 2.5));
		return mix(c, vec3(1.0), hl * 0.85);
	}
	return c;
}

void fragment() {
	highp vec2 p = wpos.xz;
	vec3 col = city_color(p);
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) break;
		vec4 h = holes[i];
		float d = distance(p, h.xy);
		if (d < h.z) discard;
		float aa = max(fwidth(d), 0.001);
		float rim = 0.1 + h.z * 0.07;
		float t = 1.0 - smoothstep(h.z + rim - aa, h.z + rim + aa, d);
		if (t > 0.0) {
			vec3 rc = rim_color(hole_colors[i].rgb, int(hole_colors[i].a + 0.5), p - h.xy, (d - h.z) / rim, h.z);
			col = mix(col, rc, t);
		}
		// Soft shadow with radial cracks in the asphalt just outside the rim.
		float edge = h.z + rim;
		float sh = (1.0 - smoothstep(edge, edge + 0.8 + h.z * 0.25, d)) * (1.0 - t);
		float cang = atan(p.y - h.y, p.x - h.x);
		float cracks = smoothstep(0.65, 0.95, sin(cang * 7.0 + float(i) * 2.3))
			* smoothstep(edge, edge + 0.35, d) * (1.0 - smoothstep(edge + 0.4, edge + 0.9, d));
		col *= 1.0 - sh * (0.20 + 0.14 * cracks);
	}
	if (zone.z > 0.0) {
		float zd = distance(p, zone.xy);
		float aa = max(fwidth(zd), 0.001);
		float zout = smoothstep(zone.z - aa, zone.z + aa, zd);
		float zedge = band(zd, zone.z - 0.6, zone.z, aa);
		// Rotating dashes on the edge line.
		float zang = atan(p.y - zone.y, p.x - zone.x);
		float dash = 0.55 + 0.45 * step(0.5, fract(zang / TAU * 48.0 + TIME * 0.3));
		col = mix(col, vec3(0.85, 0.15, 0.2), 0.45 * zout);
		col = mix(col, vec3(1.0, 0.3, 0.3) * (0.6 + 0.4 * dash), zedge);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
