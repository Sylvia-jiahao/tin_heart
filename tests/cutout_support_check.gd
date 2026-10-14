extends SceneTree

const DRESS=preload("res://scripts/set_dressing.gd")
const CUTOUT=preload("res://scripts/cutout_collision.gd")
var failures: Array=[]
func _init() -> void: call_deferred("verify")
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func visible_top(picture: Sprite2D,foot_x: float) -> float:
	var image:=picture.texture.get_image()
	var left: int=clampi(floori((foot_x-12.5-picture.position.x)/picture.scale.x),0,image.get_width()-1)
	var right: int=clampi(ceili((foot_x+12.5-picture.position.x)/picture.scale.x),0,image.get_width()-1)
	for y in range(image.get_height()):
		for x in range(left,right+1):
			if image.get_pixel(x,y).a>=0.72: return picture.position.y+y*picture.scale.y
	return INF
func verify() -> void:
	var scene=load("res://scenes/tabletop_journey.tscn").instantiate()
	scene.save_path="E:/tinheart/journey_qa/v4/support_test_save.json"
	root.add_child(scene)
	current_scene=scene
	await frames(6)
	scene.active=false
	# Reproduce the original bookcase with raised side posts, not just the replacement art.
	var body:=StaticBody2D.new()
	body.position=Vector2(-4000,420)
	scene.add_child(body)
	var picture:=DRESS.fitted("v3_furniture_mid_1",Vector2(220,320))
	body.add_child(picture)
	CUTOUT.add_to(body,picture)
	var middle: float=picture.position.x+picture.texture.get_width()*picture.scale.x*0.5
	var expected: float=body.position.y+visible_top(picture,middle)
	scene.player.reset_at(body.position+Vector2(middle,-70))
	await frames(90)
	check(scene.player.is_on_floor() and absf(scene.player.position.y-expected)<3.0,"soldier lands on visible bookcase board instead of a transparent bounding box")
	var ray:=PhysicsRayQueryParameters2D.create(body.position+Vector2(-15,-60),body.position+Vector2(-15,320))
	ray.exclude=[scene.player.get_rid()]
	check(scene.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"transparent side of bookcase has no air wall")
	var furniture_count: int=0
	for panel in scene.panels:
		for p in panel.platforms:
			if not p.picture.texture.atlas.resource_path.get_file().begins_with("v4_furniture_"): continue
			furniture_count+=1
			var graphics: int=0
			for child in p.body.get_children():
				if child is Sprite2D: graphics+=1
			check(graphics==1 and absf(p.body.position.y+p.picture.texture.get_height()*p.picture.scale.y-735)<0.01,"furniture rests directly on desk: "+p.picture.name)
	check(furniture_count>20,"replacement covers furniture across the whole journey")
	var final: Dictionary=scene.panels[29].platforms[-1]
	var castle: Sprite2D=scene.panels[29].root.get_node("PaperCastle")
	var castle_width: float=castle.texture.get_width()*castle.scale.x
	var support_left: float=final.body.position.x+final.bounds.position.x
	var support_right: float=final.body.position.x+final.bounds.end.x
	check(castle.position.x>=support_left+10 and castle.position.x+castle_width<=support_right-10,"both castle towers are inside the broad book base")
	var dancer_floor: float=final.body.position.y+CUTOUT.surface_y(final.shapes,scene.dancer_axis.position.x-final.body.position.x)
	check(absf(scene.dancer_axis.position.y-dancer_floor)<0.01,"dancer supporting toe meets the visible book surface")
	scene._load_room(29)
	scene.player.reset_at(scene.room_root.global_position+Vector2(1235,530))
	scene._enter_meeting()
	var soldier_floor: float=final.body.global_position.y+CUTOUT.surface_y(final.shapes,scene.player.global_position.x-final.body.global_position.x)
	check(absf(scene.player.global_position.y-soldier_floor)<0.01,"meeting and cheat place the soldier on the book instead of freezing him in midair")
	print("SUPPORT_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
