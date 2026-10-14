extends SceneTree
func _init() -> void: call_deferred("verify")
func verify() -> void:
	var music=root.get_node("ChapterMusic")
	var failed: bool=false
	for key in music.players:
		var player: AudioStreamPlayer=music.players[key]
		var stream: AudioStreamWAV=player.stream
		player.play(stream.get_length()-0.08)
		await process_frame
		OS.delay_msec(250)
		await process_frame
		var expected: float=float(stream.loop_begin)/stream.mix_rate
		var actual: float=player.get_playback_position()
		var ok: bool=player.playing and actual>=expected-0.05 and actual<expected+1.0
		print("PASS " if ok else "FAIL ","native loop continues into bridge exit: ",key," expected=",expected," actual=",actual)
		if not ok: failed=true
		player.stop()
		player.stream=null
	OS.delay_msec(80)
	print("MUSIC_LOOP_RESULT ",failed)
	quit(1 if failed else 0)
