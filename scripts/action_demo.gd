extends Node2D

var soldier: CharacterBody2D
var status: Label
var charge_bar: ProgressBar
var elapsed: float = 0.0

func _ready() -> void:
	_setup_inputs()
	RenderingServer.set_default_clear_color(Color("f3ede1"))
	_ground(PackedVector2Array([Vector2(0,650),Vector2(600,650),Vector2(920,530),Vector2(1280,530),Vector2(1280,800),Vector2(0,800)]))
	_platform(Vector2(300,590),Vector2(110,18))
	_platform(Vector2(450,525),Vector2(110,18))
	soldier = CharacterBody2D.new()
	soldier.set_script(load("res://scripts/tin_soldier.gd"))
	soldier.position = Vector2(140,648)
	add_child(soldier)
	var ui := CanvasLayer.new()
	add_child(ui)
	_label(ui, "TIN HEART   /   锡兵动作实验", Vector2(44,26), 29)
	_label(ui, "手绘剪纸锡兵 · 五种动作 · 可调手感", Vector2(45,70), 16)
	status = _label(ui, "", Vector2(46,112), 20)
	charge_bar = ProgressBar.new()
	charge_bar.position = Vector2(46,151)
	charge_bar.size = Vector2(290,10)
	charge_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bd8346")
	charge_bar.add_theme_stylebox_override("fill", fill)
	charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(charge_bar)
	var preview := Node2D.new()
	preview.set_script(load("res://scripts/soldier_art.gd"))
	preview.actor = soldier
	preview.position = Vector2(1110,332)
	preview.scale = Vector2(1.8,1.8)
	ui.add_child(preview)
	_label(ui, "纸偶放大预览", Vector2(1050,340), 15)
	_label(ui, "← → / A D 走路     Shift / S / ↓ 按住立正     空格短按小跳 · 长按蓄力后松开大跳", Vector2(45,715), 18)
	_label(ui, "R / 1 回到平地     2 前往风坡     蓄力约 0.35 秒 · 固定大跳 · 落地短暂停顿后恢复控制", Vector2(45,750), 15)
	_label(ui, "01  平地与跳台", Vector2(45,432), 20)
	_label(ui, "02  风坡 · 按住立正试试", Vector2(800,368), 20)
	_label(ui, "风向 ←   风力周期变化", Vector2(820,400), 16)
	_label(ui, "示范规则：立正时可稳定蓄力，起跳后失去稳定。此规则尚待试玩确认。", Vector2(45,191), 14)

func _setup_inputs() -> void:
	var bindings := {"move_left":[KEY_A,KEY_LEFT], "move_right":[KEY_D,KEY_RIGHT], "jump":[KEY_SPACE], "brace":[KEY_SHIFT,KEY_S,KEY_DOWN], "reset_demo":[KEY_R,KEY_1], "slope_demo":[KEY_2]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _ground(points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionPolygon2D.new()
	collision.polygon = points
	body.add_child(collision)
	add_child(body)

func _platform(at: Vector2, dimensions: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var art := Polygon2D.new()
	art.polygon = PackedVector2Array([Vector2(-dimensions.x/2,-dimensions.y/2),Vector2(dimensions.x/2,-dimensions.y/2),Vector2(dimensions.x/2,dimensions.y/2),Vector2(-dimensions.x/2,dimensions.y/2)])
	art.color = Color("9b8061")
	body.add_child(art)
	add_child(body)

func _label(parent: Node, text: String, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("343e4b"))
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	elapsed += delta
	if Input.is_action_just_pressed("reset_demo"):
		soldier.reset_at(Vector2(140,648))
	if Input.is_action_just_pressed("slope_demo"):
		soldier.reset_at(Vector2(805,568))
	status.text = "当前动作  %s    |    上次起跳  %s" % [soldier.state,soldier.last_jump]
	charge_bar.value = clampf(soldier.charge_time/soldier.charge_duration*100,0,100) if soldier.preparing else 0.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(35,100,690,125), Color("e8dfcf"))
	draw_rect(Rect2(0,700,1280,100), Color("e2d7c4"))
	draw_circle(Vector2(1100,250),94,Color("e9dfcb"))
	var ground := PackedVector2Array([Vector2(0,650),Vector2(600,650),Vector2(920,530),Vector2(1280,530),Vector2(1280,700),Vector2(0,700)])
	draw_colored_polygon(ground,Color("c5b598"))
	draw_polyline(PackedVector2Array([Vector2(0,650),Vector2(600,650),Vector2(920,530),Vector2(1280,530)]),Color("796a57"),3)
	for i in range(9):
		var x: float = 650.0 + fposmod(float(i)*39.0 - elapsed*85,300.0)
		var y: float = 450.0 + float(i%3)*26
		draw_line(Vector2(x,y),Vector2(x+29,y),Color("9aafb4"),2)
		draw_line(Vector2(x,y),Vector2(x+7,y-4),Color("9aafb4"),2)
		draw_line(Vector2(x,y),Vector2(x+7,y+4),Color("9aafb4"),2)
