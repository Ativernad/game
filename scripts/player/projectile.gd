class_name Projectile
extends Node3D
## Стріла / вогняна куля. Летить, перевіряє зіткнення променем.

var velocity := Vector3.ZERO
var damage := 10.0
var target_group := "enemies"
var tex_name := "arrow"
var gravity := 0.0
var life := 5.0
var tint := Color.WHITE
var _stuck := false

const HEADSHOT_MULT := 1.75
const BODY_BOTTOM := 0.2      # висоти зони влучання (× масштаб ворога)
const BODY_TOP := 1.6
const HEAD_FROM := 1.3        # вище цієї висоти — «голова»

func setup(pos: Vector3, vel: Vector3, dmg: float, group: String, tex: String) -> void:
	position = pos
	velocity = vel
	damage = dmg
	target_group = group
	tex_name = tex

func _ready() -> void:
	if tex_name == "arrow":
		for i in 2:
			var s := LevelBuilder.sprite("arrow", 0.05, false)
			s.shaded = false
			var b := Basis(Vector3.UP, -PI / 2)
			if i == 1:
				b = Basis(Vector3.FORWARD, PI / 2) * b
			s.transform.basis = b
			add_child(s)
	else:
		var s := LevelBuilder.sprite(tex_name, 0.05, true)
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.modulate = tint
		add_child(s)
		var l := OmniLight3D.new()
		l.light_color = tint * Color(1.0, 0.6, 0.3)
		l.light_energy = 1.2
		l.omni_range = 4.0
		add_child(l)
	_orient()

func _orient() -> void:
	if velocity.length() > 0.1 and tex_name == "arrow":
		var up := Vector3.UP if abs(velocity.normalized().y) < 0.95 else Vector3.RIGHT
		look_at(global_position + velocity, up)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if _stuck:
		return
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	# цілі шукаємо лише до стіни, інакше стріла влучає крізь неї
	if not hit.is_empty():
		to = hit.position
	for t in get_tree().get_nodes_in_group(target_group):
		if t.get("dead"):
			continue
		# зона влучання — вертикальна капсула на весь зріст (раніше була куля
		# на висоті 1 м, і стріли в голову пролітали мимо)
		var hs: float = t.get_meta("hscale", 1.0)
		var base: Vector3 = t.global_position + Vector3(0, BODY_BOTTOM * hs, 0)
		var top: Vector3 = t.global_position + Vector3(0, BODY_TOP * hs, 0)
		var r: float = t.get_meta("hit_radius", 0.6)
		var pts := Geometry3D.get_closest_points_between_segments(from, to, base, top)
		var cp: Vector3 = pts[0]
		if cp.distance_to(pts[1]) < r:
			if target_group == "enemies":
				# стріла у верхню частину (голову) — критична шкода
				var crit: bool = tex_name == "arrow" and cp.y > t.global_position.y + HEAD_FROM * hs
				t.take_damage(damage * (HEADSHOT_MULT if crit else 1.0), velocity.normalized() * 1.5)
				if crit:
					Audio.play_3d("bone", cp, 1.7, 3.0)
					if t.get("world"):
						t.world.spawn_hit_fx(cp)
						t.world.spawn_hit_fx(cp)
			else:
				t.take_damage(damage, from)
			Audio.play_3d("arrow_hit", cp)
			queue_free()
			return
	if not hit.is_empty():
		global_position = hit.position - velocity.normalized() * 0.1
		Audio.play_3d("arrow_hit", hit.position, 1.3, -6.0)
		if tex_name == "arrow":
			_stuck = true
			life = 3.0
		else:
			queue_free()
		return
	global_position = to
	_orient()
