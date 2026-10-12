shader_type canvas_item;

void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	if (max(max(sampled.r, sampled.g), sampled.b) < 0.025) {
		discard;
	}
	COLOR = sampled * COLOR;
}
