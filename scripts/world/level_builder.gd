class_name LevelBuilder
extends RefCounted
## Будує 3D-локацію з текстової сітки LevelDB: підлогу, стіни, стелю, сходи,
## дерева, колони, декор і світло. Сутності (вороги, предмети) повертає списками.

const T := 2.0
const WALLS := "#SH"
const BLOCK := "#SHWTo_UIYqRjVEKQu"
const STAIRS := "^v<>"
const PIT := "_"              # обрив: без підлоги, падіння — смерть
const BRIDGE := "="           # тонкий кам'яний міст над обривом
const PIT_DEPTH := -30.0      # до якої глибини тягнуться скелі під обривом
const BRIDGE_THICK := 1.2
## Текстури без затінення — виглядають підсвіченими ззовні (вітражі).
const UNSHADED := ["stained_glass"]
## Вологі поверхні блищать (менша шорсткість).
const WET := {"crypt_wall": 0.45, "crypt_niche": 0.5, "crypt_ceil": 0.55, "wet_floor": 0.3, "water": 0.04}

var level: Dictionary
var grid: Array[String] = []
var hmap: Array = []
var w := 0
var h := 0
var max_h := 0.0
var ceil_y := 4.0
var outdoor := false
var rng := RandomNumberGenerator.new()

var spawn := Vector3.ZERO
var entities: Array = []   # [{type, char, pos, x, z}]

var _st := {}              # текстура -> SurfaceTool
var _col := PackedVector3Array()
var _mats := {}

func setup(lv: Dictionary, seed_v: int) -> void:
	level = lv
	rng.seed = seed_v
	outdoor = lv.get("outdoor", false)
	var rows: Array = lv.map
	for r in rows:
		w = max(w, r.length())
	h = rows.size()
	for r in rows:
		grid.append(r.rpad(w, "#"))
	var hs: Array = lv.get("heights", [])
	for z in h:
		var row := PackedFloat32Array()
		row.resize(w)
		for x in w:
			var v := 0.0
			if z < hs.size() and x < hs[z].length():
				v = float(max(LevelDB.HEIGHT_CHARS.find(hs[z][x]), 0))
			row[x] = v
			if not grid[z][x] in WALLS:
				max_h = max(max_h, v + (1.0 if grid[z][x] in STAIRS else 0.0))
		hmap.append(row)
	ceil_y = max_h + float(lv.get("wall_h", 4.0))

# ---------------------------------------------------------------- запити до сітки

func ch(x: int, z: int) -> String:
	if x < 0 or z < 0 or x >= w or z >= h:
		return "#"
	return grid[z][x]

func hgt(x: int, z: int) -> float:
	if x < 0 or z < 0 or x >= w or z >= h:
		return 0.0
	return hmap[z][x]

static func stair_dir(c: String) -> Vector2i:
	match c:
		"^": return Vector2i(0, -1)
		"v": return Vector2i(0, 1)
		"<": return Vector2i(-1, 0)
		">": return Vector2i(1, 0)
	return Vector2i.ZERO

func walkable(x: int, z: int) -> bool:
	return not ch(x, z) in BLOCK

## Висота краю клітинки у напрямку d (для сходів — різна з різних боків).
func edge_h(x: int, z: int, d: Vector2i) -> float:
	var c := ch(x, z)
	var base := hgt(x, z)
	if c in STAIRS:
		var sd := stair_dir(c)
		if d == sd:
			return base + 1.0
		if d == -sd:
			return base
		return -999.0
	return base

func connected(x: int, z: int, d: Vector2i) -> bool:
	if not walkable(x, z) or not walkable(x + d.x, z + d.y):
		return false
	var a := edge_h(x, z, d)
	var b := edge_h(x + d.x, z + d.y, -d)
	return a > -100.0 and b > -100.0 and abs(a - b) < 0.3

