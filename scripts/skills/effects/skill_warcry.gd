extends Node2D

func execute(player: Player, data: Dictionary) -> void:
	global_position = player.global_position
	var duration: float = data["duration"]
	var atk_bonus: int = int(player.stats.get_total_attack() * data["atk_mult"])
	var def_bonus: int = int(player.stats.get_total_defense() * data["def_mult"])

	player.stats.add_buff({
		"id": "warcry",
		"atk_bonus": atk_bonus,
		"def_bonus": def_bonus,
		"timer": duration,
	})

	_spawn_vfx()

	# 金色闪光提示
	var tween = player.create_tween()
	tween.tween_property(player.sprite, "modulate", Color(1.4, 1.2, 0.6), 0.1)
	tween.tween_property(player.sprite, "modulate", Color.WHITE, 0.3)

	VfxManager.play_at("fx2_starburst", global_position, "orange", 0.45, 30.0)
	player._camera_shake(2.0, 0.1)

	await get_tree().create_timer(0.5).timeout
	queue_free()


func _spawn_vfx() -> void:
	for i in 8:
		var ring = ColorRect.new()
		var angle: float = TAU / 8.0 * i
		ring.size = Vector2(4, 2)
		ring.position = Vector2(cos(angle) * 10, sin(angle) * 10)
		ring.rotation = angle
		ring.color = Color(1.0, 0.85, 0.3, 0.9)
		add_child(ring)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.3).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
