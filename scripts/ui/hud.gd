class_name HUD
extends CanvasLayer
## Ігровий інтерфейс: здоров'я, витривалість, бос, підказки, повідомлення.

var player: Player
var _bars: Control
var _prompt: Label
var _msgs: VBoxContainer
var _boss_box: Control
var _boss_name: Label
var _boss: Enemy
var _flash: ColorRect
var _fade: ColorRect
var _title: VBoxContainer
var _big: Label
var _info: Label
var _cross: Control
var _pad := false
var _shown_hp := 100.0

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)

	_flash = ColorRect.new()
	_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	_cross = Control.new()
	_place(_cross, 0.5, 0.5, 0, 0, 1, 1)
	_cross.draw.connect(_draw_cross)
	root.add_child(_cross)

	_bars = Control.new()
	_place(_bars, 0.0, 1.0, 28, -96, 700, 60)
	_bars.draw.connect(_draw_bars)
	root.add_child(_bars)

	_info = UITheme.label("", 18, UITheme.DIM)
	_place(_info, 0.0, 1.0, 30, -48, 1100, 30)
	root.add_child(_info)

	_prompt = UITheme.label("", 24, UITheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt, 0.5, 1.0, -400, -210, 800, 40)
	_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	root.add_child(_prompt)

	_msgs = VBoxContainer.new()
	_place(_msgs, 0.0, 0.0, 28, 24, 700, 300)
	root.add_child(_msgs)

	_boss_box = Control.new()
	_place(_boss_box, 0.5, 0.0, -360, 30, 720, 60)
	_boss_box.visible = false
	_boss_box.draw.connect(_draw_boss)
	root.add_child(_boss_box)
	_boss_name = UITheme.label("", 24, UITheme.GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name.size = Vector2(720, 30)
	_boss_name.add_theme_color_override("font_shadow_color", Color.BLACK)
	_boss_box.add_child(_boss_name)

	_big = UITheme.title("", 64)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.modulate.a = 0.0
	root.add_child(_big)

	_title = VBoxContainer.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.modulate.a = 0.0
	root.add_child(_title)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)

	Game.message.connect(show_message)
	if player:
		player.damaged.connect(_on_damaged)
	_shown_hp = Game.hp

func _place(c: Control, ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_top = oy
	c.offset_right = ox + w
	c.offset_bottom = oy + h

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.4):
		_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_pad = false

func key_name(action: String) -> String:
	var map_pad := {"interact": "X", "heal": "Y", "inventory": "Back", "pause": "Start"}
	var map_kb := {"interact": "E", "heal": "Q", "inventory": "Tab", "pause": "Esc"}
	return (map_pad if _pad else map_kb).get(action, "?")

func _process(delta: float) -> void:
	_shown_hp = lerp(_shown_hp, Game.hp, clamp(delta * 4.0, 0.0, 1.0))
	_bars.queue_redraw()
	_cross.queue_redraw()
	if _boss_box.visible:
		_boss_box.queue_redraw()
	if player and not player.dead:
		var it := player.find_interactable()
		var pr := it.prompt() if it else ""
		_prompt.text = ("[%s] %s" % [key_name("interact"), pr]) if pr != "" else ""
		var heals := 0
		for e in Game.inventory:
			if ItemDB.get_item(e.id).has("heal"):
				heals += e.count
		var buffs := ""
		if player.buff_damage > 0.0:
			buffs += "   Сіль: %dс" % int(player.buff_damage)
		if player.buff_stamina > 0.0:
			buffs += "   Ладан: %dс" % int(player.buff_stamina)
		_info.text = "[%s] лікування: %d    [%s] інвентар%s" % [key_name("heal"), heals, key_name("inventory"), buffs]
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 1.5)
	var low: float = 1.0 - clamp(Game.hp / Game.max_hp() / 0.3, 0.0, 1.0)
	if low > 0.0:
		_flash.color.a = max(_flash.color.a, low * (0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.006)))

