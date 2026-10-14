extends Node2D

const ART=preload("res://scripts/journey_art.gd")
var strength: float=0.0
var time: float=0.0
var wind_direction: float=1.0
var streaks: Array[Sprite2D]=[]
var scraps: Array[Sprite2D]=[]

func clear() -> void:
	strength=0.0
	for sprite in streaks: sprite.modulate.a=0.0
	for sprite in scraps: sprite.modulate.a=0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	for i in range(22):
		var stroke:=ART.sprite("wind_streak",Vector2(120+(i%4)*35,16+(i%3)*8))
		stroke.modulate.a=0.0
		add_child(stroke)
		streaks.append(stroke)
	for i in range(8):
		var scrap:=ART.sprite("paper_leaf",Vector2(12+(i%3)*3,14+(i%3)*4))
		scrap.modulate.a=0.0
		add_child(scrap)
		scraps.append(scrap)

func _process(delta: float) -> void:
	var viewport:=get_viewport_rect().size
	var intensity:=clampf(absf(strength)/500.0,0.0,1.0)
	# Keep the last direction while fading out through a lull in the gust.
	if absf(strength)>0.01:
		wind_direction=signf(strength)
	var direction: float=wind_direction
	time+=delta*(40.0+absf(strength)*1.5)
	for i in range(streaks.size()):
		var stroke: Sprite2D=streaks[i]
		var x:=fposmod(float(i)*137.0+time,viewport.x+280)-140
		stroke.position=Vector2(x if direction>0 else viewport.x-x,120+fposmod(float(i)*113.0,viewport.y-150)+sin(time*0.003+i)*14)
		# Negative Node2D scales decompose into rotation and the other scale axis.
		# Sprite mirroring keeps the direction stable over successive frames.
		stroke.flip_h=direction<0.0
		stroke.modulate.a=lerpf(stroke.modulate.a,intensity*0.45,1.0-exp(-delta*9))
	for i in range(scraps.size()):
		var scrap: Sprite2D=scraps[i]
		var x:=fposmod(i*237.0+time*0.78,viewport.x+100)-50
		scrap.position=Vector2(x if direction>0 else viewport.x-x,150+fposmod(i*183.0,viewport.y-180)+sin(time*0.006+i)*40)
		scrap.rotation=time*0.005*direction+i
		scrap.modulate.a=lerpf(scrap.modulate.a,intensity*0.65,1.0-exp(-delta*9))
