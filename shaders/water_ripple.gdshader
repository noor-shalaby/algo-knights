shader_type canvas_item;


uniform float wave_speed : hint_range(0.0, 10.0) = 1.0;
uniform float wave_frequency : hint_range(1.0, 40.0) = 1.0;
uniform float pixel_displacement : hint_range(0.0, 4.0) = 1.0;


void fragment() {
	// Clean pixel snapping in screen/texture texel space:
	vec2 tex_size = 1.0 / max(TEXTURE_PIXEL_SIZE, vec2(0.0001));
	vec2 texel = floor(UV * tex_size);

	float phase = TIME * wave_speed + (texel.x + texel.y * 0.5) * (wave_frequency * 0.1);
	float offset_px = round(sin(phase) * pixel_displacement);

	vec2 shifted_uv = UV + vec2(offset_px, 0.0) * TEXTURE_PIXEL_SIZE;
	shifted_uv = clamp(shifted_uv, vec2(0.0), vec2(1.0));

	COLOR = texture(TEXTURE, shifted_uv);
}