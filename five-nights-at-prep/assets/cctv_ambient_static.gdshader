shader_type canvas_item;
render_mode unshaded, blend_mix;

// One existing overlay for continuous idle hiss AND a restartable switch burst.
// No screen texture, photo processing, extra layers, or whole-frame white flashes.
uniform float intensity : hint_range(0.0, 0.2, 0.005) = 0.10;
uniform float grain_size : hint_range(0.5, 3.0, 0.25) = 1.25;
uniform float updates_per_second : hint_range(1.0, 60.0, 1.0) = 30.0;
uniform float band_strength : hint_range(0.0, 0.05, 0.001) = 0.016;
uniform float burst_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burst_opacity : hint_range(0.0, 1.0, 0.01) = 0.90;
uniform float burst_updates_per_second : hint_range(20.0, 60.0, 1.0) = 48.0;

float grain_hash(vec3 point) {
	// Small arithmetic hash: no texture fetches or large sin() arguments.
	point = fract(point * 0.1031);
	point += dot(point, point.yzx + 33.33);
	return fract((point.x + point.y) * point.z);
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / max(grain_size, 0.5));
	float tick = floor(TIME * updates_per_second);
	float grain = grain_hash(vec3(cell, tick));
	// Three faint, slowly drifting horizontal interference bands, not scanlines.
	float band_phase = fract(UV.y * 3.0 - TIME * (updates_per_second / 30.0) * 0.18);
	float band = 1.0 - smoothstep(0.01, 0.05, abs(band_phase - 0.5));
	float idle_alpha = clamp(intensity + band * band_strength, 0.0, 1.0);
	float gray = grain;
	float alpha = idle_alpha;
	if (burst_amount > 0.0) {
		float burst_tick = floor(TIME * burst_updates_per_second);
		float snow = grain_hash(vec3(cell, burst_tick + 19.0));
		float row = grain_hash(vec3(0.0, floor(FRAGCOORD.y / 2.0), burst_tick + 71.0));
		// Dark-biased snow with fine horizontal breakup: strong obscuration,
		// restrained average luminance (about 0.28), never a flat white flash.
		float burst_gray = 0.84 * mix(snow * snow, row * row, 0.22);
		gray = mix(grain, burst_gray, burst_amount);
		alpha = mix(idle_alpha, burst_opacity, burst_amount);
	}
	COLOR = vec4(vec3(gray), alpha);
}
