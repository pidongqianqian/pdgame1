extends Node2D

func execute(player: Player, data: Dictionary) -> void:
	global_position = player.global_position
	var dmg: int = int(player.stats.get_total_attack() * data["damage_mult"])
	var radius: float = data["radius"]
	var freeze_dur: float = data["freeze_duration"]

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
			(e as EnemyBase).take_damage(dmg, dir * 0.5)
			if e.has_method("apply_freeze"):
				(e as EnemyBase).apply_freeze(freeze_dur)

	player._camera_shake(3.0, 0.15)

	await get_tree().create_timer(0.6).timeout
	queue_free()


func _spawn_vfx(radius: float) -> void:
	# 冰晶环
	for i in 16:
		var angle: float = TAU / 16.0 * i
		var crystal = ColorRect.new()
		crystal.size = Vector2(3, 5)
		crystal.position = Vector2.ZERO
		crystal.rotation = angle + PI / 2
		crystal.color = Color(0.5, 0.8, 1.0, 0.9)
		add_child(crystal)

		var tween = create_tween()
		var target = Vector2(cos(angle) * radius * 0.8, sin(angle) * radius * 0.8)
		tween.tween_property(crystal, "position", target, 0.2).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(crystal, "modulate:a", 0.0, 0.5)

	# 中心闪光
	var flash = ColorRect.new()
	flash.size = Vector2(8, 8)
	flash.position = Vector2(-4, -4)
	flash.color = Color(0.7, 0.9, 1.0, 0.8)
	add_child(flash)
	var tw = create_tween()
	tw.tween_property(flash, "scale", Vector2(4.0, 4.0), 0.15)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.3)