func center(x: int, z: int) -> Vector3:
	var y := hgt(x, z)
	if ch(x, z) in STAIRS:
		y += 0.5
	return Vector3(x * T + T * 0.5, y, z * T + T * 0.5)

func tile_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / T)), int(floor(p.z / T)))

# ---------------------------------------------------------------- матеріали

func mat(tex_name: String) -> StandardMaterial3D:
	if _mats.has(tex_name):
		return _mats[tex_name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = Art.tex(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = WET.get(tex_name, 1.0)
	m.metallic_specular = 0.15 if not WET.has(tex_name) else 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex_name in UNSHADED:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex_name == "gate" or tex_name == "railing":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	if tex_name == "water":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic_specular = 1.0
		m.metallic = 0.3
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.emission_enabled = true          # ледь світиться, щоб воду було видно в темряві
		m.emission = Color(0.05, 0.14, 0.13)
		m.emission_energy_multiplier = 0.6
	_mats[tex_name] = m
	return m

func _st_for(tex_name: String) -> SurfaceTool:
	if not _st.has(tex_name):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[tex_name] = st
	return _st[tex_name]

func _uv(p: Vector3, n: Vector3) -> Vector2:
	if abs(n.y) > 0.5:
		return Vector2(p.x, p.z) / T
	if abs(n.x) > 0.5:
		return Vector2(p.z, -p.y) / T
	return Vector2(p.x, -p.y) / T

func quad(tex_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, collide := true) -> void:
	var st := _st_for(tex_name)
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(_uv(v, n))
		st.add_vertex(v)
	if collide:
		_col.append_array([a, b, c, a, c, d])

## Коробка: faces — бітова маска сторін (1 +x, 2 -x, 4 +z, 8 -z, 16 верх, 32 низ)
func box(tex_name: String, mn: Vector3, mx: Vector3, faces := 63, collide := true) -> void:
	if faces & 16:
		quad(tex_name, Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3.UP, collide)
	if faces & 32:
		quad(tex_name, Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mn.y, mn.z), Vector3.DOWN, collide)
	if faces & 1:
		quad(tex_name, Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3.RIGHT, collide)
	if faces & 2:
		quad(tex_name, Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(mn.x, mx.y, mn.z), Vector3(mn.x, mn.y, mn.z), Vector3.LEFT, collide)
	if faces & 4:
		quad(tex_name, Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(mn.x, mn.y, mx.z), Vector3.BACK, collide)
	if faces & 8:
		quad(tex_name, Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3.FORWARD, collide)

# ---------------------------------------------------------------- побудова

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIR_FACE := [1, 2, 4, 8]

func build(root: Node3D) -> void:
	var floor_tex: String = level.floor
	var wall_tex: String = level.wall
	var alt_tex: String = level.get("alt_wall", wall_tex)
	var wall_h: float = level.get("wall_h", 4.0)
	# "wall_mix": [текстура, шанс] — частина звичайних стін іншою текстурою (напр. ніші)
	var mix: Array = level.get("wall_mix", [])
	var ceil_tex: String = level.get("ceiling", "stone_dark" if wall_tex != "bonewall" else "bonewall")
	var water: float = level.get("water", -1.0)
	var bridge_tex: String = level.get("bridge_tex", wall_tex)
	var has_pit := false
	for r in grid:
		if PIT in r:
			has_pit = true
	for z in h:
		for x in w:
			var c := ch(x, z)
			var x0 := x * T
			var z0 := z * T
			if c in WALLS:
				# "wall_S" / "wall_H" — окрема текстура для кожного символу стіни
				var tex: String = level.get("wall_" + c, alt_tex if c in "SH" else wall_tex)
				if c == "#" and mix.size() == 2 and rng.randf() < float(mix[1]):
					tex = mix[0]
				var top := ceil_y
				if outdoor:
					top = max_h + wall_h * (rng.randf_range(0.8, 1.5) if tex in ["rock", "ruin", "cliff"] else 1.0)
				if level.has("top_" + c):
					# "top_H": [мін, макс] — власна висота стіни (будинки, книжкові шафи)
					var tr: Array = level["top_" + c]
					top = rng.randf_range(tr[0], tr[1])
				var faces := 16 if outdoor or level.has("top_" + c) else 0
				var bottom := -0.5
				for i in 4:
					var nc0 := ch(x + DIRS[i].x, z + DIRS[i].y)
					if not nc0 in WALLS:
						faces |= DIR_FACE[i]
					if nc0 == PIT:
						bottom = PIT_DEPTH   # скеля продовжується в безодню
				box(tex, Vector3(x0, bottom, z0), Vector3(x0 + T, top, z0 + T), faces)
				continue
			if c == PIT:
				continue
			var hh := hgt(x, z)
			if c in STAIRS:
				_stairs(x, z, level.get("stairs_tex", floor_tex))
			else:
				var ftex := bridge_tex if c == BRIDGE else floor_tex
				quad(ftex, Vector3(x0, hh, z0), Vector3(x0 + T, hh, z0), Vector3(x0 + T, hh, z0 + T), Vector3(x0, hh, z0 + T), Vector3.UP)
				if c == BRIDGE:
					quad(bridge_tex, Vector3(x0, hh - BRIDGE_THICK, z0), Vector3(x0, hh - BRIDGE_THICK, z0 + T), Vector3(x0 + T, hh - BRIDGE_THICK, z0 + T), Vector3(x0 + T, hh - BRIDGE_THICK, z0), Vector3.DOWN)
				# бокові грані, якщо сусід нижче (або обрив)
				for i in 4:
					var d: Vector2i = DIRS[i]
					var nc := ch(x + d.x, z + d.y)
					if nc in WALLS:
						continue
					var nh := hgt(x + d.x, z + d.y)
					if nc == PIT:
						nh = hh - BRIDGE_THICK if c == BRIDGE else PIT_DEPTH
					if nh < hh - 0.01:
						var mn := Vector3(x0, nh, z0)
						var mx := Vector3(x0 + T, hh, z0 + T)
						var stex := bridge_tex if c == BRIDGE else (floor_tex if hh - nh < 1.5 else wall_tex)
						box(stex, mn, mx, DIR_FACE[i])
			if not outdoor:
				quad(ceil_tex, Vector3(x0, ceil_y, z0), Vector3(x0, ceil_y, z0 + T), Vector3(x0 + T, ceil_y, z0 + T), Vector3(x0 + T, ceil_y, z0), Vector3.DOWN, false)
			if water > 0.0 and hh < water:
				# мілка вода над підлогою (без колізії — по ній ходять)
				var wy := water
				quad("water", Vector3(x0, wy, z0), Vector3(x0 + T, wy, z0), Vector3(x0 + T, wy, z0 + T), Vector3(x0, wy, z0 + T), Vector3.UP, false)
			_tile_object(root, x, z, c)
	# зовнішня "земля" під рівнем, щоб у тумані не було порожнечі
	if outdoor and not has_pit:
		box(floor_tex, Vector3(-40, -0.6, -40), Vector3(w * T + 40, -0.5, h * T + 40), 16, false)
	_ring_arches(root)
	if level.get("railings", false):
		_railings(root)
	# "decor_boxes": [[x0, z0, x1, z1, y0, y1, текстура], ...] у клітинках (x1/z1 — край, не включно)
	for b in level.get("decor_boxes", []):
		box(b[6], Vector3(b[0] * T, b[4], b[1] * T), Vector3(b[2] * T, b[5], b[3] * T))
	_commit(root)
	if water > 0.0:
		# вода повільно тече
		var wm := mat("water")
		var tw := root.create_tween().set_loops()
		tw.tween_property(wm, "uv1_offset", Vector3(1.0, 0.5, 0.0), 40.0).from(Vector3.ZERO)

func _stairs(x: int, z: int, tex: String) -> void:
	var c := ch(x, z)
	var d := stair_dir(c)
	var hh := hgt(x, z)
	var x0 := x * T
	var z0 := z * T
	var n := 4
	for i in n:
		var a := float(i) / n * T
		var b := float(i + 1) / n * T
		var top := hh + float(i + 1) / n
		var mn: Vector3
		var mx: Vector3
		match d:
			Vector2i(1, 0):
				mn = Vector3(x0 + a, hh, z0); mx = Vector3(x0 + b, top, z0 + T)
			Vector2i(-1, 0):
				mn = Vector3(x0 + T - b, hh, z0); mx = Vector3(x0 + T - a, top, z0 + T)
			Vector2i(0, 1):
				mn = Vector3(x0, hh, z0 + a); mx = Vector3(x0 + T, top, z0 + b)
			_:
				mn = Vector3(x0, hh, z0 + T - b); mx = Vector3(x0 + T, top, z0 + T - a)
		box(tex, mn, mx, 63, false)
	# колона під сходами — або, для "летючих" сходів ("stairs_thin"), лише тонка плита
	var thin: bool = level.get("stairs_thin", false)
	if thin:
		box(tex, Vector3(x0, hh - 0.8, z0), Vector3(x0 + T, hh, z0 + T), 47, false)
	elif hh > 0.01:
		box(tex, Vector3(x0, 0, z0), Vector3(x0 + T, hh, z0 + T), 15, false)
	# сходи над обривом: скеля донизу з боку безодні
	for i in 4:
		if ch(x + DIRS[i].x, z + DIRS[i].y) == PIT:
			box(level.wall, Vector3(x0, PIT_DEPTH, z0), Vector3(x0 + T, hh, z0 + T), DIR_FACE[i], false)
	# похила рампа для колізії
	var lo := hh
	var hi := hh + 1.0
	var p := [Vector3(x0, 0, z0), Vector3(x0 + T, 0, z0), Vector3(x0 + T, 0, z0 + T), Vector3(x0, 0, z0 + T)]
	for i in 4:
		var v: Vector3 = p[i]
		var k := 0.0
		match d:
			Vector2i(1, 0): k = (v.x - x0) / T
			Vector2i(-1, 0): k = 1.0 - (v.x - x0) / T
			Vector2i(0, 1): k = (v.z - z0) / T
			_: k = 1.0 - (v.z - z0) / T
		v.y = lerpf(lo, hi, k)
		p[i] = v
	_col.append_array([p[0], p[1], p[2], p[0], p[2], p[3]])
	# бокові стінки рампи (невидимі), щоб не провалюватися збоку
	for i in 4:
		var dd: Vector2i = DIRS[i]
		if dd == d or dd == -d:
			continue
		if ch(x + dd.x, z + dd.y) in WALLS:
			continue
		var nh := hgt(x + dd.x, z + dd.y)
		if thin:
			nh = max(nh, lo - 0.8)     # бокова тятива замість стіни до підлоги
		var mn2 := Vector3(x0, min(nh, lo), z0)
		var mx2 := Vector3(x0 + T, hi, z0 + T)
		box(tex, mn2, mx2, DIR_FACE[i], true)

func _commit(root: Node3D) -> void:
	for tex_name in _st:
		var st: SurfaceTool = _st[tex_name]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat(tex_name)
		root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_col)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)

