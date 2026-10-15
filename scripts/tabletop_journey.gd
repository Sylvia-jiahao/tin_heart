extends Node2D

const ART=preload("res://scripts/journey_art.gd")
const OLD_ART=preload("res://scripts/chapter_art.gd")
const ROOMS=preload("res://scripts/journey_rooms.gd")
const SOLDIER=preload("res://scripts/tin_soldier.gd")
const WIND=preload("res://scripts/wind_effect.gd")
const STAR_EFFECT=preload("res://scripts/paper_star_effect.gd")
const DRESS=preload("res://scripts/set_dressing.gd")
const CUTOUT=preload("res://scripts/cutout_collision.gd")
const SAVE_PATH="user://tinheart_journey.json"
const ROOM_WIDTH=1280.0
var save_path: String=SAVE_PATH
var embedded: bool=false
var active: bool=true
var player: CharacterBody2D
var room_root: Node2D
var camera: Camera2D
var room_index: int=0
var room_time: float=0.0
var elapsed: float=0.0
var deaths: int=0
var stars: Array=[]
var skipped: Array=[]
var platforms: Array=[]
var swings: Array=[]
var panels: Array=[]
var gear: Sprite2D
var star: Sprite2D
var windmill: Sprite2D
var room: Dictionary
var heading: Label
var hint: Label
var footer: Label
var ui: CanvasLayer
var wind_view: Node2D
var transition: float=0.0
var initialized: bool=false
var finished: bool=false
var phase: String="journey"
var dancer_axis: Node2D
var meeting_time: float=0.0
var meeting_start:=Vector2.ZERO
var meeting_zoom:=Vector2.ONE
var window_cinematic: Node2D
var meeting_input_ready: bool=false
var star_pickup_sound: AudioStreamPlayer

func _ready() -> void:
	if not embedded: ChapterMusic.play_exploration(true)
	star_pickup_sound=AudioStreamPlayer.new()
	star_pickup_sound.name="StarPickupSound"
	star_pickup_sound.stream=load("res://assets/audio/sfx/paper_star_pickup.wav")
	star_pickup_sound.volume_db=-14.0
	star_pickup_sound.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(star_pickup_sound)
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("mcp_watch")
	_setup_inputs()
	if camera==null:
		camera=Camera2D.new()
		camera.position=Vector2(640,400)
		add_child(camera)
	if player==null:
		player=SOLDIER.new()
		player.z_index=20
		add_child(player)
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	_ui()
	_wall()
	var starting_index: int=room_index
	for i in range(30): _build_panel(i)
	room_index=starting_index
	var resume: bool=get_tree().get_meta("tinheart_resume_journey",false)
	if resume:
		_load_save()
		get_tree().remove_meta("tinheart_resume_journey")
	var completed_save: bool=finished
	finished=false
	active=not embedded
	ui.visible=active
	_select_room(room_index)
	if active:
		_load_room(room_index)
		if completed_save:
			player.global_position=room_root.global_position+Vector2(1230,550)
			_enter_meeting()
	initialized=true
	if active: _save()

func _setup_inputs() -> void:
	# Remove the old binding during hot reload; F8 belongs to the editor's Stop command.
	if InputMap.has_action("cheat_skip"):
		InputMap.action_erase_events("cheat_skip")
	var bindings={"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"brace":[KEY_SHIFT,KEY_S,KEY_DOWN],"retry_room":[KEY_R],"pause_journey":[KEY_ESCAPE],"cheat_skip":[KEY_K]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event:=InputEventKey.new()
			event.physical_keycode=key
			if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

func _label(parent: Node, at: Vector2, width: float, size: int) -> Label:
	var label:=Label.new()
	label.position=at
	label.size.x=width
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color.BLACK)
	label.add_theme_color_override("font_outline_color",Color.WHITE)
	label.add_theme_constant_override("outline_size",4)
	parent.add_child(label)
	return label

func _ui() -> void:
	ui=CanvasLayer.new()
	ui.layer=100
	add_child(ui)
	heading=_label(ui,Vector2(45,28),1160,32)
	hint=_label(ui,Vector2(45,80),1180,24)
	footer=_label(ui,Vector2(45,752),1180,21)
	wind_view=WIND.new()
	ui.add_child(wind_view)

