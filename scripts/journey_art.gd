extends RefCounted

static var index: Dictionary = {}
static var cutout: ShaderMaterial

static func sprite(asset: String, dimensions: Vector2, region_override: Rect2=Rect2()) -> Sprite2D:
	if index.is_empty():
		index=JSON.parse_string(FileAccess.get_file_as_string("res://assets/journey/asset_index.json"))
	var entry: Dictionary=index[asset]
	var b: Array=entry.region
	var atlas:=AtlasTexture.new()
	atlas.atlas=load("res://assets/journey/%s.png" % asset)
	atlas.region=Rect2(b[0],b[1],b[2],b[3])
	if region_override.has_area(): atlas.region=region_override
	atlas.filter_clip=true
	var picture:=Sprite2D.new()
	picture.name=asset.to_pascal_case()
	picture.texture=atlas
	picture.centered=false
	picture.scale=dimensions/atlas.region.size
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if entry.transparent:
		if cutout==null:
			cutout=ShaderMaterial.new()
			cutout.shader=load("res://assets/soldier/paper_cutout.gdshader")
		picture.material=cutout
	return picture
