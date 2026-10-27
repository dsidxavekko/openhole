shader_type spatial;
// Inside walls of a hole: dark, fading to black with depth.
render_mode unshaded, cull_front;

uniform vec3 tint : source_color = vec3(0.10, 0.08, 0.14);

varying float vy;

void vertex() {
	vy = VERTEX.y;
}

void fragment() {
	ALBEDO = mix(vec3(0.0), tint, smoothstep(-0.5, 0.5, vy));
}
