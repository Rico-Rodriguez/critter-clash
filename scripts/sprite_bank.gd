class_name SpriteBank
extends RefCounted

## Loads painted sprites by filename. Missing files get a flat fallback so a
## new critter id still runs before its PNG lands.
## See README "Sprite drop-in" for paths and pixel sizes.

static var _cache: Dictionary = {}


static func critter(id: String) -> Texture2D:
	return _load("res://assets/sprites/critters/%s.png" % id, id)


static func arena(id: String) -> Texture2D:
	return _load("res://assets/sprites/arenas/%s.png" % id, "arena-" + id)


static func fx(id: String) -> Texture2D:
	return _load("res://assets/sprites/fx/%s.png" % id, id)


static func vignette() -> Texture2D:
	return _load("res://assets/sprites/ui/vignette.png", "vignette")


static func _load(path: String, id: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			_cache[path] = tex
			return tex
	var fallback := _fallback(id)
	_cache[path] = fallback
	return fallback


static func _fallback(id: String) -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color("ffb070")
	var info := Catalog.critter(id)
	if not info.is_empty() and info.has("color"):
		col = Color(str(info["color"]))
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 68).length()
			if d < 42.0:
				var shade := col.lightened(0.15 if y < 60 else -0.05)
				img.set_pixel(x, y, shade)
	var tex := ImageTexture.create_from_image(img)
	return tex
