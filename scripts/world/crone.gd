extends Interactable
## Стара ворожка посеред руїн: розкладає карти таро, і герой, що прийшов
## «ніким», обирає клас. Після вибору віддає ключ від ґрат (поле рівня "npc_key").

const LINES_AFTER := [
	"Стара: «Карти вже сказали своє. Іди.»",
	"Стара: «Під каплицею вода. Мертві в ній не сплять.»",
	"Стара: «Не озирайся на хрести. Вони рахують тих, хто повертається.»",
]

var _spr: Sprite3D
var _greeted := false
var _line := 0

func _ready() -> void:
	super._ready()
	_spr = LevelBuilder.ground_sprite("crone", 0.05, Vector3.ZERO)
	add_child(_spr)
	var l := OmniLight3D.new()                   # свічка біля ворожки
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 1.2
	l.omni_range = 5.0
	l.position = Vector3(-0.5, 1.0, 0.3)
	l.set_script(load("res://scripts/world/flicker.gd"))
	add_child(l)
	var candles := LevelBuilder.ground_sprite("candles", 0.04, Vector3(-0.6, 0, 0.3))
	add_child(candles)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	body.add_child(cs)
	add_child(body)

func _process(_delta: float) -> void:
	if _greeted or Game.class_id != "nobody":
		return
	var p = get_tree().get_first_node_in_group("player")
	if p and p.global_position.distance_to(global_position) < 7.0:
		_greeted = true
		Game.message.emit("Стара: «Підійди, ніхто. Карти чекали на тебе.»")

func prompt() -> String:
	return "Говорити зі старою" if Game.class_id == "nobody" else "Стара"

func interact(_player: Node) -> void:
	if Game.class_id == "nobody":
		Audio.play("bell", 1.4, -6.0)
		get_tree().current_scene.open_tarot(self)
	else:
		Game.message.emit(LINES_AFTER[_line % LINES_AFTER.size()])
		_line += 1

func after_choice() -> void:
	var lv: Dictionary = get_tree().current_scene.level
	Game.message.emit("Стара: «%s. Так і буде.»" % Game.cls().card.capitalize())
	if lv.has("npc_key") and Game.count(lv.npc_key) == 0:
		Game.add_item(lv.npc_key)
		Game.message.emit("Стара: «І візьми ключ. Ґрати за каплицею ведуть униз.»")
	Game.save_game()
