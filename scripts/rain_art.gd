extends RefCounted

static var index: Dictionary={}
static var material: ShaderMaterial

static func sprite(asset: String,width: float,height: float=0.0) -> Sprite2D:
	if index.is_empty() and FileAccess.file_exists("res://assets/chapter02/asset_index.json"):
		index=JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter02/asset_index.json"))
	if not index.has(asset):
		push_error("Missing generated chapter-two asset: "+asset)
		return Sprite2D.new()
	var entry: Dictionary=index[asset]
	var b: Array=entry.region
	var atlas:=AtlasTexture.new()
	atlas.atlas=load("res://assets/chapter02/%s.png" % asset)
	atlas.region=Rect2(b[0],b[1],b[2],b[3])
	atlas.filter_clip=true
	var picture:=Sprite2D.new()
	picture.name=asset.to_pascal_case()
	picture.texture=atlas
	picture.centered=false
	picture.scale=Vector2.ONE*width/float(b[2])
	if height>0: picture.scale.y=height/float(b[3])
	if entry.transparent:
		if material==null:
			material=ShaderMaterial.new()
			material.shader=load("res://assets/cinematics/paper.gdshader")
		picture.material=material
	return picture
