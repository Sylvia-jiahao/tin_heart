extends SceneTree

var scene: Node
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func release() -> void:
	for action in ["move_left","move_right","jump","brace"]: Input.action_release(action)

func traverse(index: int,attempt: int) -> bool:
	var legacy: bool=attempt>=32
	var trial: int=attempt%32
	scene._enter_street(index,false)
	scene.clock=trial*0.39
	scene.phase_time=trial*0.39
	await frames(10)
	var deaths: int=scene.deaths
	var panel: Dictionary=scene.panels[index]
	if panel.data.continuous:
		Input.action_press("move_right")
		for i in range(340):
			await frames(1)
			if scene.active_room>index or scene.phase=="boat": release(); return true
			if scene.deaths!=deaths: release(); return false
		release()
		return false
	for k in range(1,panel.platforms.size()):
		var previous: Dictionary=panel.platforms[k-1]
		var target: Dictionary=panel.platforms[k]
		var launch: float=panel.root.position.x+previous.body.position.x+previous.w-(25 if panel.data.low else 35)
		if index==23 and k==3: launch=panel.root.position.x+803
		var fraction: float=0.42 if legacy else float([0.78,0.42,0.6][attempt%3])
		var target_x: float=panel.root.position.x+target.body.position.x+target.w*fraction
		Input.action_press("move_right")
		for i in range(240):
			await frames(1)
			if scene.deaths!=deaths: release(); return false
			if scene.player.position.x>=launch: break
		Input.action_release("move_right")
		Input.action_press("brace")
		await frames(6+trial%4*4 if legacy else 4+attempt%6*7)
		# Observe the same wind cycle and painted landing warnings as a player.
		# Waiting uses real attention input; hazards and moving bodies remain active.
		for waiting in range(900):
			if legacy or attempt%3==1: break
			var safe: bool=true
			if previous.motion:
				var lift_phase: float=(scene.phase_time+0.4)*TAU/previous.period+previous.motion_phase
				var local_top: float=scene.CUTOUT.surface_y([previous.shape],previous.w-35)
				var release_height: float=previous.base.y+local_top+sin(lift_phase)*previous.amplitude
				if release_height-float(panel.data.platforms[k].y)>175: safe=false
				if panel.data.height_gate and cos(lift_phase)>0.3: safe=false
			if panel.data.wind!=0:
				var wp: float=fposmod(scene.phase_time,panel.data.wind_period)
				safe=safe and (wp>0.3 and wp<1.0 if index==19 else wp>2.3 and wp<2.95)
			if target.motion:
				var future_y: float=target.base.y+sin((scene.phase_time+1.25)*TAU/target.period+target.motion_phase)*target.amplitude
				if scene.player.position.y-future_y>125: safe=false
			# Forecast the full jump corridor, not just the instant of landing.
			for sample in range(1,36):
				var flight: float=sample*0.03
				var jump_speed: float=520 if panel.data.low else 760
				var predicted_y: float=scene.player.position.y-jump_speed*flight+750*flight*flight
				var predicted_x: float=minf(scene.player.position.x+260*flight,target_x)
				if not panel.swing.is_empty():
					var period: float=panel.data.swing_period
					var swing_t: float=scene.phase_time+0.4+flight
					var angle: float=sin(swing_t*TAU/period+(1.1 if index==23 else 0.0))*0.48
					var sign_center: Vector2=panel.swing.pivot.global_position+Vector2(-sin(angle)*245,cos(angle)*245)
					if sign_center.distance_to(Vector2(predicted_x,predicted_y-52))<76: safe=false
				for drop in panel.drops:
					if absf(panel.root.position.x+drop.root.position.x-predicted_x)>62: continue
					var t: float=fposmod(scene.phase_time+(0.067 if panel.data.low else 0.4)+flight+drop.phase,drop.period)
					var impact: float=drop.period-0.26
					if t>=impact and predicted_y>drop.floor-80 and predicted_y<drop.floor+35: safe=false
					if t>=impact-0.36 and t<impact:
						var drop_y: float=lerpf(drop.start_y,drop.floor-55,(t-impact+0.36)/0.36)
						if predicted_y>drop_y and predicted_y-103<drop_y+62: safe=false
			if safe: break
			await frames(1)
			if scene.deaths!=deaths: release(); return false
		Input.action_release("brace")
		Input.action_press("jump")
		await frames(4 if panel.data.low else 24)
		Input.action_press("move_right")
		Input.action_release("jump")
		var airborne: bool=false
		var landed: bool=false
		for i in range(115):
			await frames(1)
			if scene.deaths!=deaths: release(); return false
			if not scene.player.is_on_floor(): airborne=true
			if scene.player.position.x>=target_x: Input.action_release("move_right")
			if airborne and scene.player.is_on_floor():
				landed=true
				break
		Input.action_release("move_right")
		if not landed or scene.player.position.x<panel.root.position.x+target.body.position.x-10: release(); return false
		await frames(18 if legacy else 5)
	Input.action_press("move_right")
	for i in range(100):
		await frames(1)
		if scene.active_room>index or scene.phase=="crossing": release(); return true
		if scene.deaths!=deaths: release(); return false
	release()
	return false

func verify() -> void:
	DirAccess.make_dir_recursive_absolute("E:/tinheart/chapter02_qa")
	scene=load("res://scenes/chapter02_rain.tscn").instantiate()
	if scene.get_script()==null:
		print("FAIL chapter-two script did not compile")
		quit(1)
		return
	scene.save_path="E:/tinheart/chapter02_qa/robot_save.json"
	scene.start_on_street=true
	root.add_child(scene)
	current_scene=scene
	await frames(8)
	var selected: Array=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--regions="):
			for value in arg.trim_prefix("--regions=").split(","): selected.append(int(value)-1)
	for index in range(36):
		if not selected.is_empty() and not selected.has(index): continue
		var passed: bool=false
		for attempt in range(64):
			if await traverse(index,attempt):
				passed=true
				print("ATTEMPTS ",index+1,": ",attempt+1)
				break
			elif not selected.is_empty() and attempt<6:
				print("DEBUG ",index+1," ",scene.last_failure," player ",scene.player.position-scene.panels[index].root.position)
		print("PASS " if passed else "FAIL ","region ",index+1," ",scene.ROOMS.NAMES[index])
		if not passed: failures.append(index+1)
	print("RAIN_ROUTE_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
