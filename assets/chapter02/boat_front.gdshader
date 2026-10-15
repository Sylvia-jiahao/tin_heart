shader_type canvas_item;
uniform vec4 atlas_region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec2 local_uv = (UV-atlas_region.xy)/atlas_region.zw;
	// Keep the generated near hull, leaving its tall central rear fold behind the actor.
	// Follow the painted fold: the near right lip is curved, not a straight V.
	float x=local_uv.x;
	float rim;
	if (x<0.20) rim=mix(0.17,0.65,x/0.20);
	else if (x<0.50) rim=mix(0.65,0.72,(x-0.20)/0.30);
	else if (x<0.80) rim=mix(0.72,0.55,(x-0.50)/0.30);
	else rim=mix(0.55,0.18,(x-0.80)/0.20);
	vec4 paper = texture(TEXTURE,UV);
	paper.a *= smoothstep(rim-0.004,rim+0.004,local_uv.y);
	COLOR=paper*tint;
}
