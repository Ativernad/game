extends Node3D
## Головна ігрова сцена: будує поточну локацію з LevelDB, спавнить гравця й
## ворогів, керує босом, паузою, інвентарем, смертю та переходами.

var level: Dictionary
var builder: LevelBuilder
var level_root: Node3D
var player: Player
var boss: Enemy
var ui_open := false

var hud: HUD
var pause_menu: PauseMenu
var inventory_ui: InventoryUI
var settings_menu: SettingsMenu
var game_over: Control
var _post: ColorRect
var _env: Environment

var _exits: Array = []
var _gates := {}           # Vector2i -> gate
var _flow := PackedInt32Array()
var _flow_t := 0.0
var _leaving := false
var grace := 4.5          # секунди спокою на старті локації
var _tarot: Control = null
var debug_menu: Control = null
const DEBUG_MENU := preload("res://scripts/ui/debug_menu.gd")
const TAROT_SCREEN := preload("res://scripts/ui/class_select.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	level = LevelDB.LEVELS[clamp(Game.level_index, 0, LevelDB.LEVELS.size() - 1)]
	level_root = Node3D.new()
	level_root.name = "Level"
	level_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level_root)
	builder = LevelBuilder.new()
	builder.setup(level, Game.level_index * 97 + 13)
	builder.build(level_root)
	_setup_env()
	_spawn_entities()
	_spawn_player()
	_setup_ui()
	Audio.set_mood(level.mood)
	Audio.fade_music(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.title_card(level.name, level.sub, "Розділ %d з %d" % [Game.level_index + 1, LevelDB.LEVELS.size()])
	Settings.changed.connect(_apply_settings)
	_apply_settings()

# ---------------------------------------------------------------- середовище

func _setup_env() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = level.get("sky", level.fog)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = level.ambient
	_env.ambient_light_energy = level.ambient_energy * 2.4
	_env.fog_enabled = true
	_env.fog_light_color = level.fog
	_env.fog_density = level.fog_density
	_env.fog_sky_affect = 1.0
	if level.has("mist"):
		_add_mist(level.mist)
	if level.has("skylight"):
		_add_skylight(level.skylight)
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.04
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.12
	_env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	if level.get("outdoor", false):
		var sun := DirectionalLight3D.new()
		sun.light_color = level.get("sun", Color(0.5, 0.5, 0.6))
		sun.light_energy = level.get("sun_energy", 0.3)
		sun.rotation_degrees = level.get("sun_rot", Vector3(-55, 35, 0))
		sun.shadow_enabled = true
		level_root.add_child(sun)
		if level.has("sun_disc"):
			_add_sun_disc(sun, float(level.sun_disc))

## Низька імла шаром над підлогою: об'ємний туман лише в межах коробки,
## тому світло свічок дає ореоли, а вище голови повітря чисте.
## mist = {"height": м, "density": 0..1, "color": Color}
func _add_mist(m: Dictionary) -> void:
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.0
	_env.volumetric_fog_length = 40.0
	var fv := FogVolume.new()
	var hgt: float = m.get("height", 1.0)
	fv.size = Vector3(builder.w * LevelBuilder.T, hgt * 2.0, builder.h * LevelBuilder.T)
	# "y" — центр шару (напр. глибоко в безодні); за замовчуванням біля підлоги
	fv.position = Vector3(builder.w * LevelBuilder.T * 0.5, m.get("y", 0.0), builder.h * LevelBuilder.T * 0.5)
	var fm := FogMaterial.new()
	fm.density = m.get("density", 0.3)
	fm.albedo = m.get("color", Color(0.6, 0.7, 0.7))
	fm.height_falloff = 1.5
	if m.has("glow"):
		# серпанок світиться сам — у безодні видно глибину
		fm.emission = Color(m.color) * float(m.glow)
	fm.edge_fade = 0.3
	fv.material = fm
	level_root.add_child(fv)

## Диск сонця з сяйвом у небі (не зникає в тумані): "sun_disc" — розмір сяйва.
func _add_sun_disc(sun: DirectionalLight3D, dist: float) -> void:
	var dir := sun.global_transform.basis.z.normalized()   # звідки світить сонце
	var center := Vector3(builder.w * LevelBuilder.T * 0.5, 0, builder.h * LevelBuilder.T * 0.5)
	for layer in [[dist * 0.7, Color(1.0, 0.75, 0.45, 0.4)], [dist * 0.16, Color(1.0, 0.92, 0.75, 1.0)]]:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * float(layer[0])
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = Art.tex("glow")
		m.albedo_color = layer[1]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.disable_fog = true
		m.no_depth_test = false
		q.material_override = m
		q.position = center + dir * 90.0   # у межах дальності камери (120 м)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level_root.add_child(q)

## Холодний промінь згори (крізь купол), у серпанку видно стовп світла.
## skylight = {"color": Color, "energy": float, "angle": градуси, "fog": сила променя в серпанку}
func _add_skylight(s: Dictionary) -> void:
	var sl := SpotLight3D.new()
	sl.light_color = s.get("color", Color(0.6, 0.7, 0.9))
	sl.light_energy = s.get("energy", 6.0)
	sl.spot_range = builder.ceil_y + 4.0
	sl.spot_angle = s.get("angle", 28.0)
	sl.spot_attenuation = 0.6
	sl.shadow_enabled = true
	sl.light_volumetric_fog_energy = s.get("fog", 1.0)
	sl.position = Vector3(builder.w * LevelBuilder.T * 0.5, builder.ceil_y - 0.3, builder.h * LevelBuilder.T * 0.5)
	if s.has("at"):
		# промінь на конкретну клітинку (напр. на трон)
		var at: Array = s.at
		sl.position = Vector3((float(at[0]) + 0.5) * LevelBuilder.T, builder.ceil_y - 0.3, (float(at[1]) + 0.5) * LevelBuilder.T)
	sl.rotation_degrees = Vector3(-90, 0, 0)
	level_root.add_child(sl)

func _apply_settings() -> void:
	_env.adjustment_brightness = Settings.get_v("brightness")
	_post.visible = Settings.get_v("retro")

# ---------------------------------------------------------------- сутності

func add_entity(n: Node) -> void:
	level_root.add_child(n)

func _spawn_entities() -> void:
	var item_i := 0
	var chest_i := 0
	var items: Array = level.get("items", [])
	var chests: Array = level.get("chests", [])
	for e in builder.entities:
		var c: String = e.char
		var pos: Vector3 = e.pos
		if Enemy.CHAR_TYPES.has(c):
			spawn_enemy(Enemy.CHAR_TYPES[c], pos)
		elif c == "B":
			spawn_enemy(level.get("boss", "warden"), pos)
		elif c == "i":
			if item_i < items.size():
				spawn_pickup(items[item_i], pos)
			item_i += 1
		elif c == "c":
			var ch: Interactable = preload("res://scripts/world/chest.gd").new()
			var it: Array = chests[chest_i] if chest_i < chests.size() else ["bandage", 1]
			chest_i += 1
			ch.setup(it[0], it[1])
			ch.position = pos
			level_root.add_child(ch)
		elif c == "G":
			var g: Interactable = preload("res://scripts/world/gate.gd").new()
			var blk := LevelBuilder.BLOCK + "G"
			var horiz: bool = builder.ch(e.x - 1, e.z) in blk or builder.ch(e.x + 1, e.z) in blk
			g.setup(level.get("key", "key_gate"), horiz, builder.mat("gate"))
			g.position = pos
			g.add_to_group("gates")
			level_root.add_child(g)
			_gates[Vector2i(e.x, e.z)] = g
		elif c == "N":
			var cr: Interactable = preload("res://scripts/world/crone.gd").new()
			cr.position = pos
			level_root.add_child(cr)
		elif c == "X":
			var x: Interactable = preload("res://scripts/world/exit_door.gd").new()
			x.locked = level.has("boss")
			x.position = pos
			level_root.add_child(x)
			_exits.append(x)

func _spawn_player() -> void:
	player = Player.new()
	player.world = self
	level_root.add_child(player)
	player.global_position = builder.spawn + Vector3(0, 0.1, 0)
	# повертаємо гравця обличчям до найближчого відкритого проходу
	var t := builder.tile_of(builder.spawn)
	var best := Vector2i(0, 1)
	var best_n := -1
	for d in LevelBuilder.DIRS:
		var n := 0
		for k in range(1, 6):
			if builder.walkable(t.x + d.x * k, t.y + d.y * k):
				n += 1
			else:
				break
		if n > best_n:
			best_n = n
			best = d
	player.set_look(atan2(-float(best.x), -float(best.y)))
	if Game.debug_shot:
		# налагодження знімків: інша точка й напрямок камери
		if Game.debug_at.x >= 0:
			player.global_position = builder.center(Game.debug_at.x, Game.debug_at.y) + Vector3(0, 0.1, 0)
		if not is_nan(Game.debug_yaw):
			player.set_look(Game.debug_yaw)
		player._pitch = Game.debug_pitch
	player.died.connect(_on_player_died)

func spawn_enemy(id: String, pos: Vector3) -> Enemy:
	if not Enemy.TYPES.has(id):
		return null
	var e := Enemy.new()
	e.setup(id, self)
	e.position = pos + Vector3(0, 0.05, 0)
	level_root.add_child(e)
	return e

func spawn_pickup(id: String, pos: Vector3) -> void:
	var p: Interactable = preload("res://scripts/world/pickup.gd").new()
	p.setup(id)
	level_root.add_child(p)
	p.global_position = pos

func spawn_hit_fx(pos: Vector3) -> void:
	var s := LevelBuilder.sprite("spark", 0.04)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	level_root.add_child(s)
	s.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 2.5, 0.18)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)

