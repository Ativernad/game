class_name Player
extends CharacterBody3D
## Гравець від першої особи. Три класи: лицар (меч+щит), лучниця (лук+кинджал),
## жебрак (палиця+ривок). Зброя показана 2D-спрайтом унизу екрана.

signal damaged(amount: float)
signal died

const GRAVITY := 18.0
const JUMP := 5.2
const ACCEL := 10.0
const PARRY_WINDOW := 0.2      # перші секунди блоку, коли удар парирується
const HEAL_TIME := 0.8         # лікування триває, а не спрацьовує миттєво
const HEAL_SLOW := 0.4
const DASH_COOLDOWN := 0.6

var world: Node
var head: Node3D
var cam: Camera3D
var torch: OmniLight3D

var stamina := 100.0
var max_stamina := 100.0
var speed := 5.0
var base_damage := 20.0
var dead := false

var _yaw := 0.0
var _pitch := 0.0
var _cooldown := 0.0
var _pending_hits: Array = []      # [{t, dmg, range, arc, knock}]
var _stam_delay := 0.0
var _bob_t := 0.0
var _step_acc := 0.0
var _shake := 0.0
var _iframes := 0.0
var _dash_t := 0.0
var _dash_dir := Vector3.ZERO
var blocking := false
var _charge := -1.0                # лук: -1 = не натягнуто
var buff_damage := 0.0
var buff_stamina := 0.0
var _was_on_floor := true
var _block_t := 0.0
var _heal_t := 0.0
var _heal_id := ""
var _dash_cd := 0.0
var _charge_cued := false
var _torch_base := -1.0

# вид від першої особи
var _vm_layer: CanvasLayer
var _vm_main: TextureRect
var _vm_off: TextureRect
var _anim_t := 1.0
var _anim_len := 0.5
var _anim_kind := ""
var _block_k := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.55
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Settings.get_v("fov")
	cam.near = 0.05
	cam.far = 120.0
	head.add_child(cam)
	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.72, 0.45)
	torch.omni_attenuation = 1.2
	torch.position = Vector3(0.3, -0.2, -0.2)
	torch.shadow_enabled = true
	torch.set_script(load("res://scripts/world/flicker.gd"))
	cam.add_child(torch)
	var c := Game.cls()
	max_stamina = c.stamina
	stamina = max_stamina
	speed = c.speed
	base_damage = c.damage
	_update_torch()
	Game.stats_changed.connect(_update_torch)
	Settings.changed.connect(func(): cam.fov = Settings.get_v("fov"))
	_build_viewmodel()

func _update_torch() -> void:
	torch.light_energy = 2.4
	torch.omni_range = 12.0 * Game.light_mult()

func set_look(yaw: float) -> void:
	_yaw = yaw
	rotation.y = _yaw

func can_act() -> bool:
	return not dead and world != null and not world.ui_open

# ---------------------------------------------------------------- ввід

