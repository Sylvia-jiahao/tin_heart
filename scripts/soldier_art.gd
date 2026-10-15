extends Node2D

@export var walk_hop_period: float = 0.26
@export var walk_hop_height: float = 18.0
var actor: Node
var walk_phase: float = 0.0
var hop_offset := Vector2.ZERO
var salute_weight: float = 0.0
var facing_root: Node2D
var torso: Node2D
var head: Node2D
var thigh: Node2D
var shin: Node2D
var boot: Node2D
var left_arm: Node2D
var right_arm: Node2D
var left_forearm: Node2D
var right_forearm: Node2D
var musket: Node2D
var cutout_material: ShaderMaterial
var border_material: ShaderMaterial
var pickup_pieces: Array[Sprite2D]=[]
var cinematic_pose: String=""
var cinematic_time: float=0.0
var boat_left_grip: Sprite2D
var boat_right_grip: Sprite2D

const REGIONS := {
	"torso": Rect2(50,105,934,1348), "head": Rect2(131,10,797,1471),
	"upper_arm": Rect2(289,92,540,1363), "forearm": Rect2(313,40,398,1438),
	"thigh": Rect2(290,46,500,1456), "shin": Rect2(324,46,427,1438),
	"boot": Rect2(53,56,1453,925), "musket": Rect2(365,38,292,1465)
}

func _ready() -> void:
	name = "PaperSoldier"
	if actor == null:
		actor = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	cutout_material = ShaderMaterial.new()
	cutout_material.shader = load("res://assets/soldier/paper_cutout.gdshader")
	border_material = ShaderMaterial.new()
	border_material.shader = cutout_material.shader
	border_material.set_shader_parameter("border_only", true)
	facing_root = _joint(self,"Facing",Vector2.ZERO)
	thigh = _joint(facing_root,"Hip",Vector2(0,-49))
	_piece(thigh,"thigh",Vector2(9,24),Vector2(-4.5,-2))
	shin = _joint(thigh,"Knee",Vector2(0,20))
	_piece(shin,"shin",Vector2(8,26),Vector2(-4,-2))
	boot = _joint(shin,"Ankle",Vector2(0,22))
	_piece(boot,"boot",Vector2(20,12),Vector2(-5,-5))
	torso = _joint(facing_root,"BodyPivot",Vector2(0,-49))
	left_arm = _joint(torso,"BackShoulder",Vector2(-16,-35))
	left_arm.z_index = 3
	_piece(left_arm,"upper_arm",Vector2(11,22),Vector2(-5.5,-3),true)
	left_forearm = _joint(left_arm,"BackElbow",Vector2(0,16))
	_piece(left_forearm,"forearm",Vector2(8,27),Vector2(-4,-3),true)
	_piece(torso,"torso",Vector2(38,51),Vector2(-19,-46))
	head = _joint(torso,"Neck",Vector2(0,-44))
	_piece(head,"head",Vector2(27,49),Vector2(-13.5,-45))
	right_arm = _joint(torso,"FrontShoulder",Vector2(16,-35))
	_piece(right_arm,"upper_arm",Vector2(11,22),Vector2(-5.5,-3))
	right_forearm = _joint(right_arm,"FrontElbow",Vector2(0,16))
	musket = _joint(right_forearm,"ToyMusket",Vector2(4,17))
	_piece(musket,"musket",Vector2(13,86),Vector2(-6,-64))
	_piece(right_forearm,"forearm",Vector2(8,27),Vector2(-4,-3))
	for joint in [torso,head,left_arm,right_arm,left_forearm,right_forearm,thigh,shin,boot]:
		_pin(joint)

func _joint(parent: Node, joint_name: String, at: Vector2) -> Node2D:
	var joint := Node2D.new()
	joint.name = joint_name
	joint.position = at
	parent.add_child(joint)
	return joint

