class_name Hud
extends CanvasLayer
## The hunt's heads-up display. Reads the hunt every frame; sends input back
## through signals. Modal screens (cards, pause, results) are their own scenes.

signal dash_pressed
signal super_pressed
signal card_picked(id: String)
signal results_closed
signal abandon_pressed

const LEVELUP := preload("res://src/ui/levelup.tscn")
const PAUSE := preload("res://src/ui/pause.tscn")
const RESULTS := preload("res://src/ui/results.tscn")

var hunt: Hunt
var _hurt := 0.0
var _banner_tween: Tween
var _toast_tween: Tween
var _scroll_tween: Tween
var _hp_shown := 1.0
var _boss: Boss
var _modal: Control
var _hint: Label
var _streak: Label
var _buffs: Label


func setup(h: Hunt) -> void:
	hunt = h
	Ui.apply_safe_area(%Safe)
	%Stick.blockers.assign([%Dash, %Super, %Pause])
	_layout_buttons()
	%Dash.pressed.connect(func(): dash_pressed.emit())
	%Super.pressed.connect(func(): super_pressed.emit())
	%Pause.pressed.connect(_open_pause)
	%Pause.icon = Ui.icon("pause-button")
	var d: Dictionary = h.hero.def
	var pt := Portraits.tex(Game.hero_id())
	if pt:
		%HeroIcon.texture = pt
		%HeroIcon.offset_left = 4
		%HeroIcon.offset_top = 4
		%HeroIcon.offset_right = -4
		%HeroIcon.offset_bottom = -4
		%HeroIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		%HeroIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		%Medal.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	else:
		%HeroIcon.texture = Ui.icon(d["icon"])
	%Medal.self_modulate = d["color"]
	%Super.icon_name = {"slam": "meteor-impact", "whirlwind": "whirlwind", "volley": "arrow-cluster", "nova": "frozen-orb"}.get(d["super"], "explosion-rays")
	%Super._icon = Ui.icon(%Super.icon_name)
	%Super.caption = d["super_name"]
	%Dash.cooldown_mode = true
	%BossBox.visible = false
	%Banner.modulate.a = 0.0
	%Toast.modulate.a = 0.0
	%Scroll.modulate.a = 0.0
	%ObjTitle.text = "SOULS"
	_buffs = Ui.label("", "HudLabel")
	_buffs.add_theme_font_size_override("font_size", 22)
	_buffs.offset_left = 134.0
	_buffs.offset_top = 112.0
	_buffs.offset_right = 520.0
	_buffs.offset_bottom = 142.0
	add_child(_buffs)
	_streak = Ui.label("", "HudTitle", HORIZONTAL_ALIGNMENT_RIGHT)
	_streak.add_theme_font_size_override("font_size", 30)
	_streak.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	_streak.anchor_left = 1.0
	_streak.anchor_right = 1.0
	_streak.offset_left = -260.0
	_streak.offset_right = -24.0
	_streak.offset_top = 156.0
	_streak.offset_bottom = 196.0
	_streak.modulate.a = 0.0
	add_child(_streak)
	if not bool(Game.data.get("seen_tutorial", false)):
		_hint = Ui.label("Drag anywhere to move\nYou attack on your own · tap the buttons to dash and unleash", "HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
		_hint.add_theme_font_size_override("font_size", 24)
		_hint.anchor_left = 0.0
		_hint.anchor_right = 1.0
		_hint.anchor_top = 0.72
		_hint.anchor_bottom = 0.72
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_hint)


## Dash and Super tuck into the bottom corner on the thumb's side (setting
## "buttons": right or left), leaving the middle of the screen free for the
## stick. The floating stick's rest spot moves to the other side.
func _layout_buttons() -> void:
	var left := str(Game.setting("buttons")) == "left"
	for spec in [[%Dash, 112.0, 116.0], [%Super, 136.0, 256.0]]:
		var c: Control = spec[0]
		var sz: float = spec[1]
		var bottom: float = spec[2]
		c.anchor_left = 0.0 if left else 1.0
		c.anchor_right = 0.0 if left else 1.0
		c.anchor_top = 1.0
		c.anchor_bottom = 1.0
		var x := 36.0 + (136.0 - sz) * 0.5
		c.offset_left = x if left else -x - sz
		c.offset_right = x + sz if left else -x
		c.offset_top = -bottom - sz
		c.offset_bottom = -bottom
		c.grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	%Stick.home_frac = 0.73 if left else 0.27
	%Stick._place_home()


func move_vector() -> Vector2:
	return %Stick.value


