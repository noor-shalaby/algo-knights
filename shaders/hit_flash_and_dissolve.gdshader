shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size : hint_range(1.0, 64.0) = 16.0;
uniform vec4 burn_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform float burn_width : hint_range(0.0, 0.25) = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (tex_color.a <= 0.001) {
		discard;
	}

	vec2 cell = floor(UV * pixel_size);
	float noise = hash(cell);

	if (dissolve_progress >= 1.0 || noise < dissolve_progress) {
		discard;
	}

	vec3 rgb = mix(tex_color.rgb, vec3(1.0, 1.0, 1.0), flash_amount);
	if (dissolve_progress > 0.0 && noise < dissolve_progress + burn_width) {
		rgb = mix(rgb, burn_color.rgb, 0.75);
	}

	COLOR = vec4(rgb, tex_color.a);
}