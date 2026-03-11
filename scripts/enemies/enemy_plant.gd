extends EnemyBase

## 食人植物：固定不动，远程吐毒液弹

const SPIT_SPEED: float = 45.0
var _spit_cooldown: float = 0.0
const SPIT_INTERVAL: float = 2.5


func _ready() -> void:
	max_hp = 18
	attack_power = 6
	move_speed = 0.0
	chase_speed = 0.0
	detection_range = 80.0
	attack_range = 70.0
	attack_cooldown = 2.5
	gold_reward = 4
	soul_reward = 1
	xp_reward = 13
	super._ready()


func _state_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	if _get_distance_to_target() <= detection_range:
		ai_state = AIState.CHASE


func _state_patrol(_delta: float) -> void:
	velocity = Vector2.ZERO
	ai_state = AIState.IDLE


func _state_chase(_delta: float) -> void:
	velocity = Vector2.ZERO
	var dist = _get_distance_to_target()
	if dist > detection_range * 1.5:
		ai_state = AIState.IDLE
		return
	if dist <= attack_range and _attack_cd_timer <= 0:
		ai_state = AIState.ATTACK


func _perform_attack() -> void:
	if not target or not is_instance_valid(target):
		return
	_spit_projectile()
	_play_attack_anim()


func _play_attack_anim() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.08)
	tw.tween_property(sprite, "scale", Vector2(0.9, 1.15), 0.08)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.08)


func _spit_projectile() -> void:
	var dir = _get_direction_to_target()

	for i in 2:
		var angle = (float(i) - 0.5) * 0.15
		var d = dir.rotated(angle)
		_spawn_spit(d)


func _spawn_spit(dir: Vector2) -> void:
	var proj = Area2D.new()
	proj.collision_layer = 0
	proj.collision_mask = 3

	var spr = ColorRect.new()
	spr.size = Vector2(3, 3)
	spr.position = Vector2(-1.5, -1.5)
	spr.color = Color(0.2, 0.7, 0.0, 0.9)
	proj.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 2.0
	col.shape = shape
	proj.add_child(col)

	proj.global_position = global_position
	get_parent().add_child(proj)

	var dmg = attack_power
	proj.body_entered.connect(func(body):
		if body is Player:
			(body as Player).take_damage(dmg, dir)
		proj.queue_free()
	)

	var target_pos = global_position + dir * 80
	var tw = create_tween()
	tw.tween_property(proj, "global_position", target_pos, 80.0 / SPIT_SPEED)
	tw.tween_callback(proj.queue_free)
