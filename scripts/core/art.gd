class_name Art
## Уся графіка гри генерується тут процедурно (піксель-арт), з кешем.
## Щоб замінити на власні малюнки — покладіть PNG у res://art/<name>.png,
## і він автоматично використається замість згенерованого.

static var _cache := {}

static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D = null
	var custom := "res://art/%s.png" % name
	if ResourceLoader.exists(custom):
		t = load(custom)
	else:
		var p: Px = _build(name)
		t = p.tex() if p else PlaceholderTexture2D.new()
	_cache[name] = t
	return t

static func C(hex: String) -> Color:
	return Color(hex)

static func _clear_ell(p: Px, cx: float, cy: float, rx: float, ry: float) -> void:
	for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
		for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
			var dx := (xx + 0.5 - cx) / rx
			var dy := (yy + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and xx >= 0 and yy >= 0 and xx < p.w and yy < p.h:
				p.img.set_pixel(xx, yy, Color(0, 0, 0, 0))

static func _tatter(p: Px, from_y: int, chance := 0.35) -> void:
	for y in range(from_y, p.h):
		for x in p.w:
			if p.rng.randf() < chance * float(y - from_y + 1) / float(p.h - from_y + 1) * 2.0:
				p.img.set_pixel(x, y, Color(0, 0, 0, 0))

static func _noise_fill(p: Px, cols: Array) -> void:
	for y in p.h:
		for x in p.w:
			p.img.set_pixel(x, y, cols[p.rng.randi() % cols.size()])

static func _build(n: String) -> Px:
	if n.begins_with("icon_"):
		return _icon(n.substr(5))
	match n:
		# ------------------------------------------------ поверхні (32x32)
		"grass": return _t_grass()
		"dirt": return _t_dirt()
		"stone": return _t_stone(C("#3b3936"), 1)
		"stone_dark": return _t_stone(C("#2a2a2e"), 2)
		"brick": return _t_brick(C("#3e2f2a"), C("#1a1311"))
		"ruin": return _t_ruin()
		"rock": return _t_rock()
		"bonewall": return _t_bonewall()
		"crypt_wall": return _t_crypt_wall(false, 21)
		"crypt_niche": return _t_crypt_wall(true, 22)
		"crypt_ceil": return _t_crypt_ceil()
		"wet_floor": return _t_wet_floor()
		"water": return _t_water()
		"cliff": return _t_cliff()
		"timber": return _t_timber()
		"masonry": return _t_masonry()
		"temple_wall": return _t_temple_wall()
		"gallery_wall": return _t_gallery_wall()
		"lab_wall": return _t_lab_wall()
		"stained_glass": return _t_stained_glass()
		"lab_floor": return _t_lab_floor()
		"railing": return _t_railing()
		"castle": return _t_castle()
		"wood": return _t_wood()
		"books": return _t_books()
		"carpet": return _t_carpet()
		"cobble": return _t_cobble()
		"plaster": return _t_plaster()
		"bark": return _t_bark()
		"gate": return _t_gate()
		"marble": return _t_marble()
		# ------------------------------------------------ шари ворогів (32x48)
		"skel_body": return _skel_body()
		"skel_armor": return _armor(C("#5b3b26"), C("#8a5a36"), C("#2e1d14"), C("#4a1616"), false)
		"armor_gold": return _armor(C("#7a5e22"), C("#c9a24a"), C("#3a2a10"), C("#2a1030"), true)
		"w_sword_shield": return _w_sword_shield()
		"w_bow": return _w_bow()
		"cape_back": return _cape(C("#23271f"), 8, 24, 4, 28)
		"hood": return _hood(C("#2c3124"))
		"robe": return _robe(C("#2a1416"), C("#5a2a1a"))
		"hood_cult": return _hood_cult()
		"w_dagger": return _w_dagger()
		"w_staff": return _w_staff()
		"zomb_body": return _zomb_body()
		"rags_grey": return _rags(C("#4a4740"))
		"rags_red": return _rags(C("#5a2420"))
		"rags_blue": return _rags(C("#2c3444"))
		"w_cleaver": return _w_cleaver()
		"ghost": return _ghost()
		"w_greatsword": return _w_greatsword()
		"prince_cape": return _cape(C("#5a0f14"), 6, 26, 1, 31)
		"prince_body": return _prince_body()
		"prince_crown": return _prince_crown()
		"w_rapier": return _w_rapier()
		# ------------------------------------------------ декорації
		"branch": return _branch()
		"grass_tuft": return _grass_tuft()
		"bones": return _bones()
		"tomb": return _tomb()
		"candles": return _candles()
		"cross": return _cross()
		"flame": return _flame()
		"chest": return _chest(false)
		"chest_open": return _chest(true)
		"exit": return _exit_door()
		"banner": return _banner()
		"skull_pike": return _skull_pike()
		"statue": return _statue()
		"crone": return _crone()
		"vat": return _vat()
		"throne": return _throne()
		"chalice": return _chalice()
		"chandelier": return _chandelier()
		"bench": return _bench()
		"cauldron": return _cauldron()
		"cross_a": return _cross_wood(0)
		"cross_c": return _cross_wood(1)
		"cross_sun": return _cross_sun()
		"shrine": return _shrine()
		"barrel": return _barrel()
		# ------------------------------------------------ ефекти
		"arrow": return _arrow()
		"fireball": return _fireball()
		"spark": return _spark()
		"glow": return _glow()
		# ------------------------------------------------ вид від першої особи
		"vm_sword": return _vm_sword()
		"vm_shield": return _vm_shield()
		"vm_bow": return _vm_bow(false)
		"vm_bow_drawn": return _vm_bow(true)
		"vm_dagger": return _vm_dagger()
		"vm_staff": return _vm_staff()
		"vm_hand": return _vm_hand()
		# ------------------------------------------------ карти таро (72x112)
		"card_knight": return _card_knight()
		"card_archer": return _card_archer()
		"card_beggar": return _card_beggar()
		"card_back": return _card_back()
	return null

# =================================================================== ПОВЕРХНІ

static func _t_grass() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 11)
	_noise_fill(p, [C("#1a2113"), C("#232b18"), C("#1e2515"), C("#151a10"), C("#2b2a1d")])
	for i in 26:
		var x := p.rng.randi() % 32
		var y := p.rng.randi() % 32
		p.p(x, y, C("#3a4426"))
		p.p(x, (y + 1) % 32, C("#2c3520"))
	for i in 6:
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C("#4b3b2a"))
	return p

static func _t_dirt() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 12)
	_noise_fill(p, [C("#2a2119"), C("#31271d"), C("#241c15"), C("#3a2f23")])
	for i in 10:
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C("#4e4436"))
	return p

static func _t_stone(base: Color, seed_v: int) -> Px:
	var p := Px.new(32, 32, base, seed_v)
	p.grime(0.05, 0.6)
	var gap := base.darkened(0.6)
	for row in 2:
		var y := row * 16
		p.rect(0, y, 32, 1, gap)
		var off := 0 if row == 0 else 8
		p.rect(off, y, 1, 16, gap)
		p.rect((off + 16) % 32, y, 1, 16, gap)
	for i in 3:
		var x := p.rng.randi() % 32
		var y := p.rng.randi() % 32
		p.line(x, y, x + p.rng.randi_range(-4, 4), y + p.rng.randi_range(2, 6), gap)
	for y in 32:
		for x in 32:
			if p.get_c(x, y) == gap and p.get_c(x + 1, y + 1) != gap:
				p.p(x + 1, y + 1, base.lightened(0.08))
	return p

static func _t_brick(base: Color, mortar: Color) -> Px:
	var p := Px.new(32, 32, mortar, 3)
	for row in 4:
		var off := 0 if row % 2 == 0 else 8
		for col in 3:
			var x := off + col * 16 - 8
			var c := base.lightened(p.rng.randf_range(-0.08, 0.08))
			p.rect(x + 1, row * 8 + 1, 15, 7, c)
			p.rect(x + 1, row * 8 + 1, 15, 1, c.lightened(0.1))
	p.grime(0.06, 0.5)
	return p

static func _t_ruin() -> Px:
	var p := Px.new(32, 32, C("#16140f"), 5)
	for row in 3:
		var off := (row * 11) % 16
		for col in 3:
			var x := off + col * 16 - 16
			var c := C("#4a4a40").lightened(p.rng.randf_range(-0.1, 0.05))
			p.rect(x + 1, row * 11 + 1, 15, 10, c)
	p.grime(0.08, 0.6)
	for i in 70:
		var x := p.rng.randi() % 32
		var y := p.rng.randi() % 32
		if p.rng.randf() < 0.6 or y > 20:
			p.p(x, y, C("#2e3a1f"))
	return p

static func _t_rock() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 7)
	var bands := [C("#3a3229"), C("#2d2720"), C("#45392c"), C("#332b23"), C("#29231d")]
	for y in 32:
		var b: Color = bands[(y / 5 + int(sin(y * 0.7) * 1.5)) % bands.size()]
		for x in 32:
			p.img.set_pixel(x, y, b.lightened(p.rng.randf_range(-0.05, 0.05)))
	for i in 5:
		var y := p.rng.randi() % 32
		p.line(0, y, 31, y + p.rng.randi_range(-2, 2), C("#17130f"))
	return p

