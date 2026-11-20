class_name MenuBase
extends Control
## Базовий повноекранний темний оверлей для меню.

var panel: PanelContainer
var box: VBoxContainer

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP

func make_frame(dim := 0.7, min_w := 420.0) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := UITheme.centered(self)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_w, 0)
	c.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

func focus_first() -> void:
	for n in find_children("*", "Button", true, false):
		if n.visible and not n.disabled:
			n.grab_focus()
			return
