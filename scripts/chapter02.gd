extends Node2D

const ART=preload("res://scripts/rain_art.gd")
const ROOMS=preload("res://scripts/rain_rooms.gd")
const SOLDIER=preload("res://scripts/tin_soldier.gd")
const CUTOUT=preload("res://scripts/cutout_collision.gd")
const WIND=preload("res://scripts/wind_effect.gd")
const JOURNEY_ART=preload("res://scripts/journey_art.gd")
const STAR_EFFECT=preload("res://scripts/paper_star_effect.gd")
const CINEMATIC_ART=preload("res://scripts/cinematic_art.gd")
const WINDOW_FOOT:=Vector2(0,508)
const WINDOW_EDGE: float=590.0
const WIDTH: float=1280.0
const COUNT: int=36
const ROAD_ORIGIN:=Vector2(3000,0)
@export var save_path: String="user://tinheart_rain.json"
@export var start_on_street: bool=false
var phase: String="book"
var chapter_book: CanvasLayer
var window_view:=Vector2(0,-150)
var window_zoom:=Vector2.ONE*1.4
var window_backdrop: Sprite2D
var window_pane: Sprite2D
var player: CharacterBody2D
var camera: Camera2D
var ui: CanvasLayer
var heading: Label
var hint: Label
var footer: Label
var pause_label: Label
var window_root: Node2D
var sash: Node2D
var sash_right: Node2D
var curtain: Sprite2D
var paper: Sprite2D
var warm_window: Sprite2D
var panels: Array=[]
var active_room: int=0
var elapsed: float=0.0
var deaths: int=0
var skipped: Array=[]
var finished: bool=false
var clock: float=0.0
var phase_time: float=0.0
var initialized: bool=false
var wind_view: Node2D
var rain: Array[Sprite2D]=[]
var rain_motion: Array[Dictionary]=[]
var rain_rng:=RandomNumberGenerator.new()
var stars: Array[int]=[]
var star_audio: AudioStreamPlayer
var fall_start:=Vector2.ZERO
var fall_camera:=Vector2.ZERO
var melody_hold: float=0.0
var melody_seen: bool=false
var final_pan_time: float=0.0
var final_pan_start:=Vector2.ZERO
var ending_hand: Sprite2D
var boat: Sprite2D
var story: Sprite2D
var ending_start:=Vector2.ZERO
var rain_audio: AudioStreamPlayer
var wind_audio: AudioStreamPlayer
var splash_audio: AudioStreamPlayer
var memory_audio: AudioStreamPlayer
var step_audio: AudioStreamPlayer
var step_clock: float=0.0
var arrival_drop: Sprite2D
var arrival_splash: Sprite2D
var drift_background: Sprite2D
var paper_audio: AudioStreamPlayer
var storm_scraps: Array[Sprite2D]=[]
var paper_folded: bool=false
var arrival_last_beat: int=0
var arrival_origin:=Vector2.ZERO
var boat_front: Sprite2D
var last_failure: Dictionary={}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("mcp_watch")
	_inputs()
	RenderingServer.set_default_clear_color(Color("536773"))
	player=SOLDIER.new()
	player.automatic_respawn=false
	player.wind_enabled=false
	player.external_wind_enabled=true
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	player.z_index=20
	add_child(player)
	camera=Camera2D.new()
	camera.position=Vector2(640,360)
	add_child(camera)
	_background()
	_ui()
	_window()
	for i in range(COUNT): _build_room(i)
	_audio()
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.reset_at(WINDOW_FOOT)
	window_view=get_tree().get_meta("tinheart_window_view",Vector2(0,-150))
	window_zoom=get_tree().get_meta("tinheart_window_zoom",Vector2.ONE*1.4)
	for key in ["tinheart_window_view","tinheart_window_zoom"]:
		if get_tree().has_meta(key): get_tree().remove_meta(key)
	camera.position=WINDOW_FOOT+window_view
	camera.zoom=window_zoom
	camera.reset_smoothing()
	player.set_physics_process(true)
	initialized=true
	var resume: bool=get_tree().get_meta("tinheart_resume_rain",false)
	if resume:
		get_tree().remove_meta("tinheart_resume_rain")
		await _load()
		if phase=="book" and not is_instance_valid(chapter_book): await _begin_book()
	elif start_on_street:
		_enter_street(0)
	else:
		await _begin_book()

func _begin_book() -> void:
	if is_instance_valid(chapter_book): chapter_book.free()
	phase="book"
	phase_time=0
	player.reset_at(WINDOW_FOOT)
	player.hold_standing()
	camera.position=WINDOW_FOOT+window_view
	camera.zoom=window_zoom
	camera.reset_smoothing()
	window_root.visible=true
	paper.position=Vector2(-135,495)
	paper_folded=false
	var paper_source:=ART.sprite("sliding_paper",270,15)
	paper.texture=paper_source.texture
	paper.scale=paper_source.scale
	paper_source.free()
	_storm(0)
	ui.visible=false
	for particle in rain: particle.visible=false
	wind_audio.volume_db=-60
	rain_audio.volume_db=-60
	var snapshot: Texture2D=null
	if get_tree().has_meta("tinheart_chapter_snapshot"): snapshot=get_tree().get_meta("tinheart_chapter_snapshot")
	if get_tree().has_meta("tinheart_chapter_snapshot"): get_tree().remove_meta("tinheart_chapter_snapshot")
	if snapshot==null and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		snapshot=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	chapter_book=load("res://scripts/chapter_page_turn.gd").new()
	chapter_book.snapshot=snapshot
	add_child(chapter_book)
	_release_scene_cover()
	ChapterMusic.play_opening()

