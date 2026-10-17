class_name StyleLib
extends RefCounted

static var toon: Shader
static var outline_shader: Shader
static var flat_shader: Shader
static var blob_shader: Shader
static var ready := false


static func ensure() -> void:
	if ready:
		return
	toon = load("res://shaders/toon.gdshader")
	outline_shader = load("res://shaders/outline.gdshader")
	flat_shader = load("res://shaders/flat.gdshader")
	blob_shader = load("res://shaders/blob.gdshader")
	ready = true


static func classify(node_name: String, mat_name: String) -> String:
	var n := node_name.to_lower()
	var m := mat_name.to_lower()
	if n.begins_with("pupil") or n == "mouth" or m == "pupil":
		return "pupil"
	if n.begins_with("catch") or m == "catch":
		return "catch"
	if n.begins_with("sclera") or m == "sclera":
		return "sclera"
	if n.begins_with("glow") or m.begins_with("glow"):
		return "glow"
	if n.begins_with("flag") or m == "flag":
		return "flag"
	if n.begins_with("cloud") or m == "cloud":
		return "cloud"
	if m == "foliage" or n.begins_with("canopy") or n.begins_with("blade") or n == "pad":
		return "foliage"
	return "clay"


static func stylize(root: Node, outline: float, team_tint: Color, flag_color: Color, unique: bool) -> Array:
	ensure()
	var touched: Array = []
	var shared := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var src := mi.mesh.surface_get_material(0)
		var mat_name := ""
		var glow := Color(1.0, 0.55, 0.2)
		var glow_energy := 2.4
		if src:
			mat_name = src.resource_name if src.resource_name != "" else src.name
			if src is StandardMaterial3D:
				var std := src as StandardMaterial3D
				if std.emission_enabled or std.emission_energy_multiplier > 0.1:
					glow = std.emission
					glow_energy = clampf(std.emission_energy_multiplier, 1.2, 4.5)
		var kind := classify(str(mi.name), mat_name)
		var mode := 0
		var wind := 0.0
		var grow := 0.0
		match kind:
			"sclera":
				mode = 1
			"pupil":
				mode = 2
			"catch":
				mode = 3
			"glow":
				mode = 4
			"cloud":
				mode = 5
			"flag":
				mode = 6
				glow = flag_color
			"foliage":
				mode = 0
				wind = 0.045
			_:
				mode = 0
				grow = outline
		var key := "%s_%s_%.3f" % [kind, str(glow), grow]
		var mat: ShaderMaterial
		if unique or not shared.has(key):
			mat = ShaderMaterial.new()
			mat.shader = toon
			mat.set_shader_parameter("shade_mode", mode)
			mat.set_shader_parameter("team_tint", team_tint)
			mat.set_shader_parameter("wind", wind)
			mat.set_shader_parameter("glow_color", glow)
			mat.set_shader_parameter("glow_energy", glow_energy)
			mat.set_shader_parameter("flash", 0.0)
			if team_tint.b > team_tint.r + 0.05:
				mat.set_shader_parameter("rim_color", Color(0.72, 0.84, 1.0))
			else:
				mat.set_shader_parameter("rim_color", Color(1.0, 0.9, 0.74))
			if grow > 0.0:
				var line := ShaderMaterial.new()
				line.shader = outline_shader
				line.set_shader_parameter("grow", grow)
				mat.next_pass = line
			if not unique:
				shared[key] = mat
		else:
			mat = shared[key]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if grow > 0.0 or kind == "clay" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind == "clay" or kind == "foliage" or kind == "flag":
			touched.append(mat)
	return touched


static func flat_material(color: Color, energy: float = 1.0) -> ShaderMaterial:
	ensure()
	var mat := ShaderMaterial.new()
	mat.shader = flat_shader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("energy", energy)
	return mat


static func blob_material(color: Color) -> ShaderMaterial:
	ensure()
	var mat := ShaderMaterial.new()
	mat.shader = blob_shader
	mat.set_shader_parameter("albedo", color)
	return mat