static func _t_bonewall() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 9)
	_noise_fill(p, [C("#1c1712"), C("#211b15"), C("#17130f")])
	var bone := C("#a89c80")
	for gy in 2:
		for gx in 2:
			var cx := gx * 16 + 8 + (4 if gy == 1 else 0)
			var cy := gy * 16 + 7
			cx = cx % 32
			p.ell(cx, cy, 4, 4, bone)
			p.rect(cx - 2, cy + 2, 5, 3, bone)
			p.rect(cx - 3, cy - 1, 2, 2, C("#0a0807"))
			p.rect(cx + 1, cy - 1, 2, 2, C("#0a0807"))
			p.p(cx, cy + 2, C("#0a0807"))
			p.p(cx - 1, cy + 4, C("#0a0807"))
			p.p(cx + 1, cy + 4, C("#0a0807"))
	for i in 6:
		var x := p.rng.randi() % 32
		var y := p.rng.randi() % 32
		p.line(x, y, x + 6, y + p.rng.randi_range(-1, 1), bone.darkened(0.3))
	p.grime(0.08, 0.4)
	return p

static func _t_castle() -> Px:
	var p := Px.new(32, 32, C("#121218"), 13)
	for row in 2:
		var off := 0 if row == 0 else 16
		for col in 2:
			var x := off + col * 32 - 16
			p.rect(x + 1, row * 16 + 1, 31, 15, C("#2c2c36").lightened(p.rng.randf_range(-0.06, 0.06)))
			p.rect(x + 1, row * 16 + 1, 31, 1, C("#3a3a46"))
	p.grime(0.05, 0.6)
	return p

static func _t_wood() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 14)
	for col in 4:
		var c := C("#3b2616").lightened(p.rng.randf_range(-0.06, 0.06))
		p.rect(col * 8, 0, 8, 32, c)
		p.rect(col * 8, 0, 1, 32, C("#1a0f08"))
		for i in 4:
			var x := col * 8 + 2 + p.rng.randi() % 5
			var y := p.rng.randi() % 32
			p.line(x, y, x, y + 6, c.darkened(0.25))
	return p

static func _t_books() -> Px:
	var p := Px.new(32, 32, C("#120a06"), 15)
	var cols := [C("#5a1e1a"), C("#2a3a22"), C("#3a2a18"), C("#22263a"), C("#4a3a20"), C("#2a1a2a")]
	for shelf in 4:
		var y0 := shelf * 8
		p.rect(0, y0 + 7, 32, 1, C("#3b2616"))
		var x := 0
		while x < 32:
			var bw := p.rng.randi_range(1, 3)
			var bh := p.rng.randi_range(4, 7)
			var c: Color = cols[p.rng.randi() % cols.size()]
			p.rect(x, y0 + 7 - bh, bw, bh, c)
			if bh > 5:
				p.p(x, y0 + 7 - bh + 2, C("#a08040"))
			x += bw
			if p.rng.randf() < 0.1:
				x += 1
	return p

static func _t_carpet() -> Px:
	var p := Px.new(32, 32, C("#4a0c10"), 16)
	p.grime(0.04, 0.6)
	for y in 32:
		for x in 32:
			var d: int = abs((x % 16) - 8) + abs((y % 16) - 8)
			if d == 6:
				p.p(x, y, C("#8a6a2a"))
			elif d == 2:
				p.p(x, y, C("#2a0608"))
	return p

static func _t_cobble() -> Px:
	var p := Px.new(32, 32, C("#141210"), 17)
	for i in 22:
		var cx := p.rng.randf() * 32
		var cy := p.rng.randf() * 32
		var c := C("#3a3631").lightened(p.rng.randf_range(-0.1, 0.06))
		for ox in [-32, 0, 32]:
			for oy in [-32, 0, 32]:
				p.ell(cx + ox, cy + oy, 3.5, 3, c)
	p.grime(0.05, 0.4)
	return p

static func _t_plaster() -> Px:
	var p := Px.new(32, 32, C("#6a6050"), 18)
	p.grime(0.08, 0.7)
	var beam := C("#24170e")
	p.rect(0, 0, 32, 3, beam)
	p.rect(0, 29, 32, 3, beam)
	p.rect(0, 0, 3, 32, beam)
	p.line(3, 28, 28, 3, beam, 2)
	for i in 20:
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C("#3a3020"))
	return p

static func _t_bark() -> Px:
	var p := Px.new(16, 32, C("#1d1611"), 19)
	for i in 14:
		var x := p.rng.randi() % 16
		var y := p.rng.randi() % 32
		p.line(x, y, x, y + p.rng.randi_range(4, 12), C("#0e0a08"))
		p.p(x + 1, y + 2, C("#2c2219"))
	return p

# ---- затоплені крипти (Катакомби)

const MOSS := ["#24381f", "#2d4527", "#3b5a30"]

## Мокрий камінь з мохом; niche=true — поховальна ніша з черепом і кістками.
static func _t_crypt_wall(niche: bool, seed_v: int) -> Px:
	var p := Px.new(32, 32, C("#0c110f"), seed_v)
	var cols := [C("#2b322e"), C("#303733"), C("#262d29"), C("#343b36"), C("#29302b")]
	var y := 0
	var row := 0
	for rh in [8, 7, 9, 8]:
		var x := -((row * 5) % 9)
		while x < 32:
			var sw := p.rng.randi_range(7, 13)
			var c: Color = cols[p.rng.randi() % cols.size()].lightened(p.rng.randf_range(-0.04, 0.04))
			p.rect(x + 1, y + 1, sw - 1, rh - 1, c)
			p.rect(x + 1, y + 1, sw - 1, 1, c.lightened(0.12))      # вологий відблиск зверху
			p.rect(x + 1, y + rh - 1, sw - 1, 1, c.darkened(0.25))
			x += sw
		y += rh
		row += 1
	p.grime(0.05, 0.5)
	if niche:
		var nc := C("#050706")
		p.rect(8, 13, 16, 13, nc)
		p.ell(16, 13, 8, 5, nc)
		p.rect(7, 26, 18, 2, C("#3a423d"))                          # кам'яна полиця
		var bone := C("#8a8a72")
		p.ell(13, 22, 3, 3, bone)                                     # череп
		p.rect(11, 23, 5, 2, bone)
		p.p(12, 22, nc); p.p(14, 22, nc); p.p(13, 24, nc)
		p.line(17, 25, 23, 24, bone.darkened(0.2))                   # кістки
		p.line(18, 23, 22, 25, bone.darkened(0.35))
		p.rect(9, 25, 3, 1, bone.darkened(0.3))
		for i in 6:                                                  # павутина й мох по краях ніші
			p.p(8 + p.rng.randi() % 16, 9 + p.rng.randi() % 3, C(MOSS[p.rng.randi() % 3]))
	# потьоки води
	for i in 4:
		var sx := p.rng.randi() % 32
		var ln := p.rng.randi_range(6, 18)
		var sy := p.rng.randi() % 14
		for k in ln:
			p.p(sx, sy + k, Color(0.02, 0.05, 0.05, 0.45))
		p.p(sx, sy + ln, C("#6a7c78"))
	# мох: густіше внизу
	for i in 120:
		var mx := p.rng.randi() % 32
		var my := p.rng.randi() % 32
		if p.rng.randf() < 0.25 + 0.75 * float(my) / 32.0:
			p.p(mx, my, C(MOSS[p.rng.randi() % 3]))
	return p

static func _t_crypt_ceil() -> Px:
	var p := _t_crypt_wall(false, 23)
	p.shade_side(0.5)
	for i in 8:                                                      # краплі, що збираються на стелі
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C("#5f716d"))
	return p

static func _t_wet_floor() -> Px:
	var p := Px.new(32, 32, C("#0d1211"), 24)
	for gy in 2:
		for gx in 2:
			var off := 4 if gy == 1 else 0
			var c := C("#1f2624").lightened(p.rng.randf_range(-0.04, 0.05))
			p.rect((gx * 16 + off) % 32 + 1, gy * 16 + 1, 15, 15, c)
	p.grime(0.05, 0.5)
	for i in 5:                                                      # калюжі з відблиском
		var cx := p.rng.randi() % 32
		var cy := p.rng.randi() % 32
		p.ell(cx, cy, p.rng.randi_range(2, 4), p.rng.randi_range(1, 2), C("#2c3836"))
		p.p(cx, cy, C("#4d5f5b"))
	for i in 30:
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C(MOSS[p.rng.randi() % 2]))
	return p

## Мілка темна вода з брижами (напівпрозора).
static func _t_water() -> Px:
	var p := Px.new(32, 32, Color(0.05, 0.12, 0.11, 0.62), 25)
	for y in 32:
		for x in 32:
			var k := 0.5 + 0.5 * sin(x * 0.4 + sin(y * 0.3) * 2.0)
			p.img.set_pixel(x, y, Color(0.08 + 0.04 * k, 0.19 + 0.06 * k, 0.18 + 0.06 * k, 0.55 + 0.1 * k))
	for i in 12:                                                     # світлі брижі
		var cx := p.rng.randi() % 32
		var cy := p.rng.randi() % 32
		var r := p.rng.randi_range(2, 5)
		for a in 10:
			var ang := -0.6 + a * 0.12
			p.p(cx + int(cos(ang) * r), cy + int(sin(ang) * r * 0.5), Color(0.55, 0.75, 0.72, 0.8))
	return p

