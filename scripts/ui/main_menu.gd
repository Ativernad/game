extends Control
## Головне меню з намальованим нічним пейзажем замку та попелом.

var _menu: VBoxContainer
var _settings: SettingsMenu
var _t := 0.0
var _bg: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_mood("menu")
	Audio.fade_music(1.0)
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.draw.connect(_draw_bg)
	add_child(_bg)
	var ash := CPUParticles2D.new()
	ash.amount = 90
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(1100, 10)
	ash.position = Vector2(640, -20)
	ash.direction = Vector2(0.2, 1)
	ash.spread = 20
	ash.gravity = Vector2(6, 12)
	ash.initial_velocity_min = 15
	ash.initial_velocity_max = 40
	ash.scale_amount_min = 1.5
	ash.scale_amount_max = 3.5
	ash.color = Color(0.75, 0.7, 0.62, 0.6)
	add_child(ash)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)
	var t := UITheme.title("ПОПІЛ СВІТАНКУ", 82)
	root.add_child(t)
	root.add_child(UITheme.label("дарк-фентезі RPG", 22, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	root.add_child(sp)
	var cc := CenterContainer.new()
	root.add_child(cc)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	cc.add_child(_menu)
	if Game.has_save():
		var b := UITheme.button("Продовжити", func(): Game.continue_game())
		_menu.add_child(b)
	_menu.add_child(UITheme.button("Нова гра", func(): get_tree().change_scene_to_file("res://scenes/class_select.tscn")))
	_menu.add_child(UITheme.button("Налаштування", _open_settings))
	_menu.add_child(UITheme.button("Вийти", func(): get_tree().quit()))
	var ver := UITheme.label("Godot 4.7 · клавіатура, миша, контролер", 14, UITheme.DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 16
	ver.offset_top = -30
	add_child(ver)
	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_menu.visible = true
		_menu.get_child(0).grab_focus())
	add_child(_settings)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 1.5)
	_menu.get_child(0).grab_focus()

func _open_settings() -> void:
	_menu.visible = false
	_settings.open()

func _process(delta: float) -> void:
	_t += delta
	_bg.queue_redraw()

func _draw_bg() -> void:
	var s := _bg.size
	var steps := 24
	for i in steps:
		var k := float(i) / steps
		var c := Color(0.02, 0.02, 0.04).lerp(Color(0.16, 0.06, 0.05), k * k)
		_bg.draw_rect(Rect2(0, s.y * k, s.x, s.y / steps + 1), c)
	# місяць
	var mp := Vector2(s.x * 0.72, s.y * 0.26)
	_bg.draw_circle(mp, 70, Color(0.75, 0.7, 0.6, 0.08))
	_bg.draw_circle(mp, 46, Color(0.78, 0.74, 0.64))
	_bg.draw_circle(mp + Vector2(16, -8), 40, Color(0.04, 0.03, 0.05))
	# далекі гори
	var hills := PackedVector2Array([Vector2(0, s.y)])
	for i in 21:
		var x := s.x * i / 20.0
		hills.append(Vector2(x, s.y * 0.72 - sin(i * 1.3) * 30 - sin(i * 0.4) * 40))
	hills.append(Vector2(s.x, s.y))
	_bg.draw_colored_polygon(hills, Color(0.06, 0.04, 0.05))
	# замок
	var base := s.y * 0.78
	var cx := s.x * 0.5
	var col := Color(0.02, 0.015, 0.02)
	var towers := [[-260, 60, 180], [-150, 44, 250], [-40, 70, 330], [60, 50, 290], [170, 46, 220], [270, 60, 160]]
	for tw in towers:
		var x: float = cx + tw[0]
		var w: float = tw[1]
		var h: float = tw[2]
		_bg.draw_rect(Rect2(x - w * 0.5, base - h, w, h + 200), col)
		_bg.draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.6, base - h), Vector2(x + w * 0.6, base - h), Vector2(x, base - h - w * 1.3)]), col)
		var flick := 0.6 + 0.4 * sin(_t * 3.0 + x)
		_bg.draw_rect(Rect2(x - 3, base - h * 0.6, 6, 10), Color(0.9, 0.5, 0.2, 0.5 * flick))
	_bg.draw_rect(Rect2(cx - 320, base - 90, 640, 300), col)
	_bg.draw_rect(Rect2(0, base + 40, s.x, s.y), Color(0.015, 0.01, 0.015))
	# віньєтка
	for i in 8:
		var a := 0.05 * (8 - i)
		_bg.draw_rect(Rect2(i * 12, i * 12, s.x - i * 24, s.y - i * 24), Color(0, 0, 0, a), false, 12.0)
