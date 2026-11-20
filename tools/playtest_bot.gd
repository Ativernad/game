extends SceneTree
## Бот-тестувальник: проходить гру від «Нової гри» до фіналу без вікна.
##
##   Godot --headless --path . --fixed-fps 60 -s res://tools/playtest_bot.gd
##
## Прокладає маршрут сіткою рівня (сходи, зіскоки, ґрати), ходить через фізику
## гравця, виконує цілі рівня по черзі: стара з картами → ключ → ґрати → бос → вихід.
## Грає з безсмертям (перевіряємо прохідність, а не вміння). Збереження гравця
## відновлюється після тесту. Код виходу: 0 — гру пройдено, 1 — ні.

const CLASS_CHOICE := "knight"
const LEVEL_TIME_LIMIT := 900.0      # секунд ігрового часу на рівень
const STUCK_WARN := 6.0              # без прогресу — спроба вибратися
const STUCK_FAIL := 30.0             # без прогресу — рівень провалено
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SOFT_BLOCK := "fcN"            # прохідні клітинки з тілом посередині (жаровня, скриня, стара)

var Game
var _save_backup := ""
var _had_save := false
var _report: Array = []
var _ok := true

# стан рівня
var w: Node
var p: Node
var _t := 0.0
var _path: Array[Vector2i] = []
var _wp := 0
var _replan := 0.0
var _last_progress := 0.0
var _best_dist := INF
var _attack_cd := 0.0
var _falls := 0
var _fallbacks := 0
var _kills0 := 0
var _boss_hp := INF

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Game = root.get_node("Game")
	_had_save = Game.has_save()
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(Game.SAVE_PATH)
	Game.new_game()
	var started := Time.get_ticks_msec()
	while true:
		await physics_frame
		if current_scene == null:
			continue
		var path := current_scene.scene_file_path
		if path.ends_with("ending.tscn"):
			_report.append("ФІНАЛ досягнуто")
			break
		if path.ends_with("game.tscn"):
			var ok: bool = await _play_level()
			if not ok:
				_ok = false
				break
	_restore_save()
	print("\n================ ЗВІТ БОТА ================")
	for line in _report:
		print(line)
	print("Реальний час: %.1f с" % ((Time.get_ticks_msec() - started) / 1000.0))
	print("РЕЗУЛЬТАТ: %s" % ("ГРУ ПРОЙДЕНО" if _ok else "ПРОВАЛ"))
	quit(0 if _ok else 1)

func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		f.store_string(_save_backup)
	else:
		Game.delete_save()

# ---------------------------------------------------------------- один рівень

func _play_level() -> bool:
	w = current_scene
	for i in 10:
		await physics_frame
	p = w.player
	var li: int = Game.level_index
	var name: String = w.level.name
	Game.god_mode = true
	_t = 0.0
	_falls = 0
	_fallbacks = 0
	_kills0 = Game.kills
	p.died.connect(func(): _report.append("  !! гравець помер на рівні %s" % name))
	var goals := _goals()
	print("[L%d %s] цілі: %s" % [li + 1, name, goals])
	for g in goals:
		var ok: bool = await _do_goal(g)
		if not ok:
			_report.append("L%d %-22s ПРОВАЛ на цілі «%s» (час %.0f с, клітинка %s)" % [li + 1, name, g, _t, w.builder.tile_of(p.global_position)])
			return false
	# вихід запущено — чекаємо зміни сцени
	var t0 := _t
	while is_instance_valid(w) and current_scene == w:
		await physics_frame
		_t += 1.0 / 60.0
		if _t - t0 > 10.0:
			_report.append("L%d %s: вихід не спрацював" % [li + 1, name])
			return false
	_report.append("L%d %-22s OK  %4.0f с ігрового часу, вбито %d, падінь %d, обхідних взаємодій %d" % [
		li + 1, name, _t, Game.kills - _kills0, _falls, _fallbacks])
	return true