## Висока моховита скеля ущелини: вертикальні тріщини, уступи, мох на виступах.
static func _t_cliff() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 26)
	for y in 32:
		for x in 32:
			var n := sin(x * 0.55 + sin(y * 0.21) * 2.3) * 0.5 + sin(y * 0.9 + x * 0.13) * 0.25
			var c := C("#2a312e").lerp(C("#3b4440"), 0.5 + 0.5 * n)
			p.img.set_pixel(x, y, c.lightened(p.rng.randf_range(-0.04, 0.04)))
	for i in 5:                                                      # вертикальні тріщини
		var x := p.rng.randi() % 32
		var y := p.rng.randi() % 32
		for k in p.rng.randi_range(8, 20):
			x = (x + p.rng.randi_range(-1, 1) + 32) % 32
			p.p(x, (y + k) % 32, C("#121614"))
			p.p((x + 1) % 32, (y + k) % 32, C("#48524d"))
	for i in 4:                                                      # уступи з мохом зверху
		var y := p.rng.randi() % 32
		var x0 := p.rng.randi() % 32
		var ln := p.rng.randi_range(6, 14)
		for k in ln:
			var xx := (x0 + k) % 32
			p.p(xx, (y + 1) % 32, C("#161b18"))
			p.p(xx, y, C(MOSS[1 + p.rng.randi() % 2]))
			if p.rng.randf() < 0.5:
				p.p(xx, (y - 1 + 32) % 32, C(MOSS[2]))
	for i in 90:                                                     # плями моху
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C(MOSS[p.rng.randi() % 3]))
	return p

# ---- Мертве місто: фахверк, кладка, храм

## Фахверкова стіна: тинькування й темні балки, віконце з ґраткою.
static func _t_timber() -> Px:
	var p := Px.new(32, 32, C("#6f6656"), 27)
	p.grime(0.06, 0.7)
	for i in 40:                                                     # облуплений тиньк
		p.p(p.rng.randi() % 32, p.rng.randi() % 32, C("#4c463c"))
	var wood := C("#2a1d14")
	p.rect(0, 30, 32, 2, wood)                                       # балка перекриття (раз на поверх)
	p.rect(0, 0, 2, 30, wood)                                        # стояк
	p.line(2, 29, 11, 18, wood, 1)                                   # розкіс
	p.rect(19, 9, 7, 9, C("#14100c"))                                # вікно
	p.rect(22, 9, 1, 9, wood); p.rect(19, 13, 7, 1, wood)
	p.rect(18, 18, 9, 1, C("#3a2a1c"))                               # підвіконня
	p.rect(20, 10, 2, 2, C("#3a3424"))                               # тьмяний відблиск у шибці
	return p

## Велика кладка міських мурів: теплий сірий камінь, мох на верхніх гранях.
static func _t_masonry() -> Px:
	var p := Px.new(32, 32, C("#1d1b17"), 28)
	var cols := [C("#5a564c"), C("#4f4b42"), C("#615c51"), C("#56524a")]
	for row in 4:
		var off := (row % 2) * 8
		for col in 3:
			var x := off + col * 16 - 8
			var c: Color = cols[p.rng.randi() % cols.size()].lightened(p.rng.randf_range(-0.05, 0.03))
			p.rect(x + 1, row * 8 + 1, 15, 7, c)
			p.rect(x + 1, row * 8 + 1, 15, 1, c.lightened(0.12))
			p.rect(x + 1, row * 8 + 7, 15, 1, c.darkened(0.2))
			for k in 4:
				p.p(x + 1 + p.rng.randi() % 15, row * 8 + 1, C(MOSS[p.rng.randi() % 3]))
	p.grime(0.06, 0.5)
	return p

## Стіна храму: дрібна тепла цегла й арочна ніша з різьбленою рамкою.
static func _t_temple_wall() -> Px:
	var p := Px.new(32, 32, C("#2a2016"), 29)
	for row in 8:
		var off := (row % 2) * 3
		for col in 6:
			var x := off + col * 6 - 3
			p.rect(x + 1, row * 4 + 1, 5, 3, C("#6a5236").lightened(p.rng.randf_range(-0.08, 0.06)))
	p.grime(0.05, 0.5)
	var frame := C("#3a2c1c")
	p.rect(7, 9, 18, 21, frame)
	p.ell(16, 10, 9, 6, frame)
	p.rect(9, 11, 14, 19, C("#8a6c44"))                              # освітлена глибина ніші
	p.ell(16, 11, 7, 5, C("#8a6c44"))
	for y in range(11, 30):                                          # світло знизу, тінь угорі
		for x in range(9, 23):
			var c := p.get_c(x, y)
			if c == C("#8a6c44"):
				p.p(x, y, c.darkened(0.45 * (1.0 - float(y - 6) / 24.0)))
	for k in range(9, 30, 2):                                        # різьблення рамки
		p.p(8, k, C("#5a4630")); p.p(23, k, C("#5a4630"))
	p.rect(7, 29, 18, 2, C("#4a3a26"))
	return p

## Кам'яна статуя: постать у мантії з високим шоломом і посохом-свічником.
static func _statue() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 30)
	var st := C("#8c877a")
	var dk := C("#5c584e")
	p.poly(PackedVector2Array([Vector2(10, 18), Vector2(22, 18), Vector2(25, 47), Vector2(7, 47)]), st)   # мантія
	p.rect(12, 18, 8, 6, st)
	p.ell(16, 13, 4, 5, st)                                          # голова
	p.poly(PackedVector2Array([Vector2(12, 11), Vector2(20, 11), Vector2(16, 2)]), st)                    # шолом
	p.line(16, 2, 17, 0, dk)
	p.rect(14, 13, 4, 2, dk)                                         # затінене обличчя
	for x in [11, 14, 18, 21]:                                       # складки
		p.line(x, 24, x - 1 if x < 16 else x + 1, 46, dk)
	p.line(6, 10, 6, 47, C("#4a3a26"))                              # посох
	p.ell(6, 9, 1.5, 1.5, C("#ffd27a"))                             # вогник
	p.rect(6, 20, 5, 2, st)                                          # рука
	p.shade_side(0.35)
	p.outline(C("#24221d"))
	return p

static func _barrel() -> Px:
	var p := Px.new(16, 20, Color(0, 0, 0, 0), 31)
	p.ell(8, 10, 7, 9.5, C("#4a3220"))
	for y in 20:
		for x in 16:
			if p.get_c(x, y).a > 0.5 and x % 3 == 0:
				p.p(x, y, C("#3a2616"))
	p.rect(1, 4, 14, 2, C("#2a2a2a")); p.rect(1, 14, 14, 2, C("#2a2a2a"))
	p.shade_side(0.3)
	p.outline()
	return p

## Ярус аркової галереї: колони, темна арка з теплим ліхтарем, балюстрада й карниз.
## Повторюється кожні 2 м по висоті — високі стіни стають багатоярусними.
static func _t_gallery_wall() -> Px:
	var p := Px.new(32, 32, C("#4a4a52"), 32)
	p.grime(0.05, 0.6)
	var dark := C("#0e0d10")
	p.rect(6, 7, 20, 18, dark)                                       # арка
	p.ell(16, 8, 10, 6, dark)
	p.rect(8, 9, 16, 16, C("#1c1612"))                              # глибина галереї
	p.ell(16, 10, 8, 5, C("#1c1612"))
	p.rect(14, 12, 4, 5, C("#e0a850"))                               # ліхтар
	p.rect(15, 13, 2, 3, C("#fff0c0"))
	p.rect(15, 10, 2, 2, C("#3a2a1a"))
	for x in [1, 2, 3, 28, 29, 30]:                                   # колони
		p.rect(x, 4, 1, 22, C("#55555c"))
	p.rect(0, 4, 5, 2, C("#62626a")); p.rect(27, 4, 5, 2, C("#62626a"))   # капітелі
	p.rect(0, 25, 32, 1, C("#1a1a1e"))                               # балюстрада
	for x in range(1, 32, 3):
		p.rect(x, 26, 1, 3, C("#2a2a30"))
	p.rect(0, 29, 32, 3, C("#4a4a52"))                               # карниз з орнаментом
	for x in range(0, 32, 4):
		p.p(x + 1, 30, C("#2a2a30")); p.p(x + 2, 31, C("#2a2a30"))
	p.rect(0, 0, 32, 2, C("#2c2c33"))
	return p

# ---- лабораторія алхіміка

const FLASKS := ["#6fe08a", "#e0a850", "#9a6ad8", "#5ac8d8", "#d85a4a"]

## Ярус лабораторії: зеленкуватий камінь, ніша з полицею колб, мідні труби, балюстрада.
static func _t_lab_wall() -> Px:
	var p := Px.new(32, 32, C("#2c3532"), 34)
	p.grime(0.05, 0.6)
	var dark := C("#0b0f0d")
	p.rect(6, 8, 20, 16, dark)                                       # ніша
	p.ell(16, 9, 10, 5, dark)
	for shelf in [15, 22]:                                           # дві полиці з колбами
		p.rect(7, shelf, 18, 1, C("#4a3624"))
		var x := 8
		while x < 24:
			var col := C(FLASKS[p.rng.randi() % FLASKS.size()])
			var fh := p.rng.randi_range(2, 4)
			p.rect(x, shelf - fh, 2, fh, col)
			p.p(x, shelf - fh, col.lightened(0.4))
			p.p(x, shelf - fh - 1, C("#8a9a96"))                    # шийка колби
			x += p.rng.randi_range(3, 4)
	p.rect(0, 3, 32, 2, C("#9a5e30")); p.rect(0, 3, 32, 1, C("#d08a50"))   # мідна труба
	for x in range(2, 32, 8):
		p.rect(x, 2, 2, 4, C("#6a4020"))                             # хомути
	p.rect(1, 5, 2, 20, C("#7a4a26")); p.rect(1, 5, 1, 20, C("#b0703a"))  # вертикальна труба
	p.rect(0, 25, 32, 1, C("#141a18"))                               # балюстрада
	for x in range(1, 32, 3):
		p.rect(x, 26, 1, 3, C("#202a26"))
	p.rect(0, 29, 32, 3, C("#3c4844"))
	return p

