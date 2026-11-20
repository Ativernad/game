extends Interactable
## Скриня з предметом.

var item_id := "bandage"
var count := 1
var opened := false
var _spr: Sprite3D

func setup(id: String, n := 1) -> void:
	item_id = id
	count = n

func _ready() -> void:
	super._ready()
	_spr = LevelBuilder.ground_sprite("chest", 0.05, Vector3.ZERO)
	add_child(_spr)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.1, 0.9, 1.1)
	cs.shape = b
	cs.position.y = 0.45
	body.add_child(cs)
	add_child(body)

func prompt() -> String:
	return "" if opened else "Відкрити скриню"

func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	enabled = false
	_spr.texture = Art.tex("chest_open")
	Audio.play_3d("chest", global_position)
	var extra := 1 if Game.class_id == "beggar" and ItemDB.get_item(item_id).type == "consumable" else 0
	Game.add_item(item_id, count + extra)
	if Game.class_id == "beggar" and randf() < 0.5:
		Game.add_item("bandage", 1)
