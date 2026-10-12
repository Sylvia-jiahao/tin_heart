extends Node2D

const INK := Color("343e4b")
const RED := Color("b95149")
const BLUE := Color("4e718b")
const GOLD := Color("e5b969")

@export var walk_hop_period: float = 0.26
@export var walk_hop_height: float = 18.0
var walk_phase: float = 0.0
var hop_offset: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	var s = get_parent()
	if s.state == "走路" and s.is_on_floor() and not s.preparing and not s.braced and s.recovery_time <= 0.0:
		walk_phase = fposmod(walk_phase + delta / walk_hop_period, 1.0)
	else:
		walk_phase = 0.0
	queue_redraw()

func block(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, INK, false, 1.6)

func pin(at: Vector2) -> void:
	draw_circle(at, 3.6, GOLD)
	draw_arc(at, 3.6, 0, TAU, 16, INK, 1.0)

func _draw() -> void:
	var s = get_parent()
	var lean: float = sin(s.clock * 2.0) * 0.028
	var crouch := 0.0
	var arm_angle := 0.08
	var leg_angle := 0.0
	hop_offset = Vector2.ZERO
	if s.preparing:
		var t: float = clampf(s.charge_time / s.charge_duration, 0, 1)
		crouch = 13.0 * t
		lean = -0.17 * t
		arm_angle = -0.48 * t
	elif s.braced:
		lean = 0.0
		arm_angle = 0.0
	elif s.recovery_time > 0.0:
		var t: float = s.recovery_time / s.landing_recovery
		crouch = 15.0 * t
		lean = sin((1.0-t) * TAU * 1.5) * 0.16 * t
		arm_angle = -0.52 * t
	elif not s.is_on_floor():
		lean = 0.1
		arm_angle = -0.65
		leg_angle = 0.16
	elif s.state == "走路":
		# Brief planted compression, then a single rigid-body hop.
		# The boot lifts with the entire paper puppet, rather than waving in place.
		lean = 0.025
		if walk_phase < 0.20:
			crouch = sin(walk_phase / 0.20 * PI) * 5.0
			arm_angle = -0.08
		else:
			var flight: float = (walk_phase - 0.20) / 0.80
			var arc: float = sin(flight * PI)
			hop_offset.y = -arc * walk_hop_height
			crouch = arc * 3.0
			leg_angle = arc * 0.06
			arm_angle = -0.08 - arc * 0.12
	draw_set_transform(hop_offset, 0, Vector2(s.facing, 1))
	# One boot, one leg: the silhouette never invents a second support leg.
	block(Rect2(-9, -10, 24, 10), INK)
	draw_set_transform(hop_offset + Vector2(0, -11), leg_angle, Vector2(s.facing, 1))
	block(Rect2(-7, -34 + crouch, 14, 34 - crouch), BLUE)
	pin(Vector2(0, -18 + crouch * 0.5))
	draw_set_transform(hop_offset + Vector2(0, -46 + crouch), lean * s.facing, Vector2(s.facing, 1))
	block(Rect2(-18, -39, 36, 40), RED)
	block(Rect2(-18, -5, 36, 5), GOLD)
	for y in [-29, -19, -10]:
		draw_circle(Vector2(0, y), 2.2, GOLD)
	block(Rect2(-9, -59, 21, 20), Color("e9d2ab"))
	draw_circle(Vector2(7, -51), 1.8, INK)
	block(Rect2(-13, -76, 29, 19), BLUE)
	block(Rect2(-14, -59, 34, 4), INK)
	block(Rect2(-1, -73, 5, 10), GOLD)
	pin(Vector2(0, 0))
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(side * 19.0, -31)
		draw_set_transform(hop_offset + Vector2(0, -46 + crouch) + shoulder * Vector2(s.facing, 1), arm_angle * side * s.facing, Vector2(s.facing, 1))
		block(Rect2(-5, 0, 10, 27), RED)
		block(Rect2(-5, 22, 10, 6), GOLD)
		block(Rect2(-4, 28, 8, 8), Color("e9d2ab"))
		pin(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