func _release_scene_cover() -> void:
	var cover:=get_tree().root.get_node_or_null("ChapterSceneCover")
	if cover!=null: cover.queue_free()

func _finish_book() -> void:
	if is_instance_valid(chapter_book): chapter_book.queue_free()
	phase="window"
	phase_time=0
	ui.visible=true
	player.set_physics_process(true)
	_music("rain")

func _inputs() -> void:
	var bindings={"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"brace":[KEY_SHIFT,KEY_S,KEY_DOWN],"retry_room":[KEY_R],"pause_journey":[KEY_ESCAPE],"cheat_skip":[KEY_K],"rain_continue":[KEY_C],"skip_intro":[KEY_ENTER]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event:=InputEventKey.new()
			event.physical_keycode=key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

func _picture(parent: Node,asset: String,at: Vector2,width: float,height: float=0.0,depth: int=0) -> Sprite2D:
	var picture:=ART.sprite(asset,width,height)
	picture.position=at
	picture.z_index=depth
	parent.add_child(picture)
	return picture

func _label(at: Vector2,width: float,size: int) -> Label:
	var label:=Label.new()
	label.position=at
	label.size.x=width
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color.BLACK)
	label.add_theme_color_override("font_outline_color",Color.WHITE)
	label.add_theme_constant_override("outline_size",4)
	ui.add_child(label)
	return label

func _background() -> void:
	var background:=CanvasLayer.new()
	background.layer=-20
	add_child(background)
	var surface:=TextureRect.new()
	var image:=ART.sprite("night_wall",1280)
	surface.texture=image.texture
	image.free()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode=TextureRect.STRETCH_SCALE
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.add_child(surface)

func _ui() -> void:
	ui=CanvasLayer.new()
	ui.layer=100
	add_child(ui)
	heading=_label(Vector2(45,25),1180,32)
	hint=_label(Vector2(55,95),1150,25)
	footer=_label(Vector2(45,752),1180,20)
	pause_label=_label(Vector2(450,310),500,38)
	pause_label.text="歇一会儿。\nEsc — 继续"
	pause_label.visible=false
	var pause_overlay:=CanvasLayer.new()
	pause_overlay.layer=120
	add_child(pause_overlay)
	pause_label.reparent(pause_overlay,false)
	wind_view=WIND.new()
	wind_view.process_mode=Node.PROCESS_MODE_PAUSABLE
	ui.add_child(wind_view)
	rain_rng.randomize()
	var rain_size: Vector2=get_viewport_rect().size
	for i in range(340):
		var depth: float=rain_rng.randf_range(0.35,1.0)
		var drop:=_picture(ui,"rain_thread_v3",Vector2(rain_rng.randf_range(-80,rain_size.x+80),rain_rng.randf_range(-100,rain_size.y+70)),rain_rng.randf_range(1.1,2.3),rain_rng.randf_range(28,64)*depth,-2)
		rain.append(drop)
		rain_motion.append({"speed":rain_rng.randf_range(650,1400)*depth,"drift":rain_rng.randf_range(-130,-65),"alpha":rain_rng.randf_range(0.2,0.5),"depth":depth})

func _rain_step(delta: float) -> void:
	var size: Vector2=get_viewport_rect().size
	for i in range(rain.size()):
		var particle: Sprite2D=rain[i]
		var data: Dictionary=rain_motion[i]
		var drift: float=data.drift+wind_view.strength*data.depth*0.22
		particle.position+=Vector2(drift,data.speed)*delta
		particle.rotation=-atan2(drift,data.speed)
		particle.modulate.a=data.alpha*(0.45 if active_room in [32,35] and phase=="street" else 1.0)
		if particle.position.y>size.y+70 or particle.position.x< -180 or particle.position.x>size.x+180:
			particle.position=Vector2(rain_rng.randf_range(-90,size.x+100),rain_rng.randf_range(-220,-30))
			data.speed=rain_rng.randf_range(650,1400)*data.depth

func _rect(parent: Node,rect: Rect2) -> StaticBody2D:
	var body:=StaticBody2D.new()
	body.position=rect.get_center()
	var shape:=RectangleShape2D.new()
	shape.size=rect.size
	var collider:=CollisionShape2D.new()
	collider.shape=shape
	body.add_child(collider)
	parent.add_child(body)
	return body

func _window() -> void:
	window_root=Node2D.new()
	add_child(window_root)
	# Exact first-chapter painting and scale, translated relative to its standing foot.
	# The sash is cut from that same original: at rest these pieces reconstruct it.
	var origin:=Vector2(-690,-10)
	window_backdrop=CINEMATIC_ART.sprite("window_landing",Vector2(1280,720))
	window_backdrop.position=origin
	window_backdrop.z_index=-5
	window_root.add_child(window_backdrop)
	var edge_material:=ShaderMaterial.new()
	edge_material.shader=load("res://assets/cinematics/window_edges.gdshader")
	window_backdrop.material=edge_material
	_rect(window_root,Rect2(-690,510,1280,400))
	_rect(window_root,Rect2(-285,-500,50,1010))
	# Exterior only becomes visible as the original sash rises, like a real sash window.
	var opening:=_picture(window_root,"window_rooftops_v1",origin+Vector2(428,0),762,475,-4)
	opening.visible=false
	opening.name="ExteriorOpening"
	sash=Node2D.new()
	sash.position=origin+Vector2(428,0)
	window_root.add_child(sash)
	var pane=CINEMATIC_ART.sprite("window_landing",Vector2(1280,720))
	var texture: AtlasTexture=pane.texture.duplicate()
	texture.region=Rect2(1672.0*428/1280,0,1672.0*762/1280,941.0*475/720)
	pane.texture=texture
	pane.z_index=-3
	sash.add_child(pane)
	window_pane=pane
	sash_right=Node2D.new()
	window_root.add_child(sash_right)
	curtain=_picture(window_root,"curtain_right",Vector2(500,-10),180,475,2)
	curtain.modulate.a=0
	paper=_picture(window_root,"sliding_paper",Vector2(-135,495),270,15,1)
	paper.modulate.a=0
	for i in range(5):
		storm_scraps.append(_picture(window_root,"paper_scrap",Vector2.ZERO,20+i*4,0,5))
	warm_window=_picture(self,"warm_window",Vector2(500,-400),260,280,-3)
	warm_window.visible=false

