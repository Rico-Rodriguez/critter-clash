extends RefCounted
## The "vfx" capture shot: in a live hunt, each element plays cast, travel,
## impact, nova and linger beside the hero, saving a frame sequence per
## element (vfx_<el>_NN.png) that tools/art/vfx_review.sh turns into an mp4.

const VfxLib := preload("res://src/vfx/vfx_lib.gd")


static func shoot(main: Node, h: Node, frames: int) -> void:
	await main._wait_sim(h, 6.0)
	h.bot = false
	for el in VfxLib.ELEMENTS:
		# Keep the level-up cards from covering the effects.
		h.run_xp = 0
		h.pending_levels = 0
		var at: Vector3 = h.hero.flat_pos() + Vector3(0, 0, -3.2)
		var v = h.fx.vfx
		v.cast(el, h.hero.flat_pos(), 1.2)
		v.travel(el, at + Vector3(-2.5, 0.8, 0), Vector3(1, 0, 0))
		v.impact(el, at, 1.6)
		v.nova(el, at, 3.5, 0.6)
		v.linger(el, at + Vector3(2.4, 0, 1.0), 1.2, 1.6)
		h.fx.telegraph(0, at + Vector3(-2.4, 0, 1.0), 0.0, Vector2(1.3, 0), 1.6, 0.6, el)
		for i in frames:
			await main._save("vfx_%s_%02d" % [el, i])
			await main._wait(0.05)
