shader_type canvas_item;
uniform bool border_only = false;

// Preserve opaque paper and its scissor edge, suppress low-alpha outer haze.
void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	paper.a = smoothstep(0.55, 0.80, paper.a);
	if (border_only) {
		paper.rgb = vec3(1.0);
	}
	COLOR = paper;
}
