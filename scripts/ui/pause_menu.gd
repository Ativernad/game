class_name PauseMenu
extends MenuBase

signal resume
signal open_inventory
signal open_settings
signal to_menu

func _ready() -> void:
	make_frame(0.65)
	box.add_child(UITheme.title("ПАУЗА", 44))
	box.add_child(UITheme.label(LevelDB.LEVELS[Game.level_index].name, 20, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(HSeparator.new())
	box.add_child(UITheme.button("Продовжити", func(): resume.emit()))
	box.add_child(UITheme.button("Інвентар", func(): open_inventory.emit()))
	box.add_child(UITheme.button("Налаштування", func(): open_settings.emit()))
	box.add_child(UITheme.button("Головне меню", func(): to_menu.emit()))
	box.add_child(UITheme.label("Прогрес зберігається на початку кожної локації.", 16, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))

func open() -> void:
	visible = true
	focus_first()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume.emit()
