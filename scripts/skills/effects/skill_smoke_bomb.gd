extends Node2D

var _player: Player
var _duration: float = 3.0
var _slow_pct: float = 0.5
var _radius: float = 36.0
var _timer: float = 0.0
var _active: bool = false


func execute(player: Player, data: Dictionary) -> void:
	_player = player
	_duration = data["duration"]
	_slow_pct = data["slow_percent"]
	_radius = data["radius"]
	_timer = _duration
	_active = true

	global_position = player.global_position
	_create_smoke_visual()

	# 隐身：敌人AI无法锁定玩家
	player.is_invisible = true
	var tween = player.create_tween()
	tween.tween_property(player.sprite, "modulate:a", 0.2, 0.15)

	_apply_slow_nearby()


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta

	# 持续减速新进入范围的敌人
	_apply_slow_nearby()

	if _timer <= 0:
		_active = false
		_end_effect()


func _apply_slow_nearby() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD:
			continue
		if e.global_position.distance_to(global_position) <= _radius:
			if e.has_method("apply_slow"):
				(e as EnemyBase).apply_slow(0.5, _slow_pct)


func _end_effect() -> void:
	if _player and is_instance_valid(_player):
		_player.is_invisible = false
		var tween = _player.create_tween()
		tween.tween_property(_player.sprite, "modulate:a", 1.0, 0.3)

	var fade_tw = create_tween()
	fade_tw.tween_property(self, "modulate:a", 0.0, 0.4)
	fade_tw.tween_callback(queue_free)


func _create_smoke_visual() -> void:
	for i in 12:
		var cloud = ColorRect.new()
		var angle: float = TAU / 12.0 * i
		var dist: float = randf_range(6, _radius * 0.6)
		cloud.size = Vector2(randf_range(4, 8), randf_range(4, 8))
		cloud.position = Vector2(cos(angle) * dist, sin(angle) * dist)
		cloud.color = Color(0.3, 0.3, 0.35, randf_range(0.3, 0.6))
		add_child(cloud)

		var tween = create_tween().set_loops(int(_duration / 1.5))
		tween.tween_property(cloud, "position", cloud.position + Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.8)
		tween.tween_property(cloud, "position", cloud.position, 0.7)
