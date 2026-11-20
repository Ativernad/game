class_name TarotCard
extends Control
## Карта таро для вибору класу: перевертається, піднімається при фокусі.

signal chosen(class_id: String)

const W := 252.0
const H := 392.0

var class_id := "knight"
var face_up := false
var _lift := 0.0
var _flip := 1.0      # горизонтальний масштаб під час перевертання
var _t := 0.0

func setup(id: String) -> void:
	class_id = id

func _ready() -> void:
	custom_minimum_size = Vector2(W, H + 30)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): grab_focus())
	focus_entered.connect(func(): Audio.play("ui_move", 0.8, -6.0))

func flip_up(delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "_flip", 0.0, 0.18)
	tw.tween_callback(func():
		face_up = true
		Audio.play("bell", 1.6, -10.0))
	tw.tween_property(self, "_flip", 1.0, 0.22)

func _process(delta: float) -> void:
	_t += delta
	_lift = lerp(_lift, 1.0 if has_focus() else 0.0, clamp(delta * 10.0, 0.0, 1.0))
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not face_up:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		accept_event()
		Audio.play("ui_ok")
		chosen.emit(class_id)

func _draw() -> void:
	var c: Dictionary = Game.CLASSES[class_id]
	var cx := size.x * 0.5
	var top := 30.0 - _lift * 26.0 + sin(_t * 1.5 + class_id.length()) * 2.0
	var w := W * _flip
	var r := Rect2(cx - w * 0.5, top, w, H)
	if _lift > 0.05:
		for i in 3:
			draw_rect(r.grow(3.0 + i * 4.0), Color(1.0, 0.75, 0.35, (0.35 - i * 0.1) * _lift), false, 2.0)
	draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, Color(0.08, 0.06, 0.05))
	if w < 8.0:
		return
	if not face_up:
		draw_texture_rect(Art.tex("card_back"), r.grow(-10), false)
		draw_rect(r.grow(-6), UITheme.GOLD, false, 2.0)
		draw_rect(r, UITheme.GOLD * Color(1, 1, 1, 0.8), false, 3.0)
		return
	var art := Rect2(r.position + Vector2(14, 44), Vector2(w - 28, H - 106))
	draw_texture_rect(Art.tex("card_" + class_id), art, false)
	draw_rect(art, UITheme.GOLD, false, 2.0)
	draw_rect(r.grow(-6), UITheme.GOLD * Color(1, 1, 1, 0.7), false, 1.5)
	draw_rect(r, UITheme.GOLD_HI if _lift > 0.5 else UITheme.GOLD, false, 3.0)
	var f := UITheme.font()
	if _flip > 0.9:
		draw_string(f, Vector2(r.position.x, top + 32), c.arcana, HORIZONTAL_ALIGNMENT_CENTER, w, 26, UITheme.GOLD_HI)
		draw_string(f, Vector2(r.position.x, top + H - 34), c.card, HORIZONTAL_ALIGNMENT_CENTER, w, 26, UITheme.GOLD_HI)
		draw_string(f, Vector2(r.position.x, top + H - 12), c.name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, 16, UITheme.TEXT)