func _platform(parent: Node2D,data: Dictionary,order: int) -> Dictionary:
	var body:=AnimatableBody2D.new()
	body.sync_to_physics=false
	body.position=Vector2(data.x,data.y)
	body.rotation=float(data.angle)
	body.set_meta("wet",data.wet)
	parent.add_child(body)
	var picture:=_picture(body,data.asset,Vector2.ZERO,1440.0 if data.asset=="pavement_v2" else float(data.w))
	var shape: CollisionPolygon2D
	if data.asset in ["pavement_v2","broken_quay_v3","quay_rock_v3"]:
		# Crop rounded ends of the generated continuous masonry. Its level cap is
		# authored geometry, independent of noisy crayon flecks and rounded corner normals.
		var atlas: AtlasTexture=picture.texture
		if data.asset=="pavement_v2":
			# Select a length of the long painted road at a consistent stone scale.
			# Small boundary banks must not squeeze an entire street into 210 pixels.
			var original_width: float=atlas.region.size.x
			atlas.region.position.x+=original_width*0.045
			picture.scale=Vector2.ONE*1440.0/(original_width*0.91)
			atlas.region.size.x=float(data.w)/picture.scale.x
		elif data.asset=="quay_rock_v3":
			var inset: float=atlas.region.size.x*0.045
			atlas.region.position.x+=inset
			atlas.region.size.x-=inset*2
			picture.scale=Vector2.ONE*float(data.w)/atlas.region.size.x
			picture.scale.y=maxf(picture.scale.y,(775.0-float(data.y))/atlas.region.size.y)
		else:
			picture.flip_h=order>0
		var traced:=CUTOUT.add_to(body,picture)
		var painted_top: float=CUTOUT.surface_y([traced],float(data.w)*0.5)
		picture.position.y=-painted_top
		traced.queue_free()
		shape=CollisionPolygon2D.new()
		var depth: float=picture.texture.get_height()*picture.scale.y-painted_top
		var left: float=8.0 if data.asset=="quay_rock_v3" or (data.asset=="broken_quay_v3" and order>0) else 0.0
		var right: float=float(data.w)-(8.0 if data.asset=="quay_rock_v3" or (data.asset=="broken_quay_v3" and order==0) else 0.0)
		shape.polygon=PackedVector2Array([Vector2(left,0),Vector2(right,0),Vector2(right,depth),Vector2(left,depth)])
		body.add_child(shape)
		if order==0 and data.asset in ["pavement_v2","broken_quay_v3"]:
			# Neighbouring bank pictures overlap like their physics. Feather only the
			# internal joining edge, leaving the exposed broken right edge intact.
			var join_material:=ShaderMaterial.new()
			join_material.shader=load("res://assets/chapter02/background_edges.gdshader")
			join_material.set_shader_parameter("quay_join",true)
			join_material.set_shader_parameter("quay_join_fraction",60.0/float(data.w))
			join_material.set_shader_parameter("quay_uv_bounds",Vector2(atlas.region.position.x,atlas.region.end.x)/atlas.atlas.get_width())
			picture.material=join_material
	else:
		shape=CUTOUT.add_to(body,picture)
	# Put the real painted top at the route's intended elevation.
	var mid: float=float(data.w)*0.5
	var top: float=CUTOUT.surface_y([shape],mid)
	if is_finite(top): body.position.y-=top
	if data.motion:
		var wave:=_picture(body,"wave_crest_v2",Vector2(-float(data.w)*1.15,picture.texture.get_height()*picture.scale.y-10),float(data.w)*3.3,220,-2)
		wave.modulate.a=0.88
		var wave_material:=ShaderMaterial.new()
		wave_material.shader=load("res://assets/chapter02/background_edges.gdshader")
		wave_material.set_shader_parameter("wave_piece",true)
		var wave_texture: AtlasTexture=wave.texture
		wave_material.set_shader_parameter("wave_uv_bounds",Vector2(wave_texture.region.position.y,wave_texture.region.end.y)/wave_texture.atlas.get_height())
		wave.material=wave_material
	if data.wet:
		# A complete timber frame replaces the duplicated board/solid triangular wedge.
		var support:=_picture(parent,"trestle_v2",Vector2(data.x+15,body.position.y+sin(body.rotation)*float(data.w)*0.5+10),float(data.w)-30,0,-1)
		# Two independently seated uprights follow the sloping plank without tilting the legs.
		var original: AtlasTexture=support.texture
		var left_texture: AtlasTexture=original.duplicate()
		left_texture.region.size.x*=0.25
		support.texture=left_texture
		var right_texture: AtlasTexture=original.duplicate()
		right_texture.region.position.x+=right_texture.region.size.x*0.75
		right_texture.region.size.x*=0.25
		var right:=Sprite2D.new()
		right.texture=right_texture
		right.centered=false
		right.material=support.material
		right.scale=support.scale
		right.z_index=-1
		right.position=support.position+Vector2((float(data.w)-30)*0.75, sin(body.rotation)*(float(data.w)-30)*0.75)
		support.position.y-=sin(body.rotation)*(float(data.w)-30)*0.375
		parent.add_child(right)
	var base_position:=body.position
	return {"body":body,"shape":shape,"picture":picture,"x":float(data.x),"w":float(data.w),"base":base_position,"motion":data.motion,"order":order,"asset":data.asset,"load":0.0,"amplitude":data.get("amplitude",78.0),"period":data.get("period",3.7),"motion_phase":data.get("motion_phase",order*0.8)}

