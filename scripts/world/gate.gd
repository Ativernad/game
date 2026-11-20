extends Interactable
## Ґрати, що відчиняються ключем.

var key_id := ""
var horizontal := true
var _mesh: MeshInstance3D
var _body: StaticBody3D

func setup(key: String, horiz: bool, mat: Material) -> void:
	key_id = key
	horizontal = horiz
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 3.2, 0.15) if horizontal else Vector3(0.15, 3.2, 2.0)
	_mesh.mesh = bm
	_mesh.material_override = mat
	_mesh.position.y = 1.6
	add_child(_mesh)
	_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = bm.size + (Vector3(0, 0, 0.3) if horizontal else Vector3(0.3, 0, 0))
	cs.shape = b
	cs.position.y = 1.6
	_body.add_child(cs)
	add_child(_body)

func prompt() -> String:
	if Game.count(key_id) > 0:
		return "Відімкнути: " + ItemDB.get_item(key_id).name
	return "Замкнено. Потрібен: " + ItemDB.get_item(key_id).name

func interact(_player: Node) -> void:
	if Game.count(key_id) <= 0:
		Audio.play_3d("block", global_position, 0.6)
		return
	enabled = false
	Audio.play_3d("door", global_position)
	Game.message.emit("Ґрати піднялися")
	for g in get_tree().get_nodes_in_group("gates"):
		if g.key_id == key_id and g != self:
			g.open()
	open()

func open() -> void:
	enabled = false
	var tw := create_tween()
	tw.tween_property(_mesh, "position:y", 4.8, 1.5).set_trans(Tween.TRANS_SINE)
	_body.queue_free()
	if get_parent().has_method("on_gate_opened"):
		get_parent().on_gate_opened(self)