## Шахова плитка лабораторії з плямами реактивів.
static func _t_lab_floor() -> Px:
	var p := Px.new(32, 32, Color.BLACK, 35)
	for gy in 2:
		for gx in 2:
			var c := C("#26302c") if (gx + gy) % 2 == 0 else C("#3a4640")
			p.rect(gx * 16, gy * 16, 16, 16, c)
	p.grime(0.05, 0.6)
	for i in 3:                                                      # плями
		p.ell(p.rng.randi() % 32, p.rng.randi() % 32, 2.5, 1.5, Color(0.3, 0.7, 0.35, 0.35))
	p.rect(0, 0, 32, 1, C("#141a18")); p.rect(0, 16, 32, 1, C("#141a18"))
	p.rect(0, 0, 1, 32, C("#141a18")); p.rect(16, 0, 1, 32, C("#141a18"))
	return p

## Скляний чан із зеленою рідиною, бульбашками й темною постаттю всередині.
static func _vat() -> Px:
	var p := Px.new(24, 48, Color(0, 0, 0, 0), 36)
	var metal := C("#4a4a52")
	p.rect(2, 2, 20, 4, metal); p.rect(2, 2, 20, 1, C("#7a7a84"))   # кришка
	p.rect(1, 42, 22, 6, metal); p.rect(1, 42, 22, 1, C("#7a7a84"))  # основа
	p.rect(3, 6, 18, 36, Color(0.15, 0.45, 0.25, 0.85))             # рідина
	p.rect(3, 6, 18, 4, Color(0.4, 0.8, 0.5, 0.9))                  # світліший верх
	p.ell(12, 26, 4, 7, Color(0.05, 0.12, 0.08, 0.9))                # гомункул
	p.ell(12, 18, 2.5, 2.5, Color(0.05, 0.12, 0.08, 0.9))
	for i in 9:                                                      # бульбашки
		p.p(5 + p.rng.randi() % 14, 10 + p.rng.randi() % 30, Color(0.7, 1.0, 0.75, 0.9))
	p.rect(3, 6, 1, 36, Color(0.8, 1.0, 0.9, 0.6))                  # відблиск скла
	p.rect(20, 6, 1, 36, Color(0.1, 0.2, 0.15, 0.9))
	p.rect(0, 14, 24, 1, metal); p.rect(0, 30, 24, 1, metal)         # обручі
	p.outline(C("#101414"))
	return p

## Алхімічний стіл: реторта, колби, перегінний куб із трубкою.
static func _bench() -> Px:
	var p := Px.new(32, 24, Color(0, 0, 0, 0), 37)
	var wood := C("#4a3220")
	p.rect(1, 13, 30, 3, wood); p.rect(1, 13, 30, 1, C("#6a4a30"))
	p.rect(3, 16, 2, 8, wood); p.rect(27, 16, 2, 8, wood)
	p.ell(8, 9, 4, 4, Color(0.6, 0.85, 0.5, 0.85))                  # реторта
	p.line(11, 6, 18, 3, C("#8a9a96"))                               # трубка
	p.rect(17, 3, 2, 6, C("#8a9a96"))
	p.ell(18, 10, 3, 3, Color(0.85, 0.6, 0.3, 0.85))                # колба з бурштином
	for i in 3:
		var x := 23 + i * 2
		p.rect(x, 9 - i, 1, 4 + i, C(FLASKS[(i + 2) % FLASKS.size()]))
	p.rect(6, 12, 5, 1, C("#e0661e"))                                # пальник
	p.outline(C("#120d0b"))
	return p

## Котел, у якому щось булькотить.
static func _cauldron() -> Px:
	var p := Px.new(24, 20, Color(0, 0, 0, 0), 38)
	p.ell(12, 12, 10, 7, C("#1c1c20"))
	p.ell(12, 7, 9, 2.5, C("#5ad070"))
	for i in 5:
		p.circ(5 + p.rng.randi() % 14, 6 + p.rng.randi() % 2, 1.2, C("#a8f0b0"))
	p.rect(3, 6, 18, 1, C("#3a3a40"))
	p.rect(5, 18, 2, 2, C("#1c1c20")); p.rect(17, 18, 2, 2, C("#1c1c20"))
	p.outline(C("#080808"))
	return p

# ---- тронна зала

## Вітраж: стрілчасте вікно з кольоровим склом і свинцевими перетинками.
## Повторюється по висоті — стовпці вітражів на всю стіну.
static func _t_stained_glass() -> Px:
	var p := Px.new(32, 32, C("#2a2228"), 39)
	p.grime(0.05, 0.6)
	var glass := [C("#8a1c24"), C("#24408a"), C("#c8962c"), C("#5a2a7a"), C("#2a6a4a")]
	var lead := C("#0c0a0c")
	p.rect(8, 2, 16, 30, lead)
	p.ell(16, 4, 8, 4, lead)
	for y in range(3, 32, 3):                                        # шибки
		for x in range(9, 23, 3):
			p.rect(x, y, 2, 2, glass[(x / 3 + y / 3 + p.rng.randi() % 2) % glass.size()].lightened(0.15))
	p.ell(16, 12, 4, 4, C("#e8c060"))                                 # «троянда» посередині
	p.ring(16, 12, 4, 1, lead)
	p.rect(15, 2, 2, 30, lead)                                        # середник
	p.rect(6, 0, 2, 32, C("#3a3238")); p.rect(24, 0, 2, 32, C("#3a3238"))   # колонки рами
	return p

## Високий готичний трон: темне дерево, золото, червона подушка.
static func _throne() -> Px:
	var p := Px.new(32, 56, Color(0, 0, 0, 0), 40)
	var wood := C("#2a1418")
	var gold := C("#b08a3a")
	p.rect(6, 4, 20, 34, wood)                                        # спинка
	p.poly(PackedVector2Array([Vector2(6, 4), Vector2(16, -2), Vector2(26, 4)]), wood)
	for x in [6, 25]:                                                 # шпилі
		p.rect(x, 0, 1, 10, gold)
	p.ell(16, 12, 5, 6, C("#5a0c14"))                                 # оксамит спинки
	p.ring(16, 12, 5, 1, gold)
	p.rect(2, 30, 28, 6, wood); p.rect(2, 30, 28, 1, gold)            # сидіння й підлокітники
	p.rect(6, 32, 20, 3, C("#7a1018"))                                # подушка
	p.rect(4, 36, 4, 18, wood); p.rect(24, 36, 4, 18, wood)           # ніжки
	p.rect(2, 52, 28, 4, C("#1a0c10"))
	p.ell(4, 30, 2, 2, gold); p.ell(28, 30, 2, 2, gold)
	p.shade_side(0.3)
	p.outline(C("#080406"))
	return p

## Розбита чаша алхіміка на пюпітрі (та, з якої принц «випив світанок»).
static func _chalice() -> Px:
	var p := Px.new(16, 24, Color(0, 0, 0, 0), 41)
	var gold := C("#c8a040")
	p.poly(PackedVector2Array([Vector2(3, 2), Vector2(13, 2), Vector2(10, 9), Vector2(6, 9)]), gold)
	p.line(3, 2, 6, 5, Color(0, 0, 0, 0))                              # скол
	p.rect(4, 3, 8, 2, C("#3a0a10"))                                  # залишки темного вина
	p.rect(7, 9, 2, 6, gold)
	p.rect(4, 14, 8, 2, gold)
	p.rect(5, 16, 6, 8, C("#3a3238")); p.rect(5, 16, 6, 1, C("#5a525a"))   # пюпітр
	p.p(4, 2, C("#fff0c0"))
	p.outline(C("#080406"))
	return p

## Люстра-обруч зі свічками на ланцюгах.
static func _chandelier() -> Px:
	var p := Px.new(32, 24, Color(0, 0, 0, 0), 42)
	var iron := C("#2a2426")
	p.line(16, 0, 4, 14, iron); p.line(16, 0, 28, 14, iron); p.line(16, 0, 16, 14, iron)
	p.rect(2, 14, 28, 3, iron)
	for x in range(3, 30, 5):
		p.rect(x, 10, 2, 4, C("#e8dcc0"))
		p.rect(x, 8, 2, 2, C("#ffb84a"))
	p.rect(14, 17, 4, 5, iron)
	p.outline(C("#080406"))
	return p

## Кована балюстрада (прозора між прутами).
static func _t_railing() -> Px:
	var p := Px.new(32, 32, Color(0, 0, 0, 0), 33)
	var iron := C("#242226")
	p.rect(0, 0, 32, 3, C("#3a3236"))                                # поручень
	p.rect(0, 29, 32, 3, iron)
	for x in range(1, 32, 4):
		p.rect(x, 3, 1, 26, iron)
		p.ring(x + 2, 16, 2, 1, iron)                                 # завитки
	return p

static func _t_gate() -> Px:
	var p := Px.new(32, 32, Color(0, 0, 0, 0), 20)
	var iron := C("#2e2b2a")
	for i in 4:
		p.rect(i * 8 + 3, 0, 2, 32, iron)
		p.p(i * 8 + 3, p.rng.randi() % 32, C("#5a3a22"))
	p.rect(0, 6, 32, 2, iron)
	p.rect(0, 24, 32, 2, iron)
	return p