# ---------------------------------------------------------------- об'єкти на клітинках

static func sprite(tex_name: String, pixel := 0.04, billboard := true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Art.tex(tex_name)
	s.pixel_size = pixel
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	return s

static func ground_sprite(tex_name: String, pixel: float, pos: Vector3, billboard := true) -> Sprite3D:
	var s := sprite(tex_name, pixel, billboard)
	s.position = pos + Vector3(0, s.texture.get_height() * pixel * 0.5, 0)
	return s

func light(root: Node3D, pos: Vector3, color: Color, energy: float, rng_: float, flicker := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_
	l.omni_attenuation = 1.4
	l.position = pos
	if flicker:
		l.set_script(load("res://scripts/world/flicker.gd"))
	root.add_child(l)
	return l

func _tile_object(root: Node3D, x: int, z: int, c: String) -> void:
	var cp := center(x, z)
	var jitter := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	match c:
		"P":
			spawn = cp
		"T":
			_tree(root, cp + jitter * 0.5, _near_walk(x, z))
		"o":
			_pillar(root, cp)
		"W":
			var top := cp.y + rng.randf_range(0.7, 1.6)
			box(level.get("low_wall", level.wall), Vector3(x * T, cp.y, z * T), Vector3(x * T + T, top, z * T + T), 63)
		"U":
			_tower(root, cp)
		"q":
			_cross_thicket(root, cp, _near_walk(x, z))
		"j":
			# великий хрест із сонячним колом
			root.add_child(ground_sprite("cross_sun", 0.14, cp))
			_collider(root, cp + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5))
		"R":
			_ring_piece(root, cp, false)
		"A":
			_ring_piece(root, cp, true)
		"I":
			# висока колона до склепіння (храм)
			_pillar(root, cp, 0.6, float(level.get("column_h", 6.0)), level.get("column_tex", level.wall))
		"Y":
			_statue(root, cp)
		"r":
			root.add_child(ground_sprite("barrel", 0.05, cp + jitter * 0.6))
		"V":
			# скляний чан із зеленим світлом
			root.add_child(ground_sprite("vat", 0.07, cp))
			light(root, cp + Vector3(0, 1.6, 0.4), Color(0.4, 1.0, 0.5), 1.1, 5.5)
			_collider(root, cp + Vector3(0, 1.6, 0), Vector3(1.6, 3.2, 1.6))
		"E":
			root.add_child(ground_sprite("bench", 0.06, cp))
			_collider(root, cp + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 1.4))
		"Q":
			# трон на помості з підсвіткою
			root.add_child(ground_sprite("throne", 0.075, cp))
			light(root, cp + Vector3(0, 2.0, 0.8), Color(1.0, 0.55, 0.4), 1.2, 6.0)
			_collider(root, cp + Vector3(0, 1.2, 0), Vector3(1.8, 2.4, 1.2))
		"u":
			root.add_child(ground_sprite("chalice", 0.045, cp))
			_collider(root, cp + Vector3(0, 0.5, 0), Vector3(0.6, 1.0, 0.6))
		"C":
			# люстра під стелею (прохідна клітинка під нею)
			var ly: float = float(level.get("chandelier_y", 6.0))
			var ch_s := sprite("chandelier", 0.07)
			ch_s.position = cp + Vector3(0, ly, 0)
			root.add_child(ch_s)
			light(root, cp + Vector3(0, ly - 0.3, 0), Color(1.0, 0.7, 0.4), 2.0, 11.0)
		"K":
			root.add_child(ground_sprite("cauldron", 0.06, cp))
			light(root, cp + Vector3(0, 1.0, 0), Color(0.45, 1.0, 0.5), 1.6, 6.0)
			_collider(root, cp + Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.4))
		"t":
			root.add_child(ground_sprite("tomb", 0.06, cp + jitter))
		"b":
			root.add_child(ground_sprite("bones", 0.05, cp + jitter))
		"x":
			root.add_child(ground_sprite("cross", 0.08, cp + jitter))
		"p":
			root.add_child(ground_sprite("skull_pike", 0.06, cp + jitter))
		"+":
			# "candle_color" — колір полум'я свічок у локації (напр. примарний зелений)
			var cc: Color = level.get("candle_color", Color(1.0, 0.7, 0.4))
			var cs := ground_sprite("candles", 0.045, cp + jitter)
			if level.has("candle_color"):
				cs.modulate = Color.WHITE.lerp(cc, 0.6)
			root.add_child(cs)
			light(root, cp + jitter + Vector3(0, 0.6, 0), cc, 0.9, 4.5)
		"f":
			root.add_child(ground_sprite("flame", 0.12, cp + Vector3(0, 0.9, 0)))
			_pillar(root, cp, 0.3, 0.9, level.wall)
			light(root, cp + Vector3(0, 1.8, 0), Color(1.0, 0.55, 0.25), 2.2, 9.0)
		"l":
			var wd := _wall_dir(x, z)
			var lp := cp + Vector3(wd.x, 0, wd.y) * 0.85 + Vector3(0, 2.0, 0)
			root.add_child(ground_sprite("flame", 0.06, lp - Vector3(0, 0.3, 0)))
			light(root, lp, Color(1.0, 0.6, 0.3), 1.6, 7.0)
		"n":
			var wd2 := _wall_dir(x, z)
			var s := sprite("banner", 0.07, false)
			s.position = cp + Vector3(wd2.x, 0, wd2.y) * 0.95 + Vector3(0, 2.6, 0)
			if wd2.x != 0:
				s.rotation.y = PI / 2
			root.add_child(s)
		".", "^", "v", "<", ">":
			if outdoor and level.floor == "grass" and rng.randf() < 0.35:
				root.add_child(ground_sprite("grass_tuft", 0.05, cp + jitter * 2.0))
		_:
			if c in "wakmzZgBicGXN":
				entities.append({"char": c, "pos": cp, "x": x, "z": z})

