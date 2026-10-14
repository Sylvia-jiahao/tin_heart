extends SceneTree
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func verify() -> void:
	var chapter=load("res://scenes/chapter01_paper_castle.tscn").instantiate()
	root.add_child(chapter)
	current_scene=chapter
	await frames(12)
	check(chapter.phase=="book_opening" and chapter.book_opening.visible,"desk book is the opening sequence")
	check(root.get_node("ChapterMusic").current_track=="opening","book uses independent music")
	var opening=chapter.book_opening
	check((opening.spread.texture as AtlasTexture).region.size.x==(opening.inside.texture as AtlasTexture).region.size.x,"fixed page only contains right half, never a full duplicate spread")
	opening.update_shot(3.5)
	check(not opening.inside.visible and opening.chapter_title.modulate.a==0,"left page and text stay hidden until cover turns past spine")
	opening.update_shot(5.0)
	check(opening.inside.visible and opening.inside.position.x>-500 and opening.chapter_title.modulate.a==0,"left page gradually unfolds with no complete page behind it")
	opening.update_shot(9.5)
	check(opening.chapter_title.modulate.a>0.9 and opening.narration.modulate.a>0.9,"text appears on new pages only after opening")
	await frames(910)
	check(chapter.phase=="cinematic" and not chapter.book_opening.visible and chapter.cg_time>=4 and chapter.cg_time<5,"book transitions into child taking soldiers out, skipping old title page")
	check(not chapter.page.visible and not chapter.title.visible and not chapter.subtitle.visible,"old title page stays hidden during box cinematic")
	check(chapter.hand.visible and chapter.placed_count<2 and not chapter.player.is_physics_processing(),"box cinematic begins with toys in box and player controls locked")
	check(root.get_node("ChapterMusic").current_track=="exploration","music changes to chapter track")
	await frames(1800)
	check(chapter.phase=="tutorial" and chapter.placed_count==24 and not chapter.hand.visible,"child finishes placing soldiers before tutorial control")
	chapter._enter_journey(true)
	check(not chapter.book_opening.visible,"skipping or continuing cannot leave book overlay visible")
	var journey=chapter.journey
	journey.save_path="E:/tinheart/journey_qa/book_window_save.json"
	journey._load_room(29)
	chapter.player.global_position=journey.room_root.global_position+Vector2(1235,548)
	journey._enter_meeting()
	var start: Vector2=chapter.player.global_position
	Input.action_press("move_right")
	await frames(550)
	check(journey.phase=="castle_arrival" and chapter.player.global_position.distance_to(start)<1,"early input cannot interrupt ten-second dance viewing")
	Input.action_release("move_right")
	await frames(65)
	check(journey.phase=="meeting_ready" and chapter.player.is_physics_processing(),"controls unlock after at least ten seconds")
	check(not journey.window_cinematic.running,"waiting without new input does not trigger hand")
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	check(journey.phase=="window_carry" and journey.window_cinematic.running and not chapter.player.is_physics_processing(),"fresh player input starts hand and locks movement during carry")
	await frames(620)
	check(journey.phase=="window_end" and journey.window_cinematic.settled,"hand completes window ending")
	check(chapter.player.global_position.distance_to(journey.window_cinematic.target)<1 and chapter.player.state=="站立","soldier settles on sill without falling")
	check(not journey.window_cinematic.hand.visible,"hand retreats after release")
	print("BOOK_WINDOW_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