func dim_player_torch(k: float) -> void:
	if player:
		player.set_torch_dim(k)

func shake(v: float) -> void:
	if player:
		player._shake = max(player._shake, v)

func safe_spawn_near(pos: Vector3, fallback: Vector3) -> Vector3:
	var t := builder.tile_of(pos)
	if builder.walkable(t.x, t.y):
		return builder.center(t.x, t.y)
	return fallback

func ground_height(pos: Vector3) -> float:
	var t := builder.tile_of(pos)
	var c := builder.ch(t.x, t.y)
	var hh := builder.hgt(t.x, t.y)
	if c in LevelBuilder.STAIRS:
		var d := LevelBuilder.stair_dir(c)
		var lx := pos.x / LevelBuilder.T - t.x
		var lz := pos.z / LevelBuilder.T - t.y
		var k := 0.0
		match d:
			Vector2i(1, 0): k = lx
			Vector2i(-1, 0): k = 1.0 - lx
			Vector2i(0, 1): k = lz
			_: k = 1.0 - lz
		hh += clamp(k, 0.0, 1.0)
	return hh

## Чи над обривом ця точка (ворогам туди не можна).
func is_pit(pos: Vector3) -> bool:
	var t := builder.tile_of(pos)
	return builder.ch(t.x, t.y) == LevelBuilder.PIT