func _goals() -> Array:
	var gl := []
	for z in w.builder.h:
		if "N" in w.builder.grid[z]:
			gl.append("стара")
			break
	var key: String = w.level.get("key", "")
	if key != "" and not w.level.has("npc_key"):
		gl.append("ключ")
	if not w._gates.is_empty():
		gl.append("ґрати")
	if w.level.has("boss"):
		gl.append("бос")
	gl.append("вихід")
	return gl

func _target_node(goal: String) -> Node:
	match goal:
		"стара":
			for n in get_nodes_in_group("interactable"):
				if _script_is(n, "crone.gd"):
					return n
		"ключ":
			for n in get_nodes_in_group("interactable"):
				if _script_is(n, "pickup.gd") and n.item_id == w.level.key:
					return n
		"ґрати":
			for g in w._gates.values():
				if is_instance_valid(g) and g.enabled:
					return g
		"бос":
			for e in get_nodes_in_group("enemies"):
				if e.is_boss and not e.dead:
					return e
		"вихід":
			return w._exits[0]
	return null

func _script_is(n: Node, file: String) -> bool:
	return n.get_script() != null and String(n.get_script().resource_path).ends_with(file)

func _done(goal: String, node) -> bool:   # node може бути вже звільнений
	match goal:
		"стара":
			return Game.class_id != "nobody"
		"ключ":
			return Game.count(w.level.key) > 0
		"ґрати":
			return w._gates.is_empty() or not is_instance_valid(node) or not node.enabled
		"бос":
			return node == null or not is_instance_valid(node) or node.dead
		"вихід":
			return w._leaving
	return true

func _do_goal(goal: String) -> bool:
	var node = _target_node(goal)
	if goal == "ґрати" and node == null:
		return true
	_path.clear()
	_replan = 0.0
	_last_progress = _t
	_best_dist = INF
	var interact_t := -1.0
	var t_start := _t
	_boss_hp = INF
	while not _done(goal, node):
		await physics_frame
		var dt := 1.0 / 60.0
		_t += dt
		if not is_instance_valid(w) or current_scene != w:
			return goal == "вихід"
		if _done(goal, node):
			break   # ціль виконано за цей кадр (напр. предмет підібрано й видалено)
		if goal != "бос" and not is_instance_valid(node):
			return false
		if _t - t_start > LEVEL_TIME_LIMIT:
			return false
		if p.global_position.y < -20.0:
			_falls += 1
		# карти таро стара вже розклала — тягнемо карту
		if w._tarot != null:
			_release_all()
			if not w._tarot.get_meta("bot_picked", false):
				w._tarot.set_meta("bot_picked", true)
				w._tarot._on_chosen(CLASS_CHOICE)
			continue
		if w.ui_open:
			_release_all()
			continue
		if goal == "бос":
			node = _target_node("бос")
			if node == null:
				break
		var tpos: Vector3 = node.global_position
		var dist := _flat(p.global_position - tpos)
		# прогрес: ближче до цілі або (для боса) менше здоров'я в боса
		if dist < _best_dist - 0.3:
			_best_dist = dist
			_last_progress = _t
		if goal == "бос" and node.hp < _boss_hp - 0.5:
			_boss_hp = node.hp
			_last_progress = _t
		if _t - _last_progress > STUCK_FAIL:
			_release_all()
			print("   ЗАСТРЯГ: ціль «%s», гравець %s (клітинка %s), ціль %s%s" % [goal, p.global_position, w.builder.tile_of(p.global_position), tpos,
				(", HP боса %.0f/%.0f" % [node.hp, node.max_hp]) if goal == "бос" else ""])
			return false
		# бій: бос або вороги поруч
		_attack_cd -= dt
		var foe := _nearest_enemy(2.8 if goal != "бос" else 3.4)
		if goal == "бос" and dist < 3.6:
			foe = node
		if foe != null:
			_face(foe.global_position)
			Input.action_release("move_forward")
			if _attack_cd <= 0.0:
				Input.action_press("attack")
				_attack_cd = 0.35
			else:
				Input.action_release("attack")
			if goal == "бос" and dist >= 2.2:
				Input.action_press("move_forward")   # ближче до боса
			continue
		Input.action_release("attack")
		# ціль поруч — взаємодіємо
		if goal != "бос" and dist < 2.4:   # гра дозволяє взаємодію до 2,6 м
			_face(tpos)
			Input.action_release("move_forward")
			if interact_t < 0.0:
				interact_t = _t
				Input.action_press("interact")
			else:
				Input.action_release("interact")
				if _t - interact_t > 1.2 and not _done(goal, node):
					_fallbacks += 1   # клавіша не спрацювала (кут/відстань) — взаємодіємо напряму
					node.interact(p)
					interact_t = _t + 2.0
			continue
		# рух маршрутом
		_replan -= dt
		if _path.is_empty() or _replan <= 0.0:
			_plan(tpos, goal != "бос")
			_replan = 1.5
		_steer(dt)
	_release_all()
	return true

