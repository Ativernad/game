extends Node
## Глобальний стан гри: клас, інвентар, рівні, збереження.

signal inventory_changed
signal message(text: String)
signal stats_changed
signal class_changed

const SAVE_PATH := "user://save.json"
## v2: прибрано Підземелля Сторожа, Катакомби перед Ущелиною.
## v3: Мертвий ліс і Руїни каплиці — одна локація.
## v4: прибрано Хол, Бібліотеку й Коридори; Великі сходи, потім Лабораторія алхіміка.
const SAVE_VERSION := 4
const MAX_RELICS := 2
const RETRY_MIN_HP := 0.5      # частка макс. здоров'я при завантаженні чекпоінта

## dmg — множник шкоди по гравцю, hp — множник здоров'я ворогів.
const DIFFICULTY := [
	{"name": "Легка", "dmg": 0.6, "hp": 0.8},
	{"name": "Звичайна", "dmg": 1.0, "hp": 1.0},
	{"name": "Важка", "dmg": 1.4, "hp": 1.25},
]

func difficulty() -> Dictionary:
	return DIFFICULTY[clampi(int(Settings.get_v("difficulty")), 0, DIFFICULTY.size() - 1)]

## Обирані карти таро (порядок — як їх розкладає стара).
const TAROT := ["knight", "archer", "beggar"]

const CLASSES := {
	# до зустрічі зі старою в руїнах герой — ніхто, і б'ється кулаками
	"nobody": {
		"name": "Ніхто", "arcana": "", "card": "",
		"hp": 80, "stamina": 100, "speed": 5.0, "damage": 13,
		"weapon": "Кулаки",
		"desc": "Без імені, без зброї, без долі.\n\nЛКМ / RT — удар правою\nПКМ / LT — важкий хук лівою",
		"items": {"bandage": 1},
		"color": Color(0.5, 0.48, 0.45),
	},
	"knight": {
		"name": "Лицар", "arcana": "VII", "card": "КОЛІСНИЦЯ",
		"hp": 130, "stamina": 100, "speed": 4.6, "damage": 26,
		"weapon": "Меч і щит",
		"desc": "Присягнув королю, якого вже немає. Важкий меч, міцний щит.\n\nЛКМ / RT — удар мечем\nПКМ / LT — тримати щит (блок)\nВчасний блок — парирування",
		"items": {"bandage": 2},
		"color": Color(0.75, 0.62, 0.3),
	},
	"archer": {
		"name": "Лучниця", "arcana": "XVIII", "card": "МІСЯЦЬ",
		"hp": 90, "stamina": 110, "speed": 5.2, "damage": 30,
		"weapon": "Довгий лук",
		"desc": "Полювала на вовків, тепер — на мерців. Б'є здалеку.\n\nЛКМ / RT — натягнути й випустити стрілу\nПКМ / LT — удар кинджалом\nСтріла в голову — більша шкода",
		"items": {"bandage": 2, "herb": 1},
		"color": Color(0.55, 0.65, 0.8),
	},
	"beggar": {
		"name": "Жебрак", "arcana": "0", "card": "БЛАЗЕНЬ",
		"hp": 100, "stamina": 130, "speed": 5.6, "damage": 20,
		"weapon": "Сучкувата палиця",
		"desc": "Не має нічого, тому нічого не боїться. Швидкий, спритний, щасливий на знахідки.\n\nЛКМ / RT — удар палицею\nПКМ / LT — ухилення (ривок)",
		"items": {"herb": 3, "incense": 1},
		"color": Color(0.6, 0.5, 0.42),
	},
}

var class_id := "knight"
var level_index := 0
var hp := 100.0
var inventory: Array = []      # [{id, count}]
var equipped: Array = []       # id реліквій
var bosses_killed: Array = []
var play_time := 0.0
var kills := 0
var debug_shot := false
var god_mode := false          # налагодження: шкода не проходить (не зберігається)

func _ready() -> void:
	# Налагодження: Godot ... -- --level=5 --class=archer  (одразу відкриває локацію)
	# Лише в debug-збірках (редактор), щоб у релізі аргументи не діяли.
	if not OS.is_debug_build():
		hp = max_hp()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):
			class_id = a.substr(8)
		elif a.begins_with("--level="):
			level_index = int(a.substr(8))
	if not CLASSES.has(class_id):
		class_id = "knight"
	hp = max_hp()
	# --shot=файл.png [--shot_wait=сек] [--at=x,z (клітинка)] [--yaw=градуси] [--pitch=градуси]
	var wait := 4.0
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--shot_wait="):
			wait = float(a.substr(12))
		elif a.begins_with("--at="):
			var xz := a.substr(5).split(",")
			debug_at = Vector2i(int(xz[0]), int(xz[1]))
		elif a.begins_with("--yaw="):
			debug_yaw = deg_to_rad(float(a.substr(6)))
		elif a.begins_with("--pitch="):
			debug_pitch = deg_to_rad(float(a.substr(8)))
	if shot != "":
		debug_shot = true
		_screenshot(shot, wait)

var debug_at := Vector2i(-1, -1)
var debug_yaw := NAN
var debug_pitch := 0.0

