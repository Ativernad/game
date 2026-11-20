class_name UITheme
## Спільна похмура тема інтерфейсу та помічники для створення елементів.

const BG := Color(0.05, 0.035, 0.035, 0.94)
const GOLD := Color(0.72, 0.56, 0.26)
const GOLD_HI := Color(0.95, 0.8, 0.45)
const TEXT := Color(0.85, 0.8, 0.7)
const DIM := Color(0.55, 0.5, 0.45)
const BLOOD := Color(0.55, 0.08, 0.08)

static var _theme: Theme
static var _font: Font

static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Palatino", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font

static func _box(bg: Color, border: Color, bw := 2, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(margin)
	s.corner_detail = 1
	return s

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD_HI)
	t.set_color("font_focus_color", "Button", GOLD_HI)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.32, 0.3))
	t.set_stylebox("normal", "Button", _box(Color(0.08, 0.06, 0.06, 0.9), Color(0.3, 0.22, 0.12), 1, 8))
	t.set_stylebox("hover", "Button", _box(Color(0.16, 0.08, 0.07, 0.95), GOLD, 1, 8))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD_HI, 2, 8))
	t.set_stylebox("pressed", "Button", _box(Color(0.3, 0.08, 0.06, 0.95), GOLD_HI, 1, 8))
	t.set_stylebox("disabled", "Button", _box(Color(0.05, 0.04, 0.04, 0.6), Color(0.15, 0.12, 0.1), 1, 8))
	t.set_stylebox("panel", "PanelContainer", _box(BG, GOLD, 2, 18))
	t.set_stylebox("panel", "Panel", _box(BG, GOLD, 2, 18))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", GOLD_HI)
	t.set_color("font_focus_color", "CheckBox", GOLD_HI)
	t.set_stylebox("normal", "CheckBox", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("hover", "CheckBox", _box(Color(0.16, 0.08, 0.07, 0.6), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("focus", "CheckBox", _box(Color(0, 0, 0, 0), GOLD_HI, 2, 6))
	t.set_stylebox("pressed", "CheckBox", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	var slider_bg := _box(Color(0.12, 0.09, 0.08), Color(0.3, 0.22, 0.12), 1, 3)
	t.set_stylebox("slider", "HSlider", slider_bg)
	var fill := _box(BLOOD, Color(0, 0, 0, 0), 0, 3)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(0.75, 0.15, 0.1), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("focus", "HSlider", _box(Color(0, 0, 0, 0), GOLD_HI, 2, 3))
	t.set_stylebox("panel", "TooltipPanel", _box(BG, GOLD, 1, 6))
	_theme = t
	return t

static func label(text: String, size := 22, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

static func title(text: String, size := 54) -> Label:
	var l := label(text, size, GOLD_HI, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_shadow_color", Color(0.3, 0.02, 0.02, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l

static func button(text: String, cb: Callable, min_w := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 48)
	b.pressed.connect(func():
		Audio.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", 1.0, -8.0))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b

## Зручний повноекранний контейнер з центрованим вмістом.
static func centered(parent: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	return c
