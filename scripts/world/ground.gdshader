shader_type spatial;
// Ground with procedural roads and circular cut-outs for every hole.

const int MAX_HOLES = 16;

uniform vec4 holes[MAX_HOLES];        // x, z, radius, unused
uniform vec4 hole_colors[MAX_HOLES];  // rim colors (linear rgb)
uniform int hole_count = 0;

uniform float half_extent = 132.0;
uniform float block_size = 30.0;
uniform float pitch = 42.0;
uniform float road = 12.0;
uniform float sidewalk = 3.0;
uniform vec3 grass_color : source_color = vec3(0.56, 0.74, 0.45);
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

vec3 city_color(vec2 p) {
	if (abs(p.x) > half_extent || abs(p.y) > half_extent) {
		return outside_color;
	}
	// Layout along each axis: road, block, road, block, ..., road.
	vec2 m = mod(p + vec2(half_extent), pitch);
	bool road_x = m.x < road;
	bool road_z = m.y < road;
	if (road_x || road_z) {
		vec3 c = road_color;
		// Dashed centre line (not inside crossings).
		if (road_x && !road_z && abs(m.x - road * 0.5) < 0.12 && mod(p.y, 4.0) < 2.0) c = line_color;
		if (road_z && !road_x && abs(m.y - road * 0.5) < 0.12 && mod(p.x, 4.0) < 2.0) c = line_color;
		return c;
	}
	vec2 b = m - vec2(road);
	if (b.x < sidewalk || b.y < sidewalk || b.x > block_size - sidewalk || b.y > block_size - sidewalk) {
		return walk_color;
	}
	return grass_color;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 col = city_color(p);
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) break;
		vec4 h = holes[i];
		float d = distance(p, h.xy);
		if (d < h.z) discard;
		float rim = 0.06 + h.z * 0.06;
		if (d < h.z + rim) col = hole_colors[i].rgb;
	}
	if (zone.z > 0.0) {
		float zd = distance(p, zone.xy);
		if (zd > zone.z) col = mix(col, vec3(0.85, 0.15, 0.2), 0.45);
		else if (zd > zone.z - 0.6) col = vec3(1.0, 0.3, 0.3);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
