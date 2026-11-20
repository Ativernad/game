class_name DebugMenu
extends MenuBase
## Меню налагодження (клавіша «Д», лише в debug-збірках): безсмертя й телепорти —
## у будь-яку локацію або до ключових точок поточної.

signal closed

var world: Node
var _first: Control

func _ready() -> void:
	make_frame(0.7, 640.0)
	box.add_child(UITheme.title("НАЛАГОДЖЕННЯ", 40))
	var god := CheckBox.new()
	god.text = "Нескінченне здоров'я (безсмертя)"
	god.button_pressed = Game.god_mode
	god.toggled.connect(func(on: bool):
		Game.god_mode = on
		if on:
			Game.hp = Game.max_hp()
		Audio.play("ui_ok"))
	box.add_child(god)
	_first = god

	box.add_child(UITheme.label("ТЕЛЕПОРТ У ЦІЙ ЛОКАЦІЇ", 18, UITheme.GOLD))
	var here := HFlowContainer.new()
	here.add_theme_constant_override("h_separation", 8)
	here.add_theme_constant_override("v_separation", 8)
	box.add_child(here)
	for p in _points():
		var pos: Vector3 = p[1]
		here.add_child(UITheme.button(p[0], func(): _teleport(pos), 190))

	box.add_child(UITheme.label("ТЕЛЕПОРТ У ЛОКАЦІЮ (без збереження)", 18, UITheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for i in LevelDB.LEVELS.size():
		var idx := i
		var b := UITheme.button("%d. %s" % [i + 1, LevelDB.LEVELS[i].name], func(): _go_level(idx), 300)
		if i == Game.level_index:
			b.disabled = true
		grid.add_child(b)
	box.add_child(UITheme.button("Закрити (Д)", func(): closed.emit()))

func open() -> void:
	visible = true
	_first.grab_focus()

## Ключові точки поточної локації: [назва, позиція].
func _points() -> Array:
	var pts: Array = [["Старт", world.builder.spawn]]
	var gate_added := false
	for x in world._exits:
		pts.append(["Вихід", x.global_position])
	for n in get_tree().get_nodes_in_group("interactable"):
		var path := String(n.get_script().resource_path) if n.get_script() else ""
		if path.ends_with("crone.gd"):
			pts.append(["Стара з картами", n.global_position + Vector3(0, 0, 2.0)])
		elif path.ends_with("gate.gd") and n.enabled and not gate_added:
			gate_added = true   # ґрати зазвичай на дві клітинки — одна кнопка
			pts.append(["Ґрати", n.global_position + Vector3(0, 0, 2.0)])
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss and not e.dead:
			pts.append(["Бос: " + e.data.name, e.global_position + Vector3(0, 0, 5.0)])
	return pts

func _teleport(pos: Vector3) -> void:
	closed.emit()
	world.player.teleport(pos)
	Game.message.emit("Телепорт")

func _go_level(i: int) -> void:
	get_tree().paused = false
	Game.go_to_level(i, false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("debug_menu")):
		get_viewport().set_input_as_handled()
		closed.emit()