func _piece(parent: Node2D, asset: String, dimensions: Vector2, at: Vector2, mirrored: bool=false) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/soldier/%s.png" % asset)
	atlas.region = REGIONS[asset]
	atlas.filter_clip = true
	# White backing keeps the scissor rim visible at gameplay scale.
	var backing := Sprite2D.new()
	backing.name = asset.to_pascal_case()+"WhiteRim"
	backing.texture = atlas
	backing.centered = false
	backing.flip_h = mirrored
	backing.position = at-Vector2.ONE
	backing.scale = (dimensions+Vector2(2,2))/atlas.region.size
	backing.material = border_material
	parent.add_child(backing)
	var sprite := Sprite2D.new()
	sprite.name = asset.to_pascal_case()+"Paper"
	sprite.texture = atlas
	sprite.centered = false
	sprite.flip_h = mirrored
	sprite.position = at
	sprite.scale = dimensions/atlas.region.size
	sprite.material = cutout_material
	parent.add_child(sprite)
	if asset!="head" and asset!="musket": pickup_pieces.append(sprite)
	return sprite

func touches_star(at: Vector2) -> bool:
	# Use the animated paper body and limbs, including mirrored or raised arms.
	# Head/hat and equipment do not extend the pickup region.
	var star:=PackedVector2Array([at+Vector2(-12,-12),at+Vector2(12,-12),at+Vector2(12,12),at+Vector2(-12,12)])
	for piece in pickup_pieces:
		var rect:=piece.get_rect()
		var body:=PackedVector2Array([piece.to_global(rect.position),piece.to_global(Vector2(rect.end.x,rect.position.y)),piece.to_global(rect.end),piece.to_global(Vector2(rect.position.x,rect.end.y))])
		if not Geometry2D.intersect_polygons(body,star).is_empty(): return true
	return false

func _pin(parent: Node2D) -> void:
	var art = load("res://scripts/chapter_art.gd")
	var pin: Sprite2D = art.sprite("brass_pin",Vector2(5,5))
	pin.name = "BrassPin"
	pin.position = Vector2(-2.5,-2.5)
	parent.add_child(pin)

func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	if cinematic_pose!="":
		_cinematic_pose()
		return
	var s = actor
	# Apply once to the actual character, not the detached action-demo paper preview.
	if get_parent()==actor:
		position=s.render_position()-s.position
	var lean: float = sin(s.clock*2.0)*0.02
	var crouch := 0.0
	var back_shoulder := 0.04
	var back_elbow := -0.08
	var gun_shoulder := 0.02
	var gun_elbow := -0.05
	var gun_tilt := -0.04
	hop_offset = Vector2.ZERO
	if s.preparing:
		walk_phase = 0.0
		var t: float = clampf(s.charge_time/s.charge_duration,0,1)
		crouch = 13.0*t
		lean = 0.24*t
		back_shoulder = 0.0
		back_elbow = -1.50*t
		gun_shoulder = 0.0
		gun_elbow = -1.25*t
		gun_tilt = lerpf(-0.04,0.30,t)
	elif s.braced:
		walk_phase = 0.0
		lean = 0.0
		back_shoulder = 0.0
		back_elbow = 0.0
		gun_shoulder = 0.0
		gun_elbow = 0.0
	elif s.recovery_time > 0.0:
		walk_phase = 0.0
		var t: float = s.recovery_time/s.landing_recovery
		crouch = 14.0*t
		lean = sin((1.0-t)*TAU)*0.12*t
		back_shoulder = 0.20*t
		back_elbow = -0.60*t
		gun_shoulder = 0.04*t
		gun_elbow = -0.15*t
	elif not s.is_on_floor():
		walk_phase = 0.0
		lean = 0.0
		crouch = 0.0
		back_shoulder = 0.0
		back_elbow = 0.0
		gun_shoulder = 0.0
		gun_elbow = 0.0
	elif s.state == "走路":
		walk_phase = fposmod(walk_phase+delta/walk_hop_period,1.0)
		lean = 0.025
		if walk_phase < 0.20:
			crouch = sin(walk_phase/0.20*PI)*5.0
		else:
			var arc: float = sin((walk_phase-0.20)/0.80*PI)
			hop_offset.y = -arc*walk_hop_height
			crouch = arc*3.0
			back_shoulder = 0.10+arc*0.08
			back_elbow = -0.22-arc*0.12
			gun_shoulder = 0.03
			gun_elbow = -0.12
	else:
		walk_phase = 0.0
	facing_root.position = hop_offset
	facing_root.scale = Vector2(s.facing,1)
	torso.position = Vector2(0,-49+crouch)
	torso.rotation = lean
	head.rotation = -lean*(0.8 if s.preparing else 0.2)
	# Compact soldier silhouette: rear elbow back, gun arm tucked at the side.
	left_arm.rotation = back_shoulder
	right_arm.rotation = gun_shoulder
	left_forearm.rotation = back_elbow
	right_forearm.rotation = gun_elbow
	# The empty hand reaches the temple; rigid paper parts turn at their pins.
	var saluting: bool = s.braced and not s.preparing and s.recovery_time <= 0.0
	salute_weight = 0.0 if s.preparing else move_toward(salute_weight,1.0 if saluting else 0.0,delta*8.0)
	var hand_target := Vector2(-6,-64)
	var hand_offset := hand_target-left_arm.position
	var reach: float = hand_offset.length()
	var shoulder_bend: float = acos(clampf((256.0+reach*reach-484.0)/(32.0*reach),-1,1))
	var salute_shoulder: float = hand_offset.angle()-PI/2.0-shoulder_bend
	if salute_shoulder < -PI:
		salute_shoulder += TAU
	var salute_elbow: float = PI-acos(clampf((740.0-reach*reach)/704.0,-1,1))
	left_arm.rotation = lerp_angle(back_shoulder,salute_shoulder,salute_weight)
	left_forearm.rotation = lerp_angle(back_elbow,salute_elbow,salute_weight)
	left_arm.z_index = 3
	# Keep the folded empty forearm visible over the coat in every pose.
	left_forearm.z_as_relative = true
	left_forearm.z_index = 0
	# Rigid paper thigh and shin fold around a visible knee; the boot stays planted.
	var distance: float = clampf(42.0-crouch,20.0,42.0)
	var hip_angle: float = acos(clampf((400.0+distance*distance-484.0)/(40.0*distance),-1,1))
	var knee_angle: float = PI-acos(clampf((400.0+484.0-distance*distance)/880.0,-1,1))
	thigh.position = Vector2(0,-49+crouch)
	thigh.rotation = -hip_angle
	shin.rotation = knee_angle
	boot.rotation = hip_angle-knee_angle
	# Counter-rotate at the grip so the long barrel stays beside the face.
	musket.rotation = -torso.rotation-right_arm.rotation-right_forearm.rotation+gun_tilt

