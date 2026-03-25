extends Node2D

var _damage: int = 0
var _slow_duration: float = 1.5
var _lifetime: float = 15.0
var _triggered: bool = false
var _player: Player


func execute(player: Player, data: Dictionary) -> void:
	_player = player
	_damage = int(player.stats.get_total_attack() * data["damage_mult"])
	_slow_duration = data["slow_duration"]
	_lifetime = data["trap_lifetime"]
	global_position = player.global_position + player.facing_direction * 16

	# 暴击
	var crit_chance: float = player.stats.get_passive_value("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		_damage *= 2

	_create_trap_visual()


func _process(delta: float) -> void:
	if _triggered:
		return
	_lifetime -= delta
	if _lifetime <= 0:
		_fade_out()
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		if e.global_position.distance_to(global_position) < 10:
			_trigger(e as EnemyBase)
			return


func _trigger(enemy: EnemyBase) -> void:
	_triggered = true
	var dir: Vector2 = global_position.direction_to(enemy.global_position)
	enemy.take_damage(_damage, dir * 0.8)
	if enemy.has_method("apply_slow"):
		enemy.apply_slow(_slow_duration, 0.5)

	# 连锁减速附近敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e == enemy or not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		if e.global_position.distance_to(global_position) < 20:
			if e.has_method("apply_slow"):
				(e as EnemyBase).apply_slow(_slow_duration * 0.5, 0.3)

	_spawn_trigger_vfx()
	VfxManager.play_at("fx_ring_explode", global_position, "green", 0.4, 35.0)
	if _player and is_instance_valid(_player):
		_player._camera_shake(2.5, 0.12)

	await get_tree().create_timer(0.4).timeout
	queue_free()


func _create_trap_visual() -> void:
	# 交叉线条
	var h = ColorRect.new()
	h.size = Vector2(8, 2)
	h.position = Vector2(-4, -1)
	h.color = Color(0.4, 0.9, 0.4, 0.7)
	add_child(h)

	var v = ColorRect.new()
	v.size = Vector2(2, 8)
	v.position = Vector2(-1, -4)
	v.color = Color(0.4, 0.9, 0.4, 0.7)
	add_child(v)

	# 呼吸闪烁
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate:a", 0.4, 0.8)
	tween.tween_property(self, "modulate:a", 1.0, 0.8)


func _spawn_trigger_vfx() -> void:
	for i in 8:
		var p = ColorRect.new()
		p.size = Vector2(3, 3)
		p.position = Vector2(-1.5, -1.5)
		var angle: float = TAU / 8.0 * i
		p.color = Color(0.3, 1.0, 0.3, 0.9)
		add_child(p)
		var tween = create_tween()
		tween.tween_property(p, "position", Vector2(cos(angle) * 14, sin(angle) * 14), 0.2)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.3)


func _fade_out() -> void:
	_triggered = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
