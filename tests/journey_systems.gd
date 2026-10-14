extends SceneTree

var failures: Array=[]

func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ",description)
	if not ok: failures.append(description)

func verify() -> void:
	var scene=load("res://scenes/tabletop_journey.tscn").instantiate()
	scene.save_path="E:/tinheart/journey_qa/systems_save.json"
	root.add_child(scene)
	current_scene=scene
	await frames(6)
	scene._load_room(0)
	await frames(6)
	scene.player.reset_at(Vector2(185,648))
	await frames(3)
	Input.action_press("move_right")
	for i in range(15):
		await frames(1)
		if not scene.player.is_on_floor(): break
	Input.action_release("move_right")
	var jumps_before: int=scene.player.small_jumps
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(2)
	check(scene.player.small_jumps==jumps_before+1 and scene.player.velocity.y<0,"short jump still launches just after leaving a ledge")
	scene._load_room(0)
	await frames(4)
	scene.player.reset_at(Vector2(100,620))
	scene.player.velocity.y=250
	jumps_before=scene.player.small_jumps
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(10)
	check(scene.player.small_jumps==jumps_before+1 and scene.player.velocity.y<0,"short press before landing is buffered into a jump")
	scene._load_room(5)
	scene.room_time=1.2
	scene.player.reset_at(scene.room_root.global_position+Vector2(300,618))
	await frames(5)
	Input.action_press("brace")
	await frames(2)
	var stood_at: Vector2=scene.player.position
	await frames(20)
	check(scene.player.braced and absf(scene.player.position.x-stood_at.x)<0.01,"attention holds position during a strong gust")
	Input.action_release("brace")
	await frames(10)
	check(absf(scene.player.position.x-stood_at.x)>5,"unbraced soldier is moved by the gust")
	scene._load_room(20)
	scene.player.reset_at(scene.room_root.global_position+Vector2(300,608))
	await frames(80)
	check(scene.platforms[1].gone,"paper ledge folds after the soldier stands on it")
	scene._retry()
	await frames(5)
	check(scene.room_index==20 and not scene.platforms[1].gone and scene.room_root.to_local(scene.player.global_position).x<190,"retry restores the same room and all paper ledges")
	scene.stars=[1,5]
	scene._save()
	scene.room_index=0
	scene.stars=[]
	scene._load_save()
	check(scene.room_index==20 and scene.stars.size()==2,"save restores room and optional stars")
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_ESCAPE
	key.pressed=true
	scene._unhandled_input(key)
	check(paused,"Escape pauses the journey")
	scene._unhandled_input(key)
	check(not paused,"Escape resumes the journey")
	scene._load_room(29)
	scene.player.global_position=scene.room_root.global_position+Vector2(1235,548)
	await frames(4)
	scene._advance()
	await process_frame
	await process_frame
	await frames(8)
	check(current_scene==scene and scene.phase=="castle_arrival","dancer meeting stays in the final region without changing scene")
	check(current_scene.player.state=="站立" and current_scene.dancer_axis.visible,"return preserves standing and visible dancer")
	print("SYSTEM_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