## Гущавина хрестів: кілька різних хрестів і капличок на клітинці, з колізією.
func _cross_thicket(root: Node3D, cp: Vector3, near := true) -> void:
	var kinds := ["cross_a", "cross_a", "cross_c", "cross", "cross_a", "shrine", "cross_sun"]
	for i in (rng.randi_range(5, 8) if near else rng.randi_range(3, 4)):
		var k: String = kinds[rng.randi() % kinds.size()]
		var px := rng.randf_range(0.03, 0.055) if k != "shrine" else rng.randf_range(0.045, 0.06)
		if k == "cross_sun":
			px *= 0.6
		var s := ground_sprite(k, px, cp + Vector3(rng.randf_range(-0.85, 0.85), 0, rng.randf_range(-0.85, 0.85)))
		s.modulate = Color(1, 1, 1).lerp(Color(0.7, 0.72, 0.75), rng.randf() * 0.6)   # частина сіра від часу
		root.add_child(s)
	if near:
		_collider(root, cp + Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 1.8))

## Поруччя вздовж країв, де перепад униз більший за 1,5 м (галереї, мости, летючі сходи):
## видима кована балюстрада з колізією — щоб не впасти вниз.
func _railings(root: Node3D) -> void:
	for z in h:
		for x in w:
			if not walkable(x, z):
				continue
			var hh := hgt(x, z)
			for i in 4:
				var d: Vector2i = DIRS[i]
				var nc := ch(x + d.x, z + d.y)
				if nc in WALLS or (not walkable(x + d.x, z + d.y) and nc != PIT):
					continue
				var mine := edge_h(x, z, d)
				var base := hh + 0.5 if mine < -100.0 else mine   # бік сходів — посередині
				var other := hgt(x + d.x, z + d.y) if nc != PIT else PIT_DEPTH
				if nc in STAIRS:
					var oe := edge_h(x + d.x, z + d.y, -d)
					if oe > -100.0 and abs(oe - mine) < 0.3:
						continue
				if base - other < 1.5:
					continue
				var cx := x * T + T * 0.5 + d.x * (T * 0.5 - 0.08)
				var cz := z * T + T * 0.5 + d.y * (T * 0.5 - 0.08)
				var size := Vector3(0.12, 1.0, T) if d.x != 0 else Vector3(T, 1.0, 0.12)
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = size
				mi.mesh = bm
				mi.material_override = mat("railing")
				mi.position = Vector3(cx, base + 0.5, cz)
				root.add_child(mi)
				_collider(root, Vector3(cx, base + 0.6, cz), size + Vector3(0, 0.2, 0))

