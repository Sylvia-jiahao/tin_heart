extends Sprite2D

var rest_position: Vector2
var rest_scale: Vector2
var halo: Sprite2D

func setup() -> void:
	centered=true
	rest_position=position
	rest_scale=scale
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0.0,0.28,0.65,1.0])
	gradient.colors=PackedColorArray([Color(1,1,0.97,0.95),Color(1,1,0.97,0.8),Color(1,0.98,0.87,0.28),Color(1,0.98,0.9,0)])
	var glow:=GradientTexture2D.new()
	glow.width=96
	glow.height=96
	glow.gradient=gradient
	glow.fill=GradientTexture2D.FILL_RADIAL
	glow.fill_from=Vector2(0.5,0.5)
	glow.fill_to=Vector2(1,0.5)
	halo=Sprite2D.new()
	halo.texture=glow
	halo.scale=Vector2(90,90)/Vector2(96,96)/rest_scale
	halo.show_behind_parent=true
	add_child(halo)
	update_effect(0.0)

func update_effect(clock: float) -> void:
	var pulse: float=0.5+0.5*sin(clock*TAU/2.4)
	position=rest_position+Vector2(0,sin(clock*TAU/3.0)*3.0)
	scale=rest_scale*lerpf(1.06,1.18,pulse)
	halo.modulate.a=lerpf(0.58,1.0,pulse)