func _unhandled_input(event: InputEvent) -> void:
	if not can_act():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.get_v("mouse_sens") * 0.01
		_yaw -= event.relative.x * s
		_pitch -= event.relative.y * s * (-1.0 if Settings.get_v("invert_y") else 1.0)
		_pitch = clamp(_pitch, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var active := can_act()
	# огляд стіком
	if active:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.0:
			var ps: float = Settings.get_v("pad_sens")
			look = look * look.length()   # м'якша крива
			_yaw -= look.x * ps * delta
			_pitch -= look.y * ps * delta * 0.7 * (-1.0 if Settings.get_v("invert_y") else 1.0)
			_pitch = clamp(_pitch, -1.45, 1.45)
	rotation.y = _yaw
	head.rotation.x = _pitch

	_cooldown = max(_cooldown - delta, 0.0)
	_iframes = max(_iframes - delta, 0.0)
	buff_damage = max(buff_damage - delta, 0.0)
	buff_stamina = max(buff_stamina - delta, 0.0)
	_dash_cd = max(_dash_cd - delta, 0.0)
	if _heal_t > 0.0:
		_heal_t -= delta
		if _heal_t <= 0.0:
			_finish_heal()
	var healing := _heal_t > 0.0

	# рух
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if active else Vector2.ZERO
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	var sprinting := active and Input.is_action_pressed("sprint") and input.length() > 0.1 and stamina > 1.0 and not blocking and not healing
	var spd := speed * (1.55 if sprinting else 1.0) * (0.45 if blocking else 1.0) * (0.6 if _charge >= 0.0 else 1.0) * (HEAL_SLOW if healing else 1.0)
	if sprinting:
		_use_stamina(18.0 * delta, 0.3)
	var target := dir * spd
	if _dash_t > 0.0:
		_dash_t -= delta
		target = _dash_dir * 14.0
	var a := ACCEL if is_on_floor() else ACCEL * 0.3
	velocity.x = lerp(velocity.x, target.x, clamp(a * delta, 0.0, 1.0))
	velocity.z = lerp(velocity.z, target.z, clamp(a * delta, 0.0, 1.0))
	if _dash_t > 0.0:
		velocity.x = target.x
		velocity.z = target.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif active and Input.is_action_just_pressed("jump") and stamina > 8.0:
		velocity.y = JUMP
		_use_stamina(8.0)
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		Audio.play("step", 0.7)
	_was_on_floor = is_on_floor()

	# витривалість
	_stam_delay -= delta
	if buff_stamina > 0.0:
		stamina = max_stamina
	elif _stam_delay <= 0.0:
		stamina = min(max_stamina, stamina + 28.0 * Game.stamina_regen_mult() * delta)

	# кроки та похитування
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hv > 0.5:
		_bob_t += delta * hv * 1.6
		_step_acc += hv * delta
		if _step_acc > 2.1:
			_step_acc = 0.0
			Audio.play("step", randf_range(0.8, 1.1), -6.0)
	var bob := sin(_bob_t) * 0.04 if Settings.get_v("head_bob") else 0.0
	head.position.y = lerp(head.position.y, 1.55 + bob, 0.3)
	_shake = max(_shake - delta * 2.5, 0.0)
	cam.h_offset = randf_range(-1, 1) * _shake * 0.08
	cam.v_offset = randf_range(-1, 1) * _shake * 0.08

	if active:
		if healing:
			blocking = false   # під час лікування руки зайняті
			_charge = -1.0
		else:
			_combat_input(delta)
		if Input.is_action_just_pressed("interact"):
			var it := find_interactable()
			if it:
				it.interact(self)
		if Input.is_action_just_pressed("heal"):
			var id := Game.best_heal_item()
			if id == "":
				Game.message.emit("Немає чим лікуватися")
			elif Game.hp >= Game.max_hp():
				Game.message.emit("Ти й так цілий")
			else:
				use_item(id)
	_process_hits(delta)
	_update_viewmodel(delta, hv)
	if global_position.y < -25.0:
		take_damage(9999.0, global_position)

func _use_stamina(v: float, delay := 0.7) -> void:
	if buff_stamina > 0.0:
		return
	stamina = max(stamina - v, 0.0)
	_stam_delay = delay

func damage_value(mult := 1.0) -> float:
	return base_damage * mult * Game.damage_mult() * (1.5 if buff_damage > 0.0 else 1.0)

# ---------------------------------------------------------------- бій

func _combat_input(delta: float) -> void:
	match Game.class_id:
		"knight":
			var want_block := Input.is_action_pressed("secondary") and stamina > 2.0
			if want_block and not blocking:
				_block_t = 0.0
				_use_stamina(5.0, 0.4)   # щоб парирування не можна було спамити
			blocking = want_block
			if blocking:
				_block_t += delta
				_stam_delay = 0.4
			if Input.is_action_just_pressed("attack") and _cooldown <= 0.0 and not blocking and stamina >= 10.0:
				_use_stamina(18.0)
				_cooldown = 0.6
				_play_anim("swing", 0.55)
				Audio.play("swing", 0.9)
				_pending_hits.append({"t": 0.18, "dmg": damage_value(), "range": 2.6, "arc": 0.45, "knock": 3.0})
		"archer":
			if Input.is_action_pressed("attack") and _cooldown <= 0.0 and stamina >= 6.0:
				if _charge < 0.0:
					_charge = 0.0
					_charge_cued = false
					Audio.play("bow", 0.7, -8.0)
				_charge = min(_charge + delta / 0.75, 1.0)
				if _charge >= 1.0 and not _charge_cued:
					_charge_cued = true   # сигнал повного натягу
					Audio.play("ui_ok", 1.5, -4.0)
			elif _charge >= 0.0:
				_fire_arrow(_charge)
				_charge = -1.0
				_cooldown = 0.35
			if Input.is_action_just_pressed("secondary") and _cooldown <= 0.0 and _charge < 0.0 and stamina >= 6.0:
				_use_stamina(10.0)
				_cooldown = 0.38
				_play_anim("stab", 0.35)
				Audio.play("swing", 1.4)
				_pending_hits.append({"t": 0.1, "dmg": damage_value(0.5), "range": 2.0, "arc": 0.6, "knock": 1.5})
		"beggar":
			if Input.is_action_just_pressed("attack") and _cooldown <= 0.0 and stamina >= 8.0:
				_use_stamina(13.0)
				_cooldown = 0.45
				_play_anim("swing", 0.45)
				Audio.play("swing", 1.1)
				_pending_hits.append({"t": 0.14, "dmg": damage_value(), "range": 2.9, "arc": 0.4, "knock": 5.0})
			if Input.is_action_just_pressed("secondary") and _dash_t <= 0.0 and _dash_cd <= 0.0 and stamina >= 20.0:
				_use_stamina(25.0)
				var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
				if inp.length() < 0.2:
					inp = Vector2(0, -1)
				_dash_dir = (transform.basis * Vector3(inp.x, 0, inp.y)).normalized()
				_dash_t = 0.22
				_dash_cd = _dash_t + DASH_COOLDOWN
				_iframes = 0.35
				Audio.play("dash")

func _fire_arrow(charge: float) -> void:
	_use_stamina(10.0)
	Audio.play("bow", 1.2)
	_play_anim("shoot", 0.3)
	var p := Projectile.new()
	var fwd := -cam.global_transform.basis.z
	p.setup(cam.global_position + fwd * 0.4, fwd * lerpf(18.0, 42.0, charge), damage_value(0.35 + 0.65 * charge), "enemies", "arrow")
	p.gravity = lerpf(6.0, 1.5, charge)
	world.add_entity(p)

func _process_hits(delta: float) -> void:
	for i in range(_pending_hits.size() - 1, -1, -1):
		var hd: Dictionary = _pending_hits[i]
		hd.t -= delta
		if hd.t <= 0.0:
			_pending_hits.remove_at(i)
			_melee(hd)

func _melee(hd: Dictionary) -> void:
	var fwd := -global_transform.basis.z
	var origin := global_position + Vector3(0, 1.2, 0)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > hd.range + e.radius:
			continue
		if d > 0.3 and fwd.dot(to / d) < hd.arc:
			continue
		var q := PhysicsRayQueryParameters3D.create(origin, e.global_position + Vector3(0, 1.0, 0), 1)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		e.take_damage(hd.dmg, to.normalized() * hd.knock)
		hit_any = true
	if hit_any:
		_shake = max(_shake, 0.35)
		Audio.play("hit")

## source — ворог, що б'є (для парирування); для снарядів null.
func take_damage(amount: float, from: Vector3, source: Node = null) -> void:
	if dead or _iframes > 0.0:
		return
	amount *= Game.difficulty().dmg
	var to := from - global_position
	to.y = 0
	var facing := to.length() > 0.01 and (-global_transform.basis.z).dot(to.normalized()) > 0.3
	if blocking and facing and _block_t <= PARRY_WINDOW:
		# парирування: без шкоди й витрати витривалості, ворог оглушений
		Audio.play("block", 1.5)
		Audio.play("hit", 1.3, -4.0)
		_block_k = 1.6
		_shake = max(_shake, 0.25)
		_iframes = 0.2
		if source and source.has_method("stun"):
			source.stun()
			Game.message.emit("Парирування!")
		return
	if blocking and facing:
		var cost := amount * 0.9
		if stamina >= cost * 0.5:
			_use_stamina(cost)
			amount *= 0.15
			Audio.play("block")
			_block_k = 1.4
		else:
			blocking = false
	amount *= 1.0 - Game.defense()
	Game.hp = max(Game.hp - amount, 0.0)
	_shake = max(_shake, clamp(amount / 20.0, 0.2, 1.0))
	_iframes = 0.25
	if amount > 2.0:
		Audio.play("hurt", randf_range(0.9, 1.1))
	damaged.emit(amount)
	if Game.hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	_heal_t = 0.0
	_vm_layer.visible = false
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.3, 0.8).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(head, "rotation:z", 0.6, 0.8)
	Audio.play("die", 0.7)
	died.emit()

