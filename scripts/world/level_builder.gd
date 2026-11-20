class_name LevelBuilder
extends RefCounted
## Будує 3D-локацію з текстової сітки LevelDB: підлогу, стіни, стелю, сходи,
## дерева, колони, декор і світло. Сутності (вороги, предмети) повертає списками.

const T := 2.0
const WALLS := "#SH"
const BLOCK := "#SHWTo"
const STAIRS := "^v<>"

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
	m.roughness = 1.0
	m.metallic_specular = 0.15
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex_name == "gate":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
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
	for z in h:
		for x in w:
			var c := ch(x, z)
			var x0 := x * T
			var z0 := z * T
			if c in WALLS:
				var tex := alt_tex if c in "SH" else wall_tex
				var top := ceil_y
				if outdoor:
					top = max_h + wall_h * (rng.randf_range(0.8, 1.5) if wall_tex == "rock" or wall_tex == "ruin" else 1.0)
				var faces := 16 if outdoor else 0
				for i in 4:
					if not ch(x + DIRS[i].x, z + DIRS[i].y) in WALLS:
						faces |= DIR_FACE[i]
				box(tex, Vector3(x0, -0.5, z0), Vector3(x0 + T, top, z0 + T), faces)
				continue
			var hh := hgt(x, z)
			if c in STAIRS:
				_stairs(x, z, floor_tex)
			else:
				quad(floor_tex, Vector3(x0, hh, z0), Vector3(x0 + T, hh, z0), Vector3(x0 + T, hh, z0 + T), Vector3(x0, hh, z0 + T), Vector3.UP)
				# бокові грані, якщо сусід нижче
				for i in 4:
					var d: Vector2i = DIRS[i]
					var nc := ch(x + d.x, z + d.y)
					if nc in WALLS:
						continue
					var nh := hgt(x + d.x, z + d.y)
					if nh < hh - 0.01:
						var mn := Vector3(x0, nh, z0)
						var mx := Vector3(x0 + T, hh, z0 + T)
						box(floor_tex if hh - nh < 1.5 else wall_tex, mn, mx, DIR_FACE[i])
			if not outdoor:
				quad("stone_dark" if wall_tex != "bonewall" else "bonewall", Vector3(x0, ceil_y, z0), Vector3(x0, ceil_y, z0 + T), Vector3(x0 + T, ceil_y, z0 + T), Vector3(x0 + T, ceil_y, z0), Vector3.DOWN, false)
			_tile_object(root, x, z, c)
	# зовнішня "земля" під рівнем, щоб у тумані не було порожнечі
	if outdoor:
		box(floor_tex, Vector3(-40, -0.6, -40), Vector3(w * T + 40, -0.5, h * T + 40), 16, false)
	_commit(root)

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
	# колона під сходами
	if hh > 0.01:
		box(tex, Vector3(x0, 0, z0), Vector3(x0 + T, hh, z0 + T), 15, false)
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
			_tree(root, cp + jitter * 0.5)
		"o":
			_pillar(root, cp)
		"W":
			var top := cp.y + rng.randf_range(0.7, 1.6)
			box(level.wall, Vector3(x * T, cp.y, z * T), Vector3(x * T + T, top, z * T + T), 63)
		"t":
			root.add_child(ground_sprite("tomb", 0.06, cp + jitter))
		"b":
			root.add_child(ground_sprite("bones", 0.05, cp + jitter))
		"x":
			root.add_child(ground_sprite("cross", 0.08, cp + jitter))
		"p":
			root.add_child(ground_sprite("skull_pike", 0.06, cp + jitter))
		"+":
			root.add_child(ground_sprite("candles", 0.045, cp + jitter))
			light(root, cp + jitter + Vector3(0, 0.6, 0), Color(1.0, 0.7, 0.4), 0.9, 4.5)
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
			if c in "wakmzZgBicGX":
				entities.append({"char": c, "pos": cp, "x": x, "z": z})

func _wall_dir(x: int, z: int) -> Vector2i:
	for d in DIRS:
		if ch(x + d.x, z + d.y) in WALLS:
			return d
	return Vector2i(0, -1)

func _tree(root: Node3D, pos: Vector3) -> void:
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
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r + 0.1
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	body.position = mi.position
	root.add_child(body)
	for i in 3:
		var s := sprite("branch", rng.randf_range(0.06, 0.1), false)
		s.modulate = Color(0.7, 0.7, 0.7)
		s.position = pos + Vector3(0, height * rng.randf_range(0.55, 0.85), 0)
		s.rotation.y = i * PI / 3.0 + rng.randf()
		root.add_child(s)

func _pillar(root: Node3D, pos: Vector3, radius := 0.45, height := -1.0, tex := "") -> void:
	if height < 0:
		height = ceil_y - pos.y if not outdoor else rng.randf_range(1.5, 5.5)
	if tex == "":
		tex = level.wall if level.floor != "marble" else "marble"
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.1
	cyl.height = height
	cyl.radial_segments = 8
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
