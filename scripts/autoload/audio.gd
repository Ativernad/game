extends Node
## Процедурний звук: темний ембієнт-дрон як музика + синтезовані ефекти.
## Жодних зовнішніх аудіофайлів не потрібно — все генерується при запуску.

const RATE := 22050.0

var _music: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx: Dictionary = {}

# параметри настрою музики
var mood := {"root": 55.0, "chord": [0, 3, 7, 10], "wind": 0.3, "pulse": 0.0, "bright": 0.3, "bells": 0.2}
var _target_mood := mood.duplicate()
var _t := 0.0
var _phases := PackedFloat64Array()
var _noise_lp := 0.0
var _noise_lp2 := 0.0
var _bell_env := 0.0
var _bell_freq := 440.0
var _bell_phase := 0.0
var _rng := RandomNumberGenerator.new()
var _music_gain := 0.0
var _music_target_gain := 1.0

const MOODS := {
	"menu": {"root": 49.0, "chord": [0, 3, 7, 12], "wind": 0.35, "pulse": 0.0, "bright": 0.25, "bells": 0.35},
	"forest": {"root": 55.0, "chord": [0, 3, 7, 10], "wind": 0.6, "pulse": 0.0, "bright": 0.35, "bells": 0.15},
	"ruins": {"root": 51.9, "chord": [0, 3, 8, 12], "wind": 0.45, "pulse": 0.0, "bright": 0.3, "bells": 0.25},
	"dungeon": {"root": 46.2, "chord": [0, 1, 7, 10], "wind": 0.15, "pulse": 0.0, "bright": 0.2, "bells": 0.1},
	"gorge": {"root": 58.3, "chord": [0, 5, 7, 12], "wind": 0.8, "pulse": 0.0, "bright": 0.4, "bells": 0.1},
	"catacombs": {"root": 43.6, "chord": [0, 3, 6, 10], "wind": 0.1, "pulse": 0.0, "bright": 0.15, "bells": 0.3},
	"city": {"root": 49.0, "chord": [0, 3, 7, 8], "wind": 0.4, "pulse": 0.0, "bright": 0.3, "bells": 0.4},
	"castle": {"root": 41.2, "chord": [0, 3, 7, 11], "wind": 0.2, "pulse": 0.0, "bright": 0.35, "bells": 0.3},
	"boss": {"root": 41.2, "chord": [0, 1, 6, 7], "wind": 0.1, "pulse": 1.0, "bright": 0.5, "bells": 0.0},
	"dawn": {"root": 65.4, "chord": [0, 4, 7, 11], "wind": 0.3, "pulse": 0.0, "bright": 0.7, "bells": 0.6},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_phases.resize(8)
	_music = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	_music.stream = gen
	_music.bus = "Music"
	add_child(_music)
	_music.play()
	_playback = _music.get_stream_playback()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_build_sfx()

func set_mood(name: String) -> void:
	if MOODS.has(name):
		_target_mood = MOODS[name].duplicate()

func fade_music(target: float) -> void:
	_music_target_gain = target

func _process(delta: float) -> void:
	# плавний перехід між настроями
	for k in ["root", "wind", "pulse", "bright", "bells"]:
		mood[k] = lerp(float(mood[k]), float(_target_mood[k]), clamp(delta * 0.6, 0.0, 1.0))
	mood["chord"] = _target_mood["chord"]
	_music_gain = move_toward(_music_gain, _music_target_gain, delta * 0.5)
	_fill()

func _fill() -> void:
	if _playback == null:
		return
	var n := _playback.get_frames_available()
	if n <= 0:
		return
	var root: float = mood.root
	var chord: Array = mood.chord
	var freqs := PackedFloat64Array()
	for i in chord.size():
		var f := root * pow(2.0, float(chord[i]) / 12.0)
		freqs.append(f)
		freqs.append(f * 1.003 * 2.0)  # октава з розстроєнням
	var wind: float = mood.wind
	var pulse: float = mood.pulse
	var bright: float = mood.bright
	var bells: float = mood.bells
	var inv := 1.0 / RATE
	var buf := PackedVector2Array()
	buf.resize(n)
	for s in n:
		_t += inv
		var lfo := 0.5 + 0.5 * sin(_t * 0.21)
		var v := 0.0
		for i in freqs.size():
			_phases[i] = fmod(_phases[i] + freqs[i] * inv, 1.0)
			var ph: float = _phases[i] * TAU
			# м'яка "пилка" з двох гармонік
			var w := sin(ph) + bright * 0.35 * sin(ph * 2.0) + bright * 0.12 * sin(ph * 3.0)
			var amp := 0.06 if i % 2 == 0 else 0.025 * lfo
			v += w * amp * (0.7 + 0.3 * sin(_t * (0.13 + i * 0.07) + i))
		# вітер: фільтрований шум
		var nz := _rng.randf() * 2.0 - 1.0
		var cut := 0.02 + 0.05 * (0.5 + 0.5 * sin(_t * 0.37))
		_noise_lp += (nz - _noise_lp) * cut
		_noise_lp2 += (_noise_lp - _noise_lp2) * cut
		v += _noise_lp2 * wind * 0.9
		# серцебиття для боїв з босом
		if pulse > 0.01:
			var beat := fmod(_t, 0.85)
			var b1: float = exp(-beat * 18.0) * sin(beat * TAU * 48.0)
			var b2: float = 0.0
			if beat > 0.22:
				b2 = exp(-(beat - 0.22) * 18.0) * sin((beat - 0.22) * TAU * 44.0)
			v += (b1 + b2 * 0.7) * pulse * 0.35
		# рідкісні дзвони
		if bells > 0.01 and _rng.randf() < bells * 0.00004:
			_bell_env = 1.0
			_bell_freq = root * pow(2.0, float(chord[_rng.randi() % chord.size()]) / 12.0) * 8.0
		if _bell_env > 0.0005:
			_bell_phase = fmod(_bell_phase + _bell_freq * inv, 1.0)
			var bp := _bell_phase * TAU
			v += (sin(bp) + 0.4 * sin(bp * 2.76) + 0.2 * sin(bp * 5.4)) * _bell_env * 0.06
			_bell_env *= 0.99985
		v = tanh(v * 1.4) * 0.6 * _music_gain
		buf[s] = Vector2(v, v)
	_playback.push_buffer(buf)

# ---------------------------------------------------------------- ефекти

func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = _sfx[name]
			p.pitch_scale = pitch * _rng.randf_range(0.94, 1.06)
			p.volume_db = vol_db
			p.play()
			return

func play_3d(name: String, pos: Vector3, pitch := 1.0, vol_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	var tree := get_tree()
	if tree.current_scene == null or not tree.current_scene is Node3D:
		play(name, pitch, vol_db)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _sfx[name]
	p.bus = "SFX"
	p.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
	p.volume_db = vol_db + 4.0
	p.unit_size = 6.0
	p.max_distance = 40.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w

## Універсальний синтезатор: тон з глайдом + шум з фільтром, експоненційна огинаюча.
func _synth(dur: float, f0: float, f1: float, tone: float, noise: float, decay: float, lp := 0.3, attack := 0.002) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var flt := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f: float = lerp(f0, f1, k)
		ph += f / RATE
		var env: float = exp(-t * decay) * clamp(t / attack, 0.0, 1.0)
		var nz := _rng.randf() * 2.0 - 1.0
		flt += (nz - flt) * lp
		var v := sin(ph * TAU) * tone + flt * noise
		out[i] = tanh(v * env * 1.5)
	return _make(out)

func _build_sfx() -> void:
	_sfx["swing"] = _synth(0.25, 300, 120, 0.0, 1.0, 12.0, 0.15, 0.04)
	_sfx["hit"] = _synth(0.25, 140, 50, 0.9, 0.6, 16.0, 0.5)
	_sfx["bone"] = _synth(0.2, 900, 400, 0.4, 0.8, 22.0, 0.7)
	_sfx["hurt"] = _synth(0.35, 220, 90, 0.8, 0.4, 9.0, 0.3)
	_sfx["block"] = _synth(0.3, 1400, 1300, 0.6, 0.5, 14.0, 0.9)
	_sfx["bow"] = _synth(0.3, 180, 260, 0.7, 0.2, 10.0, 0.3)
	_sfx["arrow_hit"] = _synth(0.12, 600, 200, 0.3, 0.9, 30.0, 0.6)
	_sfx["pickup"] = _synth(0.35, 660, 1320, 0.7, 0.0, 7.0)
	_sfx["heal"] = _synth(0.6, 330, 660, 0.6, 0.1, 4.0, 0.2, 0.05)
	_sfx["chest"] = _synth(0.5, 90, 70, 0.6, 0.6, 5.0, 0.1)
	_sfx["door"] = _synth(0.9, 60, 45, 0.7, 0.5, 3.0, 0.05, 0.05)
	_sfx["step"] = _synth(0.08, 80, 60, 0.2, 0.7, 40.0, 0.08)
	_sfx["die"] = _synth(0.7, 200, 40, 0.5, 0.7, 5.0, 0.2)
	_sfx["roar"] = _synth(1.4, 70, 40, 0.8, 0.8, 2.0, 0.08, 0.2)
	_sfx["ui_move"] = _synth(0.06, 880, 880, 0.5, 0.0, 40.0)
	_sfx["ui_ok"] = _synth(0.2, 440, 660, 0.6, 0.0, 12.0)
	_sfx["dash"] = _synth(0.3, 200, 600, 0.0, 1.0, 9.0, 0.25, 0.03)
	_sfx["bell"] = _synth(2.0, 220, 219, 0.9, 0.0, 1.5)
	_sfx["magic"] = _synth(0.6, 300, 900, 0.6, 0.3, 4.0, 0.4, 0.03)