func use_item(id: String) -> bool:
	var it := ItemDB.get_item(id)
	if it.type != "consumable" or Game.count(id) <= 0:
		return false
	if it.has("heal"):
		if Game.hp >= Game.max_hp():
			Game.message.emit("Ти й так цілий")
			return false
		if _heal_t > 0.0:
			return false
		# лікування займає час: повільний рух, без атак; предмет витрачається в кінці
		_heal_t = HEAL_TIME
		_heal_id = id
		Audio.play("heal", 0.7, -6.0)
		return true
	match it.get("buff", ""):
		"damage":
			buff_damage = 30.0
			Audio.play("magic")
			Game.message.emit("Зброя пам'ятає смерть")
		"stamina":
			buff_stamina = 30.0
			Audio.play("magic", 0.8)
			Game.message.emit("Втома відступила")
	Game.remove_item(id)
	return true

func _finish_heal() -> void:
	var id := _heal_id
	_heal_id = ""
	if dead or Game.count(id) <= 0:
		return
	var it := ItemDB.get_item(id)
	Game.hp = min(Game.max_hp(), Game.hp + float(it.heal))
	Game.remove_item(id)
	Audio.play("heal")
	Game.message.emit("+%d здоров'я" % int(it.heal))

func is_healing() -> bool:
	return _heal_t > 0.0

