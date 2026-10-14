extends SceneTree

var failures: Array=[]
var used: Dictionary={}
func _init() -> void: call_deferred("verify")
func check(ok: bool,description: String) -> void:
	print("PASS " if ok else "FAIL ",description)
	if not ok: failures.append(description)
func inspect(node: Node) -> void:
	if node is Sprite2D and node.texture is AtlasTexture:
		var path: String=node.texture.atlas.resource_path
		if "/v3_" in path or "/v4_furniture_" in path or "/v4_castle_books" in path:
			var ratio_ok: bool=absf(absf(node.scale.x)-absf(node.scale.y))<0.00001
			if not used.has(path) or not ratio_ok:
				check(ratio_ok,"preserved ratio: "+path.get_file())
			used[path]=true
		if "shelf_support.png" in path:
			check(false,"obsolete tall-post assembly was found")
	for child in node.get_children(): inspect(child)
func verify() -> void:
	var scene=load("res://scenes/tabletop_journey.tscn").instantiate()
	scene.save_path="E:/tinheart/journey_qa/dressing_check_save.json"
	root.add_child(scene)
	current_scene=scene
	await physics_frame
	inspect(scene)
	check(used.size()>=30,"at least 30 distinct new cutouts are used in the level")
	print("ART_USAGE ",used.size()," ",used.keys())
	quit(0 if failures.is_empty() else 1)
