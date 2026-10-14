extends SceneTree

const SOLDIER=preload("res://scripts/tin_soldier.gd")
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func flight(force: float,direction: int,brace: bool=false) -> Vector2:
	var actor=SOLDIER.new()
	actor.automatic_respawn=false
	actor.wind_enabled=false
	actor.external_wind_enabled=true
	actor.external_wind=force
	actor.position=Vector2(-3000,-2000)
	root.add_child(actor)
	if direction>0: Input.action_press("move_right")
	elif direction<0: Input.action_press("move_left")
	if brace: Input.action_press("brace")
	await frames(31)
	var result:=Vector2(actor.position.x+3000,actor.velocity.x)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("brace")
	actor.queue_free()
	await frames(2)
	return result
func verify() -> void:
	for action in ["move_left","move_right","brace","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var still: Vector2=await flight(0,0)
	var right: Vector2=await flight(500,0)
	var left: Vector2=await flight(-500,0)
	check(absf(still.x)<0.1,"no input and no wind produce no horizontal drift")
	check(right.x>35 and right.y>150,"airborne soldier is carried right by sustained wind")
	check(left.x<-35 and left.y<-150,"airborne soldier is carried left by sustained wind")
	var steered: Vector2=await flight(0,1)
	var tailwind: Vector2=await flight(500,1)
	var headwind: Vector2=await flight(-500,1)
	check(tailwind.x>steered.x+35 and headwind.x<steered.x-35,"wind changes jump trajectory even while a direction is held")
	check(headwind.y>0 and headwind.y<steered.y-150,"air steering still works against the wind")
	var salute: Vector2=await flight(500,0,true)
	check(salute.x>35,"holding attention in midair does not cancel wind")
	print("AIR_WIND_RESULT ",failures," still=",still," right=",right," left=",left," headwind=",headwind)
	quit(0 if failures.is_empty() else 1)
