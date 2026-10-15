extends SceneTree
## Check every rendered loading frame, rather than only settled chapter screenshots.
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func verify() -> void:
	var directory: String="E:/tinheart/chapter02_qa/flash"
	if "--wide" in OS.get_cmdline_user_args(): directory+="_wide"
	DirAccess.make_dir_recursive_absolute(directory)
	var chapter=load("res://scenes/chapter01_paper_castle.tscn").instantiate()
	root.add_child(chapter)
	current_scene=chapter
	await frames(8)
	chapter.journey.save_path=directory+"/first.json"
	chapter._enter_journey(true)
	var journey=chapter.journey
	journey._load_room(29)
	chapter.player.global_position=journey.room_root.global_position+Vector2(1235,548)
	journey._enter_meeting()
	journey.window_cinematic.start()
	journey.phase="window_carry"
	await frames(650)
	journey._turn_chapter_page()
	var covered: bool=true
	var desk_opaque: bool=true
	var load_frames: int=0
	for i in range(40):
		await RenderingServer.frame_post_draw
		var incoming: Node=current_scene
		var book_ready: bool=false
		if incoming!=null and incoming.get_script().resource_path=="res://scripts/chapter02.gd":
			book_ready=is_instance_valid(incoming.chapter_book)
			if book_ready:
				desk_opaque=desk_opaque and is_equal_approx(incoming.chapter_book.desk.modulate.a,1.0)
			else:
				load_frames+=1
				covered=covered and root.get_node_or_null("ChapterSceneCover")!=null
		elif incoming==null:
			load_frames+=1
			covered=covered and root.get_node_or_null("ChapterSceneCover")!=null
		if i<12 or i==39: root.get_texture().get_image().save_png(directory+"/frame_%02d.png" % i)
	check(covered and load_frames>0,"outgoing frame covers every rendered scene-load gap")
	check(desk_opaque,"opaque desk fills every early book frame around the shrinking picture")
	var next=current_scene
	next.save_path=directory+"/second.json"
	check(root.get_node_or_null("ChapterSceneCover")==null,"temporary root cover is removed once the book is ready")
	next.set_process(false)
	for t in [0.1,0.5,1.0,2.0,8.9]:
		next.chapter_book.update_shot(t)
		check(is_equal_approx(next.chapter_book.desk.modulate.a,1.0),"next chapter stays covered before the final reveal at t="+str(t))
	next.chapter_book.update_shot(10)
	check(next.chapter_book.desk.modulate.a>0 and next.chapter_book.desk.modulate.a<1,"intentional scene reveal still fades at the end of the chapter page")
	print("CHAPTER_FLASH_RESULT ",failures," loading frames ",load_frames)
	quit(0 if failures.is_empty() else 1)
