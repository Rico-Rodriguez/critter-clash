class_name KK
extends RefCounted
## KayKit helpers: every hero and skeleton shares the Rig_Medium skeleton, so
## one AnimationLibrary (baked by tools/bake_anims.gd) drives all of them.

const LIB_PATH := "res://assets/kaykit/animations/rig_medium_lib.res"
const CHAR_DIR := "res://assets/kaykit/characters/"
const WEAPON_DIR := "res://assets/kaykit/weapons/"

static var _lib: AnimationLibrary
static var _scenes := {}


static func lib() -> AnimationLibrary:
	if _lib == null:
		_lib = load(LIB_PATH)
	return _lib


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Instances a prop (gltf/glb) by path.
static func prop(path: String) -> Node3D:
	return scene(path).instantiate()


## Builds a character: the model, an AnimationPlayer with the shared library,
## and weapons in its hand slots. `weapons` maps "handslot.r"/"handslot.l" to a
## weapon file name inside assets/kaykit/weapons.
static func character(model: String, weapons := {}) -> Node3D:
	var root: Node3D = scene(CHAR_DIR + model + ".glb").instantiate()
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	root.add_child(ap)
	ap.add_animation_library("", lib())
	var skel: Skeleton3D = root.find_child("Skeleton3D", true, false)
	for slot in weapons:
		var att := BoneAttachment3D.new()
		att.bone_name = slot
		skel.add_child(att)
		att.add_child(prop(WEAPON_DIR + str(weapons[slot])))
	return root


static func anim_player(character_root: Node) -> AnimationPlayer:
	return character_root.get_node("Anim")


static func meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n)
	return out
