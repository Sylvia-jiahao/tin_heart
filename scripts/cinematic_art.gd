extends RefCounted
static var index: Dictionary={}
static func sprite(asset: String,dimensions: Vector2) -> Sprite2D:
	if index.is_empty(): index=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cinematics/asset_index.json"))
	var entry: Dictionary=index[asset]
	var b: Array=entry.region
	var atlas:=AtlasTexture.new()
	atlas.atlas=load("res://assets/cinematics/%s.png" % asset)
	atlas.region=Rect2(b[0],b[1],b[2],b[3])
	atlas.filter_clip=true
	var picture:=Sprite2D.new()
	picture.name=asset.to_pascal_case()
	picture.texture=atlas
	picture.centered=false
	picture.scale=dimensions/atlas.region.size
	if entry.transparent:
		var material:=ShaderMaterial.new()
		material.shader=load("res://assets/cinematics/paper.gdshader")
		picture.material=material
	return picture
