extends SceneTree
## Run with normal rendering and --fixed-fps 120; observe after the frame was drawn.
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await RenderingServer.frame_post_draw
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func verify() -> void:
	var chapter=load("res://scenes/chapter02_rain.tscn").instantiate()
	chapter.start_on_street=true
	chapter.save_path="E:/tinheart/chapter02_qa/render_motion_save.json"
	root.add_child(chapter)
	current_scene=chapter
	await frames(15)
	var actor=chapter.player
	Input.action_press("move_right")
	await frames(30)
	var previous: float=actor.body_art.global_position.x
	var smallest: float=INF
	var largest: float=0
	var physical_holds: int=0
	var physical_previous: float=actor.position.x
	for i in range(60):
		await RenderingServer.frame_post_draw
		var step: float=actor.body_art.global_position.x-previous
		smallest=minf(smallest,step)
		largest=maxf(largest,step)
		if is_equal_approx(actor.position.x,physical_previous): physical_holds+=1
		previous=actor.body_art.global_position.x
		physical_previous=actor.position.x
	check(smallest>2.10 and largest<2.23,"120 Hz rendered movement advances evenly, without held or backward frames")
	check(physical_holds>=29 and physical_holds<=31,"collision still advances at the unchanged 60 Hz rate")
	Input.action_release("move_right")
	actor.reset_at(chapter.ROAD_ORIGIN+Vector2(600,650))
	check(actor.body_art.position==Vector2.ZERO,"checkpoint reset clears the visual offset immediately")
	Input.action_press("move_right")
	await frames(30)
	var previous_screen: float=actor.body_art.global_position.x-chapter.camera.position.x
	var reverse: int=0
	for i in range(60):
		await RenderingServer.frame_post_draw
		var screen: float=actor.body_art.global_position.x-chapter.camera.position.x
		if screen<previous_screen-0.02: reverse+=1
		previous_screen=screen
	check(reverse==0,"following camera introduces no alternating backward character steps")
	paused=true
	var frozen: Vector2=actor.body_art.global_position
	await frames(4)
	check(actor.body_art.global_position==frozen,"pause freezes the interpolated picture")
	paused=false
	Input.action_release("move_right")
	actor.hold_standing()
	check(actor.body_art.position==Vector2.ZERO,"cinematic standing clears interpolation and leaves no trail")
	print("MOTION_RENDER_RESULT ",failures," step range ",smallest,"..",largest)
	quit(0 if failures.is_empty() else 1)
