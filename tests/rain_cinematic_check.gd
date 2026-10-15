extends SceneTree
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func photo(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func verify() -> void:
	var directory: String="E:/tinheart/chapter02_qa/cinematic"
	if "--wide" in OS.get_cmdline_user_args(): directory+="_wide"
	DirAccess.make_dir_recursive_absolute(directory)
	var scene=load("res://scenes/chapter02_rain.tscn").instantiate()
	scene.start_on_street=true
	scene.save_path=directory+"/save.json"
	root.add_child(scene)
	current_scene=scene
	await frames(8)
	scene.set_process(false)
	scene._begin_arrival()
	check(scene.phase=="arrival" and not scene.player.is_physics_processing(),"landing recovery is a locked cinematic, not a new player action")
	for time in [0.0,0.8,1.5,2.5,3.5,4.5,6.6]:
		scene.phase_time=time
		scene._arrival(0)
		await photo(directory+"/rise_%02d.png" % int(time*10))
		if time<0.9: check(scene.player.body_art.facing_root.rotation>1.5,"soldier lies sideways on the wet stone")
		if time==2.5: check(scene.player.body_art.facing_root.rotation>0.3 and scene.player.body_art.facing_root.rotation<1.3,"midpoint has a distinct pushing-up pose")
	check(scene.phase=="street" and scene.player.is_physics_processing() and scene.player.body_art.cinematic_pose=="","standing finishes before normal input is restored")
	check(scene.deaths==0,"scripted fall and getting up do not count as failure")
	scene._enter_street(35,false)
	scene._begin_boat()
	for time in [10.0,15.0,18.0]:
		scene.phase_time=time
		scene._boat(0)
		await photo(directory+"/boat_%02d.png" % int(time))
	var art=scene.player.body_art
	check(art.cinematic_pose=="boat_hold" and not art.thigh.visible,"seated lower body stays inside the paper boat")
	check(scene.boat.z_index<scene.player.z_index and scene.player.z_index<scene.boat_front.z_index,"rear fold, soldier coat and front hull have separate depth")
	check(not art.left_arm.z_as_relative and art.left_arm.z_index>scene.boat_front.z_index and art.right_arm.z_index>scene.boat_front.z_index,"both arms and hands remain in front of the gunwale")
	check(art.boat_left_grip.visible and art.boat_right_grip.visible and not art.left_forearm.get_node("ForearmPaper").visible,"curled gripping hands replace the dangling normal forearms")
	for grip in [art.boat_left_grip,art.boat_right_grip]:
		var finger:=Vector2(0.12 if grip.flip_h else 0.88,0.85)
		var uv: Vector2=scene.boat.to_local(grip.to_global(grip.texture.get_size()*finger))/scene.boat.texture.get_size()
		var rim: float=rim_at(uv.x)
		var gap: float=absf(uv.y-rim)*100
		print("GRIP_RIM_GAP ",gap)
		check(gap<6,"visible fingers stay against the near paper rim")
	check(art.musket.z_index<scene.boat_front.z_index and art.musket.z_index>scene.boat.z_index,"gun rests inside the boat between its rear and near folds")
	var butt_uv: Vector2=scene.boat.to_local(art.musket.to_global(Vector2(0,20)))/scene.boat.texture.get_size()
	var butt_rim: float=rim_at(butt_uv.x)
	var depth: float=(butt_uv.y-butt_rim)*100
	print("STOCK_RIM_DEPTH ",depth)
	check(depth>4 and depth<16,"only the bottom of the stock tucks naturally behind the near gunwale")
	var barrel_uv: Vector2=scene.boat.to_local(art.musket.to_global(Vector2(0,-12)))/scene.boat.texture.get_size()
	var barrel_rim: float=rim_at(barrel_uv.x)
	check(barrel_uv.y<barrel_rim,"upper stock and barrel remain visibly above the rim")
	check(art.left_forearm.get_node("BrassPin").z_index>art.boat_left_grip.z_index and art.right_forearm.get_node("BrassPin").z_index>art.boat_right_grip.z_index,"both elbow rivets show above the gripping forearms")
	scene._enter_street(0,false)
	check(art.cinematic_pose=="" and art.thigh.visible and art.left_arm.z_as_relative,"checkpoint reset clears boat pose and restores normal paper layers")
	check(not art.boat_left_grip.visible and art.left_forearm.get_node("ForearmPaper").visible,"normal forearm artwork returns after the cinematic")
	scene._begin_arrival()
	scene._enter_street(0,false)
	check(scene.arrival_drop==null and scene.arrival_splash==null and art.cinematic_pose=="","skipping recovery removes its pose and temporary rain props")
	print("RAIN_CINEMATIC_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)

func rim_at(x: float) -> float:
	if x<0.20: return lerpf(0.17,0.65,x/0.20)
	if x<0.50: return lerpf(0.65,0.72,(x-0.20)/0.30)
	if x<0.80: return lerpf(0.72,0.55,(x-0.50)/0.30)
	return lerpf(0.55,0.18,(x-0.80)/0.20)
