class_name ClassSelect
extends Control
## Вибір класу: три карти таро — Колісниця (лицар), Місяць (лучниця), Блазень (жебрак).
## in_game = true — карти розкладає стара посеред руїн (поверх гри, на паузі).

signal picked(id: String)
signal cancelled

var in_game := false

var _cards: Array[TarotCard] = []
var _name: Label
var _weapon: Label
var _desc: Label
var _stats: Control
var _cur := "knight"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not in_game:
		Audio.set_mood("menu")
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.025, 0.86 if in_game else 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := UITheme.centered(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	if in_game:
		v.add_child(UITheme.title("СТАРА РОЗКЛАДАЄ КАРТИ", 46))
		v.add_child(UITheme.label("«Ти прийшов ніким. Витягни карту — і підеш далі кимось.»", 20, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UITheme.title("ВИТЯГНИ СВОЮ КАРТУ", 46))
		v.add_child(UITheme.label("Доля вже перетасувала колоду. Тобі лишилося обрати.", 20, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	for id in Game.TAROT:
		var card := TarotCard.new()
		card.setup(id)
		card.chosen.connect(_on_chosen)
		card.focus_entered.connect(func(): _show(id))
		row.add_child(card)
		_cards.append(card)
	var info := PanelContainer.new()
	info.custom_minimum_size = Vector2(900, 190)
	v.add_child(info)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 24)
	info.add_child(ih)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	ih.add_child(left)
	_name = UITheme.label("", 30, UITheme.GOLD_HI)
	left.add_child(_name)
	_weapon = UITheme.label("", 18, UITheme.GOLD)
	left.add_child(_weapon)
	_stats = Control.new()
	_stats.custom_minimum_size = Vector2(300, 100)
	_stats.draw.connect(_draw_stats)
	left.add_child(_stats)
	_desc = UITheme.label("", 18)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(_desc)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	v.add_child(btns)
	btns.add_child(UITheme.button("Ще не час" if in_game else "Назад", _back, 200))
	btns.add_child(UITheme.label("Клік / A по карті — %s" % ("обрати долю" if in_game else "почати шлях"), 18, UITheme.DIM))
	# роздача карт
	for i in _cards.size():
		var card := _cards[i]
		card.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.15 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.4)
		card.flip_up(0.7 + 0.35 * i)
	_show("knight")
	await get_tree().create_timer(1.6).timeout
	_cards[0].grab_focus()

func _show(id: String) -> void:
	_cur = id
	var c: Dictionary = Game.CLASSES[id]
	_name.text = c.name
	_weapon.text = "%s %s · %s" % [c.arcana, c.card, c.weapon]
	_desc.text = c.desc
	_stats.queue_redraw()

func _draw_stats() -> void:
	var c: Dictionary = Game.CLASSES[_cur]
	var rows := [["Здоров'я", c.hp / 140.0], ["Витривалість", c.stamina / 140.0], ["Швидкість", c.speed / 6.0], ["Шкода", c.damage / 32.0]]
	var f := UITheme.font()
	for i in rows.size():
		var y := 14.0 + i * 24.0
		_stats.draw_string(f, Vector2(0, y + 6), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.TEXT)
		_stats.draw_rect(Rect2(130, y - 6, 160, 10), Color(0.12, 0.09, 0.08))
		_stats.draw_rect(Rect2(130, y - 6, 160 * clamp(rows[i][1], 0.0, 1.0), 10), UITheme.BLOOD.lightened(0.2))

func _on_chosen(id: String) -> void:
	for card in _cards:
		card.focus_mode = Control.FOCUS_NONE
		if card.class_id != id:
			create_tween().tween_property(card, "modulate:a", 0.0, 0.5)
	Audio.play("bell", 0.9)
	if in_game:
		var tw2 := create_tween()
		tw2.tween_interval(0.7)
		tw2.tween_property(self, "modulate:a", 0.0, 0.6)
		await tw2.finished
		picked.emit(id)
		queue_free()
		return
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	await tw.finished
	Game.new_game(id)

func _back() -> void:
	if in_game:
		cancelled.emit()
		queue_free()
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()
