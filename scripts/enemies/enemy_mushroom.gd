extends EnemyBase

## 蘑菇怪：靠近释放孢子云AoE，减速玩家

var _spore_cooldown: float = 0.0
const SPORE_INTERVAL: float = 4.0
const SPORE_RADIUS: float = 24.0


func _ready() -> void:
	max_hp = 14
	attack_power = 4
	move_speed = 15.0
	chase_speed = 20.0
	detection_range = 50.0
	attack_range = 18.0
	attack_cooldown = 1.5
	gold_reward = 3
	soul_reward = 1
	xp_reward = 11
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		return
	if ai_state == AIState.DEAD:
		return

	_spore_cooldown -= delta
	if _spore_cooldown <= 0 and ai_state == AIState.CHASE:
		var dist = _get_distance_to_target()
		if dist < SPORE_RADIUS:
			_release_spores()
			_spore_cooldown = SPORE_INTERVAL


func _release_spores() -> void:
	var vfx = ColorRect.new()
	var size = SPORE_RADIUS * 2
	vfx.size = Vector2(size, size)
	vfx.position = global_position - Vector2(SPORE_RADIUS, SPORE_RADIUS)
	vfx.color = Color(0.2, 0.6, 0.1, 0.25)
	get_parent().add_child(vfx)

	_apply_spore_damage()

	var tw = create_tween()
	tw.tween_property(vfx, "color:a", 0.4, 0.2)
	tw.tween_property(vfx, "color:a", 0.0, 1.5)
	tw.tween_callback(vfx.queue_free)

	sprite.modulate = Color(0.5, 1.0, 0.3)
	var ctw = create_tween()
	ctw.tween_property(sprite, "modulate", Color.WHITE, 0.4)


func _apply_spore_damage() -> void:
	var dmg = attack_power
	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			if p.global_position.distance_to(global_position) <= SPORE_RADIUS:
				var dir = global_position.direction_to(p.global_position)
				(p as Player).take_damage(dmg, dir)
	else:
		if target and is_instance_valid(target) and target is Player:
			if target.global_position.distance_to(global_position) <= SPORE_RADIUS:
				var dir = global_position.direction_to(target.global_position)
				(target as Player).take_damage(dmg, dir)