static func _t_marble() -> Px:
	var p := Px.new(32, 32, C("#57534e"), 21)
	p.grime(0.04, 0.7)
	for i in 4:
		var x := p.rng.randi() % 32
		p.line(x, 0, x + p.rng.randi_range(-8, 8), 31, C("#6e6a63"))
	p.rect(0, 0, 32, 1, C("#2a2826"))
	p.rect(0, 0, 1, 32, C("#2a2826"))
	return p

# =================================================================== ВОРОГИ

static func _skel_body() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 30)
	var B := C("#cfc5a8")
	var S := C("#8f8670")
	var K := C("#140c0a")
	p.ell(16, 7, 5.5, 6, B)
	p.rect(12, 11, 8, 3, B)
	p.rect(11, 9, 1, 3, S)
	p.rect(12, 6, 3, 3, K)
	p.p(13, 7, C("#d0402a"))
	p.p(15, 10, K)
	p.p(12, 13, K)
	p.p(14, 13, K)
	p.rect(15, 14, 1, 2, S)
	p.line(9, 16, 15, 16, B)
	p.rect(15, 17, 1, 14, S)
	for i in 5:
		var y := 18 + i * 2
		var l := 6.0 - i * 0.7
		p.line(15 - l, y + 1, 14, y, B)
	p.ell(16, 31, 5, 2.2, B)
	p.rect(14, 31, 2, 1, K)
	p.line(9, 16, 7, 24, B, 2)
	p.line(7, 24, 6, 31, B)
	p.line(8, 24, 7, 31, S)
	p.rect(5, 31, 3, 2, B)
	p.line(13, 33, 12, 40, B, 2)
	p.line(12, 40, 12, 46, B)
	p.line(13, 40, 13, 46, S)
	p.rect(10, 46, 4, 2, B)
	p.mirror()
	p.outline()
	p.grime(0.06, 0.3)
	return p

static func _armor(base: Color, hi: Color, dark: Color, cloth: Color, crown: bool) -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 31)
	p.ell(16, 4, 6.2, 4.5, base)
	p.rect(10, 4, 12, 2, base)
	p.rect(12, 2, 3, 1, hi)
	p.rect(15, 5, 2, 5, hi)
	if crown:
		for x in [10, 13, 15]:
			p.rect(x, -1, 1, 3, hi)
			p.p(x, -2, hi)
	p.rect(10, 17, 6, 9, base)
	p.rect(10, 17, 6, 1, hi)
	p.p(11, 19, hi)
	p.p(11, 23, hi)
	p.rect(10, 25, 6, 1, dark)
	p.ell(9, 17, 3.2, 2.6, base)
	p.p(8, 16, hi)
	p.rect(11, 29, 5, 1, dark)
	p.rect(13, 30, 3, 8, cloth)
	p.p(13, 38, cloth)
	p.p(15, 39, cloth)
	p.mirror()
	p.outline()
	p.grime(0.1, 0.4)
	return p

static func _w_sword_shield() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 32)
	p.line(6, 30, 4, 7, C("#a7a9ad"), 2)
	p.line(7, 30, 5, 8, C("#6c6f75"))
	p.p(4, 6, C("#c8cacf"))
	p.line(2, 30, 9, 30, C("#6b4a22"))
	p.rect(5, 31, 2, 3, C("#3a2414"))
	p.p(5, 34, C("#6b4a22"))
	p.circ(24, 27, 7, C("#4b3320"))
	for x in [21, 24, 27]:
		p.line(x, 21, x, 33, C("#33220f"))
	p.ring(24, 27, 7, 1.2, C("#6e6e70"))
	p.circ(24, 27, 1.8, C("#9a9a9a"))
	p.outline()
	return p

static func _w_bow() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 33)
	var wood := C("#5a3a1e")
	var prev := Vector2(24, 14)
	for y in range(14, 47):
		var k := (y - 30.0) / 16.0
		var x := 24.0 + 4.5 * (1.0 - k * k)
		p.line(prev.x, prev.y, x, y, wood)
		p.p(int(x) + 1, y, wood.darkened(0.3))
		prev = Vector2(x, y)
	p.line(24, 14, 24, 46, Color(0.75, 0.72, 0.65, 0.8))
	p.rect(27, 29, 2, 3, C("#3a2414"))
	p.outline()
	return p

static func _cape(c: Color, x0: int, x1: int, bx0: int, bx1: int) -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 34)
	p.poly(PackedVector2Array([Vector2(x0, 14), Vector2(x1, 14), Vector2(bx1, 47), Vector2(bx0, 47)]), c)
	for i in 5:
		var x := lerpf(x0, x1, i / 4.0)
		p.line(x, 16, lerpf(bx0, bx1, i / 4.0), 46, c.darkened(0.35))
	_tatter(p, 42, 0.3)
	p.outline()
	p.grime(0.05, 0.4)
	return p

static func _hood(c: Color) -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 35)
	p.ell(16, 7, 7.5, 7.5, c)
	_clear_ell(p, 16, 9, 4.3, 5.0)
	p.ell(16, 15.5, 8.5, 3, c)
	p.rect(10, 1, 12, 1, c.lightened(0.1))
	p.outline()
	p.grime(0.05, 0.4)
	return p

static func _robe(c: Color, trim: Color) -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 36)
	p.poly(PackedVector2Array([Vector2(10, 13), Vector2(22, 13), Vector2(27, 48), Vector2(5, 48)]), c)
	p.line(10, 14, 5, 28, c, 3)
	p.line(22, 14, 27, 28, c, 3)
	p.rect(9, 28, 14, 1, trim)
	p.line(16, 14, 16, 47, c.darkened(0.4))
	p.rect(4, 29, 3, 3, C("#b7a58e"))
	p.rect(26, 29, 3, 3, C("#b7a58e"))
	p.line(12, 30, 9, 47, c.darkened(0.3))
	p.line(20, 30, 23, 47, c.darkened(0.3))
	_tatter(p, 45, 0.25)
	p.outline()
	p.grime(0.06, 0.4)
	return p

static func _hood_cult() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 37)
	var c := C("#1d0e10")
	p.poly(PackedVector2Array([Vector2(16, -1), Vector2(23.5, 8), Vector2(24, 16), Vector2(8, 16), Vector2(8.5, 8)]), c)
	p.ell(16, 10, 3.3, 3.8, C("#050303"))
	p.p(14, 10, C("#e8c04a"))
	p.p(17, 10, C("#e8c04a"))
	p.line(16, 0, 21, 7, c.lightened(0.12))
	p.outline()
	return p

static func _w_dagger() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 38)
	p.line(5, 29, 4, 20, C("#9a9ca0"), 2)
	p.p(4, 19, C("#c8cacf"))
	p.line(2, 29, 8, 29, C("#4a3018"))
	p.outline()
	return p

static func _w_staff() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 39)
	p.line(27, 7, 27, 47, C("#3a2616"), 2)
	p.circ(27.5, 5, 2.6, C("#c84a1e"))
	p.p(27, 4, C("#ffd27a"))
	p.outline()
	return p

static func _zomb_body() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 40)
	var F := C("#5f6b4c")
	var D := C("#3d4632")
	var K := C("#1a0c0a")
	p.ell(16, 10, 5, 5.5, F)
	p.rect(13, 9, 2, 1, C("#d8d0a0"))
	p.rect(14, 12, 2, 3, K)
	p.rect(11, 6, 2, 2, D)
	p.rect(14, 15, 2, 2, F)
	p.poly(PackedVector2Array([Vector2(10, 17), Vector2(16, 17), Vector2(16, 31), Vector2(11, 31)]), F)
	p.line(10, 18, 7, 23, F, 2)
	p.line(7, 23, 8, 26, F, 2)
	p.ell(8, 27, 2.2, 1.6, F)
	p.p(7, 29, F)
	p.p(9, 29, F)
	p.rect(12, 31, 3, 14, F)
	p.rect(11, 45, 4, 2, D)
	p.mirror()
	p.circ(19, 22, 1.6, C("#6e1e1a"))
	p.line(11, 20, 14, 21, D)
	p.line(11, 23, 14, 24, D)
	p.p(20, 9, C("#d8d0a0"))
	p.outline()
	p.grime(0.1, 0.5)
	return p

static func _rags(c: Color) -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), int(c.r * 1000))
	p.poly(PackedVector2Array([Vector2(10, 17), Vector2(16, 17), Vector2(16, 28), Vector2(10, 30)]), c)
	p.line(10, 18, 8, 22, c, 2)
	p.rect(11, 30, 5, 11, c.darkened(0.3))
	p.p(11, 41, c.darkened(0.3))
	p.p(13, 42, c.darkened(0.3))
	p.mirror()
	for i in 10:
		var x := p.rng.randi_range(10, 22)
		var y := p.rng.randi_range(18, 40)
		p.img.set_pixel(x, y, Color(0, 0, 0, 0))
	_clear_ell(p, 19, 22, 2, 2)
	p.outline()
	p.grime(0.07, 0.5)
	return p

static func _w_cleaver() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 41)
	p.rect(23, 20, 6, 8, C("#8a8c90"))
	p.rect(23, 27, 6, 1, C("#c0c2c6"))
	p.rect(25, 28, 2, 6, C("#3a2414"))
	p.p(24, 22, C("#6e1e1a"))
	p.p(27, 24, C("#6e1e1a"))
	p.outline()
	return p