func _screenshot(path: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

func _process(delta: float) -> void:
	if get_tree().current_scene and get_tree().current_scene.name == "Root" and not get_tree().paused:
		play_time += delta

func cls() -> Dictionary:
	return CLASSES[class_id]

## Назва для інтерфейсу: "Лицар · VII КОЛІСНИЦЯ" або просто "Ніхто".
func class_title() -> String:
	var c := cls()
	return c.name if c.arcana == "" else "%s · %s %s" % [c.name, c.arcana, c.card]

## Стара розклала карти — герой стає тим, кого обрав. Повне здоров'я й речі класу.
func choose_class(id: String) -> void:
	class_id = id
	var items: Dictionary = cls().items
	for k in items:
		add_item(k, items[k])
	hp = max_hp()
	class_changed.emit()
	stats_changed.emit()

func new_game(id := "nobody") -> void:
	class_id = id
	level_index = 0
	inventory.clear()
	equipped.clear()
	bosses_killed.clear()
	play_time = 0.0
	kills = 0
	var items: Dictionary = cls().items
	for k in items:
		add_item(k, items[k], true)
	hp = max_hp()
	save_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

# ---------------------------------------------------------------- стати

func _relic_sum(key: String) -> float:
	var s := 0.0
	for id in equipped:
		s += float(ItemDB.get_item(id).get(key, 0.0))
	return s

func max_hp() -> float:
	return float(cls().hp) + _relic_sum("max_hp")

func damage_mult() -> float:
	return 1.0 + _relic_sum("damage")

func defense() -> float:
	return clamp(_relic_sum("defense"), 0.0, 0.8)

func stamina_regen_mult() -> float:
	return 1.0 + _relic_sum("stamina_regen")

func light_mult() -> float:
	var m := 1.0
	for id in equipped:
		m *= float(ItemDB.get_item(id).get("light", 1.0))
	return m

# ---------------------------------------------------------------- інвентар

func count(id: String) -> int:
	for e in inventory:
		if e.id == id:
			return e.count
	return 0

func add_item(id: String, n := 1, silent := false) -> void:
	var it := ItemDB.get_item(id)
	var cap: int = int(it.get("stack", 1)) if it.type == "consumable" else 1
	var found := false
	for e in inventory:
		if e.id == id:
			e.count = mini(e.count + n, cap)
			found = true
	if not found:
		inventory.append({"id": id, "count": mini(n, cap)})
	if not silent:
		message.emit("Знайдено: %s%s" % [it.name, (" ×%d" % n) if n > 1 else ""])
	inventory_changed.emit()

func remove_item(id: String, n := 1) -> void:
	for e in inventory:
		if e.id == id:
			e.count -= n
			if e.count <= 0:
				inventory.erase(e)
				equipped.erase(id)
			break
	inventory_changed.emit()

func toggle_equip(id: String) -> void:
	if equipped.has(id):
		equipped.erase(id)
		message.emit("Знято: " + ItemDB.get_item(id).name)
	else:
		if equipped.size() >= MAX_RELICS:
			message.emit("Можна носити лише %d реліквії" % MAX_RELICS)
			return
		equipped.append(id)
		message.emit("Вдягнено: " + ItemDB.get_item(id).name)
	hp = min(hp, max_hp())
	inventory_changed.emit()
	stats_changed.emit()

## Найкраще лікувальне, яке є (для швидкого використання).
func best_heal_item() -> String:
	var missing := max_hp() - hp
	var best := ""
	var best_val := 99999.0
	for e in inventory:
		var it := ItemDB.get_item(e.id)
		if it.has("heal"):
			var d: float = abs(float(it.heal) - missing)
			if d < best_val:
				best_val = d
				best = e.id
	return best

# ---------------------------------------------------------------- рівні та збереження

func go_to_level(i: int, save := true) -> void:
	level_index = i
	if level_index >= LevelDB.LEVELS.size():
		get_tree().change_scene_to_file("res://scenes/ending.tscn")
		return
	if save:
		save_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func next_level() -> void:
	go_to_level(level_index + 1)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION, "class": class_id, "level": level_index, "hp": hp,
		"inventory": inventory, "equipped": equipped,
		"bosses": bosses_killed, "time": play_time, "kills": kills,
	}))

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	class_id = d.get("class", "knight")
	level_index = int(d.get("level", 0))
	if int(d.get("version", 1)) < 2:
		# старий порядок: 0 ліс, 1 руїни, 2 підземелля, 3 ущелина, 4 катакомби, 5+ місто…
		# 0–3 лягають на ліс, руїни, катакомби (замість підземелля), ущелину;
		# 4 (катакомби після ущелини) веде далі — у місто; решта зсувається на 1.
		if level_index >= 5:
			level_index -= 1
	if int(d.get("version", 1)) < 3 and level_index >= 1:
		level_index -= 1     # руїни злилися з лісом: усе після них зсувається
	if int(d.get("version", 1)) < 4:
		# v3: 0 ліс, 1 кат, 2 ущ, 3 місто, 4 хол, 5 сходи, 6 бібл, 7 туман, 8 коридори, 9 трон
		level_index = [0, 1, 2, 3, 4, 4, 5, 6, 7, 7][clampi(level_index, 0, 9)]
	inventory = []
	for e in d.get("inventory", []):
		inventory.append({"id": str(e.id), "count": int(e.count)})
	equipped = []
	for e in d.get("equipped", []):
		equipped.append(str(e))
	bosses_killed = d.get("bosses", [])
	play_time = float(d.get("time", 0.0))
	kills = int(d.get("kills", 0))
	# Не менше половини здоров'я: інакше можна застрягти на чекпоінті з 5 HP без ліків.
	hp = clamp(float(d.get("hp", max_hp())), max_hp() * RETRY_MIN_HP, max_hp())
	return true

func continue_game() -> void:
	if load_game():
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
