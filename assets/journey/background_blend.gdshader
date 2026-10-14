shader_type canvas_item;
void fragment() {
	vec4 ink=texture(TEXTURE,UV);
	float edge=smoothstep(0.0,0.06,UV.x)*(1.0-smoothstep(0.94,1.0,UV.x));
	COLOR=vec4(ink.rgb,ink.a*edge);
}
