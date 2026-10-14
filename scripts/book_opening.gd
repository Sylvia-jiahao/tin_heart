extends CanvasLayer
const ART=preload("res://scripts/cinematic_art.gd")
const DURATION=15.0
var clock: float=0.0
var book: Node2D
var cover: Sprite2D
var spread: Sprite2D
var cover_scale: Vector2
var backdrop: Sprite2D
var inside: Sprite2D
var chapter_title: Label
var narration: Label
var skip_hint: Label
func _ready() -> void:
	layer=110
	backdrop=ART.sprite("desk_opening",Vector2(1280,800))
	add_child(backdrop)
	book=Node2D.new()
	add_child(book)
	spread=ART.sprite("book_spread",Vector2(1000,600))
	# Only the fixed right half exists behind the cover. Never draw a full spread.
	var right_texture: AtlasTexture=spread.texture.duplicate()
	right_texture.region.position.x+=right_texture.region.size.x*0.5
	right_texture.region.size.x*=0.5
	spread.texture=right_texture
	spread.scale=Vector2(500,600)/right_texture.region.size
	book.add_child(spread)
	cover=ART.sprite("book_cover",Vector2(500,600))
	book.add_child(cover)
	cover_scale=cover.scale
	inside=ART.sprite("book_spread",Vector2(1000,600))
	# Use the generated left page as the inside of the turning cover.
	var texture: AtlasTexture=inside.texture.duplicate()
	texture.region.size.x*=0.5
	inside.texture=texture
	inside.scale=Vector2(500,600)/texture.region.size
	book.add_child(inside)
	chapter_title=label("第一章\n纸城堡",Vector2(60,130),380,42)
	narration=label("盒子里有二十五个锡兵。\n\n最后一个，只有一条腿。",Vector2(50,310),400,25)
	skip_hint=label("Enter 跳过  ·  C 继续旅程",Vector2(40,730),550,18,self)
	update_shot(0.0)
func label(text: String,at: Vector2,width: float,size: int,parent: Node=null) -> Label:
	if parent==null: parent=book
	var result:=Label.new()
	result.text=text
	result.position=at
	result.size.x=width
	result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",Color.BLACK)
	result.add_theme_color_override("font_outline_color",Color.WHITE)
	result.add_theme_constant_override("outline_size",4)
	parent.add_child(result)
	return result
func smooth(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)
func update_shot(time: float) -> void:
	clock=time
	var viewport: Vector2=get_viewport().get_visible_rect().size
	backdrop.scale=viewport/backdrop.texture.get_size()
	var opening: float=smooth((clock-1.8)/4.5)
	book.position=Vector2(390+250*opening,100)
	spread.visible=opening>0.0
	# The front cover rotates around its left spine, rather than its center.
	cover.scale=cover_scale*Vector2(maxf(0.005,cos(opening*PI)),1.0)
	cover.visible=opening<0.5
	inside.visible=opening>=0.5
	inside.scale=Vector2(500,600)/(inside.texture as AtlasTexture).region.size*Vector2(maxf(0.005,-cos(opening*PI)),1.0)
	inside.position.x=-500*maxf(0.005,-cos(opening*PI))
	var zoom: float=smooth((clock-12.0)/2.0)
	book.scale=Vector2.ONE*lerpf(1.0,1.6,zoom)
	book.position=book.position.lerp(Vector2(640,400)-Vector2(250,300)*book.scale,zoom)
	book.position+=(viewport-Vector2(1280,800))*0.5
	chapter_title.modulate.a=smooth((clock-6.5)/1.0)
	narration.modulate.a=smooth((clock-7.8)/1.5)
	var fade: float=1.0-smooth((clock-13.5)/1.5)
	book.modulate.a=fade
	backdrop.modulate.a=fade
	skip_hint.modulate.a=fade
