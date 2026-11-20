class_name Enemy
extends CharacterBody3D
## Ворог 2.5D: кілька 2D-шарів (Sprite3D) з відступом у глибину, які завжди
## повернуті до камери. Шари комбінуються: скелет-воїн і скелет-лучник мають
## однакове тіло, але різні шари зброї/одягу.

signal died_signal(enemy)

const TYPES := {
	"skel_warrior": {"name": "Скелет-воїн", "layers": ["skel_body", "skel_armor", "w_sword_shield"],
		"hp": 50, "speed": 2.6, "dmg": 14, "range": 1.9, "cd": 1.5, "windup": 0.45, "kind": "melee",
		"sound": "bone", "aggro": 14.0, "drops": [["bandage", 0.25], ["herb", 0.08]]},
	"skel_archer": {"name": "Скелет-лучник", "layers": ["cape_back", "skel_body", "hood", "w_bow"],
		"hp": 32, "speed": 2.4, "dmg": 11, "range": 16.0, "keep": 6.0, "cd": 2.4, "windup": 0.7, "kind": "ranged",
		"proj": "arrow", "proj_speed": 20.0, "sound": "bone", "aggro": 18.0, "drops": [["bandage", 0.3]]},
	"cultist": {"name": "Культист", "layers": ["robe", "hood_cult", "w_dagger"],
		"hp": 36, "speed": 3.9, "dmg": 10, "range": 1.7, "cd": 1.1, "windup": 0.3, "kind": "melee",
		"sound": "hurt", "aggro": 13.0, "drops": [["herb", 0.3], ["incense", 0.05]]},
	"cult_mage": {"name": "Культист-маг", "layers": ["robe", "hood_cult", "w_staff"],
		"hp": 30, "speed": 2.6, "dmg": 16, "range": 16.0, "keep": 7.0, "cd": 2.8, "windup": 0.8, "kind": "ranged",
		"proj": "fireball", "proj_speed": 10.0, "sound": "hurt", "aggro": 16.0, "drops": [["herb", 0.35], ["salt", 0.08]]},
	"zombie": {"name": "Зомбі", "layers": ["zomb_body", "rags_grey"],
		"hp": 55, "speed": 1.8, "dmg": 16, "range": 1.7, "cd": 1.7, "windup": 0.6, "kind": "melee",
		"sound": "hurt", "aggro": 11.0, "drops": [["bandage", 0.25]]},
	"brute": {"name": "Громило", "layers": ["zomb_body", "rags_red", "w_cleaver"], "scale": 1.35,
		"hp": 130, "speed": 2.1, "dmg": 28, "range": 2.4, "cd": 2.2, "windup": 0.8, "kind": "melee", "stagger": 35,
		"sound": "hurt", "aggro": 12.0, "drops": [["elixir", 0.5], ["herb", 0.5]]},
	"ghost": {"name": "Привид", "layers": ["ghost"], "alpha": 0.7, "float": true,
		"hp": 30, "speed": 3.1, "dmg": 12, "range": 1.6, "cd": 1.4, "windup": 0.45, "kind": "melee",
		"sound": "magic", "aggro": 13.0, "drops": [["herb", 0.2]]},
	"warden": {"name": "Кістяний Сторож", "layers": ["cape_back", "skel_body", "armor_gold", "w_greatsword"], "scale": 2.3,
		"hp": 520, "speed": 2.7, "dmg": 30, "range": 3.6, "cd": 1.8, "windup": 0.75, "kind": "melee", "boss": true,
		"sound": "bone", "aggro": 13.0, "drops": [["elixir", 1.0]]},
	"prince": {"name": "Принц Вічної Ночі", "layers": ["prince_cape", "prince_body", "prince_crown", "w_rapier"], "scale": 1.35,
		"hp": 820, "speed": 4.0, "dmg": 22, "range": 2.5, "cd": 1.15, "windup": 0.4, "kind": "melee", "boss": true,
		"sound": "hurt", "aggro": 15.0, "drops": []},
}