# ---------------------------------------------------------------- маршрут і керування

func _plan(target: Vector3, adjacent_ok: bool) -> void:
	var b = w.builder
	var start: Vector2i = b.tile_of(p.global_position)
	var goal_t: Vector2i = b.tile_of(target)
	var prev := {start: start}
	var q: Array[Vector2i] = [start]
	var found := Vector2i(-999, -999)
	var rails: bool = w.level.get("railings", false)
	while not q.is_empty():
		var t: Vector2i = q.pop_front()
		if t == goal_t or (adjacent_ok and (t - goal_t).length_squared() == 1 and _blocked_soft(goal_t)):
			found = t
			break
		for d in DIRS:
			var n: Vector2i = t + d
			if prev.has(n):
				continue
			if n != goal_t and _blocked(n):
				continue
			if n == goal_t and not b.walkable(n.x, n.y) and not (adjacent_ok):
				continue
			var a: float = b.edge_h(t.x, t.y, d)
			var e: float = b.edge_h(n.x, n.y, -d)
			if a < -100.0 or e < -100.0 or e > a + 0.3:
				continue
			if rails and a - e > 1.5:
				continue
			prev[n] = t
			q.append(n)
	_path.clear()
	_wp = 0
	if found.x == -999:
		return
	var cur := found
	while cur != start:
		_path.push_front(cur)
		cur = prev[cur]

func _blocked(t: Vector2i) -> bool:
	var b = w.builder
	if not b.walkable(t.x, t.y):
		return true
	if b.ch(t.x, t.y) in SOFT_BLOCK:
		return true
	if w._gates.has(t) and w._gates[t].enabled:
		return true
	return false

func _blocked_soft(t: Vector2i) -> bool:
	return _blocked(t) or w.builder.ch(t.x, t.y) in "GX"

func _steer(dt: float) -> void:
	if _path.is_empty():
		Input.action_release("move_forward")
		return
	var b = w.builder
	var target: Vector3 = b.center(_path[_wp].x, _path[_wp].y)
	if _flat(p.global_position - target) < 0.6:
		_wp += 1
		_last_progress = _t
		if _wp >= _path.size():
			_path.clear()
			Input.action_release("move_forward")
			return
		target = b.center(_path[_wp].x, _path[_wp].y)
	_face(target)
	Input.action_press("move_forward")
	# застряг об щось — стрибок і крок убік
	if _t - _last_progress > STUCK_WARN and fmod(_t, 1.5) < dt:
		Input.action_press("jump")
		Input.action_press("move_left" if randf() < 0.5 else "move_right")
	else:
		Input.action_release("jump")
		Input.action_release("move_left")
		Input.action_release("move_right")

func _face(pos: Vector3) -> void:
	var d: Vector3 = pos - p.global_position
	if Vector2(d.x, d.z).length() < 0.05:
		return
	p.set_look(atan2(-d.x, -d.z))
	p._pitch = 0.0

func _nearest_enemy(r: float) -> Node:
	var best: Node = null
	var bd := r
	for e in get_nodes_in_group("enemies"):
		if e.dead:
			continue
		var d := _flat(e.global_position - p.global_position)
		if d < bd and abs(e.global_position.y - p.global_position.y) < 2.0:
			bd = d
			best = e
	return best

func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

func _release_all() -> void:
	for a in ["move_forward", "move_left", "move_right", "attack", "interact", "jump"]:
		Input.action_release(a)
