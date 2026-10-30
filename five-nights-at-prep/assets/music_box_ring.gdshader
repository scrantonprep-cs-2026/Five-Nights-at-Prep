shader_type canvas_item;

uniform float charge : hint_range(0.0, 1.0) = 1.0;
// Muted monochrome phosphor for the old desk CRT.
uniform vec4 fill_color : source_color = vec4(0.70, 0.70, 0.70, 1.0);

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float radius = length(point);
	float ring = (1.0 - smoothstep(0.88, 0.93, radius)) * smoothstep(0.65, 0.70, radius);
	float angle = mod(atan(point.x, -point.y) + 6.28318530718, 6.28318530718) / 6.28318530718;
	float filled = step(angle, charge) * step(0.0001, charge);
	vec3 tint = mix(vec3(0.13), fill_color.rgb, filled);
	COLOR = vec4(tint, ring);
}