func _collider(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	root.add_child(body)

## Арки круглої руїни: "ring_arches": [[кут°, ширина прорізу м], ...] (0° — схід, 90° — південь).
func _ring_arches(root: Node3D) -> void:
	var rg: Array = level.get("ring", [])
	if rg.is_empty():
		return
	var tex: String = level.get("ring_tex", level.wall)
	var c := Vector3(float(rg[0]) * T, 0, float(rg[1]) * T)
	var r := float(rg[2]) * T
	for a in level.get("ring_arches", []):
		var ang := deg_to_rad(float(a[0]))
		var gap := float(a[1])
		var d := Vector3(cos(ang), 0, sin(ang))
		var t := tile_of(c + d * r)
		var pos := c + d * r + Vector3(0, hgt(t.x, t.y), 0)
		var yaw := atan2(d.x, d.z)
		var tan_v := Vector3(d.z, 0, -d.x)
		var ah := 5.0
		for sgn: float in [-1.0, 1.0]:
			_rot_box(root, pos + tan_v * (gap * 0.5 + 0.35) * sgn + Vector3(0, ah * 0.5, 0), Vector3(0.7, ah, 1.1), yaw, tex)
		_rot_box(root, pos + Vector3(0, ah + 0.4, 0), Vector3(gap + 1.4, 0.8, 1.1), yaw, tex, false)
		_rot_box(root, pos + Vector3(0, ah + 1.1, 0), Vector3(gap * 0.5, 0.6, 1.1), yaw, tex, false)

## Матеріал із триплановою текстурою (для повернутих коробок, де UV не з сітки).
func _mat_tri(tex_name: String) -> StandardMaterial3D:
	var key := tex_name + "@tri"
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = mat(tex_name).duplicate()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / T
	_mats[key] = m
	return m

func _rot_box(root: Node3D, pos: Vector3, size: Vector3, yaw: float, tex: String, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat_tri(tex)
	mi.position = pos
	mi.rotation.y = yaw
	root.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		body.position = pos
		body.rotation.y = yaw
		root.add_child(body)

## Шматок круглої руїни: "ring": [cx, cz, r] у клітинках. Сегмент стоїть
## на справжньому колі (не на сітці) і повернутий по дотичній; arch — арка-прохід.
func _ring_piece(root: Node3D, cp: Vector3, arch: bool) -> void:
	var rg: Array = level.get("ring", [w * 0.5, h * 0.5, 5.0])
	var c := Vector3(float(rg[0]) * T, cp.y, float(rg[1]) * T)
	var d := Vector3(cp.x - c.x, 0, cp.z - c.z).normalized()
	var r := float(rg[2]) * T
	var pos := c + d * r
	var yaw := atan2(d.x, d.z)
	var seg := T * 1.25          # трохи довше за клітинку, щоб сусідні сегменти змикалися
	var tex: String = level.get("ring_tex", level.wall)
	if arch:
		var ah := rng.randf_range(4.2, 5.5)
		for sgn: float in [-1.0, 1.0]:
			var side: Vector3 = Vector3(d.z, 0, -d.x) * (seg * 0.5 - 0.3) * sgn
			_rot_box(root, pos + side + Vector3(0, ah * 0.5, 0), Vector3(0.6, ah, 1.0), yaw, tex)
		_rot_box(root, pos + Vector3(0, ah - 0.45, 0), Vector3(seg + 0.1, 0.9, 1.0), yaw, tex, false)
	else:
		var hgt := rng.randf_range(1.6, 6.5)     # обвалені мури різної висоти
		_rot_box(root, pos + Vector3(0, hgt * 0.5, 0), Vector3(seg + 0.15, hgt, 1.0), yaw, tex)
		if hgt > 4.0 and rng.randf() < 0.5:      # віконний отвір угорі
			_rot_box(root, pos + Vector3(0, hgt + 0.6, 0), Vector3(0.5, 1.2, 1.0), yaw, tex, false)

func _wall_dir(x: int, z: int) -> Vector2i:
	for d in DIRS:
		if ch(x + d.x, z + d.y) in WALLS:
			return d
	return Vector2i(0, -1)

## Чи поруч (включно з діагоналями) є прохідна клітинка. Глибину лісу чи
## заростей гравець не досягне — там не потрібні колізія й зайві спрайти.
func _near_walk(x: int, z: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dz != 0) and walkable(x + dx, z + dz):
				return true
	return false

func _tree(root: Node3D, pos: Vector3, near := true) -> void:
	var height := rng.randf_range(7.0, 12.0)
	var r := rng.randf_range(0.22, 0.38)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.5
	cyl.bottom_radius = r * 1.2
	cyl.height = height
	cyl.radial_segments = 6
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat("bark")
	mi.position = pos + Vector3(0, height * 0.5, 0)
	mi.rotation = Vector3(rng.randf_range(-0.06, 0.06), rng.randf(), rng.randf_range(-0.06, 0.06))
	root.add_child(mi)
	if near:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r + 0.1
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		body.position = mi.position
		root.add_child(body)
	for i in (3 if near else 2):
		var s := sprite("branch", rng.randf_range(0.06, 0.1), false)
		s.modulate = Color(0.7, 0.7, 0.7)
		s.position = pos + Vector3(0, height * rng.randf_range(0.55, 0.85), 0)
		s.rotation.y = i * PI / 3.0 + rng.randf()
		root.add_child(s)

## Кам'яна статуя на постаменті з теплим підсвічуванням.
func _statue(root: Node3D, pos: Vector3) -> void:
	_pillar(root, pos, 0.55, 0.6, level.get("column_tex", level.wall))
	var s := ground_sprite("statue", 0.06, pos + Vector3(0, 0.6, 0))
	root.add_child(s)
	light(root, pos + Vector3(0, 0.4, 0), Color(1.0, 0.75, 0.45), 1.1, 4.0)

## Кругла кам'яна вежа з зубцями (напр. обабіч міської брами).
func _tower(root: Node3D, pos: Vector3) -> void:
	var tex: String = level.get("tower_tex", "castle")
	var height: float = level.get("tower_h", 16.0)
	var r := 1.8
	_pillar(root, pos, r, height, tex)
	# виступ-машикулі та зубці
	var ring_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r + 0.35
	cyl.bottom_radius = r + 0.1
	cyl.height = 0.8
	cyl.radial_segments = 12
	ring_m.mesh = cyl
	ring_m.material_override = mat(tex)
	ring_m.position = pos + Vector3(0, height - 0.4, 0)
	root.add_child(ring_m)
	for i in 8:
		var a := TAU * i / 8.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.8, 0.5)
		mi.mesh = bm
		mi.material_override = mat(tex)
		mi.position = pos + Vector3(cos(a) * (r + 0.2), height + 0.4, sin(a) * (r + 0.2))
		mi.rotation.y = -a
		root.add_child(mi)

func _pillar(root: Node3D, pos: Vector3, radius := 0.45, height := -1.0, tex := "") -> void:
	if height < 0:
		height = ceil_y - pos.y if not outdoor else float(level.get("pillar_h", rng.randf_range(1.5, 5.5)))
	if tex == "":
		tex = level.wall if level.floor != "marble" else "marble"
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.1
	cyl.height = height
	cyl.radial_segments = 8 if radius < 1.0 else 18
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = mat(tex)
	mi.position = pos + Vector3(0, height * 0.5, 0)
	root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius + 0.05
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.position = mi.position
	root.add_child(body)
