extends Node2D

const ART = preload("res://scripts/chapter_art.gd")
const SOLDIER = preload("res://scripts/tin_soldier.gd")
const HAND = preload("res://scripts/child_hand.gd")
const INTRO_DURATION: float = 33.0
const PLACE_INTERVAL: float = 0.75
var phase: String = "cinematic"
var cg_time: float = 0.0
var player: CharacterBody2D
var hand: Node2D
var camera: Camera2D
var soldiers: Array[Node2D] = []
var page: Sprite2D
var title: Label
var subtitle: Label
var narration: Label
var help: Label
var dancer_axis: Node2D
var dancer_art: Sprite2D
const DANCER_SCALE: float = 142.0/177.0
const DANCER_SIZE := Vector2(118,177)*DANCER_SCALE
const DANCER_SUPPORT_POINT := Vector2(45,174)*DANCER_SCALE
var placed_count: int = 0
var checkpoint := Vector2(875,648)
var initialized: bool = false
var completed: bool = false
var ending_time: float = 0.0
var meeting_camera_start := Vector2.ZERO
var meeting_zoom_start := Vector2.ONE
const MEETING_PUSH_DURATION: float = 3.2
const MEETING_ZOOM: float = 2.15
var small_cleared: bool = false
var big_cleared: bool = false

func _ready() -> void:
	add_to_group("mcp_watch")
	_setup_inputs()
	RenderingServer.set_default_clear_color(Color("efe4cd"))
	# One panoramic painting keeps the entire room continuous during camera travel.
	_picture(self,"room_panorama",Vector2(2720,820),Vector2(-80,-120),-10)
	_picture(self,"desk_surface",Vector2(2720,175),Vector2(-80,475),-5)
	_picture(self,"desk_apron",Vector2(2720,450),Vector2(-80,650),-4)
	_picture(self,"tabletop",Vector2(2720,70),Vector2(-80,650),21)
	_solid(Rect2(0,650,2400,150))
	_picture(self,"box_back",Vector2(310,205),Vector2(75,445),0)
	_picture(self,"box_front",Vector2(310,28),Vector2(75,626),14)
	for i in range(24):
		var item := Node2D.new()
		item.name = "Brother%02d" % (i+1)
		var sprite := ART.sprite("regular_soldier",Vector2(43,138))
		sprite.position = Vector2(-21.5,-138)
		item.add_child(sprite)
		add_child(item)
		soldiers.append(item)
		_box_pose(i)
	_player()
	_picture(self,"small_block",Vector2(120,55),Vector2(980,595),4)
	_solid(Rect2(980,595,120,55))
	_picture(self,"wooden_box",Vector2(180,135),Vector2(1280,515),4)
	_solid(Rect2(1280,515,180,135))
	_picture(self,"books_platform",Vector2(700,210),Vector2(1560,440),4)
	_solid(Rect2(1560,470,700,180))
	_picture(self,"paper_castle",Vector2(540,345),Vector2(1720,125),5)
	_picture(self,"thread_spool",Vector2(60,95),Vector2(40,545),2)
	_picture(self,"loose_buttons",Vector2(60,42),Vector2(860,575),2)
	_picture(self,"loose_buttons",Vector2(45,32),Vector2(1500,597),2)
	dancer_axis = Node2D.new()
	dancer_axis.name = "DancerOuterAxis"
	dancer_axis.position = Vector2(1963,470)
	dancer_axis.z_index = 15
	add_child(dancer_axis)
	# Offset the painting so its supporting toe remains at the axis during a flip.
	dancer_art = _picture(dancer_axis,"paper_dancer",DANCER_SIZE,-DANCER_SUPPORT_POINT,0)
	hand = HAND.new()
	hand.z_index = 50
	add_child(hand)
	HUD()
	camera = Camera2D.new()
	camera.position = Vector2(640,400)
	camera.position_smoothing_enabled = false
	add_child(camera)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_physics_process(false)
	initialized = true
	_cinematic()

func _player() -> void:
	player = SOLDIER.new()
	player.wind_enabled = false
	player.world_right = 2380
	player.respawn_position = checkpoint
	player.position = checkpoint
	player.z_index = 20
	add_child(player)

func _setup_inputs() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"brace":[KEY_SHIFT,KEY_S,KEY_DOWN],"skip_intro":[KEY_ENTER],"replay_chapter":[KEY_R]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action,event):
				InputMap.action_add_event(action,event)

func _picture(parent: Node, asset: String, dimensions: Vector2, at: Vector2, depth: int = 0, region: Rect2 = Rect2()) -> Sprite2D:
	var picture := ART.sprite(asset,dimensions,region)
	picture.position = at
	picture.z_index = depth
	parent.add_child(picture)
	return picture

