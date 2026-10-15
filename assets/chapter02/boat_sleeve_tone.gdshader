shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 paper=texture(TEXTURE,UV);
	// Grade only the new red sleeve. Keep the ivory hand/rim and gold cuff intact.
	float red_mask=smoothstep(0.02,0.12,paper.r*0.55-paper.g);
	paper.rgb=mix(paper.rgb,paper.rgb*vec3(0.87,1.45,1.50),red_mask);
	paper.a=smoothstep(0.55,0.80,paper.a);
	COLOR=paper*tint;
}
