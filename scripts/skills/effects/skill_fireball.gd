extends Node2D

var _direction: Vector2
var _speed: float
var _damage: int
var _explosion_radius: float
var _player: Player
var _lifetime: float = 1.5
var _exploded: bool = false


func execute(player: Player, data: Dictionary) -> void:
	_player = player
	_direction = player.facing_direction.normalized()
	_speed = data["speed"]
	_damage = int(player.stats.get_total_attack() * data["damage_mult"])
	_explosion_radius = data["explosion_radius"]
	global_position = player.global_position + _direction * 8

	# 暴击判定
	var crit_chance: float = player.stats.get_passive_value("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		_damage *= 2

	_create_fireball_visual()


func _process(delta: float) -> void:
	if _exploded:
		return
	_lifetime -= delta
	if _lifetime <= 0:
		_explode()
		return
	global_position += _direction * _speed * delta

	# 碰撞检测
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		if e.global_position.distance_to(global_position) < 8:
			_explode()
			return


func _explode() -> void:
	_exploded = true
	# 清除飞行特效
	for child in get_children():
		child.queue_free()

	_spawn_explosion_vfx()

	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		if e.global_position.distance_to(global_position) <= _explosion_radius:
			var dir: Vector2 = global_position.direction_to(e.global_position)
			(e as EnemyBase).take_damage(_damage, dir * 1.5)

	if _player and is_instance_valid(_player):
		_player._camera_shake(4.0, 0.2)

	await get_tree().create_timer(0.5).timeout
	queue_free()


func _create_fireball_visual() -> void:
	var core = ColorRect.new()
	core.size = Vector2(6, 6)
	core.position = Vector2(-3, -3)
	core.color = Color(1.0, 0.9, 0.3)
	add_child(core)

	var outer = ColorRect.new()
	outer.size = Vector2(8, 8)
	outer.position = Vector2(-4, -4)
	outer.color = Color(1.0, 0.4, 0.1, 0.6)
	add_child(outer)
	outer.z_index = -1

	rotation = _direction.angle()


func _spawn_explosion_vfx() -> void:
	for i in 16:
		var p = ColorRect.new()
		p.size = Vector2(3, 3)
		p.position = Vector2(-1.5, -1.5)
		var angle: float = TAU / 16.0 * i + randf_range(-0.2, 0.2)
		var dist: float = randf_range(6, _explosion_radius)
		p.color = [Color(1.0, 0.3, 0.05), Color(1.0, 0.7, 0.1), Color(1.0, 0.9, 0.4)][randi() % 3]
		add_child(p)
		var tween = create_tween()
		tween.tween_property(p, "position", Vector2(cos(angle) * dist, sin(angle) * dist), 0.25)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.35)
		tween.tween_callback(p.queue_free)

	var flash = ColorRect.new()
	flash.size = Vector2(10, 10)
	flash.position = Vector2(-5, -5)
	flash.color = Color(1.0, 0.8, 0.3, 0.9)
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.15)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.25)