func _wall() -> void:
	var wall:=Sprite2D.new()
	wall.texture=load("res://assets/journey/quiet_wall.png")
	wall.centered=false
	wall.region_enabled=true
	wall.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.region_rect=Rect2(0,0,ROOM_WIDTH*30+2200,wall.texture.get_height())
	wall.scale.y=1300.0/wall.texture.get_height()
	wall.position=Vector2(-700,-250)
	wall.z_index=-20
	add_child(wall)

func _picture(asset: String, size: Vector2, at: Vector2, depth: int=0) -> Sprite2D:
	var picture:=ART.sprite(asset,size)
	picture.position=at
	picture.z_index=depth
	room_root.add_child(picture)
	return picture

func _build_panel(index: int) -> void:
	room_index=index
	room=ROOMS.get_room(index)
	platforms=[]
	swings=[]
	gear=null
	room_root=Node2D.new()
	room_root.name="Area%02d" % (index+1)
	room_root.position=Vector2(index*ROOM_WIDTH,0)
	room_root.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(room_root)
	var backdrop:=_picture(room.background,Vector2(1460,1050),Vector2(-90,-130),-10)
	var atlas: AtlasTexture=backdrop.texture
	atlas.region.size.y*=0.78
	backdrop.scale.y=1050.0/atlas.region.size.y
	var blend:=ShaderMaterial.new()
	blend.shader=load("res://assets/journey/background_blend.gdshader")
	backdrop.material=blend
	var apron:=OLD_ART.sprite("desk_apron",Vector2(1280,160))
	apron.position=Vector2(0,720)
	apron.z_index=30
	room_root.add_child(apron)
	if index==29:
		room.platforms[-1].x=1010.0
		room.platforms[-1].w=800.0
	for i in range(room.platforms.size()): _platform(room.platforms[i],index,i)
	for data in room.branches: _platform(data,index,7)
	if not room.ceiling.is_empty():
		var c: Array=room.ceiling
		_platform({"x":c[0],"y":c[1],"w":c[2],"kind":"wood","ceiling":true,"height":c[3]},index,8)
	for data in room.swings:
		var arm:=Node2D.new()
		arm.position=data.pivot
		arm.z_index=8
		room_root.add_child(arm)
		var rod:=ART.sprite("pendulum_bob",Vector2(12,data.length),Rect2(456,155,119,795))
		rod.position=Vector2(-6,0)
		arm.add_child(rod)
		var bob:=ART.sprite("pendulum_bob",Vector2(75,75),Rect2(220,940,585,565))
		bob.position=Vector2(-37.5,data.length-37.5)
		arm.add_child(bob)
		var pin:=OLD_ART.sprite("brass_pin",Vector2(18,18))
		pin.position=Vector2(-9,-9)
		arm.add_child(pin)
		swings.append({"node":arm,"length":data.length,"period":data.period,"phase":data.phase})
	if index in [12,27]: gear=_picture("toy_gear",Vector2(58,58),Vector2(700,580),8)
	star=_picture("paper_star",Vector2(36,36),room.star,12)
	star.set_script(STAR_EFFECT)
	star.setup()
	if index!=29: _picture("bookmark_flag",Vector2(44,64),Vector2(1175,room.finish_y-64),5)
	windmill=_picture("wind_pinwheel",Vector2(72,72),Vector2(1196,171),2)
	windmill.centered=true
	windmill.visible=absf(room.wind)>0.0
	panels.append({"root":room_root,"data":room,"platforms":platforms,"swings":swings,"gear":gear,"star":star,"windmill":windmill,"time":0.0})
	if index==29:
		_castle()
		window_cinematic=load("res://scripts/window_cinematic.gd").new()
		room_root.add_child(window_cinematic)
		window_cinematic.setup(player,camera)

