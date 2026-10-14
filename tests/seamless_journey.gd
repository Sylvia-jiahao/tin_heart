extends SceneTree

var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ",description)
	if not ok: failures.append(description)

func verify() -> void:
	var chapter=load("res://scenes/chapter01_paper_castle.tscn").instantiate()
	root.add_child(chapter)
	current_scene=chapter
	await frames(8)
	chapter.set_process(false)
	chapter.begin_play()
	chapter.small_cleared=true
	chapter.big_cleared=true
	chapter.journey.save_path="E:/tinheart/journey_qa/seamless_save.json"
	chapter.player.reset_at(Vector2(1850,468))
	await frames(5)
	Input.action_press("brace")
	for i in range(90):
		chapter._gameplay(1.0/60.0)
		await frames(1)
	Input.action_release("brace")
	check(chapter.brace_taught and chapter.brace_gate.get_child(0).disabled,"attention lesson opens the passage after standing against wind")
	check(chapter.tutorial_wind.streaks.size()>15,"tutorial has full-screen wind strokes")
	var actor_id: int=chapter.player.get_instance_id()
	var camera_id: int=chapter.camera.get_instance_id()
	chapter.player.reset_at(Vector2(2450,548))
	await frames(5)
	Input.action_press("move_right")
	for i in range(40):
		chapter._gameplay(1.0/60.0)
		await frames(1)
		if chapter.phase=="journey": break
	Input.action_release("move_right")
	check(current_scene==chapter and chapter.phase=="journey","walking from tutorial enters journey without replacing the scene")
	check(chapter.journey.player.get_instance_id()==actor_id and chapter.journey.camera.get_instance_id()==camera_id,"handoff reuses the same actor and camera")
	var journey=chapter.journey
	var cached_ids: Array=[]
	for panel in journey.panels: cached_ids.append(panel.root.get_instance_id())
	journey._load_room(0)
	chapter.player.global_position=journey.room_root.global_position+Vector2(1230,588)
	await frames(6)
	Input.action_press("move_right")
	var biggest_step: float=0.0
	var prev: float=chapter.player.global_position.x
	for i in range(45):
		await frames(1)
		biggest_step=maxf(biggest_step,absf(chapter.player.global_position.x-prev))
		prev=chapter.player.global_position.x
	Input.action_release("move_right")
	check(journey.room_index==1 and biggest_step<6.0,"boundary crossing preserves continuous movement without teleporting")
	check(journey.panels[0].root.get_instance_id()==cached_ids[0] and journey.panels[1].root.get_instance_id()==cached_ids[1] and journey.transition==0.0,"crossing uses existing regions with no rebuild or transition pause")
	var skip_key:=InputEventKey.new()
	skip_key.physical_keycode=KEY_K
	skip_key.pressed=true
	Input.parse_input_event(skip_key)
	await frames(2)
	skip_key.pressed=false
	Input.parse_input_event(skip_key)
	check(journey.room_index==2 and 1 in journey.skipped,"K skips the current region and records the cheat")
	journey._load_room(29)
	chapter.player.global_position=journey.room_root.global_position+Vector2(1235,548)
	await frames(8)
	check(current_scene==chapter and journey.finished and journey.phase=="castle_arrival","dancer meeting is part of the final region in the same chapter")
	check(chapter.player.state=="站立","final meeting forces standing")
	print("SEAMLESS_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
