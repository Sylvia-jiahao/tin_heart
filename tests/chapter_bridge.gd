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
	journey.phase="window_carry"
	await frames(620)
	if journey.phase!="window_end":
		print("FAIL first chapter must end standing on sill")
		quit(1)
		return
	print("PASS first chapter still ends on the sill")
	var expected_zoom: Vector2=journey.camera.zoom
	var expected_view: Vector2=journey.camera.global_position-journey.player.global_position
	Input.action_press("skip_intro")
	await frames(10)
	Input.action_release("skip_intro")
	var next: Node=current_scene
	if next.get_script().resource_path!="res://scripts/chapter02.gd":
		print("FAIL Enter did not open chapter two")
		quit(1)
		return
	next.save_path="E:/tinheart/chapter02_qa/bridge_second_save.json"
	var ok: bool=next.phase=="book" and next.panels.size()==36 and not next.player.is_physics_processing()
	ok=ok and next.player.position.distance_to(next.WINDOW_FOOT)<1
	ok=ok and next.camera.zoom.distance_to(expected_zoom)<0.01
	ok=ok and (next.camera.position-next.player.position).distance_to(expected_view)<1
	print("PASS " if ok else "FAIL ","Enter opens book while carrying the original window composition")
	next.chapter_book.update_shot(6.5)
	ok=ok and next.chapter_book.title.modulate.a>0.99
	ok=ok and not next.chapter_book.scene_picture.visible
	print("PASS " if ok else "FAIL ","page flips before the second chapter title appears")
	paused=true
	var frozen: float=next.phase_time
	await frames(4)
	ok=ok and is_equal_approx(next.phase_time,frozen)
	paused=false
	next.phase_time=3.5
	Input.action_press("skip_intro")
	await frames(3)
	Input.action_release("skip_intro")
	ok=ok and next.phase=="window"
	await frames(125)
	ok=ok and next.phase=="window" and next.player.is_physics_processing() and next.deaths==0
	print("PASS " if ok else "FAIL ","book returns to the same sill before the playable storm")
	print("CHAPTER_BRIDGE_RESULT ",ok)
	quit(0 if ok else 1)