func refresh(dt: float) -> void:
	var hero := hunt.hero
	if _hint and (hero.vel.length() > 1.0 and hunt.time > 2.0 or hunt.time > 12.0):
		var h := _hint
		_hint = null
		var t := create_tween()
		t.tween_property(h, "modulate:a", 0.0, 0.6)
		t.tween_callback(h.queue_free)
		Game.data["seen_tutorial"] = true
	var hp_k := clampf(hero.hp / hero.max_hp, 0.0, 1.0)
	_hp_shown = lerpf(_hp_shown, hp_k, 1.0 - exp(-10.0 * dt))
	%HP.value = _hp_shown * 100.0
	%HPText.text = "%d" % ceili(hero.hp)
	%Lvl.text = str(hunt.run_level)
	%XP.value = float(hunt.run_xp) / DB.run_level_xp(hunt.run_level) * 100.0
	%Clock.text = Ui.fmt_time(hunt.time)
	%Souls.value = hunt.progress() * 100.0
	%SoulText.text = "%d / %d" % [hunt.souls, hunt.souls_goal]
	%Gold.text = Ui.fmt_num(hunt.gold)
	# Active shrine blessings with their time left.
	var parts: PackedStringArray = []
	var bcol := Color.WHITE
	for bid: String in hero.buffs:
		parts.append("%s %ds" % [DB.SHRINES[bid]["short"], ceili(float(hero.buffs[bid]) - hunt.time)])
		bcol = DB.SHRINES[bid]["color"]
	_buffs.text = "  ".join(parts)
	_buffs.add_theme_color_override("font_color", bcol)
	# Kill streak: appears from 5 and fades with the window.
	if hunt.streak >= 5:
		_streak.text = "%d kills" % hunt.streak
		_streak.modulate.a = clampf(hunt.streak_t / 0.6, 0.0, 1.0)
	else:
		_streak.modulate.a = 0.0
	%Super.fill = hero.super_charge
	%Super.is_ready = hero.super_ready()
	%Dash.fill = 1.0 - clampf(hero.dash_cd / hero.dash_cd_max, 0.0, 1.0)
	%Dash.is_ready = hero.dash_cd <= 0.0
	if _boss and is_instance_valid(_boss):
		%BossBar.value = clampf(_boss.hp / _boss.max_hp, 0.0, 1.0) * 100.0
	# Hurt vignette: a flash on hits, a slow pulse under 30% health.
	_hurt = maxf(_hurt - dt * 2.2, 0.0)
	var low := 0.0
	if hp_k < 0.3 and hero.alive:
		low = (0.3 - hp_k) / 0.3 * (0.45 + 0.25 * sin(hunt.time * 6.0))
	(%Hurt.material as ShaderMaterial).set_shader_parameter("strength", maxf(_hurt, low))


func hurt(s: float) -> void:
	_hurt = maxf(_hurt, s)


func banner(text: String, color: Color, sub := "") -> void:
	%BannerTitle.text = text
	%BannerTitle.add_theme_color_override("font_color", color)
	%BannerSub.text = sub
	%BannerSub.visible = sub != ""
	if _banner_tween:
		_banner_tween.kill()
	%Banner.pivot_offset = %Banner.size * 0.5
	%Banner.scale = Vector2.ONE * 1.25
	_banner_tween = create_tween().set_parallel(true)
	_banner_tween.tween_property(%Banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(%Banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(1.4)
	_banner_tween.chain().tween_property(%Banner, "modulate:a", 0.0, 0.5)


func toast(bbcode: String, caption := "") -> void:
	%ToastText.text = "[center]%s[/center]" % bbcode
	%ToastCap.text = caption
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(%Toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(%Toast, "modulate:a", 0.0, 0.4)


## The Old School level-up scroll.
func skill_toast(skill: String, level: int) -> void:
	var nm: String = DB.SKILL_NAME[skill]
	%ScrollTitle.text = "Congratulations!"
	var article := "an" if nm[0] in "AEIOU" else "a"
	%ScrollText.text = "You've just advanced %s %s level.\nYou are now level %d." % [article, nm, level]
	%ScrollIcon.texture = Ui.icon(DB.SKILL_ICON[skill])
	if _scroll_tween:
		_scroll_tween.kill()
	_scroll_tween = create_tween().set_parallel(true)
	_scroll_tween.tween_property(%Scroll, "modulate:a", 1.0, 0.2)
	_scroll_tween.chain().tween_interval(2.0)
	_scroll_tween.chain().tween_property(%Scroll, "modulate:a", 0.0, 0.5)
	hunt.fx.burst(hunt.hero.flat_pos() + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.3), 16, 6.0, 1.4)


func boss_mode(b: Boss) -> void:
	_boss = b
	%BossBox.visible = b != null
	%ObjBox.visible = b == null and hunt.phase == "rise"
	if b:
		%BossName.text = "%s, %s" % [b.display_name.to_upper(), b.title.to_upper()]
		Ui.pop_in(%BossBox, 0.0, 0.9)


func show_levelup(choices: Array, level: int) -> void:
	%Stick.release()
	Sfx.duck(true)
	var m := LEVELUP.instantiate()
	add_child(m)
	m.open(hunt, choices, level)
	m.picked.connect(func(id: String):
		m.queue_free()
		Sfx.duck(false)
		card_picked.emit(id))


func _open_pause() -> void:
	if get_tree().paused or hunt.phase in ["victory", "defeat"]:
		return
	%Stick.release()
	get_tree().paused = true
	Sfx.duck(true)
	var m := PAUSE.instantiate()
	add_child(m)
	m.open(hunt)
	m.resumed.connect(func():
		m.queue_free()
		Sfx.duck(false)
		get_tree().paused = false)
	m.abandoned.connect(func():
		m.queue_free()
		Sfx.duck(false)
		abandon_pressed.emit())
	Sfx.play("ui_tap", -4.0)


func _notification(what: int) -> void:
	# Leaving the app mid-hunt pauses it.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hunt and hunt.phase in ["rise", "boss"] and not get_tree().paused:
		_open_pause()


func show_results(result: Dictionary) -> void:
	%Controls.visible = false
	%Safe.visible = false
	%Banner.visible = false
	%Scroll.visible = false
	%Toast.visible = false
	var m := RESULTS.instantiate()
	add_child(m)
	m.open(result)
	m.closed.connect(func(): results_closed.emit())
