extends Node
## Налаштування гри: звук, графіка, керування. Зберігаються у user://settings.cfg.
## Також тут створюється карта керування (клавіатура/миша + контролер).

signal changed

const PATH := "user://settings.cfg"

var values := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"ambient": 0.7,
	"mouse_sens": 0.25,
	"pad_sens": 3.0,
	"invert_y": false,
	"fov": 75.0,
	"fullscreen": false,
	"vsync": true,
	"retro": true,
	"brightness": 1.1,
	"head_bob": true,
	"difficulty": 1,    # 0 легка, 1 звичайна, 2 важка (див. Game.DIFFICULTY)
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_input()
	load_settings()
	apply()

func get_v(key: String):
	return values.get(key)

func set_v(key: String, v) -> void:
	values[key] = v
	apply()
	save_settings()
	changed.emit()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in values.keys():
		values[k] = cfg.get_value("settings", k, values[k])

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in values.keys():
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)

func apply() -> void:
	_set_bus("Master", values.master)
	_set_bus("Music", values.music)
	_set_bus("SFX", values.sfx)
	_set_bus("Ambient", values.ambient)
	var win_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != win_mode:
		DisplayServer.window_set_mode(win_mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)

func _set_bus(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)

func _setup_buses() -> void:
	for b in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# Легка реверберація для атмосфери підземель
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.7
		rev.wet = 0.18
		rev.dry = 0.9
		AudioServer.add_bus_effect(sfx, rev)

# ---------------------------------------------------------------- керування

func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e

func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e

func _joy(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e

func _add(action: String, events: Array, deadzone := 0.25) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for e in events:
		InputMap.action_add_event(action, e)

func _setup_input() -> void:
	_add("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_add("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)], 0.15)
	_add("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)], 0.15)
	_add("look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)], 0.15)
	_add("look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)], 0.15)
	_add("attack", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _joy(JOY_BUTTON_RIGHT_SHOULDER)], 0.4)
	_add("secondary", [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _joy(JOY_BUTTON_LEFT_SHOULDER)], 0.4)
	_add("jump", [_key(KEY_SPACE), _joy(JOY_BUTTON_A)])
	_add("sprint", [_key(KEY_SHIFT), _joy(JOY_BUTTON_LEFT_STICK)])
	_add("interact", [_key(KEY_E), _key(KEY_F), _joy(JOY_BUTTON_X)])
	_add("heal", [_key(KEY_Q), _joy(JOY_BUTTON_Y)])
	_add("inventory", [_key(KEY_TAB), _key(KEY_I), _joy(JOY_BUTTON_BACK)])
	_add("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	_add("debug_menu", [_key(KEY_L)])    # клавіша «Д» (L в англ. розкладці); лише в debug-збірках
	# Навігація меню стіком/хрестовиною вже є у вбудованих ui_* діях,
	# додаємо лише лівий стік для зручності.
	_add("ui_up", [_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add("ui_down", [_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add("ui_left", [_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add("ui_right", [_axis(JOY_AXIS_LEFT_X, 1.0)])