func _solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.position = rect.get_center()
	body.add_child(collision)
	add_child(body)

func HUD() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 100
	add_child(ui)
	page = _picture(ui,"storybook_blank",Vector2(1280,800),Vector2.ZERO,0)
	title = _label(ui,"第一章  纸城堡",Vector2(100,270),1080,49)
	subtitle = _label(ui,"第二十五个锡兵",Vector2(100,355),1080,28)
	# Typography is rendered live; the paper underneath is generated artwork.
	narration = _label(ui,"",Vector2(800,315),450,26)
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	narration.add_theme_constant_override("outline_size",3)
	narration.add_theme_color_override("font_outline_color",Color("efe4cd"))
	narration.z_index = 2
	help = _label(ui,"Enter 跳过演出   ·   R 重播",Vector2(760,28),480,16)
	help.z_index = 3

func _label(parent: Node, text: String, at: Vector2, width: float, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("4d3e32"))
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	if not initialized:
		return
	if Input.is_action_just_pressed("replay_chapter"):
		get_tree().reload_current_scene()
		return
	if phase == "cinematic":
		cg_time += delta
		player.clock += delta
		_cinematic()
		if cg_time >= INTRO_DURATION or Input.is_action_just_pressed("skip_intro"):
			begin_play()
	else:
		_gameplay(delta)

func _source(i: int) -> Vector2:
	return Vector2(160+(i%5)*46,535+(i/5)*21)

func _destination(i: int) -> Vector2:
	return Vector2(465+(i%6)*61,560+(i/6)*30)

func _box_pose(i: int) -> void:
	soldiers[i].position = _source(i)
	soldiers[i].rotation = -PI/2.0
	soldiers[i].scale = Vector2(0.42,0.42)
	soldiers[i].z_index = 6

func _table_pose(i: int) -> void:
	soldiers[i].position = _destination(i)
	soldiers[i].rotation = 0
	soldiers[i].scale = Vector2.ONE
	soldiers[i].z_index = 8+i/6

func _ease(value: float) -> float:
	var t := clampf(value,0,1)
	return t*t*(3.0-2.0*t)

func _cinematic() -> void:
	var t := cg_time
	narration.position = Vector2(800,315)
	narration.size.x = 450
	page.modulate.a = 1.0-_ease((t-2.5)/2.0)
	title.modulate.a = 1.0-_ease((t-2.8)/1.0)
	subtitle.modulate.a = title.modulate.a
	placed_count = clampi(int((t-4.0)/PLACE_INTERVAL),0,24)
	for i in range(24):
		if i < placed_count:
			_table_pose(i)
		else:
			_box_pose(i)
	player.position = Vector2(345,630)
	player.scale = Vector2(0.42,0.42)
	player.rotation = -PI/2.0
	player.body_art.rotation = 0
	hand.visible = t >= 4.0 and t < 27.0
	hand.grip = 0
	if t >= 4.0 and t < 22.0:
		var i: int = mini(placed_count,23)
		var u: float = fposmod(t-4.0,PLACE_INTERVAL)/PLACE_INTERVAL
		var progress := _ease((u-0.22)/0.52)
		var item := soldiers[i]
		item.position = _source(i).lerp(_destination(i),progress)+Vector2(0,-sin(progress*PI)*100)
		item.rotation = lerpf(-PI/2.0,0.0,progress)
		item.scale = Vector2.ONE*lerpf(0.42,1.0,progress)
		item.z_index = 51
		var grip_point: Vector2 = item.to_global(Vector2(0,-85))
		hand.position = grip_point+Vector2(12,-142)
		if u < 0.22:
			hand.position.y -= (1.0-_ease(u/0.22))*100
		elif u > 0.78:
			hand.position.y -= _ease((u-0.78)/0.22)*100
		hand.grip = _ease(u/0.22)*(1.0-_ease((u-0.76)/0.16))
	elif t >= 22.0:
		var progress := _ease((t-22.4)/3.0)
		player.position = Vector2(345,630).lerp(checkpoint,progress)+Vector2(0,-sin(progress*PI)*130)
		player.rotation = lerpf(-PI/2.0,0,progress)
		player.scale = Vector2.ONE*lerpf(0.42,1.0,progress)
		player.z_index = 51 if t < 26.0 else 20
		hand.position = player.to_global(Vector2(0,-85))+Vector2(12,-142)
		hand.grip = _ease((t-22.0)/0.6)*(1.0-_ease((t-25.4)/0.6))
		if t > 25.4:
			hand.position.y -= _ease((t-25.4)/1.6)*260
		if t >= 26.0:
			var wobble: float = clampf((t-26.0)/2.4,0,1)
			player.body_art.rotation = sin(wobble*TAU*2.0)*0.13*(1.0-wobble)
	if t < 4.0:
		narration.text = ""
	elif t < 22.0:
		narration.text = "盒子里有\n二十五个锡兵。"
	elif t < 29.0:
		narration.text = "最后一个，\n只有一条腿。"
	else:
		narration.text = ""
	# Follow the last toy from the child's pinch, then hold on its two settling wobbles.
	var push := _ease((t-22.0)/1.4)
	var follow: Vector2 = player.to_global(Vector2(0,-60))+Vector2(0,-60)
	if t >= 25.4:
		follow = checkpoint+Vector2(0,-120)
	var pull_back := _ease((t-28.6)/4.0)
	var close_position := Vector2(640,400).lerp(follow,push)
	camera.zoom = Vector2.ONE*lerpf(lerpf(1.0,2.15,push),1.0,pull_back)
	camera.position = close_position.lerp(Vector2(checkpoint.x,440),pull_back)
	if t >= 22.0:
		narration.position = Vector2(880,100)
		narration.size.x = 350

