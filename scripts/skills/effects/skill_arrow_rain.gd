extends Node2D

func execute(player: Player, data: Dictionary) -> void:
	global_position = player.global_position
	var base_dir: Vector2 = player.facing_direction.normalized()
	var dmg: int = int(player.stats.get_total_attack() * data["damage_mult"])
	var arrow_count: int = data["arrow_count"]
	var spread: float = deg_to_rad(data["spread_angle"])

	# 暴击判定
	var crit: bool = false
	var crit_chance: float = player.stats.get_passive_value("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		crit = true
		dmg *= 2

	var arrow_script = load("res://scripts/player/projectile_arrow.gd")

	for i in arrow_count:
		var angle_offset: float = -spread / 2.0 + spread / float(arrow_count - 1) * i if arrow_count > 1 else 0.0
		var dir: Vector2 = base_dir.rotated(angle_offset)

		var arrow = Area2D.new()
		arrow.set_script(arrow_script)
		arrow.collision_layer = 0
		arrow.collision_mask = 4

		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(10, 3)
		col.shape = shape
		col.rotation = dir.angle()
		arrow.add_child(col)

		arrow.global_position = global_position + dir * 8
		player.get_parent().add_child(arrow)
		arrow.setup(dir, dmg, 120.0, 1, player)

	player._camera_shake(2.5, 0.15)
	_spawn_vfx(base_dir)

	await get_tree().create_timer(0.3).timeout
	queue_free()


func _spawn_vfx(dir: Vector2) -> void:
	for i in 5:
		var p = ColorRect.new()
		p.size = Vector2(2, 2)
		p.position = dir * 6 + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		p.color = Color(0.5, 1.0, 0.5, 0.8)
		add_child(p)
		var tween = create_tween()
		tween.tween_property(p, "position", p.position + dir * 12, 0.2)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.25)
