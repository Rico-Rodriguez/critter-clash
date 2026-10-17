class_name HuntMap
extends RefCounted

## One biome's world, as data. The shipped hunts are a single screen:
## one chunk, one spawn zone, boss at the top of that zone.
## A later explorable map is the same record with more chunks and zones
## (about 4 by 4 screens, sixteen times the area).

const VIEW := Vector2(720, 1280)
## The shipped hunt arena: about three times the old one-screen field, so the far
## follow camera (RunSim.VIEW_BOX) fits inside it with room for packs to
## appear just off screen and still inside the arena.
const ARENA := Vector2(1120, 2236)
const PLAY := Rect2(40, 168, 1040, 1900)
const CHUNK := Vector2(720, 1280)
## A zone this close to the hero (or holding the hero) is allowed to spawn.
const ZONE_REACH := 1100.0
## Extra world pixels kept alive past the view so a chunk is ready before it scrolls in.
const STREAM_MARGIN := 128.0


var id := "meadow"
var size := VIEW
var play := PLAY
var chunk_size := CHUNK
var chunks: Array = []
var zones: Array = []
## Top-center of the boss arena. The boss stands one radius below this point.
var boss_at := Vector2(360, 168)


static func for_biome(biome_id: String) -> HuntMap:
	var map := HuntMap.new()
	map.id = biome_id
	map.size = ARENA
	map.play = PLAY
	map.chunk_size = ARENA
	map.boss_at = Vector2(PLAY.get_center().x, PLAY.position.y)
	map.chunks = [{
		"col": 0,
		"row": 0,
		"ground": biome_id,
		"props": [],
	}]
	map.zones = [{
		"id": "wilds",
		"rect": PLAY,
	}]
	return map


## A 4x4-screen world for tests and for the next map. Not used by a live hunt.
static func explore(biome_id: String, screens_x: int = 4, screens_y: int = 4) -> HuntMap:
	var map := HuntMap.new()
	map.id = biome_id
	map.chunk_size = CHUNK
	map.size = Vector2(CHUNK.x * float(screens_x), CHUNK.y * float(screens_y))
	map.play = Rect2(Vector2.ZERO, map.size)
	map.chunks = []
	map.zones = []
	for row in screens_y:
		for col in screens_x:
			var origin := Vector2(float(col) * CHUNK.x, float(row) * CHUNK.y)
			map.chunks.append({
				"col": col,
				"row": row,
				"ground": biome_id,
				"props": [
					{"sprite": "gem", "pos": Vector2(160, 280), "scale": 0.35},
					{"sprite": "shadow", "pos": Vector2(420, 760), "scale": 0.45},
				],
			})
			map.zones.append({
				"id": "%d_%d" % [col, row],
				"rect": Rect2(origin + PLAY.position, PLAY.size),
			})
	var last: Vector2 = map.chunk_origin(screens_x - 1, screens_y - 1)
	map.boss_at = last + Vector2(PLAY.get_center().x, PLAY.position.y)
	return map


func boss_spawn(radius: float) -> Vector2:
	return boss_at + Vector2(0, radius + 8.0)


func chunk_origin(col: int, row: int) -> Vector2:
	return Vector2(float(col) * chunk_size.x, float(row) * chunk_size.y)


func chunk_rect(chunk: Dictionary) -> Rect2:
	return Rect2(chunk_origin(int(chunk["col"]), int(chunk["row"])), chunk_size)


func chunks_in(view: Rect2, margin: float = STREAM_MARGIN) -> Array:
	var area := view.grow(margin)
	var out: Array = []
	for chunk in chunks:
		if chunk_rect(chunk).intersects(area):
			out.append(chunk)
	return out


func zone_near(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1.0e12
	var near: Dictionary = {}
	var near_d := 1.0e12
	for zone in zones:
		var rect: Rect2 = zone["rect"]
		var dist := _dist_to_rect(at, rect)
		if dist < best_d:
			best = zone
			best_d = dist
		if dist <= ZONE_REACH and dist < near_d:
			near = zone
			near_d = dist
	if not near.is_empty():
		return near
	if best.is_empty():
		return {"id": "wilds", "rect": play}
	return best


static func rim_point(rect: Rect2, rng: RandomNumberGenerator) -> Vector2:
	var side := rng.randi() % 4
	match side:
		0:
			return Vector2(rect.position.x + 8.0, rng.randf_range(rect.position.y, rect.end.y))
		1:
			return Vector2(rect.end.x - 8.0, rng.randf_range(rect.position.y, rect.end.y))
		2:
			return Vector2(rng.randf_range(rect.position.x, rect.end.x), rect.position.y + 8.0)
		_:
			return Vector2(rng.randf_range(rect.position.x, rect.end.x), rect.end.y - 8.0)


static func _dist_to_rect(at: Vector2, rect: Rect2) -> float:
	var x := clampf(at.x, rect.position.x, rect.end.x)
	var y := clampf(at.y, rect.position.y, rect.end.y)
	return at.distance_to(Vector2(x, y))
