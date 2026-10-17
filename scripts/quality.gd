class_name Quality
extends RefCounted

## Render quality tier for the 3D views: "high", "medium" (every phone starts
## here), or "low". The hunt watches its own frame time and steps down a tier
## when frames run long, and the choice is saved so the next hunt starts there.
## Override from the command line with --quality=low|medium|high.

const SLOW_FRAME := 1.0 / 48.0
const WINDOW := 2.0

static var _level := ""


static func level() -> String:
	if _level != "":
		return _level
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			_level = arg.substr(10)
			return _level
	var saved := str(SaveGame.data.get("quality", ""))
	if saved in ["high", "medium", "low"]:
		_level = saved
	elif OS.has_feature("mobile") or OS.get_name() == "iOS":
		_level = "medium"
	else:
		_level = "high"
	return _level


static func set_level(value: String) -> void:
	_level = value
	SaveGame.data["quality"] = value
	SaveGame._write()


## 3D render scale per tier: phones at 3x are fill-rate bound, so medium
## renders the world at 80% and low at 66%, upscaled with FSR.
static func render_scale() -> float:
	match level():
		"low":
			return 0.66
		"medium":
			return 0.8
	return 1.0


## The auto-drop is off in capture, movie and profile runs (they must be
## deterministic) and on software renderers, where every frame is slow.
static func can_auto_drop() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture") or arg.begins_with("--movie") or arg.begins_with("--quality="):
			return false
	var name := RenderingServer.get_video_adapter_name().to_lower()
	return not ("llvmpipe" in name or "lavapipe" in name or "swiftshader" in name)
