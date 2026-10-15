extends SceneTree

var failures: Array=[]
var scene: Node

func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func release() -> void:
	for action in ["move_left","move_right","jump","brace"]: Input.action_release(action)

func verify() -> void:
	scene=load("res://scenes/chapter02_rain.tscn").instantiate()
	if scene.get_script()==null:
		print("FAIL chapter-two script did not compile")
		quit(1)
		return
	scene.save_path="E:/tinheart/chapter02_qa/system_save.json"
	DirAccess.make_dir_recursive_absolute("E:/tinheart/chapter02_qa")
	root.add_child(scene)
	current_scene=scene
	await frames(8)
	check(scene.panels.size()==36,"36 continuous regions constructed")
	var assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter02/asset_index.json"))
	var missing: Array=[]
	for name in assets:
		if not ResourceLoader.exists("res://assets/chapter02/%s.png" % name): missing.append(name)
	check(assets.size()==57 and missing.is_empty(),"all 57 original generated assets and revisions are indexed and imported")
	var identity: int=scene.player.get_instance_id()
	for mode in ["idle","brace","left","jump","mixed"]:
		release()
		scene.phase="window"
		scene.phase_time=0
		scene.window_root.visible=true
		scene.player.reset_at(Vector2(690,508))
		scene.player.set_physics_process(true)
		for i in range(1800):
			if mode=="brace": Input.action_press("brace")
			if mode=="left": Input.action_press("move_left")
			if mode=="jump" or mode=="mixed":
				if i%75==0: Input.action_press("jump")
				if i%75==25: Input.action_release("jump")
			if mode=="mixed":
				if i%180<90: Input.action_press("brace")
				else: Input.action_release("brace")
			await frames(1)
			if scene.phase=="fall": break
		check(scene.phase=="fall" and scene.deaths==0,"storm inevitably falls without death: "+mode)
		release()
		scene.set_process(false)
		scene._fall(0)
		scene.set_process(true)
	scene._enter_street(0)
	await frames(10)
	check(scene.player.environment_drift==0 and scene.player.air_wind_speed_limit==320,"storm parameters cleared on street")
	scene._enter_street(2)
	await frames(5)
	scene.set_process(false)
	scene.phase_time=1.9
	scene._mechanisms(scene.panels[2],0)
	check(scene.panels[2].drops[0].warning and not scene.panels[2].drops[0].active,"drop has visible warning before impact")
	scene.phase_time=2.65
	scene._mechanisms(scene.panels[2],0)
	check(scene.panels[2].drops[0].active,"drop impact window is active")
	scene._enter_street(12)
	var body: Node2D=scene.panels[12].platforms[1].body
	var old: Vector2=body.position
	scene.phase_time=1.0
	scene._mechanisms(scene.panels[12],0)
	check(body.position.distance_to(old)>1,"floating support really moves with its collision")
	scene._enter_street(7)
	var p=scene.panels[7].platforms[1]
	check(p.body.get_meta("wet",false) and absf(p.body.rotation)>0.15,"wet slope is physical tilted wood")
	var surface: float=scene.CUTOUT.surface_y([p.shape],p.w*0.5)
	scene.player.reset_at(p.body.to_global(Vector2(p.w*0.5,surface-4)))
	await frames(12)
	scene.player.wet_surface_slide=340.0
	var slope_start: Vector2=scene.player.position
	await frames(18)
	check(scene.player.position.distance_to(slope_start)>2,"unbraced soldier really slips down wet wood")
	Input.action_press("brace")
	await frames(3)
	var braced_start: Vector2=scene.player.position
	await frames(15)
	check(scene.player.position.distance_to(braced_start)<1,"attention stops wet-slope slipping")
	release()
	scene._enter_street(32)
	check(scene.player.get_instance_id()==identity,"regions reuse the same character")
	scene.player.position.x=scene.panels[32].root.position.x+600
	scene.player.braced=true
	scene._street(2.1)
	check(scene.melody_seen,"optional two-second attention reveals melody")
	scene._enter_street(20)
	scene.deaths=7
	scene.skipped=[2,5]
	scene._save()
	scene._enter_street(0,false)
	scene._load()
	check(scene.active_room==20 and scene.deaths==7 and scene.skipped==[2,5],"independent checkpoint save resumes integer skip records and progress")
	paused=true
	var old_clock: float=scene.clock
	await frames(4)
	check(scene.clock==old_clock,"pause freezes cinematic and mechanism clocks")
	paused=false
	scene._enter_street(35)
	scene._begin_boat()
	for time in [1.0,4.0,7.0,10.0,15.0,20.0]:
		scene.phase_time=time
		scene._boat(0)
	check(scene.finished and scene.phase=="end","storybook ends with boat drift, no third-chapter controls")
	print("RAIN_SYSTEM_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
