extends Node3D
## One piece of the Cinder Mire's boardwalk. It sits on a PLANK terrain cell, which
## is how the arena finds it (`arena.plank_nodes`): when the cell catches fire the
## arena calls `burn()` and the wood chars and glows; when the cell falls into the
## bog the arena sinks the node. No class_name: preloaded by arena_mire.gd.

var _body: MeshInstance3D
var _burnt: Material


func setup(mesh: Mesh, material: Material, burnt: Material) -> void:
	_body = MeshInstance3D.new()
	_body.mesh = mesh
	_body.material_override = material
	add_child(_body)
	_burnt = burnt


func burn() -> void:
	if _body != null and _burnt != null:
		_body.material_override = _burnt
