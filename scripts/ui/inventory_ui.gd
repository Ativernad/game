class_name InventoryUI
extends MenuBase
## Інвентар: сітка предметів, опис, реліквії, характеристики.
## Наведення/фокус — показує опис. Натискання — використати / вдягнути.

signal closed

const COLS := 6
const SLOTS := 24

var player: Player
var _grid: GridContainer
var _icon: TextureRect
var _name: Label
var _type: Label
var _desc: Label
var _hint: Label
var _stats: Label
var _relics: HBoxContainer
var _slots: Array[Button] = []
var _ids: Array = []
var _last_focus := 0

var _class_label: Label

func _ready() -> void:
	make_frame(0.75, 980.0)
	var head := HBoxContainer.new()
	var t := UITheme.title("ІНВЕНТАР", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_class_label = UITheme.label(Game.class_title(), 20, UITheme.GOLD)
	head.add_child(_class_label)
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	var left := VBoxContainer.new()
	row.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	for i in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 56)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size", 16)
		var idx := i
		b.focus_entered.connect(func():
			_last_focus = idx
			_show(idx)
			Audio.play("ui_move", 1.2, -10.0))
		b.mouse_entered.connect(func(): b.grab_focus())
		b.pressed.connect(func(): _activate(idx))
		_grid.add_child(b)
		_slots.append(b)
	left.add_child(UITheme.label("РЕЛІКВІЇ (макс. %d)" % Game.MAX_RELICS, 16, UITheme.GOLD))
	_relics = HBoxContainer.new()
	left.add_child(_relics)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(96, 96)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_icon)
	_name = UITheme.label("", 26, UITheme.GOLD_HI)
	right.add_child(_name)
	_type = UITheme.label("", 16, UITheme.DIM)
	right.add_child(_type)
	_desc = UITheme.label("", 19)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(400, 150)
	right.add_child(_desc)
	_hint = UITheme.label("", 17, UITheme.GOLD)
	right.add_child(_hint)
	right.add_child(HSeparator.new())
	_stats = UITheme.label("", 17, UITheme.TEXT)
	right.add_child(_stats)

	box.add_child(UITheme.button("Закрити", func(): closed.emit()))
	Game.inventory_changed.connect(_refresh)

func open() -> void:
	visible = true
	_class_label.text = Game.class_title()   # клас міг змінитися посеред рівня
	_refresh()
	_slots[clamp(_last_focus, 0, SLOTS - 1)].grab_focus()

func _refresh() -> void:
	if not is_inside_tree():
		return
	_ids.clear()
	for e in Game.inventory:
		_ids.append(e.id)
	for i in SLOTS:
		var b := _slots[i]
		if i < _ids.size():
			var id: String = _ids[i]
			b.icon = Art.tex("icon_" + id)
			var n := Game.count(id)
			b.text = str(n) if n > 1 else ""
			if Game.equipped.has(id):
				b.text = "✦"
			b.modulate = Color(1, 1, 1)
		else:
			b.icon = null
			b.text = ""
			b.modulate = Color(0.6, 0.6, 0.6)
	for ch in _relics.get_children():
		ch.queue_free()
	for i in Game.MAX_RELICS:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(52, 52)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if i < Game.equipped.size():
			tr.texture = Art.tex("icon_" + Game.equipped[i])
		var p := PanelContainer.new()
		p.add_child(tr)
		_relics.add_child(p)
	_stats.text = "Здоров'я: %d / %d\nШкода: %d%%   Захист: %d%%\nВбито ворогів: %d" % [
		int(Game.hp), int(Game.max_hp()), int(Game.damage_mult() * 100), int(Game.defense() * 100), Game.kills]
	_show(_last_focus)

func _show(i: int) -> void:
	if i >= _ids.size():
		_icon.texture = null
		_name.text = "—"
		_type.text = ""
		_desc.text = "Порожньо. Як і більшість кишень у цих землях."
		_hint.text = ""
		return
	var id: String = _ids[i]
	var it := ItemDB.get_item(id)
	_icon.texture = Art.tex("icon_" + id)
	_name.text = it.name
	_type.text = ItemDB.TYPE_NAMES.get(it.type, "") + ("  ×%d" % Game.count(id) if Game.count(id) > 1 else "")
	_desc.text = it.desc
	match it.type:
		"consumable": _hint.text = "Натисни, щоб використати"
		"relic": _hint.text = "Натисни, щоб " + ("зняти" if Game.equipped.has(id) else "вдягнути")
		"key": _hint.text = "Відчиняє замкнені ґрати"
		_: _hint.text = ""

func _activate(i: int) -> void:
	if i >= _ids.size():
		return
	var id: String = _ids[i]
	var it := ItemDB.get_item(id)
	match it.type:
		"consumable":
			if player:
				player.use_item(id)
		"relic":
			Game.toggle_equip(id)
			Audio.play("ui_ok")
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
