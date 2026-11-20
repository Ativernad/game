class_name GameOverScreen
extends MenuBase

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.0, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.85, 1.5)
	var c := UITheme.centered(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	c.add_child(v)
	var t := UITheme.title("ТИ ЗАГИНУВ", 72)
	t.add_theme_color_override("font_color", Color(0.65, 0.08, 0.06))
	v.add_child(t)
	v.add_child(UITheme.label("Темрява не відпускає так легко.", 22, UITheme.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Control.new())
	var b1 := UITheme.button("Спробувати знову", func(): Game.continue_game())
	var b2 := UITheme.button("Головне меню", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	for b in [b1, b2]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	v.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(v, "modulate:a", 1.0, 1.2)
	b1.grab_focus()