const CHAR_TYPES := {"w": "skel_warrior", "a": "skel_archer", "k": "cultist", "m": "cult_mage",
	"z": "zombie", "Z": "brute", "g": "ghost"}

var type_id := "zombie"
var data: Dictionary
var world: Node
var hp := 50.0
var max_hp := 50.0
var dead := false
var alerted := false
var radius := 0.4
var is_boss := false
var phase := 1

var visual: Node3D
var layers: Array[Sprite3D] = []
var _base_pos: Array[Vector3] = []
var _shadow: Sprite3D
var _t := 0.0
var _cd := 0.0
var _state := "idle"     # idle, move, windup, recover, special, dying
var _state_t := 0.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _los := false
var _los_t := 0.0
var _special := ""
var _special_cd := 6.0
var _summoned := []
var _lunge_dir := Vector3.ZERO
var _hit_done := false
var _home := Vector3.ZERO
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _stagger_cd := 0.0
var _stun_t := 0.0
var _tele_len := 0.5      # тривалість поточного замаху (для підсвічування)

const STAGGER_IMMUNITY := 2.5
const STUN_NORMAL := 1.5
const STUN_BOSS := 0.8
const STUN_DAMAGE_MULT := 1.5
const SLAM_RADIUS := 4.8
const WARDEN_EXHAUST := 1.8
const PRINCE_DARK := 0.45     # яскравість смолоскипа в третій фазі Принца

func setup(id: String, w: Node) -> void:
	type_id = id
	world = w
	data = TYPES[id]

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(50)
	var sc: float = data.get("scale", 1.0)
	is_boss = data.get("boss", false)
	max_hp = data.hp * Game.difficulty().hp
	hp = max_hp
	radius = 0.4 * sc
	set_meta("hit_radius", 0.55 * sc)
	set_meta("hscale", sc)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = max(1.7 * sc, radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	visual = Node3D.new()
	visual.scale = Vector3.ONE * sc
	add_child(visual)
	var names: Array = data.layers.duplicate()
	if type_id == "zombie" and randf() < 0.5:
		names[1] = "rags_blue"
	for i in names.size():
		var s := LevelBuilder.sprite(names[i], 0.04, false)
		s.position = Vector3(0, 0.96, i * 0.045)
		if data.has("alpha"):
			s.modulate.a = data.alpha
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			s.shaded = false
		visual.add_child(s)
		layers.append(s)
		_base_pos.append(s.position)
	_shadow = LevelBuilder.sprite("glow", 0.08 * sc, false)
	_shadow.modulate = Color(0, 0, 0, 0.6)
	_shadow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_shadow.shaded = false
	_shadow.rotation.x = -PI / 2
	_shadow.position.y = 0.03
	add_child(_shadow)
	_home = global_position
	_t = randf() * 10.0
	_cd = randf_range(0.3, 1.0)

func player() -> Player:
	return world.player if world else null

# ---------------------------------------------------------------- шкода

func take_damage(amount: float, knock: Vector3) -> void:
	if dead:
		return
	if _stun_t > 0.0:
		amount *= STUN_DAMAGE_MULT   # оглушений ворог беззахисний
	hp -= amount
	_flash = 0.15
	_knock += knock * (0.25 if is_boss else 1.0)
	Audio.play_3d(data.sound, global_position, randf_range(0.8, 1.2))
	_alert()
	if world:
		world.spawn_hit_fx(global_position + Vector3(0, 1.0 * data.get("scale", 1.0), 0))
	if hp <= 0.0:
		_die()
	elif not is_boss and _state == "windup" and amount >= data.get("stagger", 15.0) and _stagger_cd <= 0.0:
		_state = "recover"   # переривання атаки
		_state_t = 0.4
		_stagger_cd = STAGGER_IMMUNITY   # потім кілька секунд замах не збити

## Оглушення після парирування: ворог відкритий і отримує більше шкоди.
func stun(duration := -1.0) -> void:
	if dead:
		return
	var t := duration if duration > 0.0 else (STUN_BOSS if is_boss else STUN_NORMAL)
	_state = "recover"
	_state_t = t
	_stun_t = t
	_special = ""
	_cd = max(_cd, t * 0.5)
	_restore_alpha()
	Audio.play_3d(data.sound, global_position, 0.6)

func _restore_alpha() -> void:
	for s in layers:
		s.modulate.a = data.get("alpha", 1.0)

func _alert() -> void:
	if alerted:
		return
	alerted = true
	if is_boss and world:
		world.start_boss(self)
	# будимо сусідів
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.alerted and not e.is_boss and e.global_position.distance_to(global_position) < 7.0:
			e.alerted = true

## Прислужник падає разом з босом: без вбивства в статистиці і без луту.
func banish() -> void:
	if dead:
		return
	hp = 0.0
	_die(false)

func _die(by_player := true) -> void:
	dead = true
	_state = "dying"
	_state_t = 0.0
	collision_layer = 0
	collision_mask = 1
	remove_from_group("enemies")
	Audio.play_3d("die", global_position, 0.8 if is_boss else 1.0)
	if data.sound == "bone":
		Audio.play_3d("bone", global_position, 0.7)
	if by_player:
		Game.kills += 1
		var luck := 1.5 if Game.class_id == "beggar" else 1.0
		for d in data.drops:
			if randf() < d[1] * luck:
				world.spawn_pickup(d[0], global_position + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)))
				break
	died_signal.emit(self)
	# шари розлітаються окремо
	for i in layers.size():
		var s := layers[i]
		var tw := create_tween()
		var fall := Vector3(randf_range(-0.4, 0.4), -0.75 + randf() * 0.2, randf_range(0.0, 0.2) + i * 0.02)
		tw.tween_property(s, "position", _base_pos[i] + fall, 0.5 + randf() * 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "rotation:z", randf_range(-1.6, 1.6), 0.6)
		tw.tween_interval(2.0 if not is_boss else 3.0)
		tw.tween_property(s, "modulate:a", 0.0, 1.0)
	var t2 := create_tween()
	t2.tween_interval(4.5)
	t2.tween_callback(queue_free)

