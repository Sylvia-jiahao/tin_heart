extends SceneTree

var scene: Node
var directory: String="E:/tinheart/chapter02_qa"
func _init() -> void: call_deferred("capture")
func frames(count: int) -> void:
	for i in range(count): await process_frame
func photo(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/"+name+".png")

func capture() -> void:
	if "--wide" in OS.get_cmdline_user_args(): directory+="/wide"
	DirAccess.make_dir_recursive_absolute(directory)
	scene=load("res://scenes/chapter02_rain.tscn").instantiate()
	scene.save_path=directory+"/capture_save.json"
	root.add_child(scene)
	current_scene=scene
	await frames(8)
	scene.set_process(false)
	scene.player.set_physics_process(false)
	scene.phase_time=1.0
	scene._storm(0)
	await photo("01_window")
	scene.phase_time=5.5
	scene.player.position=Vector2(900,508)
	scene._storm(0)
	await photo("02_storm")
	scene.phase="fall"
	scene.fall_start=Vector2(1080,510)
	scene.fall_camera=Vector2(960,360)
	scene.warm_window.visible=true
	scene.warm_window.position=Vector2(640,80)
	scene.phase_time=3.5
	scene._fall(0)
	await photo("03_fall")
	for index in [0,2,7,12,13,16,18,19,23,24,26,29,30,31,32,33,34,35]:
		scene._enter_street(index,false)
		await frames(5)
		scene.player.hold_standing()
		scene.phase_time=2.6
		scene._street(0)
		await photo("region_%02d" % (index+1))
	# Show actual contact at both ends of the enlarged floating movement.
	for t in [0.65,2.9]:
		scene._enter_street(26,false)
		scene.player.hold_standing()
		scene.phase_time=t
		scene._street(0)
		var p: Dictionary=scene.panels[26].platforms[1]
		var y: float=scene.CUTOUT.surface_y([p.shape],p.w*0.5)
		scene.player.position=p.body.to_global(Vector2(p.w*0.5,y))
		scene.camera.position=scene.panels[26].root.position+Vector2(640,440)
		await photo("float_high" if t>2 else "float_low")
	scene._enter_street(33,false)
	scene._street(0)
	scene.player.hold_standing()
	scene.player.position=scene.panels[33].root.position+Vector2(1280,650)
	scene.camera.position=scene.panels[33].root.position+Vector2(1280,440)
	await photo("bank_join_34_35")
	scene._enter_street(35,false)
	scene.player.position.x=scene.panels[35].root.position.x+1050
	scene._begin_boat()
	for time in [1.8,4.0,7.0,10.0,15.0,20.0]:
		scene.phase_time=time
		scene._boat(0)
		await photo("ending_%02d" % int(time))
	print("RAIN_CAPTURE_DONE ",root.size)
	quit()
