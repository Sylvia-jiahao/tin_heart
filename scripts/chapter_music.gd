extends Node

const TRACKS={
	"opening":"res://assets/audio/chapter01/storybook_prelude.wav",
	"exploration":"res://assets/audio/chapter01/paper_castle_walk.wav",
	"dance":"res://assets/audio/chapter01/paper_dancer_waltz.wav",
	"rain":"res://assets/audio/chapter02/rain_nocturne.wav"
}
@export var exploration_volume_db: float=-12.0
@export var opening_volume_db: float=-14.0
@export var dance_volume_db: float=-10.0
@export var crossfade_seconds: float=4.5
var current_track: String=""
var players: Dictionary={}
var fade: Tween

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/chapter01/score.json"))
	var loop_points: Dictionary={}
	for entry in manifest.tracks: loop_points[entry.file]=entry
	if FileAccess.file_exists("res://assets/audio/chapter02/score.json"):
		var rain_score: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/chapter02/score.json"))
		for entry in rain_score.tracks: loop_points[entry.file]=entry
	for track in TRACKS:
		var player:=AudioStreamPlayer.new()
		player.name=str(track).to_pascal_case()
		var stream: AudioStreamWAV=load(TRACKS[track]).duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		var entry: Dictionary=loop_points[TRACKS[track].get_file()]
		stream.loop_begin=int(entry.loop_begin_frame)
		stream.loop_end=int(entry.loop_end_frame)
		player.stream=stream
		player.volume_linear=0.0
		add_child(player)
		players[track]=player

func play_exploration(restart: bool=false) -> void:
	_play("exploration",restart)

func play_opening(restart: bool=false) -> void:
	_play("opening",restart)

func play_dance() -> void:
	_play("dance",false)

func play_rain() -> void:
	_play("rain",false)

func _exit_tree() -> void:
	if is_instance_valid(fade): fade.kill()
	for player in players.values(): player.stop()

func _play(track: String,restart: bool) -> void:
	if current_track==track and not restart and players[track].playing: return
	if is_instance_valid(fade): fade.kill()
	current_track=track
	var incoming: AudioStreamPlayer=players[track]
	if restart or not incoming.playing:
		incoming.volume_linear=0.0
		incoming.play()
	var volume: float=dance_volume_db if track=="dance" else exploration_volume_db
	if track=="opening": volume=opening_volume_db
	if track=="rain": volume=-15.0
	var outgoing: Dictionary={}
	for other in players:
		if other==track: continue
		outgoing[players[other]]=players[other].volume_linear
	fade=create_tween()
	fade.tween_method(_blend.bind(incoming,incoming.volume_linear,db_to_linear(volume),outgoing),0.0,1.0,crossfade_seconds)
	fade.tween_callback(_stop_outgoing.bind(outgoing))

func _blend(progress: float,incoming: AudioStreamPlayer,start: float,target: float,outgoing: Dictionary) -> void:
	var smooth: float=progress*progress*(3.0-2.0*progress)
	var angle: float=smooth*PI*0.5
	incoming.volume_linear=lerpf(start,target,sin(angle))
	for player in outgoing: player.volume_linear=outgoing[player]*cos(angle)

func _stop_outgoing(outgoing: Dictionary) -> void:
	for player in outgoing:
		player.volume_linear=0.0
		player.stop()