func _platform(data: Dictionary,index: int,ordinal: int) -> void:
	var moving: bool=data.kind=="ruler"
	var ceiling: bool=data.get("ceiling",false)
	var body: PhysicsBody2D=AnimatableBody2D.new() if moving else StaticBody2D.new()
	if moving: body.sync_to_physics=false
	var height: float=data.get("height",40.0)
	var ground_height: float=maxf(50,735.0-data.y)
	var solid_stack: bool=not moving and data.kind!="paper" and not ceiling and ordinal!=7
	body.position=Vector2(data.x,data.y)
	room_root.add_child(body)
	var picture: Sprite2D
	var ropes: Array=[]
	var zone: int=index/5
	if index==29 and ordinal==room.platforms.size()-1 and not ceiling:
		picture=DRESS.fitted("v4_castle_books",Vector2(data.w,ground_height))
	elif moving:
		picture=ART.sprite("ruler_lift",Vector2(data.w,height))
		for x in [data.w*0.22,data.w*0.78]:
			ropes.append(_suspension(body,x))
	elif data.kind=="paper":
		picture=ART.sprite("v3_paper_bridge_%d" % (1+(index+ordinal)%2),Vector2(data.w,height))
		var uniform: float=data.w/picture.texture.get_width()
		picture.scale=Vector2.ONE*uniform
		for x in [data.w*0.12,data.w*0.88]:
			ropes.append(_suspension(body,x))
	elif ceiling:
		picture=DRESS.wall_shelf(body,data.w,index,true)
	elif ordinal==7:
		picture=DRESS.wall_shelf(body,data.w,index+ordinal)
	else:
		picture=DRESS.complete_stack(body,index,ordinal,data.w,ground_height)
	if picture.get_parent()==null:
		body.add_child(picture)
	var shapes: Array=[]
	var graphics: Array[Sprite2D]=[]
	for child in body.get_children():
		if child is Sprite2D and not child.has_meta("suspension_knot"):
			graphics.append(child)
	if solid_stack:
		shapes.append(CUTOUT.add_stack(body,graphics))
	else:
		for child in graphics:
			var collider:=CUTOUT.add_to(body,child)
			collider.one_way_collision=not solid_stack and not ceiling
			collider.one_way_collision_margin=8.0
			shapes.append(collider)
	var actual_bounds:=CUTOUT.bounds(shapes)
	if ceiling:
		# Brackets are part of the shelf: place its visible underside at the intended ceiling.
		body.position.y=data.y+height-actual_bounds.end.y
	var landing_span: Vector2=shapes[0].get_meta("landing_span",Vector2(actual_bounds.position.x,actual_bounds.end.x))
	platforms.append({"body":body,"shape":shapes[0],"shapes":shapes,"bounds":actual_bounds,"landing_span":landing_span,"picture":picture,"ropes":ropes,"data":data,"timer":-1.0,"gone":false,"base":body.position})
	_update_suspensions(body,ropes)

func _suspension(body: PhysicsBody2D,x: float) -> Dictionary:
	var axis:=Node2D.new()
	axis.position=Vector2(body.position.x+x,165)
	axis.z_index=1
	room_root.add_child(axis)
	var cord:=ART.sprite("v4_cotton_cord",Vector2(3,300))
	cord.position.x=-1.5
	axis.add_child(cord)
	var anchor:=ART.sprite("v4_rope_anchor",Vector2(17,23),Rect2(688,97,166,230))
	anchor.position=Vector2(-anchor.texture.get_width()*anchor.scale.x*0.5,-16)
	anchor.z_index=2
	room_root.add_child(anchor)
	anchor.position+=axis.position
	var knot:=DRESS.fitted("v4_cord_knot",Vector2(12,24))
	knot.position=Vector2(x-6,-5)
	knot.set_meta("suspension_knot",true)
	body.add_child(knot)
	return {"axis":axis,"cord":cord,"x":x,"knot":knot}

func _update_suspensions(body: PhysicsBody2D,ropes: Array) -> void:
	for rope in ropes:
		var end:=body.position+Vector2(rope.x,2)
		var difference: Vector2=end-rope.axis.position
		rope.axis.rotation=Vector2.DOWN.angle_to(difference)
		rope.cord.scale=Vector2(3.0/rope.cord.texture.get_width(),difference.length()/rope.cord.texture.get_height())

