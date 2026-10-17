class_name MapStream
extends Node2D

## Instances the ground and props for chunks that overlap the camera,
## and frees the rest. A one-chunk map keeps a single backdrop.

var _nodes: Dictionary = {}


func sync(map: HuntMap, view: Rect2) -> void:
	var want := {}
	for chunk in map.chunks_in(view):
		want[_key(chunk)] = chunk
	var stale: Array = []
	for key in _nodes.keys():
		if not want.has(key):
			stale.append(key)
	for key in stale:
		var gone: Node = _nodes[key]
		_nodes.erase(key)
		if is_instance_valid(gone):
			remove_child(gone)
			gone.free()
	for key in want.keys():
		if _nodes.has(key):
			continue
		var node := _build(map, want[key])
		_nodes[key] = node
		add_child(node)


func _key(chunk: Dictionary) -> String:
	return "%d_%d" % [int(chunk["col"]), int(chunk["row"])]


func _build(map: HuntMap, chunk: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = _key(chunk)
	root.position = map.chunk_origin(int(chunk["col"]), int(chunk["row"]))
	var ground := Sprite2D.new()
	ground.centered = false
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex := SpriteBank.arena(str(chunk.get("ground", map.id)))
	ground.texture = tex
	if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
		ground.scale = Vector2(map.chunk_size.x / float(tex.get_width()), map.chunk_size.y / float(tex.get_height()))
	root.add_child(ground)
	var props: Array = chunk.get("props", [])
	for prop in props:
		var sprite := Sprite2D.new()
		sprite.centered = true
		sprite.texture = SpriteBank.fx(str(prop.get("sprite", "gem")))
		sprite.position = prop.get("pos", Vector2.ZERO)
		var scale := float(prop.get("scale", 1.0))
		sprite.scale = Vector2(scale, scale)
		root.add_child(sprite)
	return root
