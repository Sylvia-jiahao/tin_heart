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
	await frames(300)
	var music=root.get_node("ChapterMusic")
	check(music.current_track=="opening" and music.players.opening.playing,"book uses its own prelude")
	chapter.begin_play()
	await frames(300)
	check(music.current_track=="exploration" and music.players.exploration.playing,"chapter starts the exploration BGM")
	check(absf(music.players.exploration.volume_db-music.exploration_volume_db)<0.1,"BGM fades in at the intended quiet volume")
	for key in music.players:
		var stream: AudioStreamWAV=music.players[key].stream
		if key=="rain":
			check(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_begin==0 and stream.loop_end==2116800,"rain score uses its circularly synthesized 48-second loop")
		else:
			check(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_begin>0 and stream.loop_end>stream.loop_begin and stream.get_length()>50,"track uses baked tail/head bridge and an interior loop start: "+key)
	var font: Font=chapter.title.get_theme_font("font")
	check("nani" in font.get_font_name().to_lower() or "何某" in font.get_font_name(),"title uses Nani handwriting font: "+font.get_font_name())
	check(chapter.title.get_theme_color("font_color")==Color.BLACK and chapter.journey.heading.get_theme_color("font_color")==Color.BLACK,"text is black with the new font's native solid strokes")
	check(chapter.narration.get_theme_font("font").get_font_name()==font.get_font_name() and chapter.journey.heading.get_theme_font("font").get_font_name()==font.get_font_name(),"narration and journey UI use the same selected font")
	var missing: String=""
	for path in ["res://scripts/chapter01.gd","res://scripts/tabletop_journey.gd","res://scripts/journey_rooms.gd"]:
		for character in FileAccess.get_file_as_string(path):
			var code: int=character.unicode_at(0)
			if code>=0x4e00 and code<=0x9fff and not font.has_char(code) and not character in missing: missing+=character
	check(missing.is_empty(),"Chinese text has no missing glyphs: "+missing)
	chapter._enter_journey(true)
	var before: float=music.players.exploration.get_playback_position()
	chapter.journey._load_room(1)
	await frames(3)
	check(music.current_track=="exploration" and music.players.exploration.get_playback_position()>=before,"region retry preserves BGM instead of restarting it")
	paused=true
	await process_frame
	check(music.players.exploration.stream_paused,"pause also pauses BGM")
	paused=false
	await process_frame
	check(not music.players.exploration.stream_paused,"resume continues BGM")
	chapter.journey._load_room(29)
	chapter.player.global_position=chapter.journey.room_root.global_position+Vector2(1235,548)
	chapter.journey._enter_meeting()
	await frames(1)
	check(music.current_track=="dance" and music.players.dance.playing and music.players.exploration.playing,"meeting begins the waltz with overlapping crossfade")
	await frames(134)
	var a: float=music.players.exploration.volume_linear/db_to_linear(music.exploration_volume_db)
	var b: float=music.players.dance.volume_linear/db_to_linear(music.dance_volume_db)
	check(absf(a*a+b*b-1.0)<0.05 and a>0.4 and b>0.4,"long equal-power crossfade preserves a smooth middle level")
	await frames(166)
	check(not music.players.exploration.playing and music.players.dance.playing and absf(music.players.dance.volume_db-music.dance_volume_db)<0.1,"crossfade finishes with only the dance track playing")
	print("AUDIO_FONT_RESULT ",failures)
	# Let the audio thread release its last playback references before headless shutdown.
	if is_instance_valid(music.fade): music.fade.kill()
	for player in music.players.values():
		player.stop()
		player.stream=null
	OS.delay_msec(80)
	quit(0 if failures.is_empty() else 1)