# ---------------------------------------------------------------- ШІ

func _physics_process(delta: float) -> void:
	_t += delta
	_flash = max(_flash - delta, 0.0)
	if dead:
		_face_camera()
		return
	var p := player()
	if p == null:
		return
	var to := p.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.25
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), p.global_position + Vector3(0, 1.4, 0), 1)
		_los = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	if not alerted and dist < data.aggro and _los and not p.dead and world.grace <= 0.0 and not Game.debug_shot:
		_alert()
	_cd = max(_cd - delta, 0.0)
	_special_cd = max(_special_cd - delta, 0.0)
	_stagger_cd = max(_stagger_cd - delta, 0.0)
	_stun_t = max(_stun_t - delta, 0.0)
	_state_t -= delta
	var move := Vector3.ZERO
	var spd: float = data.speed * (1.3 if phase >= 2 else 1.0)

	if p.dead:
		alerted = false
	match _state:
		"idle", "move":
			if alerted:
				move = _chase(p, flat, dist)
				if is_boss:
					_boss_think(p, flat, dist)
				if _state in ["idle", "move"] and _cd <= 0.0 and _los:
					if data.kind == "melee" and dist <= data.range + 0.2:
						_begin_attack()
					elif data.kind == "ranged" and dist <= data.range:
						_begin_attack()
			else:
				_wander_t -= delta
				if _wander_t <= 0.0:
					_wander_t = randf_range(2.0, 5.0)
					_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * (0.0 if randf() < 0.5 else 0.35)
					if global_position.distance_to(_home) > 3.0:
						_wander = (_home - global_position).normalized() * 0.4
						_wander.y = 0
				move = _wander
		"windup":
			if _state_t <= 0.0:
				_strike(p, flat, dist)
		"recover":
			if _state_t <= 0.0:
				_state = "move"
		"special":
			move = _special_tick(p, flat, dist, delta)

	var target := move * spd
	target += _knock
	_knock = _knock.move_toward(Vector3.ZERO, delta * 12.0)
	# розштовхуємося з іншими
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var l := d.length()
		if l < (radius + e.radius) * 1.2 and l > 0.01:
			target += d / l * 1.5
	velocity.x = lerp(velocity.x, target.x, clamp(delta * 8.0, 0.0, 1.0))
	velocity.z = lerp(velocity.z, target.z, clamp(delta * 8.0, 0.0, 1.0))
	if data.get("float", false):
		var ground: float = world.ground_height(global_position)
		velocity.y = (ground + 0.3 + sin(_t * 2.0) * 0.15 - global_position.y) * 4.0
	elif not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _chase(p: Player, flat: Vector3, dist: float) -> Vector3:
	var dir := Vector3.ZERO
	if _los and dist < 6.0:
		dir = flat.normalized()
	else:
		dir = world.flow_dir(global_position)
		if dir == Vector3.ZERO and _los:
			dir = flat.normalized()
	if data.kind == "ranged":
		var keep: float = data.get("keep", 6.0)
		if _los and dist < keep:
			dir = -flat.normalized()
		elif _los and dist < keep + 3.0:
			dir = flat.normalized().cross(Vector3.UP) * (1.0 if sin(_t * 0.6) > 0 else -1.0) * 0.5
	elif dist < data.range * 0.6:
		dir = Vector3.ZERO
	_state = "move"
	return dir