## Чи стоїть точка у воді (для звуку кроків).
func is_wet(pos: Vector3) -> bool:
	return level.has("water") and ground_height(pos) < float(level.water)

func on_gate_opened(g: Node) -> void:
	for k in _gates.keys():
		if _gates[k] == g:
			_gates.erase(k)
			break

# ---------------------------------------------------------------- поле шляхів для ворогів

func _process(delta: float) -> void:
	if get_tree().paused or player == null:
		return
	grace = max(grace - delta, 0.0)
	_flow_t -= delta
	if _flow_t <= 0.0:
		_flow_t = 0.35
		_compute_flow()

func _passable(x: int, z: int) -> bool:
	if not builder.walkable(x, z):
		return false
	var k := Vector2i(x, z)
	return not (_gates.has(k) and _gates[k].enabled)

func _compute_flow() -> void:
	var w := builder.w
	var hh := builder.h
	_flow.resize(w * hh)
	_flow.fill(-1)
	var start := builder.tile_of(player.global_position)
	if start.x < 0 or start.y < 0 or start.x >= w or start.y >= hh:
		return
	var queue: Array[Vector2i] = [start]
	_flow[start.y * w + start.x] = 0
	var head := 0
	while head < queue.size():
		var t: Vector2i = queue[head]
		head += 1
		var dcur := _flow[t.y * w + t.x]
		if dcur > 30:
			continue
		for d in LevelBuilder.DIRS:
			var n: Vector2i = t + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= hh:
				continue
			if _flow[n.y * w + n.x] != -1:
				continue
			if not _passable(n.x, n.y) or not builder.connected(t.x, t.y, d):
				continue
			_flow[n.y * w + n.x] = dcur + 1
			queue.append(n)

func flow_dir(pos: Vector3) -> Vector3:
	var w := builder.w
	var t := builder.tile_of(pos)
	if t.x < 0 or t.y < 0 or t.x >= w or t.y >= builder.h or _flow.size() != w * builder.h:
		return Vector3.ZERO
	var cur := _flow[t.y * w + t.x]
	if cur <= 0 or cur > 22:
		return Vector3.ZERO
	var best := cur
	var best_t := t
	for d in LevelBuilder.DIRS:
		var n: Vector2i = t + d
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= builder.h:
			continue
		var v := _flow[n.y * w + n.x]
		if v >= 0 and v < best and builder.connected(t.x, t.y, d):
			best = v
			best_t = n
	if best_t == t:
		return Vector3.ZERO
	var target := builder.center(best_t.x, best_t.y)
	var dir := target - pos
	dir.y = 0
	return dir.normalized()