static func _ghost() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 42)
	var c := Color(0.75, 0.82, 0.9, 0.85)
	p.ell(16, 10, 6.5, 7.5, c)
	p.poly(PackedVector2Array([Vector2(9, 12), Vector2(23, 12), Vector2(21, 38), Vector2(16, 47), Vector2(11, 38)]), c)
	p.line(10, 16, 5, 30, c, 2)
	p.line(22, 16, 27, 30, c, 2)
	p.ell(16, 11, 3.6, 4.2, C("#0a0a14"))
	p.p(14, 11, C("#9fd8ff"))
	p.p(17, 11, C("#9fd8ff"))
	_tatter(p, 36, 0.3)
	return p

static func _w_greatsword() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 43)
	p.rect(15, 3, 2, 31, C("#9ea1a6"))
	p.rect(16, 3, 1, 31, C("#6c6f75"))
	p.p(15, 2, C("#c8cacf"))
	p.rect(10, 33, 12, 2, C("#7a5e22"))
	p.rect(15, 35, 2, 5, C("#2a1a0c"))
	p.circ(16, 41, 1.5, C("#c9a24a"))
	p.rect(13, 35, 2, 2, C("#cfc5a8"))
	p.rect(17, 37, 2, 2, C("#cfc5a8"))
	p.outline()
	return p

static func _prince_body() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 44)
	var skin := C("#d9cfc4")
	var hair := C("#c9c4cf")
	var cloth := C("#1b1420")
	var gold := C("#b08a3a")
	p.ell(16, 8, 4.5, 5.5, skin)
	p.rect(11, 3, 2, 12, hair)
	p.ell(16, 3.5, 5, 2.5, hair)
	p.rect(13, 7, 2, 2, C("#050305"))
	p.p(13, 7, C("#ff3a3a"))
	p.p(15, 12, C("#8a5a5a"))
	p.rect(15, 13, 1, 2, skin)
	p.poly(PackedVector2Array([Vector2(10, 15), Vector2(16, 15), Vector2(16, 31), Vector2(11, 31)]), cloth)
	p.line(16, 15, 16, 31, gold)
	p.rect(11, 22, 5, 1, gold)
	p.line(10, 16, 7, 24, cloth, 3)
	p.line(7, 24, 7, 30, cloth, 2)
	p.rect(6, 30, 3, 2, skin)
	p.ell(9, 16, 2.6, 2, gold)
	p.rect(12, 31, 3, 13, C("#120c16"))
	p.rect(11, 44, 5, 4, C("#2a1a12"))
	p.mirror()
	p.outline()
	p.grime(0.04, 0.3)
	return p

static func _prince_crown() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 45)
	var g := C("#c9a24a")
	p.rect(11, 1, 10, 2, g)
	for x in [11, 13, 15]:
		p.rect(x, -1, 1, 2, g)
	p.mirror()
	p.p(15, 1, C("#a01820"))
	p.p(16, 1, C("#a01820"))
	p.outline()
	return p

static func _w_rapier() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 46)
	p.line(25, 30, 30, 4, C("#c8cacf"))
	p.ring(25, 32, 2.2, 1, C("#c9a24a"))
	p.rect(24, 32, 2, 3, C("#2a1a12"))
	p.outline()
	return p

# =================================================================== ДЕКОРАЦІЇ

static func _branch() -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 50)
	_br(p, Vector2(32, 64), -PI / 2, 22.0, 4, C("#140f0b"))
	return p

static func _br(p: Px, from: Vector2, ang: float, l: float, t: int, c: Color) -> void:
	var to := from + Vector2(cos(ang), sin(ang)) * l
	p.line(from.x, from.y, to.x, to.y, c, max(t, 1))
	if l < 5.0:
		return
	var n := 2 if p.rng.randf() < 0.7 else 3
	for i in n:
		_br(p, to, ang + p.rng.randf_range(-0.9, 0.9), l * p.rng.randf_range(0.55, 0.75), t - 1, c)

static func _grass_tuft() -> Px:
	var p := Px.new(16, 16, Color(0, 0, 0, 0), 51)
	for i in 9:
		var x := p.rng.randi_range(2, 13)
		var hh := p.rng.randi_range(4, 12)
		var c: Color = [C("#2e3a1f"), C("#3e4528"), C("#4a4530")][i % 3]
		p.line(x, 15, x + p.rng.randi_range(-2, 2), 15 - hh, c)
	return p

static func _bones() -> Px:
	var p := Px.new(24, 12, Color(0, 0, 0, 0), 52)
	var b := C("#b8ad92")
	p.line(2, 10, 14, 8, b, 2)
	p.line(8, 11, 20, 10, b)
	p.line(12, 7, 22, 11, b)
	p.ell(8, 6, 3.5, 3.5, b)
	p.rect(6, 5, 1, 2, C("#100a08"))
	p.rect(9, 5, 1, 2, C("#100a08"))
	p.outline()
	return p

static func _tomb() -> Px:
	var p := Px.new(16, 24, Color(0, 0, 0, 0), 53)
	var s := C("#4a4a48")
	p.ell(8, 7, 6, 6, s)
	p.rect(2, 7, 12, 17, s)
	p.rect(7, 6, 2, 9, C("#2a2a28"))
	p.rect(5, 8, 6, 2, C("#2a2a28"))
	p.grime(0.08, 0.6)
	for i in 12:
		p.p(p.rng.randi_range(2, 13), p.rng.randi_range(15, 23), C("#2e3a1f"))
	p.outline()
	return p

static func _candles() -> Px:
	var p := Px.new(16, 16, Color(0, 0, 0, 0), 54)
	for c in [[3, 8], [7, 5], [11, 9]]:
		p.rect(c[0], c[1], 2, 16 - c[1], C("#d8ceb0"))
		p.p(c[0], c[1] - 1, C("#ffcf5a"))
		p.p(c[0], c[1] - 2, C("#ff8a2a"))
	p.outline()
	return p

static func _cross() -> Px:
	var p := Px.new(16, 32, Color(0, 0, 0, 0), 55)
	p.rect(7, 2, 3, 30, C("#2a1c12"))
	p.rect(2, 8, 13, 3, C("#2a1c12"))
	p.outline()
	return p

## Стара ворожка: згорблена постать у каптурі, з ціпком і віялом карт таро.
static func _crone() -> Px:
	var p := Px.new(32, 44, Color(0, 0, 0, 0), 64)
	var cloak := C("#3a3330")
	var cloak_hi := C("#524842")
	p.poly(PackedVector2Array([Vector2(9, 14), Vector2(20, 10), Vector2(25, 18), Vector2(26, 43), Vector2(6, 43), Vector2(7, 24)]), cloak)
	p.poly(PackedVector2Array([Vector2(9, 14), Vector2(20, 10), Vector2(18, 22), Vector2(9, 24)]), cloak_hi)   # згорблена спина
	p.ell(12, 13, 5, 5, cloak)                                       # каптур
	p.ell(10, 14, 2.5, 3, C("#140f0d"))                              # тінь під каптуром
	p.p(9, 15, C("#c9b48a")); p.p(8, 16, C("#a8946c"))              # ніс і підборіддя
	p.p(10, 13, C("#e8d9a0"))                                        # блиск ока
	p.rect(5, 23, 4, 2, C("#8a7a64"))                                # кістлява рука
	for i in 3:                                                      # віяло карт
		var x := 1 + i * 2
		p.rect(x, 18 - i, 3, 5, C("#d8c08a"))
		p.rect(x, 18 - i, 3, 1, C("#8a2a1c"))
	p.line(24, 20, 29, 43, C("#4a3624"))                             # ціпок
	p.p(24, 19, C("#6a4e34"))
	for x in range(8, 26, 3):                                        # обтріпаний поділ
		p.p(x, 43, Color(0, 0, 0, 0))
	p.shade_side(0.25)
	p.outline(C("#120d0b"))
	return p

## Дерев'яний хрест: variant 0 — простий, 1 — з дашком і перекладиною знизу.
static func _cross_wood(variant: int) -> Px:
	var p := Px.new(16, 32, Color(0, 0, 0, 0), 60 + variant)
	var w := C("#6a4a2c")
	var hi := C("#8a6440")
	p.rect(7, 3, 2, 29, w); p.rect(7, 3, 1, 29, hi)
	p.rect(2, 9, 12, 2, w); p.rect(2, 9, 12, 1, hi)
	if variant == 1:
		p.line(3, 4, 8, 0, C("#3a2a1a")); p.line(8, 0, 13, 4, C("#3a2a1a"))   # дашок
		p.rect(4, 17, 8, 1, w)                                                  # нижня перекладина
		p.rect(6, 12, 4, 3, C("#c9b48a"))                                      # іконка
	p.grime(0.08, 0.6)
	p.outline(C("#1a120a"))
	return p

## Великий хрест із сонячним колом навколо перехрестя.
static func _cross_sun() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 62)
	var w := C("#7a5634")
	var iron := C("#3a3632")
	for a in 16:                                                     # промені
		var ang := TAU * a / 16.0
		p.line(16, 12, 16 + cos(ang) * 11, 12 + sin(ang) * 11, iron)
	p.ring(16, 12, 7, 1.2, iron)
	p.rect(14, 1, 4, 47, w); p.rect(14, 1, 1, 47, C("#9a7448"))
	p.rect(5, 10, 22, 4, w); p.rect(5, 10, 22, 1, C("#9a7448"))
	p.grime(0.08, 0.6)
	p.outline(C("#1a120a"))
	return p