func begin_play() -> void:
	phase = "tutorial"
	placed_count = 24
	for i in range(24):
		_table_pose(i)
	hand.visible = false
	page.visible = false
	title.visible = false
	subtitle.visible = false
	player.scale = Vector2.ONE
	player.rotation = 0
	player.body_art.rotation = 0
	player.z_index = 20
	player.reset_at(checkpoint)
	player.set_physics_process(true)
	help.text = "R 重播开场"
	camera.zoom = Vector2.ONE
	camera.position = Vector2(checkpoint.x,440)

func _gameplay(delta: float) -> void:
	if completed:
		_meeting_shot(delta)
		return
	var target := Vector2(clampf(player.position.x,640,1840),440)
	camera.position = camera.position.lerp(target,1.0-exp(-delta*4.0))
	camera.zoom = camera.zoom.lerp(Vector2.ONE,1.0-exp(-delta*2.0))
	# Advance on landing on the obstacle, rather than after leaving its far edge.
	if (player.is_on_floor() and player.position.x >= 970 and player.position.x <= 1110 and player.position.y <= 601) or player.position.x > 1110:
		small_cleared = true
	if (player.is_on_floor() and player.position.x >= 1270 and player.position.x <= 1470 and player.position.y <= 521) or player.position.x > 1470:
		big_cleared = true
	narration.position = Vector2(80,165)
	narration.size.x = 620
	if big_cleared:
		narration.text = "再向前，便是纸城堡。\n跳上旧书叠成的平台。"
	elif small_cleared:
		narration.text = "前面还有一个高高的木盒。\n按住空格蓄力，松开大跳。"
	elif player.position.x < 945:
		narration.text = "小锡兵向前走去。\nA / D 移动"
	elif not small_cleared:
		narration.text = "一块小积木挡住了去路。\n短按空格，松开小跳。"
	if not completed and player.position.x > 1660 and player.is_on_floor() and player.position.y < 490 and small_cleared and big_cleared:
		completed = true
		phase = "castle_arrival"
		player.hold_standing()
		meeting_camera_start = camera.position
		meeting_zoom_start = camera.zoom
	if completed:
		_meeting_shot(delta)

func _meeting_shot(delta: float) -> void:
	ending_time += delta
	narration.text = "纸城堡里，\n站着一位纸做的舞蹈家。"
	narration.position = Vector2(80,70)
	player.clock += delta
	var push := _ease(ending_time/MEETING_PUSH_DURATION)
	var together := Vector2((player.position.x+dancer_axis.position.x)*0.5,400)
	camera.position = meeting_camera_start.lerp(together,push)
	camera.zoom = meeting_zoom_start.lerp(Vector2.ONE*MEETING_ZOOM,push)
	_dance(ending_time)

func _dance(time: float) -> void:
	# Fast flip around the planted supporting foot, with long holds on either side.
	var t := fposmod(time,1.8)
	var horizontal := 1.0
	if t > 0.78 and t < 0.90:
		horizontal = lerpf(1,-1,(t-0.78)/0.12)
	elif t >= 0.90 and t < 1.68:
		horizontal = -1
	elif t >= 1.68:
		horizontal = lerpf(-1,1,(t-1.68)/0.12)
	dancer_axis.scale.x = horizontal

func _mcp_state() -> Dictionary:
	return {"phase":phase,"cg_time":snappedf(cg_time,0.1),"placed_soldiers":placed_count,"total_soldiers":25,"hand_visible":hand.visible,"small_cleared":small_cleared,"big_cleared":big_cleared,"completed":completed}
