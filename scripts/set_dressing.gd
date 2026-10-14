extends RefCounted

const ART=preload("res://scripts/journey_art.gd")

static func _tier(width: float,height: float) -> String:
	var proportion: float=height/maxf(width,1.0)
	return "tall" if proportion>1.8 else ("mid" if proportion>0.8 else "low")

static func asset_for(index: int,ordinal: int,width: float,height: float) -> String:
	var zone: int=index/5
	var seed: int=index*5+ordinal
	var tier:=_tier(width,height)
	var family: String="books"
	if zone==0 and index%5==0:
		family="blocks"
	elif zone==2 or (zone==0 and index%5==3):
		return "v3_furniture_%s_%d" % [tier,1+seed%2]
	elif zone==4 or zone==5:
		family="blocks" if (index+ordinal)%3==0 else "books"
	elif zone==1 and ordinal%3==0:
		return "v3_furniture_%s_%d" % [tier,1+seed%2]
	elif zone==3 and seed%2==0:
		family="blocks"
	var asset: String="v3_%s_%s_%d" % [family,tier,1+seed%4]
	return asset+"_flat" if asset in ["v3_blocks_tall_1","v3_blocks_tall_3"] else asset

static func fitted(asset: String,maximum: Vector2) -> Sprite2D:
	var picture:=ART.sprite(asset,maximum)
	var bounds: Vector2=picture.texture.get_size()
	var uniform: float=minf(maximum.x/bounds.x,maximum.y/bounds.y)
	picture.scale=Vector2.ONE*uniform
	picture.position.x=(maximum.x-bounds.x*uniform)*0.5
	return picture

static func _supported_asset(preferred: String,width: float,height: float) -> String:
	var bounds: Array=ART.index[preferred].region
	var natural_ratio: float=float(bounds[3])/float(bounds[2])
	if minf(1.0,height/width/natural_ratio)>=0.7:
		return preferred
	var family: String="v3_furniture_" if "furniture" in preferred else ("v3_blocks_" if "blocks" in preferred else "v3_books_")
	var best: String=preferred
	var best_error: float=1000.0
	for candidate in ART.index:
		if not str(candidate).begins_with(family) or candidate in ["v3_blocks_tall_1","v3_blocks_tall_3"]: continue
		var box: Array=ART.index[candidate].region
		var proportion: float=float(box[3])/float(box[2])
		if minf(1.0,height/width/proportion)<0.7: continue
		var error: float=absf(log(proportion/(height/width)))
		if error<best_error:
			best_error=error
			best=candidate
	return best

static func complete_stack(parent: Node2D,index: int,ordinal: int,width: float,height: float) -> Sprite2D:
	var name:=asset_for(index,ordinal,width,height)
	if "furniture" in name:
		# A cabinet belongs on the floor. Choose its proportions instead of propping it on books.
		var required: float=height/width
		var options: Array[String]=[]
		for candidate in ART.index:
			if not str(candidate).begins_with("v4_furniture_"): continue
			var box: Array=ART.index[candidate].region
			var ratio: float=float(box[3])/float(box[2])
			if ratio<required*0.95: continue
			options.append(str(candidate))
		var matched: Array[String]=[]
		for candidate in options:
			var box: Array=ART.index[candidate].region
			var ratio: float=float(box[3])/float(box[2])
			if ratio<=required*1.35: matched.append(candidate)
		matched.sort()
		if not matched.is_empty():
			var selected: String=matched[(index+ordinal)%matched.size()]
			var furniture:=ART.sprite(selected,Vector2(width,height))
			var uniform: float=height/furniture.texture.get_height()
			furniture.scale=Vector2.ONE*uniform
			furniture.position.x=(width-furniture.texture.get_width()*uniform)*0.5
			parent.add_child(furniture)
			return furniture
		# A narrow cabinet cannot stand in for a broad landing. Use a book stack there.
		name="v3_books_%s_%d" % [_tier(width,height),1+(index+ordinal)%4]
	name=_supported_asset(name,width,height)
	var picture:=fitted(name,Vector2(width,height))
	parent.add_child(picture)
	var used_height: float=picture.texture.get_height()*picture.scale.y-4.0
	var seed: int=index*3+ordinal
	# Complete lower books support any remaining height. Every component keeps its ratio.
	for row in range(8):
		var remaining: float=height-used_height
		if remaining<=5.0: break
		var tier:=_tier(width,remaining)
		var lower_name: String="v3_single_book_%d" % (1+(seed+row)%4) if remaining<width*0.3 else "v3_books_%s_%d" % [tier,1+(seed+row+1)%4]
		var lower:=fitted(lower_name,Vector2(width,remaining))
		lower.position.y=used_height-3.0
		parent.add_child(lower)
		used_height=lower.position.y+lower.texture.get_height()*lower.scale.y-3.0
	return picture

static func wall_shelf(parent: Node2D,width: float,seed: int,wide: bool=false) -> Sprite2D:
	var name: String="v3_wall_shelf_wide" if wide else "v3_wall_shelf_%d" % (1+seed%3)
	var picture:=ART.sprite(name,Vector2(width,width*0.3))
	var ratio: float=width/picture.texture.get_width()
	picture.scale=Vector2.ONE*ratio
	parent.add_child(picture)
	return picture
