extends RefCounted

static var index: Dictionary = {}
static var material: ShaderMaterial

static func sprite(asset: String, dimensions: Vector2, region_override: Rect2 = Rect2()) -> Sprite2D:
	if index.is_empty():
		index = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter01/asset_index.json"))
	var entry: Dictionary = index[asset]
	var bounds: Array = entry["region"]
	var region := Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	if region_override.has_area():
		region = region_override
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/chapter01/%s.png" % asset)
	atlas.region = region
	atlas.filter_clip = true
	var result := Sprite2D.new()
	result.name = asset.to_pascal_case()
	result.texture = atlas
	result.centered = false
	result.scale = dimensions/region.size
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if entry["transparent"]:
		if material == null:
			material = ShaderMaterial.new()
			material.shader = load("res://assets/soldier/paper_cutout.gdshader")
		result.material = material
	return result