## Придорожня капличка-стовп з двосхилим дашком.
static func _shrine() -> Px:
	var p := Px.new(16, 48, Color(0, 0, 0, 0), 63)
	var w := C("#5e4430")
	p.rect(6, 14, 4, 34, w); p.rect(6, 14, 1, 34, C("#7e5e42"))
	p.rect(3, 8, 10, 7, C("#4a3624"))                                # скринька
	p.rect(5, 9, 6, 5, C("#1a120c"))
	p.rect(7, 10, 2, 3, C("#c9b48a"))                                # фігурка
	p.poly(PackedVector2Array([Vector2(1, 8), Vector2(15, 8), Vector2(8, 1)]), C("#2e221a"))   # дашок
	p.line(8, 1, 8, -2, C("#3a3632"))
	p.rect(7, 0, 2, 1, C("#3a3632"))
	p.grime(0.08, 0.6)
	p.outline(C("#1a120a"))
	return p

static func _flame() -> Px:
	var p := Px.new(8, 12, Color(0, 0, 0, 0), 56)
	p.ell(4, 8, 3, 4, C("#e0661e"))
	p.ell(4, 8.5, 2, 3, C("#ffb84a"))
	p.ell(4, 9, 1, 1.6, C("#fff0b0"))
	p.p(4, 2, C("#e0661e"))
	p.p(3, 3, C("#e0661e"))
	return p

static func _chest(open: bool) -> Px:
	var p := Px.new(24, 20, Color(0, 0, 0, 0), 57)
	var w := C("#4a2e18")
	var m := C("#6a6a6c")
	p.rect(2, 9, 20, 11, w)
	if open:
		p.rect(2, 1, 20, 6, w.darkened(0.2))
		p.rect(3, 8, 18, 3, C("#0a0604"))
		p.p(8, 9, C("#e8c04a"))
		p.p(14, 9, C("#e8c04a"))
	else:
		p.ell(12, 9, 10, 5, w)
		p.rect(2, 9, 20, 1, w.darkened(0.3))
	p.rect(6, 3 if not open else 1, 2, 17, m)
	p.rect(16, 3 if not open else 1, 2, 17, m)
	p.rect(11, 10, 2, 3, C("#c9a24a"))
	p.grime(0.06, 0.5)
	p.outline()
	return p

static func _exit_door() -> Px:
	var p := Px.new(32, 48, Color(0, 0, 0, 0), 58)
	p.ell(16, 14, 12, 12, C("#2a2622"))
	p.rect(4, 14, 24, 34, C("#2a2622"))
	p.ell(16, 15, 9, 9, C("#e8d6a0"))
	p.rect(7, 15, 18, 33, C("#e8d6a0"))
	p.ell(16, 18, 6, 6, C("#fff6d8"))
	p.rect(10, 18, 12, 30, C("#fff6d8"))
	p.grime(0.04, 0.3)
	return p

static func _banner() -> Px:
	var p := Px.new(16, 40, Color(0, 0, 0, 0), 59)
	p.rect(0, 0, 16, 2, C("#3a2616"))
	p.poly(PackedVector2Array([Vector2(1, 2), Vector2(15, 2), Vector2(15, 39), Vector2(8, 33), Vector2(1, 39)]), C("#4a0c10"))
	p.circ(8, 14, 3, C("#b08a3a"))
	p.rect(7, 18, 2, 8, C("#b08a3a"))
	p.grime(0.06, 0.5)
	return p

static func _skull_pike() -> Px:
	var p := Px.new(16, 40, Color(0, 0, 0, 0), 60)
	p.rect(7, 8, 2, 32, C("#2a1c12"))
	p.ell(8, 6, 4.5, 5, C("#c8bd9f"))
	p.rect(5, 5, 2, 2, C("#0a0604"))
	p.rect(9, 5, 2, 2, C("#0a0604"))
	p.rect(6, 9, 4, 2, C("#c8bd9f"))
	p.outline()
	return p

# =================================================================== ЕФЕКТИ

static func _arrow() -> Px:
	var p := Px.new(16, 5, Color(0, 0, 0, 0), 61)
	p.rect(2, 2, 12, 1, C("#6a4a2a"))
	p.rect(13, 1, 3, 3, C("#9a9ca0"))
	p.rect(0, 1, 3, 1, C("#d8d0c0"))
	p.rect(0, 3, 3, 1, C("#d8d0c0"))
	return p

static func _fireball() -> Px:
	var p := Px.new(12, 12, Color(0, 0, 0, 0), 62)
	p.circ(6, 6, 5.5, Color(0.85, 0.3, 0.1, 0.7))
	p.circ(6, 6, 3.8, C("#ff9a3a"))
	p.circ(6, 6, 2, C("#fff0b0"))
	return p

static func _spark() -> Px:
	var p := Px.new(8, 8, Color(0, 0, 0, 0), 63)
	p.line(0, 4, 7, 4, C("#ffe8a0"))
	p.line(4, 0, 4, 7, C("#ffe8a0"))
	p.p(4, 4, Color.WHITE)
	return p

static func _glow() -> Px:
	var p := Px.new(16, 16, Color(0, 0, 0, 0), 64)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			if d < 1.0:
				p.img.set_pixel(x, y, Color(1, 0.9, 0.6, pow(1.0 - d, 2.0)))
	return p

# =================================================================== ВИД ВІД ПЕРШОЇ ОСОБИ (64x64)

static func _vm_sword() -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 70)
	p.line(44, 50, 16, 4, C("#8e9096"), 4)
	p.line(43, 48, 16, 3, C("#c9cbd0"))
	p.line(46, 51, 18, 6, C("#5c5f66"))
	p.line(36, 46, 54, 56, C("#6b4a22"), 3)
	p.rect(36, 47, 2, 2, C("#c9a24a"))
	p.line(46, 54, 54, 64, C("#3a2414"), 4)
	p.ell(52, 58, 7, 6, C("#4a4a50"))
	p.ell(51, 56, 4, 3, C("#6a6a72"))
	p.outline()
	return p

static func _vm_shield() -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 71)
	var pts := PackedVector2Array([Vector2(4, 8), Vector2(44, 8), Vector2(44, 34), Vector2(24, 62), Vector2(4, 34)])
	p.poly(pts, C("#5c5f66"))
	var inner := PackedVector2Array([Vector2(7, 11), Vector2(41, 11), Vector2(41, 33), Vector2(24, 57), Vector2(7, 33)])
	p.poly(inner, C("#3a1416"))
	p.circ(24, 26, 7, C("#b08a3a"))
	p.circ(24, 26, 4.5, C("#3a1416"))
	for i in 8:
		var a := i * TAU / 8.0
		p.line(24 + cos(a) * 8, 26 + sin(a) * 8, 24 + cos(a) * 12, 26 + sin(a) * 12, C("#b08a3a"))
	p.grime(0.08, 0.5)
	p.outline()
	return p

static func _vm_bow(drawn: bool) -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 72)
	var wood := C("#5a3a1e")
	var prev := Vector2(36, 2)
	for y in range(2, 63):
		var k := (y - 32.0) / 30.0
		var x := 36.0 - 12.0 * (1.0 - k * k)
		p.line(prev.x, prev.y, x, y, wood, 3)
		prev = Vector2(x, y)
	var sx := 52.0 if drawn else 37.0
	p.line(36, 2, sx, 32, Color(0.85, 0.82, 0.75))
	p.line(sx, 32, 36, 62, Color(0.85, 0.82, 0.75))
	p.rect(21, 28, 6, 9, C("#3a2a1e"))
	if drawn:
		p.line(sx, 32, 12, 32, C("#6a4a2a"), 2)
		p.poly(PackedVector2Array([Vector2(6, 32), Vector2(13, 28), Vector2(13, 36)]), C("#9a9ca0"))
		p.rect(sx - 5, 29, 4, 2, C("#d8d0c0"))
		p.rect(sx - 5, 34, 4, 2, C("#d8d0c0"))
		p.ell(sx + 3, 33, 5, 4, C("#8a6a50"))
	p.outline()
	return p

static func _vm_dagger() -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 73)
	p.poly(PackedVector2Array([Vector2(40, 44), Vector2(28, 20), Vector2(45, 40)]), C("#a7a9ad"))
	p.line(36, 46, 48, 40, C("#4a3018"), 3)
	p.line(44, 48, 52, 60, C("#2a1a0e"), 4)
	p.ell(52, 58, 7, 6, C("#8a6a50"))
	p.outline()
	return p

static func _vm_staff() -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 74)
	var w := C("#3e2a18")
	p.line(56, 64, 24, 2, w, 5)
	p.line(55, 62, 24, 2, C("#5a4028"))
	for k in [0.3, 0.55, 0.8]:
		var x := lerpf(56, 24, k)
		var y := lerpf(64, 2, k)
		p.circ(x - 2, y, 2.5, w.darkened(0.3))
	p.line(26, 6, 18, 2, w, 2)
	p.rect(46, 44, 10, 8, C("#6a5a44"))
	p.line(46, 46, 56, 48, C("#4a3e2e"))
	p.ell(53, 56, 7, 6, C("#8a6a50"))
	p.outline()
	return p

static func _vm_hand() -> Px:
	var p := Px.new(64, 64, Color(0, 0, 0, 0), 75)
	p.ell(16, 52, 9, 8, C("#8a6a50"))
	p.rect(10, 56, 12, 8, C("#4a3e2e"))
	p.outline()
	return p

# =================================================================== КАРТИ ТАРО (72x112)

