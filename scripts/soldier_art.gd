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
	_piece(left_arm,"upper_arm",Vector2(11,22),Vector2(-5.5,-3))
	left_forearm = _joint(left_arm,"BackElbow",Vector2(0,16))
	_piece(left_forearm,"forearm",Vector2(8,27),Vector2(-4,-3))
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

func _piece(parent: Node2D, asset: String, dimensions: Vector2, at: Vector2) -> Sprite2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/soldier/%s.png" % asset)
	atlas.region = REGIONS[asset]
	atlas.filter_clip = true
	# White backing keeps the scissor rim visible at gameplay scale.
	var backing := Sprite2D.new()
	backing.name = asset.to_pascal_case()+"WhiteRim"
	backing.texture = atlas
	backing.centered = false
	backing.position = at-Vector2.ONE
	backing.scale = (dimensions+Vector2(2,2))/atlas.region.size
	backing.material = border_material
	parent.add_child(backing)
	var sprite := Sprite2D.new()
	sprite.name = asset.to_pascal_case()+"Paper"
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = at
	sprite.scale = dimensions/atlas.region.size
	sprite.material = cutout_material
	parent.add_child(sprite)
	return sprite

func _pin(parent: Node2D) -> void:
	var rim := Polygon2D.new()
	rim.name = "BrassPinRim"
	var face := Polygon2D.new()
	face.name = "BrassPin"
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(12):
		var p := Vector2.from_angle(float(i)/12.0*TAU)
		outer.append(p*2.5)
		inner.append(p*1.6)
	rim.polygon = outer
	rim.color = Color("695039")
	face.polygon = inner
	face.color = Color("d9b369")
	parent.add_child(rim)
	parent.add_child(face)

func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	var s = actor
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
