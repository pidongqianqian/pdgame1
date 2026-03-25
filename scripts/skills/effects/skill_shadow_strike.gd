extends Node2D

func execute(player: Player, data: Dictionary) -> void:
	var dmg: int = int(player.stats.get_total_attack() * data["damage_mult"])
	var range_dist: float = data["range"]

	# 暴击判定
	var crit_chance: float = player.stats.get_passive_value("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= 2

	# 找到最近的敌人
	var nearest: EnemyBase = null
	var nearest_dist: float = range_dist
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		var d: float = player.global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e as EnemyBase

	if nearest == null:
		queue_free()
		return

	# 残影
	_spawn_shadow(player)

	# 瞬移到敌人身后
	var dir_to_enemy: Vector2 = player.global_position.direction_to(nearest.global_position)
	var behind_pos: Vector2 = nearest.global_position + dir_to_enemy * 12
	player.global_position = behind_pos
	player.facing_direction = -dir_to_enemy

	# 造成伤害
	nearest.take_damage(dmg, dir_to_enemy * 2.0)
	VfxManager.play_at("fx2_wave_slash", global_position, "red", 0.4, 40.0)

	# 出现特效
	global_position = behind_pos
	_spawn_appear_vfx()

	player._camera_shake(3.5, 0.15)
	player._freeze_frame(0.05)

	await get_tree().create_timer(0.4).timeout
	queue_free()


func _spawn_shadow(player: Player) -> void:
	var ghost = Sprite2D.new()
	ghost.texture = player.sprite.texture
	ghost.global_position = player.global_position
	ghost.flip_h = player.sprite.flip_h
	ghost.modulate = Color(0.2, 0.1, 0.3, 0.7)
	ghost.z_index = -1
	player.get_parent().add_child(ghost)
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ghost.queue_free)


func _spawn_appear_vfx() -> void:
	for i in 6:
		var p = ColorRect.new()
		p.size = Vector2(2, 2)
		p.position = Vector2(-1, -1)
		var angle: float = TAU / 6.0 * i
		p.color = Color(0.6, 0.2, 0.8, 0.9)
		add_child(p)
		var tween = create_tween()
		tween.tween_property(p, "position", Vector2(cos(angle) * 10, sin(angle) * 10), 0.2)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