func _begin_attack(extra := 0.0) -> void:
	_state = "windup"
	_state_t = data.windup * (0.75 if phase >= 2 else 1.0) + extra
	_tele_len = _state_t
	_hit_done = false
	# звуковий сигнал замаху, щоб атаку можна було прочитати й заблокувати
	Audio.play_3d("windup", global_position, (0.7 if is_boss else 1.0) * randf_range(0.95, 1.05), -2.0)

func _strike(p: Player, flat: Vector3, dist: float) -> void:
	_state = "recover"
	_state_t = 0.45
	_cd = data.cd * (0.7 if phase >= 2 else 1.0)
	if data.kind == "ranged":
		_shoot(p, data.proj, 1)
		return
	Audio.play_3d("swing", global_position, 0.7 if is_boss else 1.0)
	if dist <= data.range + 0.4 and not p.dead:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), p.global_position + Vector3(0, 1.0, 0), 1)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			p.take_damage(data.dmg, global_position, self)

func _shoot(p: Player, proj: String, count: int, spread := 0.0, tint := Color.WHITE) -> void:
	var src := global_position + Vector3(0, 1.3 * data.get("scale", 1.0), 0)
	var aim := (p.global_position + Vector3(0, 1.2, 0)) - src
	Audio.play_3d("bow" if proj == "arrow" else "magic", src)
	for i in count:
		var ang := (i - (count - 1) * 0.5) * spread
		var dir := aim.normalized().rotated(Vector3.UP, ang)
		var pr := Projectile.new()
		pr.setup(src + dir * 0.6, dir * data.get("proj_speed", 12.0), data.dmg, "player", proj)
		pr.gravity = 1.0 if proj == "arrow" else 0.0
		pr.tint = tint
		world.add_entity(pr)

# ---------------------------------------------------------------- боси

func _boss_think(p: Player, flat: Vector3, dist: float) -> void:
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		Audio.play("roar", 0.8)
		Game.message.emit("%s лютує!" % data.name)
		for s in layers:
			s.modulate = Color(1.0, 0.7, 0.7)
		_summon(3 if type_id == "warden" else 2)
	if type_id == "prince" and phase == 2 and hp < max_hp * 0.25:
		# третя фаза: темрява й телепорти за спину
		phase = 3
		Audio.play("roar", 0.6)
		Game.message.emit("Принц кличе вічну ніч!")
		_summon(2)
		if world.has_method("dim_player_torch"):
			world.dim_player_torch(PRINCE_DARK)
		_special_cd = 1.5
	if _special_cd > 0.0 or not _los:
		return
	match type_id:
		"warden":
			if dist < 6.0:
				_start_special("slam", 1.1)
		"prince":
			if phase == 3 and dist > 3.0 and randf() < 0.5:
				_start_special("blink", 0.6)
			elif dist > 4.5 and dist < 13.0 and randf() < 0.6:
				_start_special("lunge", 0.55)
			elif phase >= 2 or randf() < 0.4:
				_start_special("volley", 0.7)

