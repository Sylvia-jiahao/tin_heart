shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 paper = texture(TEXTURE, UV);
	paper.a = smoothstep(0.55, 0.80, paper.a);
	COLOR = paper * tint;
}