func _castle() -> void:
	var base: Dictionary=platforms[room.platforms.size()-1]
	var floor_y: float=base.body.position.y+CUTOUT.surface_y(base.shapes,1430-base.body.position.x)
	var castle_size:=Vector2(540,345)*(430.0/540.0)
	var castle:=OLD_ART.sprite("paper_castle",castle_size)
	castle.position=Vector2(1200,floor_y-castle_size.y+8.0)
	castle.z_index=5
	room_root.add_child(castle)
	dancer_axis=Node2D.new()
	dancer_axis.position=Vector2(1430,floor_y)
	dancer_axis.z_index=15
	room_root.add_child(dancer_axis)
	var scale_factor: float=142.0/177.0
	var dancer:=OLD_ART.sprite("paper_dancer",Vector2(118,177)*scale_factor)
	dancer.position=-Vector2(45,174)*scale_factor
	dancer_axis.add_child(dancer)
	var apron:=OLD_ART.sprite("desk_apron",Vector2(800,160))
	apron.position=Vector2(1280,720)
	apron.z_index=30
	room_root.add_child(apron)

func _select_room(index: int) -> void:
	room_index=clampi(index,0,29)
	var panel: Dictionary=panels[room_index]
	room_root=panel.root
	room=panel.data
	platforms=panel.platforms
	swings=panel.swings
	gear=panel.gear
	star=panel.star
	windmill=panel.windmill
	room_time=panel.time
	star.visible=not room_index in stars
	heading.text="%s  ·  %02d / 30  %s" % [room.zone,room_index+1,room.name]
	hint.text=room.hint
	_footer()

func _load_room(index: int) -> void:
	_select_room(index)
	wind_view.clear()
	room_time=0.0
	panels[room_index].time=0.0
	for p in platforms:
		p.timer=-1.0
		p.gone=false
		p.body.position=p.base
		for collider in p.shapes: collider.set_deferred("disabled",false)
		_update_suspensions(p.body,p.ropes)
		p.picture.visible=true
		p.picture.rotation=0.0
		p.picture.modulate.a=1.0
	player.reset_at(player.get_parent().to_local(room_root.global_position+Vector2(100,648)))
	player.facing=1.0
	player.external_wind_enabled=true
	player.external_wind=0.0
	player.wind_enabled=false
	player.automatic_respawn=false
	player.set_physics_process(true)
	camera.global_position=room_root.global_position+Vector2(640,400)
	camera.zoom=Vector2.ONE

func activate() -> void:
	active=true
	ui.visible=true
	player.automatic_respawn=false
	player.external_wind_enabled=true
	player.wind_enabled=false
	_select_room(0)
	_save()

func resume() -> void:
	active=true
	ui.visible=true
	_load_save()
	var completed_save: bool=finished
	finished=false
	_load_room(room_index)
	if completed_save:
		player.global_position=room_root.global_position+Vector2(1235,550)
		_enter_meeting()

func _physics_process(delta: float) -> void:
	if not initialized or not active or get_tree().paused: return
	if finished:
		_meeting_shot(delta)
		return
	elapsed+=delta
	room_time+=delta
	panels[room_index].time=room_time
	if Input.is_action_just_pressed("retry_room"):
		_retry()
		return
	if Input.is_action_just_pressed("cheat_skip"):
		_skip_room()
		return
	var local: Vector2=room_root.to_local(player.global_position)
	if local.x>=ROOM_WIDTH and room_index<29:
		_select_room(room_index+1)
		_save()
		local=room_root.to_local(player.global_position)
	for i in range(maxi(0,room_index-1),mini(30,room_index+2)):
		if i!=room_index: panels[i].time+=delta
		_tick_panel(panels[i],i,delta)
		if room_root.to_local(player.global_position).x<190 and player.position.y>700: break
	var gust: float=pow(maxf(0.0,sin(room_time*TAU/5.5)),2.0)
	player.external_wind=room.wind*gust if local.x>200 and local.x<1080 else 0.0
	wind_view.strength=room.wind*gust
	if player.global_position.y>805 or local.x<-35:
		_retry()
		return
	if room_index==29 and local.x>1230 and _standing_on(platforms[room.platforms.size()-1].body):
		_enter_meeting()