func _build_room(index: int) -> void:
	var data: Dictionary=ROOMS.room(index)
	var panel:=Node2D.new()
	panel.name="RainRegion%02d" % (index+1)
	panel.position=ROAD_ORIGIN+Vector2(index*WIDTH,0)
	add_child(panel)
	var backdrop: String="street_panorama" if index<12 else ("gutter_panorama" if index<30 else "porch_panorama")
	var background:=_picture(panel,backdrop,Vector2(-200,-160),1680,1000,-10)
	var blend:=ShaderMaterial.new()
	blend.shader=load("res://assets/chapter02/background_edges.gdshader")
	background.material=blend
	var water:=_picture(panel,"water_flow",Vector2(-200,665),1680,540,8)
	var water_material:=ShaderMaterial.new()
	water_material.shader=blend.shader
	water_material.set_shader_parameter("water_surface",true)
	water.material=water_material
	var water_texture: AtlasTexture=water.texture
	water_texture.region.position.y+=water_texture.region.size.y*0.055
	water_texture.region.size.y*=0.945
	water_material.set_shader_parameter("water_uv_top",water_texture.region.position.y/water_texture.atlas.get_height())
	var platforms: Array=[]
	for j in range(data.platforms.size()): platforms.append(_platform(panel,data.platforms[j],j))
	var drops: Array=[]
	for definition in data.drops:
		var group:=Node2D.new()
		group.position=Vector2(definition.x,0)
		panel.add_child(group)
		var roof_y: float=minf(190,float(definition.y)-380)
		_picture(group,"porch_roof",Vector2(-80,roof_y),160,85,-1)
		var gathering:=_picture(group,"gathered_drop",Vector2(-12,roof_y+74),24,36,6)
		var falling:=_picture(group,"falling_drop",Vector2(-16,roof_y+80),32,62,6)
		var ripple:=_picture(group,"ripple",Vector2(-47,float(definition.y)-4),94,16,5)
		var splash:=_picture(group,"splash",Vector2(-55,float(definition.y)-36),110,40,6)
		drops.append({"root":group,"gather":gathering,"gather_scale":gathering.scale,"fall":falling,"ripple":ripple,"splash":splash,"phase":float(definition.phase),"period":float(definition.period),"floor":float(definition.y),"active":false,"warning":false,"start_y":roof_y+85})
	var swing: Dictionary={}
	if data.swing:
		var pivot:=Node2D.new()
		pivot.position=Vector2(620,250) if index==23 else Vector2(760 if index==19 else 710,295)
		panel.add_child(pivot)
		_picture(pivot,"rope",Vector2(-4,0),8,240,1)
		var sign:=_picture(pivot,"hanging_sign",Vector2(-62,210),124,75,3)
		_picture(panel,"porch_roof",pivot.position+Vector2(-100,-90),200,90,-1)
		swing={"pivot":pivot,"sign":sign}
	if data.low:
		_picture(panel,"awning",Vector2(325,350),800,90,3)
		_rect(panel,Rect2(345,405,760,35))
	if index%4==0: _picture(panel,"drain",Vector2(1140,662),100,34,3)
	if index==22: _picture(panel,"crate",Vector2(360,400),100,190,-1)
	if index>=30:
		_picture(panel,"porch_roof",Vector2(380,175),530,130,2)
		_picture(panel,"warm_window",Vector2(700,130),135,165,-3)
	var boots: Sprite2D
	if index==35:
		_picture(panel,"newspaper",Vector2(880,620),210,30,3)
		boots=_picture(panel,"boots",Vector2(900,450),260,200,4)
		boots.visible=false
	var star: Sprite2D
	if index<35:
		star=JOURNEY_ART.sprite("paper_star",Vector2(36,36))
		star.position=data.star
		star.z_index=21
		star.set_script(STAR_EFFECT)
		panel.add_child(star)
		star.setup()
	panels.append({"root":panel,"data":data,"platforms":platforms,"drops":drops,"swing":swing,"boots":boots,"water":water,"star":star})

func _audio_player(file: String,volume: float,loop: bool=false) -> AudioStreamPlayer:
	var sound:=AudioStreamPlayer.new()
	sound.process_mode=Node.PROCESS_MODE_PAUSABLE
	if ResourceLoader.exists("res://assets/audio/chapter02/"+file):
		var stream: AudioStreamWAV=load("res://assets/audio/chapter02/"+file).duplicate()
		if loop:
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_end=stream.data.size()/(4 if stream.stereo else 2)
		sound.stream=stream
	sound.volume_db=volume
	add_child(sound)
	return sound

func _audio() -> void:
	rain_audio=_audio_player("rain.wav",-24,true)
	wind_audio=_audio_player("wind.wav",-32,true)
	splash_audio=_audio_player("splash.wav",-14)
	memory_audio=_audio_player("memory.wav",-15)
	step_audio=_audio_player("step.wav",-25)
	paper_audio=_audio_player("paper.wav",-20)
	star_audio=AudioStreamPlayer.new()
	star_audio.stream=load("res://assets/audio/sfx/paper_star_pickup.wav")
	star_audio.volume_db=-14
	star_audio.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(star_audio)
	if rain_audio.stream: rain_audio.play()
	if wind_audio.stream: wind_audio.play()

