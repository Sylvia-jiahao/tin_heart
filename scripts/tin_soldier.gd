extends CharacterBody2D

@export var walk_speed: float = 260.0
@export var gravity: float = 1500.0
@export var small_jump_speed: float = 520.0
@export var big_jump_speed: float = 760.0
@export var hold_threshold: float = 0.12
@export var charge_duration: float = 0.35
@export var landing_lock: float = 0.06
@export var landing_recovery: float = 0.26

var state: String = "站立"
var facing: float = 1.0
var charge_time: float = 0.0
var preparing: bool = false
var recovery_time: float = 0.0
var clock: float = 0.0
var wind: float = 0.0
var in_wind: bool = false
var braced: bool = false
var big_in_flight: bool = false
var last_jump: String = "无"
var small_jumps: int = 0
var big_jumps: int = 0
var last_landing_locked: bool = false
var body_art: Node2D

func _ready() -> void:
	name = "TinSoldier"
	add_to_group("mcp_watch")
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(40.0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(25, 103)
	collider.shape = shape
	collider.position = Vector2(0, -51.5)
	add_child(collider)
	body_art = Node2D.new()
	body_art.set_script(load("res://scripts/soldier_art.gd"))
	add_child(body_art)

func _physics_process(delta: float) -> void:
	clock += delta
	var grounded := is_on_floor()
	var direction := Input.get_axis("move_left", "move_right")
	var locked := recovery_time > landing_recovery - landing_lock
	last_landing_locked = locked
	recovery_time = maxf(0.0, recovery_time - delta)
	braced = grounded and Input.is_action_pressed("brace") and not locked
	in_wind = position.x > 625.0 and position.x < 965.0
	wind = (310.0 + 190.0 * sin(clock * 1.8)) if in_wind else 0.0
	if direction != 0.0 and not braced and not preparing and not locked:
		facing = signf(direction)
	if grounded and not locked and Input.is_action_just_pressed("jump"):
		preparing = true
		charge_time = 0.0
	if preparing:
		if not grounded or locked:
			preparing = false
			charge_time = 0.0
		else:
			charge_time += delta
			if not Input.is_action_pressed("jump"):
				var large := charge_time >= charge_duration
				velocity.y = -big_jump_speed if large else -small_jump_speed
				big_in_flight = large
				last_jump = "大跳" if large else "小跳"
				if large:
					big_jumps += 1
				else:
					small_jumps += 1
				preparing = false
				braced = false
				# Direction at release determines launch, including from attention.
				velocity.x = direction * walk_speed
				if direction != 0.0:
					facing = signf(direction)
	if not grounded:
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, direction * walk_speed, 1400.0 * delta)
	elif braced:
		velocity.x = 0.0
		velocity.y = 0.0
	elif locked:
		velocity.x = 0.0
		velocity.y = gravity * delta
	elif velocity.y >= 0.0:
		var desired := 0.0 if preparing and charge_time >= hold_threshold else direction * walk_speed
		velocity.x = desired if in_wind else move_toward(velocity.x, desired, 1600.0 * delta)
		velocity.y = gravity * delta
	# Wind and slippery slope are environmental motion, independent of animation.
	if not braced:
		velocity.x -= wind * 0.20 if grounded and velocity.y >= 0.0 else wind * delta
		if grounded and in_wind and velocity.y >= 0.0:
			velocity.x -= absf(get_floor_normal().x) * 75.0
	floor_stop_on_slope = braced or not in_wind
	move_and_slide()
	if not grounded and is_on_floor() and big_in_flight:
		recovery_time = landing_recovery
		big_in_flight = false
	if not is_on_floor():
		state = "大跳" if big_in_flight else "小跳 / 下落"
	elif recovery_time > 0.0:
		state = "落地恢复"
	elif preparing:
		state = "大跳就绪 · 松开起跳" if charge_time >= charge_duration else ("大跳蓄力" if charge_time >= hold_threshold else "起跳准备")
	elif braced:
		state = "立正"
	elif absf(direction) > 0.0:
		state = "走路"
	else:
		state = "站立"
	if position.y > 850.0 or position.x < 20.0 or position.x > 1260.0:
		reset_at(Vector2(140, 648))
	body_art.queue_redraw()

func reset_at(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	preparing = false
	charge_time = 0.0
	recovery_time = 0.0
	big_in_flight = false
	braced = false

func _mcp_state() -> Dictionary:
	return {"action": state, "grounded": is_on_floor(), "braced": braced, "preparing": preparing, "charge": snappedf(charge_time, 0.01), "recovery": snappedf(recovery_time, 0.01), "last_jump": last_jump, "small_jumps": small_jumps, "big_jumps": big_jumps, "wind": snappedf(wind, 0.1), "landing_locked": last_landing_locked}