static func _card_bg(seed_v: int, top: Color, bottom: Color) -> Px:
	var p := Px.new(72, 112, Color.BLACK, seed_v)
	for y in 112:
		var c := top.lerp(bottom, y / 111.0)
		for x in 72:
			p.img.set_pixel(x, y, c)
	for i in 30:
		p.p(p.rng.randi() % 72, p.rng.randi() % 70, Color(1, 0.95, 0.8, p.rng.randf_range(0.2, 0.8)))
	return p

static func _card_knight() -> Px:
	var p := _card_bg(80, C("#1a1430"), C("#3a1a16"))
	p.circ(36, 22, 14, C("#c9a24a"))
	p.circ(36, 22, 11, C("#e8c86a"))
	p.rect(0, 92, 72, 20, C("#1a120e"))
	var arm := C("#6e7078")
	var dark := C("#3a3c44")
	p.ell(36, 40, 6, 6.5, arm)
	p.rect(31, 41, 10, 3, dark)
	p.line(36, 34, 40, 27, C("#8a1c1c"), 2)
	p.poly(PackedVector2Array([Vector2(28, 48), Vector2(44, 48), Vector2(46, 72), Vector2(26, 72)]), arm)
	p.rect(29, 72, 5, 20, dark)
	p.rect(38, 72, 5, 20, dark)
	p.poly(PackedVector2Array([Vector2(14, 50), Vector2(32, 50), Vector2(32, 68), Vector2(23, 80), Vector2(14, 68)]), C("#5c5f66"))
	p.poly(PackedVector2Array([Vector2(16, 52), Vector2(30, 52), Vector2(30, 67), Vector2(23, 77), Vector2(16, 67)]), C("#4a0c10"))
	p.circ(23, 62, 4, C("#c9a24a"))
	p.line(48, 70, 56, 18, C("#c9cbd0"), 2)
	p.line(44, 66, 54, 70, C("#c9a24a"), 2)
	p.outline(C("#050304"))
	p.grime(0.04, 0.3)
	return p

static func _card_archer() -> Px:
	var p := _card_bg(81, C("#0c1628"), C("#141a22"))
	p.circ(36, 22, 15, C("#d8dce8"))
	p.circ(42, 18, 14, C("#0c1628"))
	p.rect(2, 40, 12, 60, C("#2a2a34"))
	p.rect(58, 40, 12, 60, C("#2a2a34"))
	p.rect(4, 36, 2, 4, C("#2a2a34"))
	p.rect(9, 36, 2, 4, C("#2a2a34"))
	p.rect(60, 36, 2, 4, C("#2a2a34"))
	p.rect(65, 36, 2, 4, C("#2a2a34"))
	p.rect(6, 50, 3, 4, C("#e8c04a"))
	p.rect(62, 50, 3, 4, C("#e8c04a"))
	p.poly(PackedVector2Array([Vector2(30, 112), Vector2(42, 112), Vector2(37, 92), Vector2(35, 92)]), C("#3a3428"))
	p.rect(0, 96, 72, 16, C("#101418"))
	var cloak := C("#2c3a2a")
	p.ell(34, 44, 6, 6.5, cloak)
	p.ell(34, 46, 3.5, 4, C("#c9b49a"))
	p.poly(PackedVector2Array([Vector2(27, 50), Vector2(41, 50), Vector2(46, 92), Vector2(22, 92)]), cloak)
	var prev := Vector2(48, 42)
	for y in range(42, 86):
		var k := (y - 64.0) / 22.0
		var x := 48.0 + 6.0 * (1.0 - k * k)
		p.line(prev.x, prev.y, x, y, C("#6a4422"), 2)
		prev = Vector2(x, y)
	p.line(48, 42, 48, 86, Color(0.9, 0.9, 0.85, 0.8))
	p.line(40, 62, 50, 64, cloak, 3)
	p.outline(C("#050304"))
	p.grime(0.04, 0.3)
	return p

static func _card_beggar() -> Px:
	var p := _card_bg(82, C("#2a1e10"), C("#1a1012"))
	p.circ(54, 18, 10, C("#f0ead8"))
	p.poly(PackedVector2Array([Vector2(0, 90), Vector2(52, 86), Vector2(60, 112), Vector2(0, 112)]), C("#2a2016"))
	var rag := C("#5a4a36")
	p.ell(32, 46, 5.5, 6, C("#c9b49a"))
	p.ell(32, 41, 6.5, 3.5, C("#3a2e22"))
	p.rect(29, 46, 1, 1, C("#140c08"))
	p.rect(34, 46, 1, 1, C("#140c08"))
	p.poly(PackedVector2Array([Vector2(25, 53), Vector2(39, 53), Vector2(42, 84), Vector2(22, 84)]), rag)
	_tatter(p, 108, 0.0)
	for i in 6:
		p.p(p.rng.randi_range(23, 41), p.rng.randi_range(70, 84), C("#2a2016"))
	p.rect(26, 84, 4, 6, C("#3a2e22"))
	p.rect(34, 84, 4, 6, C("#3a2e22"))
	p.line(20, 90, 50, 34, C("#4a321c"), 2)
	p.circ(51, 33, 5, C("#7a3a2a"))
	p.ell(14, 86, 5, 3.5, C("#d8d0c0"))
	p.ell(10, 82, 2.5, 2.5, C("#d8d0c0"))
	p.p(9, 81, C("#140c08"))
	p.outline(C("#050304"))
	p.grime(0.04, 0.3)
	return p

static func _card_back() -> Px:
	var p := Px.new(72, 112, C("#140c10"), 83)
	for y in 112:
		for x in 72:
			var d: int = (abs(x - 36) + abs(y - 56)) % 8
			if d == 0:
				p.p(x, y, C("#3a1a20"))
	p.circ(36, 56, 14, C("#c9a24a"))
	p.circ(36, 56, 12, C("#140c10"))
	p.ell(36, 56, 9, 5, C("#c9a24a"))
	p.ell(36, 56, 7, 3.6, C("#140c10"))
	p.circ(36, 56, 3, C("#c9a24a"))
	p.circ(36, 56, 1.4, C("#140c10"))
	return p

# =================================================================== ІКОНКИ (16x16)

static func _icon(id: String) -> Px:
	var p := Px.new(16, 16, Color(0, 0, 0, 0), id.hash())
	match id:
		"bandage":
			p.ell(8, 8, 6, 4, C("#b8ad92"))
			p.ell(8, 8, 2.2, 1.6, C("#6a5a44"))
			p.line(3, 7, 13, 9, C("#8a7a60"))
			p.p(10, 6, C("#7a1c1c"))
		"herb":
			p.line(8, 15, 8, 4, C("#3a4a22"))
			for i in 4:
				p.ell(6 if i % 2 == 0 else 10, 5 + i * 2.5, 2.5, 1.3, C("#4e6a2a"))
			p.p(8, 3, C("#8a5aa0"))
		"elixir":
			p.ell(8, 10, 5, 5, C("#7a1018"))
			p.rect(7, 2, 3, 4, C("#6a7a7a"))
			p.rect(6, 1, 5, 1, C("#4a3018"))
			p.p(6, 8, C("#ff8a8a"))
		"salt":
			p.rect(3, 6, 10, 9, C("#3a2a1e"))
			p.ell(8, 6, 5, 2, C("#d8d8d0"))
			p.p(6, 5, Color.WHITE)
		"incense":
			p.rect(5, 10, 6, 5, C("#3a3434"))
			p.line(8, 10, 8, 4, C("#2a1a10"))
			p.line(8, 4, 6, 1, Color(0.7, 0.7, 0.7, 0.6))
			p.line(8, 4, 10, 0, Color(0.7, 0.7, 0.7, 0.4))
		"ring_bone":
			p.ring(8, 9, 5, 2, C("#cfc5a8"))
			p.circ(8, 4, 2, C("#e8e0c8"))
		"raven_eye":
			p.ell(8, 8, 6, 4, C("#d8c890"))
			p.circ(8, 8, 2.5, C("#1a1010"))
			p.p(7, 7, Color.WHITE)
		"ash_bead":
			p.circ(8, 8, 5, C("#4a4a52"))
			p.circ(8, 8, 3, C("#c84a1e"))
			p.p(6, 6, C("#ffd27a"))
		"martyr_candle":
			p.rect(6, 5, 4, 10, C("#d8ceb0"))
			p.ell(8, 3, 1.5, 2.5, C("#ffb84a"))
			p.p(7, 8, C("#7a1c1c"))
		"iron_heart":
			p.circ(5.5, 6, 3, C("#5c5f66"))
			p.circ(10.5, 6, 3, C("#5c5f66"))
			p.poly(PackedVector2Array([Vector2(2.5, 7), Vector2(13.5, 7), Vector2(8, 14)]), C("#5c5f66"))
			p.p(5, 5, C("#a0a4ac"))
		"key_gate", "key_crypt", "key_tower":
			var kc := C("#8a5a30") if id == "key_gate" else (C("#9aa0b0") if id == "key_crypt" else C("#a01820"))
			p.ring(5, 8, 3.5, 1.5, kc)
			p.rect(8, 7, 7, 2, kc)
			p.rect(12, 9, 1, 3, kc)
			p.rect(14, 9, 1, 2, kc)
		_:
			p.rect(3, 2, 10, 12, C("#c8b890"))
			p.rect(2, 1, 12, 2, C("#8a7a5a"))
			p.rect(2, 13, 12, 2, C("#8a7a5a"))
			for y in [5, 7, 9, 11]:
				p.line(5, y, 11, y, C("#5a4a3a"))
	p.outline()
	return p
