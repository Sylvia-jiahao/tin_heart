extends SceneTree

func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func verify() -> void:
	DirAccess.make_dir_recursive_absolute("E:/tinheart/chapter02_qa")
	var chapter=load("res://scenes/chapter01_paper_castle.tscn").instantiate()
	root.add_child(chapter)
	current_scene=chapter
	await frames(8)
	chapter.journey.save_path="E:/tinheart/chapter02_qa/bridge_first_save.json"
	chapter._enter_journey(true)
	var journey=chapter.journey
	journey._load_room(29)
	chapter.player.global_position=journey.room_root.global_position+Vector2(1235,548)
	journey._enter_meeting()
	journey.window_cinematic.start()
	journey.window_cinematic.clock=9.6
	journey.phase="window_carry"
	journey._meeting_shot(0)
	if journey.phase!="window_end":
		print("FAIL first chapter must end standing on sill")
		quit(1)
		return
	print("PASS first chapter still ends on the sill")
	Input.action_press("skip_intro")
	await frames(10)
	Input.action_release("skip_intro")
	var next: Node=current_scene
	if next.get_script().resource_path!="res://scripts/chapter02.gd":
		print("FAIL Enter did not open chapter two")
		quit(1)
		return
	next.save_path="E:/tinheart/chapter02_qa/bridge_second_save.json"
	var ok: bool=next.phase=="window" and next.panels.size()==36 and next.player.is_physics_processing()
	print("PASS " if ok else "FAIL ","Enter opens chapter two without accidentally skipping the storm")
	print("CHAPTER_BRIDGE_RESULT ",ok)
	quit(0 if ok else 1)