func _start_special(kind: String, windup: float) -> void:
	_state = "special"
	_special = kind
	_state_t = windup
	_hit_done = false
	_special_cd = randf_range(6.0, 9.0) * (0.7 if phase >= 2 else 1.0)
	_tele_len = windup
	if kind == "blink":
		Audio.play_3d("magic", global_position, 0.5)
	else:
		Audio.play_3d("roar", global_position, 1.3, -6.0)
	if kind == "slam":
		_spawn_danger_ring(SLAM_RADIUS, windup)

## Куди телепортуватися: за спину гравця, а якщо там стіна — збоку чи спереду.
func _blink_target(p: Player) -> Vector3:
	var b := p.global_transform.basis
	for dir in [b.z, b.x, -b.x, (b.z + b.x).normalized(), (b.z - b.x).normalized(), -b.z]:
		var flat_dir := Vector3(dir.x, 0, dir.z).normalized()
		var t: Vector2i = world.builder.tile_of(p.global_position + flat_dir * 2.2)
		if world.builder.walkable(t.x, t.y):
			return world.builder.center(t.x, t.y)
	return global_position

## Червона пляма на землі: зона, куди прийде удар.
func _spawn_danger_ring(r: float, t: float) -> void:
	var s := LevelBuilder.sprite("glow", 0.08, false)
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.modulate = Color(1.0, 0.15, 0.1, 0.0)
	s.rotation.x = -PI / 2
	world.add_entity(s)
	s.global_position = global_position + Vector3(0, 0.06, 0)
	var full := r * 2.0 / (16.0 * 0.08)   # текстура glow 16 px
	s.scale = Vector3.ONE * full * 0.3
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * full, t).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(s, "modulate:a", 0.7, t)
	tw.tween_property(s, "modulate:a", 0.0, 0.35)
	tw.tween_callback(s.queue_free)

func _special_tick(p: Player, flat: Vector3, dist: float, delta: float) -> Vector3:
	match _special:
		"slam":
			if _state_t <= 0.0 and not _hit_done:
				_hit_done = true
				Audio.play_3d("door", global_position, 1.4, 6.0)
				world.shake(0.9)
				for i in 10:
					world.spawn_hit_fx(global_position + Vector3(randf_range(-3, 3), 0.2, randf_range(-3, 3)))
				if dist < SLAM_RADIUS:
					p.take_damage(26.0, global_position, self)
				_state_t = -0.01
			if _state_t < -0.6:
				# після удару Сторож застряг мечем у підлозі — вікно для атаки
				stun(WARDEN_EXHAUST * (0.7 if phase >= 2 else 1.0))
			return Vector3.ZERO
		"blink":
			if _state_t > 0.0:
				for s in layers:
					s.modulate.a = clampf(_state_t / _tele_len, 0.1, 1.0)
				return Vector3.ZERO
			# з'являється за спиною гравця й одразу замахується
			global_position = _blink_target(p)
			_restore_alpha()
			world.spawn_hit_fx(global_position + Vector3(0, 1.2, 0))
			Audio.play_3d("magic", global_position, 0.8)
			_begin_attack(0.25)
			return Vector3.ZERO
		"lunge":
			if _state_t > 0.0:
				_lunge_dir = flat.normalized()
				return Vector3.ZERO
			if _state_t > -0.45:
				if not _hit_done and dist < 2.0:
					_hit_done = true
					p.take_damage(26.0, global_position, self)
				return _lunge_dir * 4.5
			_state = "recover"
			_state_t = 0.7
			return Vector3.ZERO
		"volley":
			if _state_t <= 0.0:
				_shoot(p, "fireball", 5 if phase >= 2 else 3, 0.22, Color(0.8, 0.4, 1.0))
				_state = "recover"
				_state_t = 0.8
			return Vector3.ZERO
	_state = "move"
	return Vector3.ZERO