func clear_cinematic_pose() -> void:
	cinematic_pose=""
	if not is_instance_valid(facing_root): return
	facing_root.rotation=0
	facing_root.position=Vector2.ZERO
	thigh.visible=true
	left_arm.z_as_relative=true
	left_arm.z_index=3
	right_arm.z_as_relative=true
	right_arm.z_index=0
	musket.z_as_relative=true
	musket.z_index=0
	musket.position=Vector2(4,17)
	if is_instance_valid(boat_left_grip):
		boat_left_grip.visible=false
		boat_right_grip.visible=false
	for forearm in [left_forearm,right_forearm]:
		forearm.get_node("ForearmPaper").visible=true
		forearm.get_node("ForearmWhiteRim").visible=true
		forearm.get_node("BrassPin").z_index=0
		forearm.get_node("BrassPin").position=Vector2(-2.5,-2.5)

func _boat_grips() -> void:
	if not is_instance_valid(boat_left_grip):
		var rain_art=load("res://scripts/rain_art.gd")
		boat_left_grip=rain_art.sprite("boat_forearm_grip",25,13)
		boat_left_grip.position=Vector2(-2,-3)
		boat_left_grip.z_index=1
		var sleeve_tone:=ShaderMaterial.new()
		sleeve_tone.shader=load("res://assets/chapter02/boat_sleeve_tone.gdshader")
		boat_left_grip.material=sleeve_tone
		left_forearm.add_child(boat_left_grip)
		boat_right_grip=rain_art.sprite("boat_forearm_grip",25,13)
		boat_right_grip.flip_h=true
		boat_right_grip.position=Vector2(-23,-5)
		boat_right_grip.z_index=1
		boat_right_grip.material=sleeve_tone
		right_forearm.add_child(boat_right_grip)
	boat_left_grip.visible=true
	boat_right_grip.visible=true
	for forearm in [left_forearm,right_forearm]:
		forearm.get_node("ForearmPaper").visible=false
		forearm.get_node("ForearmWhiteRim").visible=false
		forearm.get_node("BrassPin").z_index=2
	left_forearm.get_node("BrassPin").position=Vector2(-2.5,-0.5)

func play_cinematic_pose(pose: String,time: float=0.0) -> void:
	cinematic_pose=pose
	cinematic_time=time
	_cinematic_pose()

