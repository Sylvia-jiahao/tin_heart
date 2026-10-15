shader_type canvas_item;
varying vec4 paper_tint;
uniform bool water_surface=false;
uniform float water_uv_top=0.0;
uniform float water_clock=0.0;
uniform bool wave_piece=false;
uniform vec2 wave_uv_bounds=vec2(0.0,1.0);
uniform bool quay_join=false;
uniform vec2 quay_uv_bounds=vec2(0.0,1.0);
uniform float quay_join_fraction=0.15;
void vertex(){paper_tint=COLOR;}
void fragment(){
	vec4 paper=texture(TEXTURE,UV)*paper_tint;
	float edge=smoothstep(0.0,0.16,UV.x)*(1.0-smoothstep(0.84,1.0,UV.x));
	if(quay_join){
		float local_x=(UV.x-quay_uv_bounds.x)/max(0.01,quay_uv_bounds.y-quay_uv_bounds.x);
		edge=smoothstep(0.0,quay_join_fraction,local_x);
	}
	if(water_surface){
		// Blend the generated paint into the street; a moving uneven mask avoids a rectangular horizon.
		float crest=0.014*sin(UV.x*37.0+water_clock*0.7)+0.009*sin(UV.x*81.0-water_clock*0.4);
		float local_y=(UV.y-water_uv_top)/max(0.01,1.0-water_uv_top);
		edge*=smoothstep(max(0.003,0.015+crest),0.14+crest,local_y);
	}
	if(wave_piece){
		float local_y=(UV.y-wave_uv_bounds.x)/max(0.01,wave_uv_bounds.y-wave_uv_bounds.x);
		edge*=1.0-smoothstep(0.65,1.0,local_y);
	}
	COLOR=vec4(paper.rgb,paper.a*edge);
}