func _music(track: String) -> void:
	if ChapterMusic.has_method("play_rain"): ChapterMusic.play_rain()
	else: ChapterMusic.play_exploration()

func _process(delta: float) -> void:
	if not initialized or get_tree().paused: return
	clock+=delta
	phase_time+=delta
	if phase=="street": elapsed+=delta
	if phase=="book":
		if is_instance_valid(chapter_book): chapter_book.update_shot(phase_time)
		if Input.is_action_just_pressed("rain_continue"): _load()
		elif phase_time>=11.0 or (phase_time>0.5 and Input.is_action_just_pressed("skip_intro")): _finish_book()
		return
	_rain_step(delta)
	if phase=="window": _storm(delta)
	elif phase=="fall": _fall(delta)
	elif phase=="arrival": _arrival(delta)
	elif phase=="street": _street(delta)
	elif phase=="crossing": _crossing(delta)
	elif phase=="boat": _boat(delta)
	if phase=="window" or phase=="fall" or phase=="arrival":
		if Input.is_action_just_pressed("skip_intro"): _enter_street(0)
		elif Input.is_action_just_pressed("rain_continue"): _load()
	if phase=="street":
		if Input.is_action_just_pressed("retry_room"): _retry()
		elif Input.is_action_just_pressed("cheat_skip"):
			if not skipped.has(active_room): skipped.append(active_room)
			if active_room<35: _enter_street(active_room+1)
			else: _begin_boat()

func _storm(delta: float) -> void:
	window_root.modulate=Color.WHITE
	warm_window.visible=false
	heading.text="第二章  雨比世界大"
	footer.text="A / D 移动  空格跳跃  Shift 立正  ·  Enter 跳过开场  C 继续旅程"
	hint.text="窗外的风，忽然变大了。" if phase_time>2 else "屋里的旋律，还没有散去。"
	var strength: float=smoothstep(2.0,5.0,phase_time)
	window_root.get_node("ExteriorOpening").visible=strength>0
	window_root.get_node("ExteriorOpening").modulate=Color.WHITE.lerp(Color("8293b2"),strength*0.65)
	# Raise the original sash behind the lintel; crop hidden pixels rather than squash it.
	var travel: float=475*strength
	var pane_texture: AtlasTexture=window_pane.texture
	pane_texture.region.position.y=travel*941.0/720
	pane_texture.region.size.y=maxf(0.5,(475-travel)*941.0/720)
	window_pane.visible=strength<0.999
	curtain.modulate.a=strength
	paper.modulate.a=smoothstep(0.3,1.5,phase_time)
	for particle in rain: particle.visible=strength>0.6
	curtain.rotation=-0.35*strength+sin(clock*8)*0.045*strength
	paper.position.x+=strength*delta*115
	paper.rotation=-0.05*strength
	if strength>0.95 and paper.position.x>370 and not paper_folded:
		var lifted:=ART.sprite("folded_paper",220)
		paper.texture=lifted.texture
		paper.scale=lifted.scale
		lifted.free()
		paper_folded=true
	for i in range(storm_scraps.size()):
		storm_scraps[i].position=Vector2(fposmod(clock*(100+i*15)+i*230,1450)-100,200+sin(clock*2+i)*90)
		storm_scraps[i].rotation=clock*strength+i
		storm_scraps[i].visible=strength>0.15
		storm_scraps[i].position.x-=690
	player.environment_drift=700.0*strength
	player.brace_drift_ratio=0.2
	player.air_wind_speed_limit=800.0
	player.external_wind=1600.0*strength if not player.is_on_floor() else 0.0
	wind_view.strength=600.0*strength
	wind_audio.volume_db=lerpf(-40,-15,strength)
	rain_audio.volume_db=lerpf(-55,-27,strength)
	camera.position=camera.position.lerp(Vector2(clampf(player.render_position().x,0,410),WINDOW_FOOT.y+window_view.y),1-exp(-delta*2))
	camera.zoom=camera.zoom.lerp(Vector2.ONE*1.25,1-exp(-delta*0.35))
	if player.position.x>WINDOW_EDGE+12 and player.position.y>500:
		fall_start=player.position
		fall_camera=camera.position
		phase="fall"
		phase_time=0.0
		player.hold_standing()
		warm_window.position=Vector2(camera.position.x-95,80)
		warm_window.visible=true
		_save()

func _fall(_delta: float) -> void:
	hint.text="那扇温暖的窗，越来越远。"
	footer.text="Enter 跳过演出"
	var t: float=maxf(0,phase_time-0.5)
	player.position=fall_start+Vector2(25*t,110*t+85*t*t)
	player.rotation=0.1*sin(t*0.8)
	camera.position=fall_camera+Vector2(0,75*t)
	warm_window.scale=Vector2.ONE*lerpf(1.0,0.25,clampf(t/4.5,0,1))
	window_root.modulate=Color.WHITE.lerp(Color("607889"),clampf(t/3,0,1))
	window_root.modulate.a=1.0-smoothstep(0.6,2.0,t)
	warm_window.visible=t>0.6
	warm_window.modulate.a=smoothstep(0.6,2.0,t)
	if phase_time>=5.5:
		_begin_arrival()

