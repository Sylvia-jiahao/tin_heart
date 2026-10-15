extends SceneTree

var scene: Node
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func release() -> void:
	for action in ["move_left","move_right","jump","brace"]: Input.action_release(action)
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)

func jump_from_float(index: int,high: bool) -> Dictionary:
	release()
	scene._enter_street(index,false)
	scene.set_process(false)
	var panel: Dictionary=scene.panels[index]
	var k: int=3 if index==16 else 2
	var lift: Dictionary=panel.platforms[k-1]
	var target: Dictionary=panel.platforms[k]
	scene.phase_time=lift.period*0.5 if high else 0.0
	scene._mechanisms(panel,0)
	var x: float=lift.w-35
	var y: float=scene.CUTOUT.surface_y([lift.shape],x)
	scene.player.reset_at(lift.body.to_global(Vector2(x,y-2)))
	await frames(8)
	Input.action_press("jump")
	await frames(24)
	Input.action_press("move_right")
	Input.action_release("jump")
	var landed: bool=false
	var min_y: float=scene.player.position.y
	var airborne: bool=false
	for i in range(100):
		await frames(1)
		min_y=minf(min_y,scene.player.position.y)
		if not scene.player.is_on_floor(): airborne=true
		if airborne and scene.player.is_on_floor():
			for c in range(scene.player.get_slide_collision_count()):
				if scene.player.get_slide_collision(c).get_collider()==target.body: landed=true
			break
	release()
	return {"landed":landed,"min_y":min_y,"ledge":float(panel.data.platforms[k].y)}

func verify() -> void:
	DirAccess.make_dir_recursive_absolute("E:/tinheart/chapter02_qa")
	scene=load("res://scenes/chapter02_rain.tscn").instantiate()
	if scene.get_script()==null: check(false,"chapter script compiles"); quit(1); return
	scene.start_on_street=true
	scene.save_path="E:/tinheart/chapter02_qa/revision_save.json"
	root.add_child(scene)
	current_scene=scene
	await frames(8)
	# Sample a preparation window at 50ms intervals over three consecutive cycles.
	var windows: bool=true
	for cycle in range(3):
		for step in range(13):
			var start: float=0.35+step*0.05
			release()
			scene._enter_street(19,false)
			var panel: Dictionary=scene.panels[19]
			scene.player.reset_at(panel.root.position+Vector2(530,603))
			scene.phase_time=cycle*6.0+start
			await frames(4)
			Input.action_press("jump")
			await frames(24)
			Input.action_release("jump")
			Input.action_press("move_right")
			var deaths: int=scene.deaths
			var airborne: bool=false
			var landed: bool=false
			for i in range(85):
				await frames(1)
				if absf(scene.player.external_wind)>1: windows=false
				if not scene.player.is_on_floor(): airborne=true
				if scene.deaths!=deaths: break
				if airborne and scene.player.is_on_floor():
					landed=scene.player.position.x>panel.root.position.x+738 and absf(scene.player.position.y-535)<3
					break
			if not landed: print("WINDOW_DEBUG ",cycle," ",start," ",scene.last_failure); windows=false
			release()
	check(windows,"room 20: 39 real jumps across three cycles succeed throughout a 0.6-second preparation window, with calm air")
	for point in [Vector2(530,605),Vector2(965,535)]:
		scene._enter_street(19,false)
		scene.player.reset_at(scene.panels[19].root.position+point-Vector2(0,2))
		var deaths: int=scene.deaths
		Input.action_press("brace")
		await frames(365)
		release()
		check(scene.deaths==deaths and absf(scene.player.position.x-scene.panels[19].root.position.x-point.x)<1,"room 20 has a safe attention waiting position at "+str(point.x))
	for index in [12,13,16,26]:
		var low: Dictionary=await jump_from_float(index,false)
		var high: Dictionary=await jump_from_float(index,true)
		check(not low.landed and low.min_y>low.ledge+50 and high.landed,"height gate "+str(index+1)+": low water cannot reach the high bank; high water can")
	# Expanded torso pickup also reaches this optional star at the low-lift jump apex.
	for high in [false,true]:
		scene.stars.clear()
		scene._enter_street(13,false)
		var panel: Dictionary=scene.panels[13]
		var lift: Dictionary=panel.platforms[3]
		scene.phase_time=0.0 if high else lift.period*0.5
		scene._mechanisms(panel,0)
		var x: float=1020-lift.body.position.x
		var y: float=scene.CUTOUT.surface_y([lift.shape],x)
		scene.player.reset_at(lift.body.to_global(Vector2(x,y-2)))
		await frames(8)
		Input.action_press("jump")
		await frames(24)
		Input.action_release("jump")
		for i in range(80):
			await frames(1)
			scene._update_stars()
		check(scene.stars.has(13),"optional star can be collected with expanded body contact: "+("raised lift" if high else "low lift jump apex"))
	scene._enter_street(0,false)
	scene.player.set_physics_process(false)
	scene.stars.clear()
	var star: Sprite2D=scene.panels[0].star
	scene.player.position=star.global_position+Vector2(0,118)
	scene.player.clock=0
	scene.player.body_art._process(0)
	scene._update_stars()
	check(scene.stars.is_empty(),"star cannot be collected with head-only contact from below")
	scene.player.position=star.global_position+Vector2(0,75)
	scene._update_stars()
	check(scene.stars==[0] and not star.visible and scene.star_audio.playing,"upper-torso pickup hides the star and plays the existing chime")
	scene._retry()
	check(scene.stars==[0] and not star.visible,"retry preserves collected stars")
	scene._save()
	scene.stars.clear()
	scene._load()
	check(scene.stars==[0] and not star.visible,"chapter-two save/load preserves star progress independently")
	var xs: Dictionary={}
	var speeds: Dictionary={}
	for i in range(scene.rain.size()):
		xs[int(scene.rain[i].position.x)]=true
		speeds[int(scene.rain_motion[i].speed)]=true
	check(scene.rain.size()==340 and xs.size()>240 and speeds.size()>180,"rain has dense independently randomized positions and fall speeds")
	check(scene.panels[0].water.material.get_shader_parameter("water_surface")==true,"foreground water uses the feathered uneven surface mask")
	print("RAIN_REVISION_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