## Заряд лука 0..1, або -1, якщо не натягнуто (для прицілу в HUD).
func bow_charge() -> float:
	return _charge

## Плавно приглушує смолоскип (k=1 — звичайне світло).
func set_torch_dim(k: float) -> void:
	if _torch_base < 0.0:
		_torch_base = torch.get("_base")
	create_tween().tween_property(torch, "_base", _torch_base * k, 2.0)

func find_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := 2.6
	var fwd := -global_transform.basis.z
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.enabled or not is_instance_valid(it):
			continue
		var to := it.global_position - global_position
		to.y = 0
		var d := to.length()
		if d < best_d and (d < 0.8 or fwd.dot(to / d) > 0.3):
			best_d = d
			best = it
	return best

# ---------------------------------------------------------------- вид від першої особи

func _build_viewmodel() -> void:
	_vm_layer = CanvasLayer.new()
	_vm_layer.layer = 1
	add_child(_vm_layer)
	_vm_off = TextureRect.new()
	_vm_main = TextureRect.new()
	for t in [_vm_off, _vm_main]:
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size = Vector2(64, 64)
		t.scale = Vector2(6, 6)
		_vm_layer.add_child(t)
	match Game.class_id:
		"knight":
			_vm_main.texture = Art.tex("vm_sword")
			_vm_off.texture = Art.tex("vm_shield")
		"archer":
			_vm_main.texture = Art.tex("vm_bow")
			_vm_off.texture = Art.tex("vm_dagger")
		"beggar":
			_vm_main.texture = Art.tex("vm_staff")
			_vm_off.texture = Art.tex("vm_hand")
	_vm_main.pivot_offset = Vector2(56, 60)
	_vm_off.pivot_offset = Vector2(20, 60)