func _process(delta: float) -> void:
	if not initialized or not active or finished or get_tree().paused: return
	# Follow the rendered actor each frame, rather than a stepped 60 Hz target.
	var ahead: float=player.render_global_position().x+100
	var left_limit: float=640.0 if embedded else global_position.x+640.0
	var right_limit: float=global_position.x+ROOM_WIDTH*29+1450
	camera.global_position=camera.global_position.lerp(Vector2(clampf(ahead,left_limit,right_limit),400),1.0-exp(-delta*5.0))

func _standing_on(body: PhysicsBody2D) -> bool:
	if not player.is_on_floor(): return false
	for contact in range(player.get_slide_collision_count()):
		if player.get_slide_collision(contact).get_collider()==body: return true
	return false

func _tick_panel(panel: Dictionary,index: int,delta: float) -> void:
	var local: Vector2=panel.root.to_local(player.global_position)
	for p in panel.platforms:
		var data: Dictionary=p.data
		if data.kind=="ruler":
			p.body.position=p.base+data.motion*sin(panel.time*TAU/data.period+data.phase)
			_update_suspensions(p.body,p.ropes)
		elif data.kind=="paper":
			var stood: bool=_standing_on(p.body)
			if stood and p.timer<0: p.timer=0.0
			if p.timer>=0:
				p.timer+=delta
				if p.timer<1.05:
					p.picture.rotation=sin(p.timer*45)*0.015*p.timer
					p.picture.modulate.a=1-p.timer*0.3
				elif not p.gone:
					p.gone=true
					for collider in p.shapes: collider.set_deferred("disabled",true)
					p.picture.visible=false
				elif p.timer>3.8:
					p.timer=-1.0
					p.gone=false
					for collider in p.shapes: collider.set_deferred("disabled",false)
					p.picture.visible=true
					p.picture.modulate.a=1.0
					p.picture.rotation=0.0
	for swing in panel.swings:
		swing.node.rotation=sin(panel.time*TAU/swing.period+swing.phase)*0.67
		if index==room_index and _hits(swing.node.to_global(Vector2(0,swing.length)),32):
			_retry()
			return
	if is_instance_valid(panel.gear):
		panel.gear.position=Vector2(700+sin(panel.time*1.7)*85,580)
		panel.gear.rotation=panel.time*1.4
		panel.gear.centered=true
		if index==room_index and _hits(panel.gear.global_position,26):
			_retry()
			return
	var gust: float=pow(maxf(0.0,sin(panel.time*TAU/5.5)),2.0)
	panel.windmill.rotation+=delta*gust*7*signf(panel.data.wind)
	panel.star.update_effect(panel.time)
	if index==room_index and panel.star.visible and player.body_art.touches_star(panel.star.global_position):
		stars.append(index)
		panel.star.visible=false
		star_pickup_sound.play()
		_save()
		_footer()

func _hits(at: Vector2,radius: float) -> bool:
	var box:=Rect2(player.global_position+Vector2(-10,-120),Vector2(20,120))
	var nearest:=Vector2(clampf(at.x,box.position.x,box.end.x),clampf(at.y,box.position.y,box.end.y))
	return at.distance_to(nearest)<radius

func _retry() -> void:
	deaths+=1
	_load_room(room_index)
	_save()

func _advance() -> void:
	if room_index==29:
		_enter_meeting()
	else:
		_select_room(room_index+1)
		_save()

func _skip_room() -> void:
	if not room_index in skipped: skipped.append(room_index)
	if room_index<29:
		_load_room(room_index+1)
	else:
		player.global_position=room_root.global_position+Vector2(1235,550)
		_enter_meeting()
	_save()

func _enter_meeting() -> void:
	ChapterMusic.play_dance()
	finished=true
	phase="castle_arrival"
	var base: Dictionary=platforms[room.platforms.size()-1]
	var local_x: float=player.global_position.x-base.body.global_position.x
	var floor_y: float=CUTOUT.surface_y(base.shapes,local_x)
	if is_finite(floor_y): player.global_position.y=base.body.global_position.y+floor_y
	player.hold_standing()
	player.external_wind=0.0
	wind_view.strength=0.0
	meeting_start=camera.global_position
	meeting_zoom=camera.zoom
	meeting_time=0.0
	meeting_input_ready=false
	heading.visible=false
	footer.visible=false
	hint.text="纸城堡里，\n站着一位纸做的舞蹈家。"
	_save()

