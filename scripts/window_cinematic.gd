extends Node2D
const ART=preload("res://scripts/cinematic_art.gd")
var actor: CharacterBody2D
var camera: Camera2D
var hand: Node2D
var window_art: Sprite2D
var clock: float=0.0
var source: Vector2
var target: Vector2
var camera_start: Vector2
var zoom_start: Vector2
var running: bool=false
var settled: bool=false
func setup(player: CharacterBody2D,view: Camera2D) -> void:
	actor=player
	camera=view
	window_art=ART.sprite("window_landing",Vector2(1280,720))
	window_art.position=Vector2(1850,-10)
	window_art.z_index=-5
	var edge_material:=ShaderMaterial.new()
	edge_material.shader=load("res://assets/cinematics/window_edges.gdshader")
	window_art.material=edge_material
	add_child(window_art)
	hand=Node2D.new()
	hand.z_index=50
	var picture:=ART.sprite("hand_lift",Vector2(190,365))
	# Fingertips surround the toy's upper torso; the palm stays above its head.
	picture.position=Vector2(-100,-318)
	hand.add_child(picture)
	add_child(hand)
	hand.visible=false
	window_art.visible=false
func start() -> void:
	running=true
	clock=0.0
	source=actor.global_position
	target=to_global(Vector2(2540,508))
	camera_start=camera.global_position
	zoom_start=camera.zoom
	actor.hold_standing()
	actor.z_index=51
	hand.visible=true
	window_art.visible=true
	update_shot(0.0)
func smooth(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)
func update_shot(delta: float) -> void:
	if not running: return
	clock+=delta
	var grip:=source+Vector2(0,-85)
	if clock<1.6:
		hand.global_position=grip+Vector2(0,lerpf(-650,0,smooth(clock/1.6)))
	elif clock<7.6:
		var carry: float=smooth((clock-1.6)/6.0)
		actor.global_position=source.lerp(target,carry)+Vector2(0,-sin(carry*PI)*230)
		hand.global_position=actor.global_position+Vector2(0,-85)
		actor.rotation=sin(carry*PI)*-0.10
		var view_target:=actor.global_position+Vector2(60,-110)
		view_target.y=maxf(view_target.y,270.0+global_position.y)
		camera.global_position=camera_start.lerp(view_target,smooth((clock-1.6)/1.7))
		camera.zoom=zoom_start.lerp(Vector2.ONE*1.4,smooth((clock-1.6)/4.0))
	else:
		actor.global_position=target
		actor.rotation=0.0
		actor.z_index=20
		hand.global_position=target+Vector2(0,-85-650*smooth((clock-7.6)/2.0))
		camera.global_position=camera.global_position.lerp(target+Vector2(0,-150),1.0-exp(-delta*3.0))
		if clock>=9.6:
			hand.visible=false
			settled=true
			actor.hold_standing()
