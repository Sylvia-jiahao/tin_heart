extends SceneTree

const CUTOUT=preload("res://scripts/cutout_collision.gd")
const DRESS=preload("res://scripts/set_dressing.gd")
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func verify() -> void:
	var scene=load("res://scenes/tabletop_journey.tscn").instantiate()
	scene.save_path="E:/tinheart/journey_qa/ledge_star_test.json"
	root.add_child(scene)
	current_scene=scene
	await frames(5)
	scene.active=false
	var body:=StaticBody2D.new()
	body.position=Vector2(-4000,350)
	scene.add_child(body)
	var upper:=DRESS.fitted("v3_books_mid_1",Vector2(180,220))
	var lower:=DRESS.fitted("v3_books_low_2",Vector2(260,100))
	upper.position.x+=40
	lower.position.y=upper.texture.get_height()*upper.scale.y-3
	body.add_child(upper)
	body.add_child(lower)
	var pictures: Array[Sprite2D]=[upper,lower]
	var shape:=CUTOUT.add_stack(body,pictures)
	var span: Vector2=shape.get_meta("landing_span")
	var middle: float=(span.x+span.y)*0.5
	scene.player.reset_at(body.position+Vector2(middle,-45))
	await frames(60)
	check(scene.player.is_on_floor(),"top of book stack still supports the soldier")
	scene.player.reset_at(body.position+Vector2(span.y+20,lower.position.y-20))
	var perched: bool=false
	for i in range(60):
		await frames(1)
		if i>4 and scene.player.is_on_floor(): perched=true
	check(not perched and scene.player.position.y>body.position.y+lower.position.y+100,"protruding lower book cover cannot become a side foothold")
	var feet:=Vector2(300,600)
	scene.player.reset_at(feet)
	scene.player.set_physics_process(false)
	scene.player.clock=0
	var art: Node2D=scene.player.body_art
	art._process(0)
	check(not art.touches_star(feet+Vector2(0,-118)),"head-only contact cannot collect a star")
	check(art.touches_star(feet+Vector2(0,-75)),"upper torso can now collect a star")
	check(art.touches_star(feet+Vector2(28,-65)),"arm contact can collect a star")
	check(art.touches_star(feet+Vector2(0,-35)),"lower body can collect a star")
	check(art.touches_star(feet+Vector2(0,-5)),"supporting foot can collect a star")
	check(not art.touches_star(feet+Vector2(50,-35)),"distant star is not collected by a wide radius")
	scene.player.facing=-1
	art._process(0)
	check(art.touches_star(feet+Vector2(-28,-65)),"mirrored arm contact can collect a star")
	scene.player.braced=true
	art._process(0.2)
	var hand: Sprite2D=art.left_forearm.get_node("ForearmPaper")
	check(art.touches_star(hand.to_global(hand.get_rect().get_center())),"raised saluting forearm can collect a star")
	print("LEDGE_STAR_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
