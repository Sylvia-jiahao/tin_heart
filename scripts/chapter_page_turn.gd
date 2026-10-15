extends CanvasLayer
## Reuses the generated opening book. The outgoing scene becomes its right page.
const ART=preload("res://scripts/cinematic_art.gd")
const DURATION: float=11.0
var clock: float=0.0
var snapshot: Texture2D
var desk: Sprite2D
var book: Node2D
var left: Sprite2D
var right: Sprite2D
var turning: Node2D
var page: Sprite2D
var scene_picture: Sprite2D
var title: Label
var narration: Label
var skip_hint: Label
func half_page(left_half: bool) -> Sprite2D:
	var result:=ART.sprite("book_spread",Vector2(1000,600))
	var texture: AtlasTexture=result.texture.duplicate()
	if not left_half: texture.region.position.x+=texture.region.size.x*0.5
	texture.region.size.x*=0.5
	result.texture=texture
	result.scale=Vector2(500,600)/texture.region.size
	return result
func _ready() -> void:
	layer=110
	desk=ART.sprite("desk_opening",Vector2(1280,800))
	add_child(desk)
	book=Node2D.new()
	add_child(book)
	left=half_page(true)
	left.position.x=-500
	book.add_child(left)
	right=half_page(false)
	book.add_child(right)
	title=make_label("第二章\n雨比世界大",Vector2(40,140),420,40)
	narration=make_label("他还望着屋里的暖光。\n\n窗外，风已经来了。",Vector2(40,340),420,25)
	turning=Node2D.new()
	book.add_child(turning)
	page=half_page(false)
	turning.add_child(page)
	scene_picture=Sprite2D.new()
	scene_picture.texture=snapshot
	scene_picture.centered=false
	turning.add_child(scene_picture)
	skip_hint=make_label("Enter — 继续  ·  C — 继续雨街旅程",Vector2.ZERO,700,18)
	skip_hint.reparent(self,false)
	update_shot(0)
func make_label(text: String,at: Vector2,width: float,size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.position=at
	label.size.x=width
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color.BLACK)
	label.add_theme_color_override("font_outline_color",Color.WHITE)
	label.add_theme_constant_override("outline_size",4)
	book.add_child(label)
	return label
func update_shot(time: float) -> void:
	clock=time
	var viewport: Vector2=get_viewport().get_visible_rect().size
	var fit: float=minf(viewport.x/1280.0,viewport.y/800.0)
	book.position=viewport*0.5+Vector2(0,-300)*fit
	book.scale=Vector2.ONE*fit
	desk.scale=viewport/desk.texture.get_size()
	var shrink: float=smoothstep(0.0,2.5,time)
	var target:=Rect2(Vector2(35,115),Vector2(430,320))
	# At t=0 this is exactly the previous full-screen shot, with no frame jump.
	scene_picture.position=(-book.position/fit).lerp(target.position,shrink)
	if snapshot!=null:
		scene_picture.scale=(viewport/fit).lerp(target.size,shrink)/snapshot.get_size()
	# The shrinking picture reveals the desk, never the next chapter underneath it.
	desk.modulate.a=1.0
	left.modulate.a=shrink
	right.modulate.a=shrink
	page.modulate.a=shrink
	var flip: float=smoothstep(3.0,5.0,time)
	var axis: float=cos(flip*PI)
	turning.scale.x=maxf(absf(axis),0.005)
	turning.position.x=0 if flip<0.5 else -500*absf(axis)
	page.texture=(right.texture if flip<0.5 else left.texture)
	scene_picture.visible=flip<0.5
	title.modulate.a=smoothstep(5.2,6.2,time)
	narration.modulate.a=smoothstep(6.3,7.5,time)
	var reveal: float=smoothstep(9.0,11.0,time)
	book.scale*=lerpf(1.0,1.6,reveal)
	book.position=book.position.lerp(viewport*0.5-Vector2(250,300)*book.scale,reveal)
	book.modulate.a=1.0-reveal
	desk.modulate.a*=1.0-reveal
	skip_hint.position=Vector2((viewport.x-700)*0.5,viewport.y-45)
	skip_hint.modulate.a=smoothstep(2.2,2.8,time)*(1.0-reveal)
