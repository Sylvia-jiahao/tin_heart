shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	float edge = smoothstep(0.0, 0.10, UV.x) * smoothstep(0.0, 0.10, 1.0-UV.x);
	edge *= smoothstep(0.0, 0.07, UV.y) * smoothstep(0.0, 0.07, 1.0-UV.y);
	COLOR = vec4(paper.rgb, paper.a * edge) * tint;
}
