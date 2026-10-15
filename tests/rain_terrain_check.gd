extends SceneTree

var scene: Node
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func verify() -> void:
	scene=load("res://scenes/chapter02_rain.tscn").instantiate()
	scene.save_path="E:/tinheart/chapter02_qa/terrain_save.json"
	scene.start_on_street=true
	root.add_child(scene)
	current_scene=scene
	await frames(8)
	# Isolate terrain from hazards; character motion and collision remain real.
	scene.set_process(false)
	var bad_seams: Array=[]
	for index in range(35):
		var origin: Vector2=scene.panels[index].root.position
		scene.player.reset_at(origin+Vector2(1220,648))
		scene.player.set_physics_process(true)
		await frames(8)
		Input.action_press("move_right")
		await frames(42)
		Input.action_release("move_right")
		if scene.player.position.x<origin.x+1380 or absf(scene.player.position.y-650)>2: bad_seams.append(index+1)
		Input.action_press("move_left")
		await frames(60)
		Input.action_release("move_left")
		if scene.player.position.x>origin.x+1250 or absf(scene.player.position.y-650)>2: bad_seams.append(index+1)
	check(bad_seams.is_empty(),"all 35 boundary joins walk in both directions without jumping: "+str(bad_seams))
	for index in [0,1,2,32,35]:
		scene._enter_street(index,false)
		await frames(8)
		Input.action_press("move_right")
		await frames(250)
		Input.action_release("move_right")
		var local: Vector2=scene.player.position-scene.panels[index].root.position
		check(local.x>1150 and absf(local.y-650)<2,"continuous painted pavement has no hidden holes or walls: "+str(index+1))
	scene._enter_street(26,false)
	var p: Dictionary=scene.panels[26].platforms[1]
	var minimum: float=INF
	var maximum: float=-INF
	for i in range(121):
		scene.phase_time=i*p.period/120.0
		scene._mechanisms(scene.panels[26],0)
		minimum=minf(minimum,p.body.position.y)
		maximum=maxf(maximum,p.body.position.y)
	check(maximum-minimum>175,"advanced floating platform travels at least 175 pixels peak to peak")
	scene._enter_street(12,false)
	p=scene.panels[12].platforms[1]
	scene.phase_time=0
	scene._mechanisms(scene.panels[12],0)
	var surface: float=scene.CUTOUT.surface_y([p.shape],p.w*0.5)
	scene.player.reset_at(p.body.to_global(Vector2(p.w*0.5,surface-2)))
	Input.action_press("brace")
	var stayed: bool=true
	for i in range(400):
		scene.phase_time=i/60.0
		scene._mechanisms(scene.panels[12],1.0/60.0)
		await frames(1)
		if i>10 and absf(scene.player.position.y-p.body.to_global(Vector2(p.w*0.5,surface)).y)>5: stayed=false
	Input.action_release("brace")
	check(stayed,"soldier can ride a complete large-amplitude float cycle without falling through")
	var combined: int=0
	for panel in scene.panels:
		if panel.data.wind!=0 and not panel.drops.is_empty(): combined+=1
	check(combined>=9,"at least nine distinct wind-and-rain combination rooms")
	var tail: int=0
	for index in [30,31,33,34]:
		if scene.panels[index].platforms.size()>2 and not scene.panels[index].drops.is_empty(): tail+=1
	check(tail==4,"four final-six rooms contain actual platform and rain challenges")
	print("RAIN_TERRAIN_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