func _summon(n: int) -> void:
	var kinds := ["skel_warrior", "skel_warrior", "skel_archer"] if type_id == "warden" else ["zombie", "skel_warrior", "ghost"]
	for i in n:
		var ang := TAU * i / n + randf()
		var pos := global_position + Vector3(cos(ang), 0, sin(ang)) * 3.0
		var e = world.spawn_enemy(kinds[i % kinds.size()], world.safe_spawn_near(pos, global_position))
		if e:
			e.alerted = true
			_summoned.append(e)
			world.spawn_hit_fx(e.global_position + Vector3(0, 1, 0))
	Audio.play("magic", 0.6)

# ---------------------------------------------------------------- анімація шарів

func _face_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position - global_position
	visual.global_rotation.y = atan2(d.x, d.z)

func _animate(delta: float, spd: float) -> void:
	_face_camera()
	var walk: float = min(spd / 2.0, 1.0)
	var bob: float = abs(sin(_t * 7.0)) * 0.05 * walk
	var sway := sin(_t * 7.0) * 0.05 * walk
	var breathe := sin(_t * 2.0) * 0.012
	var wpn_off := Vector3.ZERO
	var wpn_rot := 0.0
	var body_lean := 0.0
	var tele := -1.0      # 0..1 — наскільки близько удар; -1 — не замахується
	if _stun_t > 0.0:
		body_lean = sin(_t * 9.0) * 0.12   # хитається, оглушений
	match _state:
		"windup":
			var k: float = 1.0 - clamp(_state_t / max(_tele_len, 0.01), 0.0, 1.0)
			tele = k
			wpn_off = Vector3(0.1, 0.35, 0) * k
			wpn_rot = 0.6 * k
			body_lean = -0.08 * k
		"recover":
			var k2: float = clamp(_state_t / 0.45, 0.0, 1.0)
			wpn_off = Vector3(-0.2, -0.15, 0) * k2
			wpn_rot = -0.9 * k2
			body_lean = 0.1 * k2
		"special":
			if _state_t > 0.0:
				tele = 1.0 - clampf(_state_t / max(_tele_len, 0.01), 0.0, 1.0)
			if _special == "slam":
				var k3: float = clamp(1.0 - _state_t / 1.1, 0.0, 1.0) if _state_t > 0 else 0.0
				wpn_off = Vector3(0, 0.6, 0) * k3
				body_lean = -0.12 * k3
			elif _special == "lunge" and _state_t <= 0.0:
				body_lean = 0.25
				wpn_rot = -0.8
	var n := layers.size()
	for i in n:
		var s := layers[i]
		var base := _base_pos[i]
		var lag := float(i) / maxi(n - 1, 1)
		s.position = base + Vector3(sway * (0.5 + lag * 0.5), bob + breathe * (1.0 + lag), 0)
		s.rotation.z = sway * 0.4 + body_lean
		var is_weapon := String(data.layers[i]).begins_with("w_")
		if is_weapon:
			s.position += wpn_off
			s.rotation.z += wpn_rot
		if _flash > 0.0:
			s.modulate = Color(1.0, 0.35, 0.3, s.modulate.a)
		elif _stun_t > 0.0:
			s.modulate = Color(0.6, 0.7, 1.1, s.modulate.a)
		elif tele >= 0.0:
			# розгоряється до біло-помаранчевого перед самим ударом
			var hot := Color(1.9, 1.35, 0.7) if not is_boss or phase == 1 else Color(1.9, 0.8, 0.6)
			var c := Color(1, 1, 1).lerp(hot, tele * tele)
			c.a = s.modulate.a
			s.modulate = c
		else:
			s.modulate = (Color(1, 1, 1, s.modulate.a) if phase == 1 else Color(1.0, 0.7, 0.7, s.modulate.a))
	if data.get("float", false):
		_shadow.position.y = world.ground_height(global_position) - global_position.y + 0.03
