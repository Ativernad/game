class_name SettingsMenu
extends MenuBase
## Налаштування: звук, графіка, керування. Працює з мишею і контролером.

signal closed

var _first: Control

func _ready() -> void:
	make_frame(0.75, 720.0)
	box.add_child(UITheme.title("НАЛАШТУВАННЯ", 40))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	_section(list, "ЗВУК")
	_slider(list, "Загальна гучність", "master", 0.0, 1.0, 0.05, true)
	_slider(list, "Музика й атмосфера", "music", 0.0, 1.0, 0.05, true)
	_slider(list, "Ефекти", "sfx", 0.0, 1.0, 0.05, true)
	_section(list, "ГРАФІКА")
	_check(list, "Повний екран", "fullscreen")
	_check(list, "Вертикальна синхронізація", "vsync")
	_check(list, "Ретро-фільтр (пікселі, палітра)", "retro")
	_slider(list, "Яскравість", "brightness", 0.5, 1.8, 0.05, true)
	_slider(list, "Поле зору (FOV)", "fov", 60.0, 100.0, 1.0, false)
	_check(list, "Похитування камери", "head_bob")
	_section(list, "КЕРУВАННЯ")
	_slider(list, "Чутливість миші", "mouse_sens", 0.05, 1.0, 0.01, false)
	_slider(list, "Чутливість стіка", "pad_sens", 1.0, 6.0, 0.1, false)
	_check(list, "Інвертувати вісь Y", "invert_y")
	_section(list, "КЛАВІШІ")
	var help := [
		["Рух", "WASD / лівий стік"], ["Огляд", "Миша / правий стік"],
		["Атака", "ЛКМ / RT"], ["Особлива дія (блок, кинджал, ривок)", "ПКМ / LT"],
		["Біг", "Shift / L3"], ["Стрибок", "Пробіл / A"], ["Взаємодія", "E / X"],
		["Швидке лікування", "Q / Y"], ["Інвентар", "Tab / Back"], ["Пауза", "Esc / Start"],
	]
	for h in help:
		var row := HBoxContainer.new()
		var a := UITheme.label(h[0], 18, UITheme.TEXT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(UITheme.label(h[1], 18, UITheme.GOLD))
		list.add_child(row)
	box.add_child(UITheme.button("Назад", close))

func _section(list: VBoxContainer, text: String) -> void:
	var l := UITheme.label(text, 18, UITheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	list.add_child(l)

func _slider(list: VBoxContainer, text: String, key: String, mn: float, mx: float, step: float, percent: bool) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.label(text, 20)
	l.custom_minimum_size = Vector2(300, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(260, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := UITheme.label("", 18, UITheme.GOLD_HI)
	v.custom_minimum_size = Vector2(70, 0)
	row.add_child(v)
	var upd := func(val: float):
		v.text = ("%d%%" % int(round(val * 100.0))) if percent else (str(snappedf(val, step)))
	upd.call(s.value)
	s.value_changed.connect(func(val: float):
		upd.call(val)
		Settings.set_v(key, val)
		if key in ["sfx", "master"]:
			Audio.play("ui_move"))
	s.mouse_entered.connect(func(): s.grab_focus())
	list.add_child(row)
	if _first == null:
		_first = s

func _check(list: VBoxContainer, text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Settings.get_v(key))
	c.toggled.connect(func(on: bool):
		Audio.play("ui_ok")
		Settings.set_v(key, on))
	c.mouse_entered.connect(func(): c.grab_focus())
	list.add_child(c)

func open() -> void:
	visible = true
	if _first:
		_first.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
