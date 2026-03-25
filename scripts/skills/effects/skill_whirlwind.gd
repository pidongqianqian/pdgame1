extends Node2D

func execute(player: Player, data: Dictionary) -> void:
	global_position = player.global_position
	var dmg: int = int(player.stats.get_total_attack() * data["damage_mult"])
	var radius: float = data["radius"]

	# 暴击判定
	var crit_chance: float = player.stats.get_passive_value("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= 2

	_spawn_vfx(radius)

	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		if e.global_position.distance_to(global_position) <= radius:
			var dir: Vector2 = global_position.direction_to(e.global_position)
			(e as EnemyBase).take_damage(dmg, dir * 2.0)

	player._camera_shake(3.5, 0.2)
	VfxManager.play_at("fx2_energy_sphere", global_position, "cyan", 0.5, 30.0)
	await get_tree().create_timer(0.6).timeout
	queue_free()


func _spawn_vfx(radius: float) -> void:
	for i in 12:
		var angle: float = TAU / 12.0 * i
		var line = ColorRect.new()
		line.size = Vector2(radius * 0.6, 2)
		line.position = Vector2(cos(angle) * 4, sin(angle) * 4)
		line.rotation = angle
		line.color = Color(0.6, 0.85, 1.0, 0.9 - i * 0.05)
		add_child(line)

	var tween = create_tween()
	tween.tween_property(self, "rotation", TAU, 0.3).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
