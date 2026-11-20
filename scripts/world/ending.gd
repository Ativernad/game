extends Node3D
## Фінал: виходимо на балкон тронної зали і бачимо перший за сто років світанок.

var _cam: Camera3D
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _t := 0.0
var _text: Label
var _stats: Label
var _can_exit := false
var _layer: CanvasLayer
const DUR := 22.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Audio.set_mood("dawn")
	Audio.fade_music(1.0)
	Game.delete_save()
	_build_world()
	_build_ui()
	_play_texts()

func _mat(tex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Art.tex(tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	m.roughness = 1.0
	return m

func _box(pos: Vector3, size: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	add_child(mi)

func _build_world() -> void:
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color(0.02, 0.02, 0.05)
	_sky.sky_horizon_color = Color(0.08, 0.05, 0.08)
	_sky.ground_bottom_color = Color(0.01, 0.01, 0.01)
	_sky.ground_horizon_color = Color(0.06, 0.04, 0.05)
	_sky.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 1.0
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.1, 0.07, 0.08)
	_env.fog_density = 0.012
	_env.fog_sun_scatter = 0.4
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.55, 0.3)
	_sun.light_energy = 0.0
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(6, 180, 0)
	add_child(_sun)
	var stone := _mat("marble")
	var wall := _mat("castle")
	# підлога балкона
	_box(Vector3(0, -0.25, -4), Vector3(10, 0.5, 12), stone)
	# балюстрада
	_box(Vector3(0, 0.55, -9.8), Vector3(10, 0.2, 0.5), stone)
	_box(Vector3(0, 1.1, -9.8), Vector3(10.4, 0.2, 0.7), stone)
	for i in 11:
		_box(Vector3(-4.6 + i * 0.92, 0.55, -9.8), Vector3(0.25, 1.0, 0.25), stone)
	for sx in [-5.0, 5.0]:
		_box(Vector3(sx, 0.55, -6), Vector3(0.5, 1.1, 8), stone)
	# стіна замку позаду з арковим проходом
	_box(Vector3(-4, 4, 2.2), Vector3(4, 8, 1), wall)
	_box(Vector3(4, 4, 2.2), Vector3(4, 8, 1), wall)
	_box(Vector3(0, 6.5, 2.2), Vector3(4, 3, 1), wall)
	# місто внизу — силуети будинків і веж
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.04, 0.05)
	dark.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		var x := rng.randf_range(-90, 90)
		var z := rng.randf_range(-130, -22)
		var h := rng.randf_range(3, 12)
		if rng.randf() < 0.08:
			h = rng.randf_range(18, 34)
		_box(Vector3(x, -30 + h * 0.5, z), Vector3(rng.randf_range(3, 8), h, rng.randf_range(3, 8)), dark)
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.04, 0.035, 0.035)
	_box(Vector3(0, -30.5, -100), Vector3(400, 1, 300), ground)
	# далекі гори
	for i in 9:
		var mi := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(30, 55)
		cone.height = rng.randf_range(30, 60)
		cone.radial_segments = 5
		mi.mesh = cone
		mi.material_override = dark
		mi.position = Vector3(-160 + i * 40 + rng.randf_range(-10, 10), -30 + cone.height * 0.5, -230)
		add_child(mi)
	_cam = Camera3D.new()
	_cam.fov = 70
	_cam.position = Vector3(0, 1.6, 4.0)
	_cam.rotation_degrees = Vector3(-2, 0, 0)
	add_child(_cam)
	var torch := OmniLight3D.new()
	torch.light_color = Color(1.0, 0.7, 0.45)
	torch.light_energy = 1.0
	torch.omni_range = 6.0
	_cam.add_child(torch)

func _build_ui() -> void:
	var post := CanvasLayer.new()
	post.layer = 2
	add_child(post)
	var pr := ColorRect.new()
	pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/retro.gdshader")
	sm.set_shader_parameter("desat", 0.15)
	pr.material = sm
	pr.visible = Settings.get_v("retro")
	post.add_child(pr)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	_text = UITheme.title("", 40)
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.offset_top = -120
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.modulate.a = 0.0
	root.add_child(_text)
	_stats = UITheme.label("", 22, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_stats.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stats.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_stats.offset_bottom = -60
	_stats.modulate.a = 0.0
	root.add_child(_stats)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 2.5)

func _say(text: String, at: float, dur: float, size := 40) -> void:
	var tw := create_tween()
	tw.tween_interval(at)
	tw.tween_callback(func():
		_text.text = text
		_text.add_theme_font_size_override("font_size", size))
	tw.tween_property(_text, "modulate:a", 1.0, 1.2)
	tw.tween_interval(dur)
	tw.tween_property(_text, "modulate:a", 0.0, 1.2)

func _play_texts() -> void:
	var c := Game.cls()
	_say("Принц упав. Чаша розбилася.", 2.0, 2.5, 36)
	_say("Ніч, що тривала сто років, відступає.", 7.5, 2.5, 36)
	_say("СВІТАНОК", 13.5, 4.0, 96)
	var mins := int(Game.play_time) / 60
	var secs := int(Game.play_time) % 60
	_stats.text = "%s · %s %s\nЧас у темряві: %d:%02d    Упокоєно: %d\n\nДякуємо за гру\n[будь-яка клавіша — у головне меню]" % [
		c.name, c.arcana, c.card, mins, secs, Game.kills]
	var tw := create_tween()
	tw.tween_interval(19.5)
	tw.tween_property(_stats, "modulate:a", 1.0, 1.5)
	tw.tween_callback(func(): _can_exit = true)
	Audio.play("bell", 0.7)

func _process(delta: float) -> void:
	_t += delta
	var k: float = clamp(_t / DUR, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	# камера йде до балюстради
	_cam.position = Vector3(0, 1.6 + sin(_t * 1.6) * 0.02 * (1.0 - e), lerpf(4.0, -8.3, clamp(_t / 14.0, 0.0, 1.0)))
	_cam.rotation_degrees.x = lerpf(-2.0, 4.0, e)
	# сонце піднімається
	_sun.rotation_degrees.x = lerpf(6.0, -14.0, e)
	_sun.light_energy = lerpf(0.0, 1.6, e)
	_sun.light_color = Color(1.0, 0.45, 0.25).lerp(Color(1.0, 0.85, 0.65), e)
	_sky.sky_top_color = Color(0.02, 0.02, 0.05).lerp(Color(0.25, 0.35, 0.55), e)
	_sky.sky_horizon_color = Color(0.08, 0.05, 0.08).lerp(Color(1.0, 0.6, 0.35), min(e * 1.4, 1.0))
	_sky.ground_horizon_color = _sky.sky_horizon_color.darkened(0.5)
	_env.fog_light_color = Color(0.1, 0.07, 0.08).lerp(Color(0.7, 0.5, 0.4), e)
	_env.ambient_light_energy = lerpf(0.3, 1.0, e)

func _input(event: InputEvent) -> void:
	if not _can_exit:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		_can_exit = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