func _reach(upper: Node2D,lower: Node2D,target: Vector2,bend: float,first: float=16.0,second: float=22.0) -> void:
	var offset: Vector2=target-upper.position
	var distance: float=clampf(offset.length(),absf(first-second)+0.1,first+second-0.01)
	var angle: float=acos(clampf((first*first+distance*distance-second*second)/(2*first*distance),-1,1))
	upper.rotation=offset.angle()-PI/2-bend*angle
	lower.rotation=bend*(PI-acos(clampf((first*first+second*second-distance*distance)/(2*first*second),-1,1)))

func _cinematic_pose() -> void:
	position=Vector2.ZERO
	musket.position=Vector2(4,17)
	facing_root.scale=Vector2.ONE
	facing_root.position=Vector2.ZERO
	facing_root.rotation=0
	torso.position=Vector2(0,-49)
	torso.rotation=0
	head.rotation=0
	thigh.position=Vector2(0,-49)
	thigh.rotation=0
	shin.rotation=0
	boot.rotation=0
	left_arm.rotation=0
	right_arm.rotation=0
	left_forearm.rotation=0
	right_forearm.rotation=0
	if cinematic_pose=="boat_hold":
		thigh.visible=false
		_boat_grips()
		# Lower the chest against the near fold; elbows open and forearms wrap inward.
		torso.position.y=-30
		torso.rotation=0.12
		head.rotation=-0.08
		left_arm.rotation=0.65
		right_arm.rotation=-0.65
		left_forearm.rotation=0.20-torso.rotation-left_arm.rotation
		right_forearm.rotation=-torso.rotation-right_arm.rotation
		# Coat and gun stay inside the hull; the gripping arms cross the near rim.
		left_arm.z_as_relative=false
		right_arm.z_as_relative=false
		left_arm.z_index=24
		right_arm.z_index=24
		musket.z_as_relative=false
		musket.z_index=21
	else:
		var rise: float=smoothstep(0.8,4.2,cinematic_time)
		var fold: float=sin(rise*PI)
		var tilt: float=(PI/2)*(1-rise)
		# Lower the hip into a crouch before straightening. A planted boot and palm
		# support the body; this must not read as a rigid toy levitating upright.
		var hip:=Vector2(-6*(1-rise),-lerpf(19,49,rise)+20*fold)
		facing_root.rotation=tilt
		facing_root.position=hip-Vector2(0,-49).rotated(tilt)
		torso.rotation=0.60*fold
		head.rotation=-0.15*fold
		var plant: float=smoothstep(0.0,0.6,rise)
		var ankle:=Vector2(lerpf(-48,0,plant),lerpf(-19,-7,plant))
		var leg_target: Vector2=facing_root.to_local(to_global(ankle))
		_reach(thigh,shin,leg_target,1,20,22)
		boot.rotation=lerpf(PI/2,0,plant)-tilt-thigh.rotation-shin.rotation
		right_arm.rotation=0.3*fold
		right_forearm.rotation=-0.75*fold
		var support: float=1-smoothstep(2.7,4.0,cinematic_time)
		var target: Vector2=torso.to_local(to_global(Vector2(30,-1)))
		_reach(left_arm,left_forearm,target,1)
		left_arm.rotation=lerp_angle(0,left_arm.rotation,support)
		left_forearm.rotation=lerp_angle(0,left_forearm.rotation,support)
		if cinematic_time>4.2:
			torso.rotation=sin((cinematic_time-4.2)*TAU*1.8)*0.045*(1-smoothstep(4.2,4.8,cinematic_time))
	musket.rotation=-torso.rotation-right_arm.rotation-right_forearm.rotation-0.04
	if cinematic_pose=="boat_hold":
		# Both hands grip the paper; the musket rests separately inside the boat.
		musket.global_position=to_global(Vector2(46,-63))
		musket.global_rotation=global_rotation-0.14
	if cinematic_pose=="rise" and cinematic_time<4.2:
		# Leave the gun on the stone while pushing up, then lift it back to its grip.
		var pickup: float=smoothstep(2.8,4.2,cinematic_time)
		var grip: Vector2=musket.global_position
		var upright: float=musket.global_rotation
		musket.global_position=to_global(Vector2(-20,-7)).lerp(grip,pickup)
		musket.global_rotation=lerp_angle(global_rotation+PI/2,upright,pickup)