func _draw_cross() -> void:
	_cross.draw_circle(Vector2.ZERO, 2.0, Color(0.9, 0.85, 0.7, 0.6))
	if player == null or player.dead:
		return
	var ch := player.bow_charge()
	if ch >= 0.0:
		# кільце стискається з натягом; на повному — золоте
		var full := ch >= 1.0
		var col := UITheme.GOLD_HI if full else Color(0.9, 0.85, 0.7, 0.35 + 0.4 * ch)
		_cross.draw_arc(Vector2.ZERO, lerpf(22.0, 7.0, ch), 0.0, TAU, 32, col, 2.0 if full else 1.5)
	if player.is_healing():
		_cross.draw_arc(Vector2.ZERO, 12.0, -PI / 2, -PI / 2 + TAU * (1.0 - player._heal_t / Player.HEAL_TIME), 32, Color(0.6, 0.9, 0.5, 0.8), 2.0)

func _draw_bars() -> void:
	var c := _bars
	var mh := Game.max_hp()
	var w := 260.0 + mh * 0.4
	_bar(c, Vector2(0, 0), Vector2(w, 18), Game.hp / mh, _shown_hp / mh, Color(0.6, 0.06, 0.06))
	c.draw_string(UITheme.font(), Vector2(w + 10, 15), "%d / %d" % [int(Game.hp), int(mh)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.TEXT)
	if player:
		var sw := 200.0 + player.max_stamina * 0.5
		var col := Color(0.55, 0.5, 0.2) if player.buff_stamina <= 0.0 else Color(0.8, 0.7, 0.3)
		_bar(c, Vector2(0, 26), Vector2(sw, 10), player.stamina / player.max_stamina, player.stamina / player.max_stamina, col)

func _bar(c: Control, pos: Vector2, size: Vector2, v: float, ghost: float, col: Color) -> void:
	c.draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color(0, 0, 0, 0.8))
	c.draw_rect(Rect2(pos, size), Color(0.1, 0.07, 0.06))
	c.draw_rect(Rect2(pos, Vector2(size.x * clamp(ghost, 0, 1), size.y)), Color(0.9, 0.8, 0.6, 0.5))
	c.draw_rect(Rect2(pos, Vector2(size.x * clamp(v, 0, 1), size.y)), col)
	c.draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), UITheme.GOLD * Color(1, 1, 1, 0.6), false, 1.0)

func _draw_boss() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var k := clampf(_boss.hp / _boss.max_hp, 0.0, 1.0)
	_bar(_boss_box, Vector2(0, 34), Vector2(720, 14), k, k, Color(0.55, 0.05, 0.08))

func show_boss(e: Enemy) -> void:
	_boss = e
	_boss_name.text = e.data.name
	_boss_box.visible = true
	_boss_box.modulate.a = 0.0
	create_tween().tween_property(_boss_box, "modulate:a", 1.0, 1.0)

func hide_boss() -> void:
	_boss_box.visible = false
	_boss = null

func show_message(text: String) -> void:
	var l := UITheme.label(text, 20, UITheme.TEXT)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	_msgs.add_child(l)
	if _msgs.get_child_count() > 5:
		_msgs.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func _on_damaged(amount: float) -> void:
	_flash.color.a = clamp(0.15 + amount / 60.0, 0.15, 0.55)

func title_card(name: String, sub: String, chapter: String) -> void:
	for c in _title.get_children():
		c.queue_free()
	_title.add_child(UITheme.label(chapter.to_upper(), 18, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_title.add_child(UITheme.title(name.to_upper(), 58))
	_title.add_child(UITheme.label(sub, 22, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_title, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.6)
	tw.tween_property(_title, "modulate:a", 0.0, 1.5)

func big_message(text: String) -> void:
	_big.text = text
	var tw := create_tween()
	tw.tween_property(_big, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(_big, "modulate:a", 0.0, 1.5)

func fade_out(t: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, t)
	return tw.finished
