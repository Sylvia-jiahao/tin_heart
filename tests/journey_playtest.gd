extends SceneTree

var scene: Node
var failures: Array=[]
var simulated_seconds: float=0.0

func _init() -> void:
	call_deferred("verify")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		simulated_seconds+=1.0/60.0

func release_all() -> void:
	for action in ["jump","move_left","move_right","brace"]:
		Input.action_release(action)

func traverse(index: int, attempt: int) -> bool:
	release_all()
	scene._load_room(index)
	scene.room_time=float(attempt)*0.71
	await frames(6)
	var death_start: int=scene.deaths
	var route: Array=scene.platforms.slice(0,scene.room.platforms.size())
	for p in range(1,route.size()):
		var source: Dictionary=route[p-1]
		var destination: Dictionary=route[p]
		# Walk close to the departure edge, using actual inputs and collisions.
		for step in range(90):
			if scene.deaths!=death_start: return false
			var margin: float=36.0 if source.data.kind in ["paper","ruler"] else 18.0
			var launch_x: float=source.body.global_position.x+source.landing_span.y-margin
			if scene.player.position.x>=launch_x: break
			Input.action_press("move_right")
			await frames(1)
		Input.action_release("move_right")
		Input.action_press("brace")
		await frames(5)
		if scene.deaths!=death_start or not scene.player.is_on_floor(): return false
		var aim: float=destination.body.global_position.x+lerpf(destination.landing_span.x,destination.landing_span.y,0.65)
		var gap: float=destination.body.global_position.x+destination.landing_span.x-scene.player.global_position.x
		var small: bool=not scene.room.ceiling.is_empty() and scene.room_root.to_local(scene.player.global_position).x>300 and absf(destination.body.global_position.y-scene.player.global_position.y)<65 and gap<175
		Input.action_press("jump")
		await frames(4 if small else 26)
		Input.action_release("brace")
		Input.action_release("jump")
		Input.action_press("move_right")
		var airborne:=false
		var landed:=false
		for step in range(130):
			await frames(1)
			if scene.deaths!=death_start: return false
			if not scene.player.is_on_floor(): airborne=true
			aim=destination.body.global_position.x+lerpf(destination.landing_span.x,destination.landing_span.y,0.65)
			var dx: float=aim-scene.player.position.x
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(dx)>10:
				Input.action_press("move_right" if dx>0 else "move_left")
			if airborne and scene.player.is_on_floor():
				# An optional upper shelf can legitimately intercept a descending jump.
				var landing_x: float=scene.player.global_position.x-destination.body.global_position.x
				landed=scene._standing_on(destination.body) or (scene.player.position.y<=destination.body.global_position.y+35 and scene.player.position.y>=destination.body.global_position.y-125 and landing_x>=destination.landing_span.x-13 and landing_x<=destination.landing_span.y+13)
				break
		release_all()
		if not landed: return false
	# The finish flag is on the last safe platform; do not invoke the scene change in this test.
	return scene.room_root.to_local(scene.player.global_position).x>1090 and scene.player.position.y<610

func verify() -> void:
	scene=load("res://scenes/tabletop_journey.tscn").instantiate()
	scene.save_path="E:/tinheart/journey_qa/playtest_save.json"
	root.add_child(scene)
	current_scene=scene
	await frames(6)
	for index in range(30):
		var success:=false
		for attempt in range(18):
			if await traverse(index,attempt):
				success=true
				print("PASS_ROUTE ",index+1," attempts=",attempt+1)
				break
		if not success:
			failures.append(index+1)
			print("FAIL_ROUTE ",index+1," position=",scene.player.position)
	release_all()
	print("ROUTE_RESULT failures=",failures," simulated_seconds=",simulated_seconds)
	quit(0 if failures.is_empty() else 1)
