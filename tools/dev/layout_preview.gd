extends Node3D
## A zone's arena with no hunt: a top-down and an angled still, for judging layouts.
## usage (see tools/dev/layout-cap.sh): res://tools/dev/layout_preview.tscn -- <zone> <out_prefix> [tilt=...] [t=<sim seconds>]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone: String = args[0] if args.size() > 0 else "frost"
	var out: String = args[1] if args.size() > 1 else "/tmp/layout"
	var a := Arena.new()
	add_child(a)
	a.build(false, zone)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 60.0
	cam.position = Vector3(0, 60, -5)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	await get_tree().create_timer(1.0).timeout
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "_top.png")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 55.0
	for v in [["south", Vector3(0, 30, 38), Vector3(-42, 0, 0)], ["north", Vector3(0, 22, -2), Vector3(-38, 0, 0)]]:
		cam.position = v[1]
		cam.rotation_degrees = v[2]
		for i in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out + "_" + str(v[0]) + ".png")
	get_tree().quit()