func _begin_arrival() -> void:
	_enter_street(0,false)
	phase="arrival"
	phase_time=0
	player.hold_standing()
	arrival_origin=player.position
	player.body_art.play_cinematic_pose("rise",0)
	camera.zoom=Vector2.ONE*2.2
	camera.position=arrival_origin+Vector2(30,-65)
	arrival_drop=_picture(self,"falling_drop",arrival_origin+Vector2(125,-400),60,105,25)
	arrival_splash=_picture(self,"splash",arrival_origin+Vector2(90,-30),160,60,25)
	arrival_last_beat=0
	if splash_audio.stream: splash_audio.play()

func _arrival(_delta: float) -> void:
	heading.text="雨中的独腿人"
	footer.text="Enter — 跳过演出"
	hint.text="他躺了一会儿。" if phase_time<0.9 else ("然后，用手撑住湿冷的石板。" if phase_time<4.2 else "一滴、两滴。\n原来，这只是普通的雨。")
	player.body_art.play_cinematic_pose("rise",phase_time)
	var t: float=smoothstep(3.8,6.3,phase_time)
	camera.zoom=Vector2.ONE*lerpf(2.2,1.0,t)
	camera.position=arrival_origin+Vector2(lerpf(30,360,t),lerpf(-65,-180,t))
	if is_instance_valid(arrival_drop):
		var count: int=int(phase_time/1.3)
		if count>arrival_last_beat and count<3:
			arrival_last_beat=count
			if splash_audio.stream: splash_audio.play()
		var beat: float=fposmod(phase_time,1.3)
		arrival_drop.visible=phase_time<3.9 and beat<0.65
		arrival_drop.position.y=player.position.y-420+380*clampf(beat/0.65,0,1)
		arrival_splash.visible=phase_time<3.9 and beat>=0.65 and beat<1.0
	if phase_time>6.5:
		phase="street"
		phase_time=0
		player.body_art.clear_cinematic_pose()
		player.body_art._process(0)
		player.set_physics_process(true)
		if is_instance_valid(arrival_drop): arrival_drop.queue_free()
		if is_instance_valid(arrival_splash): arrival_splash.queue_free()
		_save()

func _enter_street(index: int,persist: bool=true) -> void:
	_release_scene_cover()
	if is_instance_valid(arrival_drop): arrival_drop.queue_free()
	if is_instance_valid(arrival_splash): arrival_splash.queue_free()
	arrival_drop=null
	arrival_splash=null
	phase="street"
	phase_time=0.0
	active_room=clampi(index,0,35)
	if is_instance_valid(chapter_book): chapter_book.queue_free()
	ui.visible=true
	for particle in rain: particle.visible=true
	window_root.visible=false
	window_root.modulate=Color.WHITE
	warm_window.visible=false
	for panel in panels: panel.root.visible=true
	for p in panels:
		if p.star!=null: p.star.visible=not stars.has(int(p.data.index))
	player.rotation=0.0
	player.scale=Vector2.ONE
	player.external_wind=0.0
	player.air_wind_speed_limit=320.0
	var panel: Dictionary=panels[active_room]
	var platform: Dictionary=panel.platforms[0]
	var x: float=150.0-platform.body.position.x
	var floor_y: float=CUTOUT.surface_y([platform.shape],x)
	player.reset_at(panel.root.position+Vector2(150,platform.body.position.y+floor_y-2))
	player.set_physics_process(true)
	camera.position=panel.root.position+Vector2(640,440)
	camera.zoom=Vector2.ONE
	for drop in panel.drops:
		drop.active=false
		drop.splash.visible=false
		phase_time=0
	for reset_platform in panel.platforms:
		reset_platform.body.position=reset_platform.base
		reset_platform.load=0.0
	if not panel.swing.is_empty(): panel.swing.pivot.rotation=0.0
	wind_view.strength=0
	wind_view.clear()
	_music("rain")
	if persist: _save()

func _street(delta: float) -> void:
	var next: int=clampi(int((player.position.x-ROAD_ORIGIN.x)/WIDTH),0,35)
	if next!=active_room:
		active_room=next
		phase_time=0
		_save()
	var panel: Dictionary=panels[active_room]
	var data: Dictionary=panel.data
	var local: Vector2=player.position-panel.root.position
	heading.text="%s  ·  %02d / 36  %s" % [data.group,active_room+1,data.name]
	hint.text=data.hint
	footer.text="A/D 移动  空格跳跃  Shift 立正  R 重试  Esc 暂停  K 跳过  ·  纸星 %d/35  失败 %d" % [stars.size(),deaths]
	var gust: float=_gust_at(data,phase_time)
	player.external_wind=float(data.wind)*gust if local.x>320 and local.x<1060 else 0.0
	# The lee of the broad crate is a visible local wind shelter.
	if active_room==22 and local.x>410 and local.x<585: player.external_wind=0.0
	wind_view.strength=player.external_wind
	player.wet_surface_slide=0
	if player.is_on_floor():
		for c in range(player.get_slide_collision_count()):
			var hit: KinematicCollision2D=player.get_slide_collision(c)
			if hit.get_normal().y< -0.5 and hit.get_collider().get_meta("wet",false): player.wet_surface_slide=340.0
	for i in range(maxi(0,active_room-1),mini(COUNT,active_room+2)): _mechanisms(panels[i],delta)
	_update_stars()
	var target:=Vector2(clampf(player.render_position().x,ROAD_ORIGIN.x+640,ROAD_ORIGIN.x+COUNT*WIDTH-640),440)
	if data.kind=="melody" and local.x>350 and local.x<1000 and player.braced:
		melody_hold+=delta
		if melody_hold>=2:
			if not melody_seen and memory_audio.stream: memory_audio.play()
			melody_seen=true
			target+=Vector2(90,-100)
			hint.text="那几个音符，像极了她的舞曲。"
	else: melody_hold=0.0
	camera.position=camera.position.lerp(target,1-exp(-delta*4))
	camera.zoom=camera.zoom.lerp(Vector2.ONE,1-exp(-delta*2))
	rain_audio.volume_db=lerpf(rain_audio.volume_db,-32.0 if data.calm else -23.0,1-exp(-delta*2))
	wind_audio.volume_db=lerpf(wind_audio.volume_db,-25.0 if absf(player.external_wind)>50 else -45.0,1-exp(-delta*2))
	if player.state=="走路":
		step_clock+=delta
		if step_clock>0.27:
			step_clock=0
			if step_audio.stream: step_audio.play()
	if active_room==35 and local.x>700:
		panel.boots.visible=true
		if phase_time>1.5 and local.x>1000: _begin_boat()
	if active_room==29 and local.x>1100 and player.is_on_floor() and final_pan_time==0:
		phase="crossing"
		phase_time=0
		final_pan_start=camera.position
		player.hold_standing()
	if player.position.y>920 or local.x< -150: _retry()

