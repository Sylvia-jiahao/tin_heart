extends SceneTree
var DIR="E:/tinheart/chapter02_qa/bridge"
func _init() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func photo(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+"/"+name+".png")
func capture() -> void:
	if "--wide" in OS.get_cmdline_user_args(): DIR+="_wide"
	DirAccess.make_dir_recursive_absolute(DIR)
	var chapter=load("res://scenes/chapter01_paper_castle.tscn").instantiate()
	root.add_child(chapter)
	current_scene=chapter
	await frames(8)
	chapter.journey.save_path=DIR+"/first.json"
	chapter._enter_journey(true)
	var journey=chapter.journey
	journey._load_room(29)
	chapter.player.global_position=journey.room_root.global_position+Vector2(1235,548)
	journey._enter_meeting()
	journey.window_cinematic.start()
	journey.phase="window_carry"
	await frames(650)
	journey.hint.visible=false
	await photo("01_sill_end")
	journey._turn_chapter_page()
	await frames(15)
	var next=current_scene
	next.save_path=DIR+"/second.json"
	next.set_process(false)
	for t in [0.0,2.5,4.0,6.5,10.0]:
		next.chapter_book.update_shot(t)
		await photo("book_%02d" % int(t*10))
	next._finish_book()
	next.player.hold_standing()
	await photo("02_sill_return")
	for t in [0.0,3.5,5.0]:
		next.phase_time=t
		next._storm(0)
		await photo("storm_%02d" % int(t*10))
	print("CHAPTER_TRANSITION_CAPTURE_DONE ",root.size)
	quit()