# ---------------------------------------------------------------- боси

func start_boss(e: Enemy) -> void:
	if boss != null:
		return
	boss = e
	hud.show_boss(e)
	Audio.set_mood("boss")
	Audio.play("roar")
	e.died_signal.connect(_on_boss_dead)

func _on_boss_dead(e: Enemy) -> void:
	hud.hide_boss()
	dim_player_torch(1.0)
	Audio.set_mood(level.mood)
	Audio.play("bell", 0.8)
	if not Game.bosses_killed.has(e.type_id):
		Game.bosses_killed.append(e.type_id)
	hud.big_message("%s %s" % [e.data.name.to_upper(), "ПАВ" if e.type_id == "prince" else "УПОКОЇВСЯ"])
	for x in _exits:
		x.set_locked(false)
	# усі прислужники падають разом з босом
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != e and not other.dead:
			other.banish()
	boss = null

# ---------------------------------------------------------------- UI, пауза, смерть

func _setup_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 2
	add_child(post_layer)
	_post = ColorRect.new()
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/retro.gdshader")
	_post.material = sm
	post_layer.add_child(_post)
	hud = HUD.new()
	hud.player = player
	add_child(hud)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 10
	add_child(menu_layer)
	inventory_ui = InventoryUI.new()
	inventory_ui.player = player
	inventory_ui.visible = false
	inventory_ui.closed.connect(_close_menus)
	menu_layer.add_child(inventory_ui)
	pause_menu = PauseMenu.new()
	pause_menu.visible = false
	menu_layer.add_child(pause_menu)
	pause_menu.resume.connect(_close_menus)
	pause_menu.open_inventory.connect(func():
		pause_menu.visible = false
		inventory_ui.open())
	pause_menu.open_settings.connect(func():
		pause_menu.visible = false
		settings_menu.open())
	pause_menu.to_menu.connect(_to_main_menu)
	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	menu_layer.add_child(settings_menu)
	settings_menu.closed.connect(func(): pause_menu.open())
	if OS.is_debug_build():
		debug_menu = DEBUG_MENU.new()
		debug_menu.world = self
		debug_menu.visible = false
		menu_layer.add_child(debug_menu)
		debug_menu.closed.connect(_close_menus)

## Стара розкладає карти таро: пауза, вибір, нова доля.
func open_tarot(crone: Node) -> void:
	if _tarot != null:
		return
	_open_menu()
	_tarot = TAROT_SCREEN.new()
	_tarot.in_game = true
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	layer.add_child(_tarot)
	_tarot.picked.connect(func(id: String):
		layer.queue_free()
		_tarot = null
		_close_menus()
		Game.choose_class(id)
		hud.big_message(Game.cls().name.to_upper())
		crone.after_choice())
	_tarot.cancelled.connect(func():
		layer.queue_free()
		_tarot = null
		_close_menus())

func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.dead or _leaving or _tarot != null:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if debug_menu and debug_menu.visible:
			_close_menus()
		elif settings_menu.visible:
			settings_menu.close()
		elif inventory_ui.visible:
			_close_menus()
		elif pause_menu.visible:
			_close_menus()
		else:
			_open_menu()
			pause_menu.open()
	elif event.is_action_pressed("debug_menu") and debug_menu != null and not ui_open:
		get_viewport().set_input_as_handled()
		_open_menu()
		debug_menu.open()
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		if inventory_ui.visible:
			_close_menus()
		elif not ui_open:
			_open_menu()
			inventory_ui.open()

func _open_menu() -> void:
	ui_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false

func _close_menus() -> void:
	pause_menu.visible = false
	inventory_ui.visible = false
	settings_menu.visible = false
	if debug_menu:
		debug_menu.visible = false
	ui_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.visible = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not Game.debug_shot and not ui_open and player and not player.dead:
		_open_menu()
		pause_menu.open()

func _on_player_died() -> void:
	ui_open = true
	Audio.fade_music(0.3)
	await get_tree().create_timer(1.8).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_over = GameOverScreen.new()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(game_over)

func leave_level() -> void:
	if _leaving:
		return
	_leaving = true
	ui_open = true
	Audio.fade_music(0.0)
	await hud.fade_out(1.2)
	Game.next_level()

func _to_main_menu() -> void:
	get_tree().paused = false
	Audio.fade_music(1.0)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