func _gust_at(data: Dictionary,time: float) -> float:
	var t: float=fposmod(time,float(data.wind_period))
	if int(data.index)==19:
		# Shared six-second score: leftward opening and an ample calm overlap every cycle.
		return smoothstep(3.2,3.65,t)*(1.0-smoothstep(5.55,5.95,t))
	return smoothstep(0,0.4,t)*(1.0-smoothstep(1.65,2.25,t))

func _update_stars() -> void:
	for i in range(maxi(0,active_room-1),mini(COUNT,active_room+2)):
		var star: Sprite2D=panels[i].star
		if star!=null and star.visible: star.update_effect(clock)
	var star: Sprite2D=panels[active_room].star
	if star==null or not star.visible: return
	if player.body_art.touches_star(star.global_position):
		stars.append(active_room)
		star.visible=false
		star_audio.play()
		_save()

func _mechanisms(panel: Dictionary,_delta: float) -> void:
	panel.water.material.set_shader_parameter("water_clock",clock)
	for platform in panel.platforms:
		if platform.motion:
			var occupied: bool=false
			if player.is_on_floor():
				for i in range(player.get_slide_collision_count()):
					if player.get_slide_collision(i).get_collider()==platform.body: occupied=true
			platform.load=move_toward(float(platform.load),12.0 if occupied else 0.0,_delta*24.0)
			platform.body.position=platform.base+Vector2(0,sin(phase_time*TAU/platform.period+platform.motion_phase)*platform.amplitude+float(platform.load))
	for drop in panel.drops:
		for support in panel.platforms:
			var x: float=drop.root.position.x-support.body.position.x
			if x>=0 and x<=support.w:
				# Use the actual world-space top, including rotated wet boards.
				var local_x: float=x/maxf(0.8,cos(support.body.rotation))
				var top: float=CUTOUT.surface_y([support.shape],local_x)
				if is_finite(top): drop.floor=support.body.to_global(Vector2(local_x,top)).y-panel.root.position.y
		drop.ripple.position.y=drop.floor-4
		drop.splash.position.y=drop.floor-36
		var period: float=drop.period
		var t: float=fposmod(phase_time+drop.phase,period)
		var impact_time: float=period-0.26
		var fall_time: float=impact_time-0.36
		drop.warning=t>=impact_time-0.95 and t<impact_time
		var was_active: bool=drop.active
		drop.active=t>=impact_time
		if drop.active and not was_active and panel==panels[active_room]:
			if splash_audio.stream:
				splash_audio.volume_db=-24
				splash_audio.play()
		drop.gather.visible=t<fall_time
		var swelling: float=lerpf(0.2,1.15,smoothstep(0,fall_time,t))
		drop.gather.scale=drop.gather_scale*swelling
		drop.gather.position.x=-12*swelling
		drop.fall.visible=t>=fall_time and t<impact_time
		drop.fall.position.y=lerpf(drop.start_y,drop.floor-55,clampf((t-fall_time)/0.36,0,1))
		drop.ripple.visible=drop.warning
		drop.splash.visible=drop.active
		if drop.fall.visible:
			var water: Vector2=drop.fall.global_position
			var wet_body:=Rect2(water,Vector2(32,62))
			var soldier_body:=Rect2(player.position+Vector2(-12,-103),Vector2(24,103))
			if wet_body.intersects(soldier_body):
				if splash_audio.stream: splash_audio.play()
				_retry("falling_drop")
				return
		if drop.active:
			var landing: Vector2=panel.root.position+Vector2(drop.root.position.x,drop.floor)
			if absf(player.position.x-landing.x)<47 and player.position.y>landing.y-75 and player.position.y<landing.y+35:
				if splash_audio.stream: splash_audio.play()
				_retry("drop_splash")
				return
	if not panel.swing.is_empty():
		panel.swing.pivot.rotation=sin(phase_time*TAU/panel.data.swing_period+(1.1 if panel.data.index==23 else 0.0))*0.48
		var impact: Vector2=panel.swing.pivot.to_global(Vector2(0,245))
		if impact.distance_to(player.position+Vector2(0,-52))<62: _retry("swing")

func _crossing(delta: float) -> void:
	player.clock+=delta
	final_pan_time+=delta
	hint.text="他晃了一下。\n但这一次，他站稳了。"
	camera.position=final_pan_start+Vector2(-70*sin(clampf(phase_time/2.4,0,1)*PI),0)
	camera.zoom=Vector2.ONE*(1.0-0.08*sin(clampf(phase_time/2.4,0,1)*PI))
	if phase_time>2.4:
		phase="street"
		phase_time=0
		player.set_physics_process(true)