func _meeting_shot(delta: float) -> void:
	if phase=="chapter_bridge": return
	if phase=="window_carry" or phase=="window_end":
		window_cinematic.update_shot(delta)
		if window_cinematic.settled:
			phase="window_end"
			hint.text="第一章 完\nEnter — 翻到下一页"
			if Input.is_action_just_pressed("skip_intro"):
				_turn_chapter_page()
		return
	meeting_time+=delta
	player.clock+=delta
	var t:=clampf(meeting_time/3.2,0,1)
	var ease:=t*t*(3-2*t)
	var target:=Vector2((player.global_position.x+dancer_axis.global_position.x)*0.5,room_root.global_position.y+480)
	camera.global_position=meeting_start.lerp(target,ease)
	camera.zoom=meeting_zoom.lerp(Vector2.ONE*2.15,ease)
	var dance:=fposmod(meeting_time,1.8)
	var horizontal:=1.0
	if dance>0.78 and dance<0.90: horizontal=lerpf(1,-1,(dance-0.78)/0.12)
	elif dance>=0.90 and dance<1.68: horizontal=-1
	elif dance>=1.68: horizontal=lerpf(-1,1,(dance-1.68)/0.12)
	dancer_axis.scale.x=horizontal
	if meeting_time>=10.0:
		if phase=="castle_arrival":
			phase="meeting_ready"
			player.set_physics_process(true)
		var actions: Array=["move_left","move_right","jump","brace"]
		var any_held:=false
		var new_press:=false
		for action in actions:
			any_held=any_held or Input.is_action_pressed(action)
			new_press=new_press or Input.is_action_just_pressed(action)
		if not any_held: meeting_input_ready=true
		if meeting_input_ready and new_press:
			phase="window_carry"
			hint.text="一只手伸了过来。"
			window_cinematic.start()

func _turn_chapter_page() -> void:
	phase="chapter_bridge"
	hint.visible=false
	get_tree().set_meta("tinheart_window_view",camera.global_position-player.global_position)
	get_tree().set_meta("tinheart_window_zoom",camera.zoom)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var snapshot:=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		get_tree().set_meta("tinheart_chapter_snapshot",snapshot)
		# Scene changes detach the old scene before the new chapter finishes _ready().
		# Keep the outgoing frame on the root so neither the clear color nor new art leaks.
		var cover:=CanvasLayer.new()
		cover.name="ChapterSceneCover"
		cover.layer=109
		var picture:=TextureRect.new()
		picture.texture=snapshot
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		cover.add_child(picture)
		get_tree().root.add_child(cover)
	get_tree().change_scene_to_file("res://scenes/chapter02_rain.tscn")

func _footer() -> void:
	footer.text="A / D 移动  空格小跳 / 蓄力大跳  Shift 立正  R 重试  Esc 暂停  K 跳过本关（作弊）  ·  纸星 %d / 30" % stars.size()

func _save() -> void:
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify({"room":room_index,"seconds":elapsed,"deaths":deaths,"stars":stars,"skipped":skipped,"finished":finished}))

func _load_save() -> void:
	if not FileAccess.file_exists(save_path): return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary:
		room_index=clampi(int(data.get("room",0)),0,29)
		elapsed=float(data.get("seconds",0))
		deaths=int(data.get("deaths",0))
		stars=data.get("stars",[])
		skipped=data.get("skipped",[])
		finished=bool(data.get("finished",false))

func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("pause_journey"):
		get_tree().paused=not get_tree().paused
		hint.text="歇一会儿。按 Esc 继续。" if get_tree().paused else room.hint
		get_viewport().set_input_as_handled()

func _mcp_state() -> Dictionary:
	return {"room":room_index+1,"name":room.name,"seconds":elapsed,"deaths":deaths,"stars":stars.size(),"wind":player.external_wind,"player":player.global_position,"transition":transition,"cached_regions":panels.size(),"phase":phase,"skipped":skipped}