func _play_anim(kind: String, length: float) -> void:
	_anim_kind = kind
	_anim_len = length
	_anim_t = 0.0

func _update_viewmodel(delta: float, hv: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var sc: float = clamp(vs.y / 720.0, 0.6, 3.0) * 6.0
	_vm_main.scale = Vector2(sc, sc)
	_vm_off.scale = Vector2(sc, sc)
	var bx := sin(_bob_t * 0.5) * 10.0 * minf(hv, 6.0) / 6.0
	var by: float = abs(cos(_bob_t * 0.5)) * 8.0 * min(hv, 6.0) / 6.0
	_anim_t = min(_anim_t + delta / max(_anim_len, 0.01), 1.0)
	var k := _anim_t
	var rot := 0.0
	var off := Vector2.ZERO
	if _anim_t < 1.0:
		match _anim_kind:
			"swing":
				if k < 0.3:
					var q := k / 0.3
					rot = 0.35 * q
					off = Vector2(40, -30) * q
				elif k < 0.6:
					var q := (k - 0.3) / 0.3
					rot = lerpf(0.35, -1.1, q)
					off = Vector2(lerpf(40, -320, q), lerpf(-30, 60, q))
				else:
					var q := (k - 0.6) / 0.4
					rot = lerpf(-1.1, 0.0, q)
					off = Vector2(lerpf(-320, 0, q), lerpf(60, 0, q))
			"stab":
				off = Vector2(-120, -90) * sin(k * PI)
			"shoot":
				off = Vector2(0, 30) * sin(k * PI)
	var main_pos := Vector2(vs.x - 64 * sc * 0.95, vs.y - 64 * sc * 0.92)
	var off_pos := Vector2(vs.x * 0.04, vs.y - 64 * sc * 0.55)
	match Game.class_id:
		"knight":
			_block_k = move_toward(_block_k, 1.0 if blocking else 0.0, delta * 6.0)
			off_pos = Vector2(lerpf(vs.x * 0.02, vs.x * 0.22, _block_k), lerpf(vs.y - 64 * sc * 0.45, vs.y - 64 * sc * 0.95, min(_block_k, 1.0)))
			_vm_main.position = main_pos + off + Vector2(bx, by) + Vector2(0, _block_k * 120.0)
		"archer":
			var drawn := _charge >= 0.0
			_vm_main.texture = Art.tex("vm_bow_drawn" if drawn else "vm_bow")
			var cpos := Vector2(vs.x * 0.5 - 32 * sc, vs.y - 64 * sc * 0.95)
			var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_charge * 3.0 if drawn else 0.0)
			_vm_main.position = (cpos if drawn else main_pos + Vector2(0, 40)) + Vector2(bx, by) + shake + (off if _anim_kind == "shoot" else Vector2.ZERO)
			off_pos = Vector2(vs.x - 64 * sc * 0.75, vs.y - 64 * sc * 0.5) + (off if _anim_kind == "stab" else Vector2(0, 160 if _anim_t >= 1.0 else 0))
			_vm_off.visible = not drawn
		"beggar":
			_vm_main.position = main_pos + off + Vector2(bx, by)
			if _dash_t > 0.0:
				off_pos += Vector2(0, 80)
	_vm_main.rotation = rot
	_vm_off.position = off_pos + Vector2(-bx, by) * 0.6
	if _heal_t > 0.0:
		# зброя опущена, поки персонаж лікується
		var drop := sin(clampf(1.0 - _heal_t / HEAL_TIME, 0.0, 1.0) * PI) * 0.6 + 0.4
		_vm_main.position.y += 220.0 * drop
		_vm_off.position.y += 220.0 * drop