func _retry(reason: String="fall_or_retry") -> void:
	if phase!="street": return
	last_failure={"room":active_room+1,"position":player.position-panels[active_room].root.position,"time":phase_time,"reason":reason}
	deaths+=1
	_enter_street(active_room)

func _begin_boat() -> void:
	phase="boat"
	phase_time=0.0
	player.hold_standing()
	player.z_index=31
	ending_start=player.position
	if paper_audio.stream: paper_audio.play()
	ending_hand=_picture(self,"hand_pinch_vertical",player.position+Vector2(-78,-1100),190,0,30)
	boat=_picture(self,"newspaper_boat",player.position+Vector2(100,100),270,100,18)
	boat_front=Sprite2D.new()
	boat_front.texture=boat.texture
	boat_front.centered=false
	boat_front.z_as_relative=false
	boat_front.z_index=22
	var front_material:=ShaderMaterial.new()
	front_material.shader=load("res://assets/chapter02/boat_front.gdshader")
	var atlas: AtlasTexture=boat.texture
	front_material.set_shader_parameter("atlas_region",Vector4(atlas.region.position.x/atlas.atlas.get_width(),atlas.region.position.y/atlas.atlas.get_height(),atlas.region.size.x/atlas.atlas.get_width(),atlas.region.size.y/atlas.atlas.get_height()))
	boat_front.material=front_material
	boat.add_child(boat_front)
	boat.visible=false
	story=_picture(ui,"storybook_find_v2",Vector2.ZERO,get_viewport_rect().size.x,get_viewport_rect().size.y,-1)
	story.visible=false
	drift_background=_picture(self,"drift_panorama",ending_start+Vector2(-700,-600),2300,1200,-2)
	drift_background.visible=false
	_save()

func _pinch_top(at: Vector2) -> Vector2:
	var height: float=ending_hand.texture.get_height()*ending_hand.scale.y
	return at+Vector2(-78,-85-height*0.99)

func _boat(_delta: float) -> void:
	heading.text=""
	footer.text=""
	if phase_time<3:
		hint.text="一双手，轻轻把他举了起来。"
		var t: float=smoothstep(0.0,1.5,phase_time)
		ending_hand.position=_pinch_top(ending_start)+Vector2(0,-500*(1-t))
		if phase_time>1.5:
			var lift: float=140*smoothstep(1.5,3.0,phase_time)
			player.position=ending_start+Vector2(0,-lift)
			ending_hand.position.y-=lift
	elif phase_time<12:
		ending_hand.visible=false
		player.visible=false
		story.visible=true
		var asset: String="storybook_find_v2" if phase_time<6 else ("storybook_fold_v2" if phase_time<9 else "storybook_place_v4")
		if story.name!=asset:
			var new_image:=ART.sprite(asset,get_viewport_rect().size.x,get_viewport_rect().size.y)
			story.texture=new_image.texture
			story.scale=new_image.scale
			story.name=asset
			new_image.free()
			if asset=="storybook_fold_v2" and paper_audio.stream: paper_audio.play()
		hint.text="两个孩子，发现了雨里的锡兵。" if phase_time<6 else ("他们折了一只小船。" if phase_time<9 else "把他放进了船里。")
		hint.position=Vector2(60,660)
	else:
		story.visible=false
		drift_background.visible=true
		for panel in panels: panel.root.visible=false
		boat.visible=true
		player.visible=true
		player.z_index=20
		var t: float=phase_time-12
		boat.position=ending_start+Vector2(80+t*75,30+sin(t*1.8)*5)
		player.position=boat.position+Vector2(130,112)
		player.body_art.play_cinematic_pose("boat_hold")
		camera.position=ending_start+Vector2(150+t*40,-100)
		camera.zoom=Vector2.ONE
		hint.position=Vector2(65,90)
		hint.text="他想回到那扇窗前。\n可是雨水，却带他去了更远的地方。"
		if t>7:
			finished=true
			phase="end"
			heading.text="第二章  完"
			_save()

func _save() -> void:
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"chapter":2,"room":active_room,"seconds":elapsed,"deaths":deaths,"skipped":skipped,"stars":stars,"finished":finished,"phase":"boat" if phase=="boat" else ("window" if phase in ["book","window","fall"] else "street")}))

func _load() -> void:
	if not FileAccess.file_exists(save_path): return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary: return
	elapsed=float(data.get("seconds",0))
	deaths=int(data.get("deaths",0))
	stars.clear()
	for saved_star in data.get("stars",[]):
		var number: int=int(saved_star)
		if number>=0 and number<35 and not stars.has(number): stars.append(number)
	skipped=[]
	for saved_room in data.get("skipped",[]):
		var number: int=int(saved_room)
		if number>=0 and number<COUNT and not skipped.has(number): skipped.append(number)
	var saved_phase: String=data.get("phase","window")
	if saved_phase=="window":
		await _begin_book()
		return
	_enter_street(int(data.get("room",0)),false)
	if saved_phase=="boat" or bool(data.get("finished",false)): _begin_boat()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_journey"):
		get_tree().paused=not get_tree().paused
		pause_label.visible=get_tree().paused
		get_viewport().set_input_as_handled()

func _mcp_state() -> Dictionary:
	return {"chapter":2,"phase":phase,"room":active_room+1,"regions":panels.size(),"deaths":deaths,"seconds":elapsed,"wind":player.external_wind,"drift":player.environment_drift,"wet":player.wet_surface_slide,"finished":finished}
