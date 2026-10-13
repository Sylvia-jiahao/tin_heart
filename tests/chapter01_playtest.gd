extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("verify")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:
		failures.append(message)

func jump(scene: Node, hold_frames: int, target_x: float) -> void:
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(hold_frames)
	Input.action_release("jump")
	var airborne := false
	for i in range(100):
		await frames(1)
		if not scene.player.is_on_floor():
			airborne = true
		if scene.player.position.x >= target_x:
			Input.action_release("move_right")
		if airborne and scene.player.is_on_floor():
			break
	Input.action_release("move_right")
	await frames(12)

func verify() -> void:
	var scene = load("res://scenes/chapter01_paper_castle.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(6)
	scene.set_process(false)
	check(scene.soldiers.size()==24,"24 brothers plus the one-legged player")
	for time in [0.0,4.0,8.0,16.0,22.0,24.0,26.6,28.6,33.0]:
		scene.cg_time = time
		scene._cinematic()
	check(scene.placed_count==24,"all brothers placed before control handoff")
	check(scene.player.rotation==0 and scene.player.scale==Vector2.ONE,"last soldier upright and full size")
	check(absf(scene.player.body_art.rotation)<0.001,"two wobbles end in a stable pose")
	scene.cg_time=24.0
	scene._cinematic()
	check(scene.camera.zoom.x>2.0 and scene.camera.position.x<scene.checkpoint.x,"last soldier is magnified while the hand carries it")
	scene.cg_time=28.4
	scene._cinematic()
	check(scene.camera.zoom.x>2.0 and absf(scene.player.body_art.rotation)<0.001,"close-up holds until the soldier stands steadily")
	scene.cg_time=33.0
	scene._cinematic()
	check(scene.camera.zoom.is_equal_approx(Vector2.ONE) and scene.camera.position.is_equal_approx(Vector2(scene.checkpoint.x,440)),"camera returns to normal before control handoff")
	scene.cg_time=8.0
	scene.set_process(true)
	Input.action_press("skip_intro")
	await process_frame
	await process_frame
	Input.action_release("skip_intro")
	scene.set_process(false)
	check(scene.phase=="tutorial" and scene.placed_count==24 and not scene.hand.visible,"Enter skip gives a complete playable state")
	if scene.phase!="tutorial":
		scene.begin_play()
	var binding_count: int = InputMap.action_get_events("jump").size()
	scene._setup_inputs()
	check(InputMap.action_get_events("jump").size()==binding_count,"replay does not duplicate input bindings")
	await frames(6)
	check(scene.player.wind_enabled==false,"tutorial has no test-room wind")
	scene.player.reset_at(Vector2(920,648))
	await frames(5)
	await jump(scene,4,1060)
	check(scene.player.small_jumps==1 and scene.player.position.x>990 and scene.player.position.y<600,"small jump reaches low block")
	scene._gameplay(0.0)
	check(scene.small_cleared and "按住空格" in scene.narration.text,"landing on the block immediately prompts big jump")
	scene.player.reset_at(Vector2(1200,648))
	await frames(5)
	await jump(scene,26,1375)
	check(scene.player.big_jumps==1 and scene.player.is_on_floor() and scene.player.position.y<520,"charged big jump reaches tall wooden box")
	scene._gameplay(0.0)
	check(scene.big_cleared and "旧书" in scene.narration.text,"landing on wooden box prompts book platform")
	scene.player.reset_at(Vector2(1440,513))
	await frames(6)
	await jump(scene,26,1700)
	check(scene.player.is_on_floor() and scene.player.position.y<490,"upper book platform reachable")
	scene.player.position.x=1700
	scene.small_cleared=true
	scene.big_cleared=true
	scene.player.recovery_time=0.2
	scene.player.preparing=true
	scene.player.braced=true
	scene.player.charge_time=0.3
	scene.player.body_art.salute_weight=1.0
	scene._gameplay(0.1)
	check(scene.completed and scene.phase=="castle_arrival","standing on upper platform completes scene")
	check(scene.player.state=="站立" and scene.player.velocity==Vector2.ZERO and not scene.player.preparing and not scene.player.braced and scene.player.recovery_time==0.0,"meeting clears charge, salute, and landing recovery into standing")
	Input.action_press("move_right")
	Input.action_press("jump")
	Input.action_press("brace")
	await frames(6)
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("brace")
	check(scene.player.state=="站立" and scene.player.body_art.torso.position.y==-49 and scene.player.body_art.salute_weight==0.0,"meeting pose remains standing despite held controls")
	for time in [0.0,0.84,0.9,1.74,1.8]:
		scene._dance(time)
		var support: Vector2 = scene.dancer_axis.to_global(scene.dancer_art.position+scene.DANCER_SUPPORT_POINT)
		check(support.distance_to(scene.dancer_axis.global_position)<0.001,"supporting foot remains planted through flip at %.2f" % time)
	scene._meeting_shot(4.0)
	check(scene.camera.zoom.is_equal_approx(Vector2.ONE*scene.MEETING_ZOOM),"meeting push reaches its final close-up")
	var half_width: float = 640.0/scene.camera.zoom.x
	check(absf(scene.player.position.x-scene.camera.position.x)<half_width-40 and absf(scene.dancer_axis.position.x-scene.camera.position.x)<half_width-100,"meeting close-up keeps both characters inside the frame")
	quit(0 if failures.is_empty() else 1)
