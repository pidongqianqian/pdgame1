extends EnemyBase

## 眼球怪：远程浮游型，保持距离射击，靠近则后退

const BEAM_SPEED: float = 60.0
const RETREAT_RANGE: float = 30.0
var _float_offset: float = 0.0


func _ready() -> void:
	max_hp = 8
	attack_power = 7
	move_speed = 18.0
	chase_speed = 22.0
	detection_range = 120.0
	attack_range = 80.0
	attack_cooldown = 2.2
	gold_reward = 5
	soul_reward = 1
	xp_reward = 14
	super._ready()


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_remote_enemy_process(delta)
		_animate_float(delta)
		return

	_animate_float(delta)

	_oob_check_timer -= delta
	if _oob_check_timer <= 0.0:
		_oob_check_timer = OOB_CHECK_INTERVAL
		_check_out_of_bounds()

	if ai_state == AIState.CHASE and target and is_instance_valid(target):
		var dist = _get_distance_to_target()
		if dist < RETREAT_RANGE:
			var away = -_get_direction_to_target()
			velocity = away * chase_speed * 1.2
			_update_sprite_facing()
			move_and_slide()
			_broadcast_sync(delta)
			_update_timers(delta)
			return

	super._physics_process(delta)


func _animate_float(delta: float) -> void:
	_float_offset += delta * 3.0
	sprite.position.y = sin(_float_offset) * 2.0


func _perform_attack() -> void:
	if not target or not is_instance_valid(target):
		return
	_shoot_beam()


func _shoot_beam() -> void:
	var dir = _get_direction_to_target()
	var beam = Area2D.new()
	beam.collision_layer = 0
	beam.collision_mask = 3

	var spr = Sprite2D.new()
	var tex = load("res://assets/sprites/projectiles/beam_cyan.png")
	if tex:
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beam.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 2.5
	col.shape = shape
	beam.add_child(col)

	beam.global_position = global_position
	get_parent().add_child(beam)

	var dmg = attack_power
	beam.body_entered.connect(func(body):
		if body is Player:
			(body as Player).take_damage(dmg, dir)
		beam.queue_free()
	)

	var target_pos = global_position + dir * 100
	var tw = create_tween()
	tw.tween_property(beam, "global_position", target_pos, 100.0 / BEAM_SPEED)
	tw.tween_callback(beam.queue_free)
