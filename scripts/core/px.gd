class_name Px
## Мінімальний піксельний "пензель" поверх Image.

var img: Image
var w: int
var h: int
var rng := RandomNumberGenerator.new()

func _init(width: int, height: int, fill := Color(0, 0, 0, 0), seed_v := 1) -> void:
	w = width
	h = height
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	rng.seed = seed_v

func p(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))

func get_c(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)

func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			p(xx, yy, c)

func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(cy - ry - 1), int(cy + ry + 2)):
		for xx in range(int(cx - rx - 1), int(cx + rx + 2)):
			var dx := (xx + 0.5 - cx) / maxf(rx, 0.01)
			var dy := (yy + 0.5 - cy) / maxf(ry, 0.01)
			if dx * dx + dy * dy <= 1.0:
				p(xx, yy, c)

func circ(cx: float, cy: float, r: float, c: Color) -> void:
	ell(cx, cy, r, r, c)

func ring(cx: float, cy: float, r: float, t: float, c: Color) -> void:
	for yy in range(int(cy - r - 1), int(cy + r + 2)):
		for xx in range(int(cx - r - 1), int(cx + r + 2)):
			var d := Vector2(xx + 0.5 - cx, yy + 0.5 - cy).length()
			if d <= r and d >= r - t:
				p(xx, yy, c)

func line(x0: float, y0: float, x1: float, y1: float, c: Color, t := 1) -> void:
	var steps := int(max(abs(x1 - x0), abs(y1 - y0))) + 1
	for i in steps + 1:
		var k := float(i) / steps
		var x := lerpf(x0, x1, k)
		var y := lerpf(y0, y1, k)
		if t <= 1:
			p(int(round(x)), int(round(y)), c)
		else:
			rect(int(round(x - t * 0.5)), int(round(y - t * 0.5)), t, t, c)

func poly(points: PackedVector2Array, c: Color) -> void:
	var r := Rect2(points[0], Vector2.ZERO)
	for pt in points:
		r = r.expand(pt)
	for yy in range(int(r.position.y), int(r.end.y) + 1):
		for xx in range(int(r.position.x), int(r.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(xx + 0.5, yy + 0.5), points):
				p(xx, yy, c)

## Дзеркалить ліву половину на праву (для симетричних фігур).
func mirror() -> void:
	for y in h:
		for x in w / 2:
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(w - 1 - x, y, c)

## Темний контур навколо непрозорих пікселів.
func outline(c := Color(0.06, 0.04, 0.04)) -> void:
	var src := img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.1:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0.5:
					img.set_pixel(x, y, c)
					break

## Випадкове затемнення/освітлення пікселів — "бруд" і фактура.
func grime(amount := 0.12, chance := 0.35) -> void:
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and rng.randf() < chance:
				var k := rng.randf_range(-amount, amount)
				img.set_pixel(x, y, Color(clamp(c.r + k, 0, 1), clamp(c.g + k, 0, 1), clamp(c.b + k, 0, 1), c.a))

## Затінення знизу/справа — псевдо-об'єм.
func shade_side(dark := 0.25) -> void:
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var k := 1.0 - dark * (float(y) / h) * 0.6 - dark * (float(x) / w) * 0.4
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))

func tex() -> ImageTexture:
	return ImageTexture.create_from_image(img)
