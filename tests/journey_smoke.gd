extends SceneTree

func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var scene=load("res://scenes/tabletop_journey.tscn").instantiate()
	scene.save_path="E:/tinheart/journey_qa/test_save.json"
	root.add_child(scene)
	current_scene=scene
	await physics_frame
	for i in range(30):
		scene._load_room(i)
		await physics_frame
		await physics_frame
		print("ROOM_READY ",i+1," ",scene.platforms.size())
	print("SMOKE_PASS")
	quit()
