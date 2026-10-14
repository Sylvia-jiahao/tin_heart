extends RefCounted

# Trace only the main opaque cutout. Transparent canvas never becomes an air wall.
static var outlines: Dictionary={}

static func outline(picture: Sprite2D) -> PackedVector2Array:
	var atlas: AtlasTexture=picture.texture
	var key: String=atlas.atlas.resource_path+str(atlas.region)
	if not outlines.has(key):
		var image:=atlas.get_image()
		var original:=Vector2(image.get_size())
		var ratio: float=minf(1.0,512.0/maxf(original.x,original.y))
		image.resize(maxi(1,roundi(original.x*ratio)),maxi(1,roundi(original.y*ratio)),Image.INTERPOLATE_NEAREST)
		var bitmap:=BitMap.new()
		bitmap.create_from_image_alpha(image,0.72)
		# Ignore individual crayon flecks so a painted book edge is a walkable surface.
		var candidates:=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,image.get_size()),5.0)
		var largest:=PackedVector2Array()
		var largest_area: float=0.0
		for polygon in candidates:
			var area: float=0.0
			for i in range(polygon.size()): area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
			if absf(area)>largest_area:
				largest_area=absf(area)
				largest=polygon
		for i in range(largest.size()): largest[i]*=original/Vector2(image.get_size())
		outlines[key]=largest
	var transformed:=PackedVector2Array()
	for point in outlines[key]: transformed.append(picture.transform*point)
	return transformed

static func add_to(body: PhysicsBody2D,picture: Sprite2D) -> CollisionPolygon2D:
	var shape:=CollisionPolygon2D.new()
	shape.polygon=walkable_outline(outline(picture))
	body.add_child(shape)
	return shape

static func add_stack(body: PhysicsBody2D,pictures: Array[Sprite2D]) -> CollisionPolygon2D:
	# Only the uppermost object supplies a floor. Lower book covers are not extra steps.
	var upper:=walkable_outline(outline(pictures[0]))
	var top:=PackedVector2Array()
	for point in upper:
		if not top.is_empty() and point.x<=top[-1].x: break
		top.append(point)
	var temporary:=CollisionPolygon2D.new()
	temporary.polygon=upper
	var center_x: float=(top[0].x+top[-1].x)*0.5
	var center_y:=surface_y([temporary],center_x)
	temporary.free()
	var cap:=PackedVector2Array()
	for point in top:
		if point.y<=center_y+10.0: cap.append(point)
	var bottom: float=-INF
	for picture in pictures:
		for point in outline(picture):
			bottom=maxf(bottom,point.y)
	# Vertical side walls cannot report a floor normal or provide a shelf for the foot.
	var landing_span:=Vector2(cap[0].x,cap[-1].x)
	cap.append(Vector2(landing_span.y,bottom))
	cap.append(Vector2(landing_span.x,bottom))
	var shape:=CollisionPolygon2D.new()
	shape.polygon=cap
	shape.set_meta("landing_span",landing_span)
	body.add_child(shape)
	return shape

static func walkable_outline(source: PackedVector2Array) -> PackedVector2Array:
	if source.size()<3: return source
	var left: float=INF
	var right: float=-INF
	for point in source:
		left=minf(left,point.x)
		right=maxf(right,point.x)
	var columns: Array[Vector3]=[]
	var count: int=maxi(2,ceili((right-left)/2.0))
	for column in range(count+1):
		var x: float=lerpf(left+0.2,right-0.2,float(column)/count)
		var top: float=INF
		var bottom: float=-INF
		for i in range(source.size()):
			var a:=source[i]
			var b:=source[(i+1)%source.size()]
			if absf(b.x-a.x)<0.001: continue
			if x>=minf(a.x,b.x) and x<=maxf(a.x,b.x):
				var y: float=lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
				top=minf(top,y)
				bottom=maxf(bottom,y)
		if is_finite(top) and bottom-top>0.1: columns.append(Vector3(x,top,bottom))
	if columns.size()<2: return source
	var tops:=PackedVector2Array()
	for i in range(columns.size()):
		var nearby: Array[float]=[]
		for j in range(maxi(0,i-2),mini(columns.size(),i+3)): nearby.append(columns[j].y)
		nearby.sort()
		# A two-pixel sampling ramp removes tiny vertical paper barbs; major posts remain.
		tops.append(Vector2(columns[i].x,minf(nearby[nearby.size()/2],columns[i].z-0.05)))
	var bottoms:=PackedVector2Array()
	for i in range(columns.size()-1,-1,-1): bottoms.append(Vector2(columns[i].x,columns[i].z))
	var result:=reduce_line(tops)
	result.append_array(reduce_line(bottoms))
	return result

static func reduce_line(points: PackedVector2Array) -> PackedVector2Array:
	var indices: Array[int]=[]
	_reduce_section(points,0,points.size()-1,indices)
	indices.append(points.size()-1)
	var result:=PackedVector2Array()
	for i in indices: result.append(points[i])
	return result

static func _reduce_section(points: PackedVector2Array,start: int,end: int,indices: Array[int]) -> void:
	var distance: float=0.2
	var split: int=-1
	for i in range(start+1,end):
		var candidate: float=points[i].distance_to(Geometry2D.get_closest_point_to_segment(points[i],points[start],points[end]))
		if candidate>distance:
			distance=candidate
			split=i
	if split>=0:
		_reduce_section(points,start,split,indices)
		_reduce_section(points,split,end,indices)
	else: indices.append(start)

static func bounds(shapes: Array) -> Rect2:
	var result:=Rect2()
	var first: bool=true
	for shape in shapes:
		for point in shape.polygon:
			if first:
				result=Rect2(point,Vector2.ZERO)
				first=false
			else: result=result.expand(point)
	return result

static func surface_y(shapes: Array,x: float) -> float:
	var top: float=INF
	for shape in shapes:
		var polygon: PackedVector2Array=shape.polygon
		for i in range(polygon.size()):
			var a:=polygon[i]
			var b:=polygon[(i+1)%polygon.size()]
			if absf(b.x-a.x)<0.001: continue
			if x>=minf(a.x,b.x) and x<=maxf(a.x,b.x):
				top=minf(top,lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
	return top
