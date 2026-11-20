extends Interactable
## Предмет на землі: 2D-іконка-білборд, що гойдається і світиться.

var item_id := ""
var count := 1
var _spr: Sprite3D
var _t := 0.0

func setup(id: String, n := 1) -> void:
	item_id = id
	count = n

func _ready() -> void:
	super._ready()
	_spr = LevelBuilder.sprite("icon_" + item_id, 0.04)
	_spr.shaded = false
	_spr.position.y = 0.6
	add_child(_spr)
	var g := LevelBuilder.sprite("glow", 0.08)
	g.shaded = false
	g.modulate = Color(1, 0.85, 0.5, 0.5)
	g.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	g.position.y = 0.6
	add_child(g)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.5)
	l.light_energy = 0.5
	l.omni_range = 2.5
	l.position.y = 0.7
	add_child(l)
	_t = randf() * 6.0

func _process(delta: float) -> void:
	_t += delta
	_spr.position.y = 0.6 + sin(_t * 2.0) * 0.08

func prompt() -> String:
	return "Підняти: " + ItemDB.get_item(item_id).name

func interact(_player: Node) -> void:
	Game.add_item(item_id, count)
	Audio.play_3d("pickup", global_position)
	queue_free()
