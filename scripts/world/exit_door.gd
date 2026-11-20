extends Interactable
## Вихід на наступну локацію. На рівнях з босом — закритий, доки бос живий.

var locked := false
var _spr: Sprite3D
var _light: OmniLight3D

func _ready() -> void:
	super._ready()
	_spr = LevelBuilder.ground_sprite("exit", 0.065, Vector3.ZERO)
	_spr.shaded = false
	add_child(_spr)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.9, 0.7)
	_light.light_energy = 1.5
	_light.omni_range = 7.0
	_light.position.y = 1.5
	add_child(_light)
	set_locked(locked)

func set_locked(v: bool) -> void:
	locked = v
	if _spr:
		_spr.modulate = Color(0.25, 0.2, 0.2) if locked else Color(1, 1, 1)
		_light.visible = not locked

func prompt() -> String:
	return "Шлях закрито темною силою…" if locked else "Йти далі"

func interact(_player: Node) -> void:
	if locked:
		return
	enabled = false
	Audio.play("door")
	get_tree().current_scene.leave_level()
