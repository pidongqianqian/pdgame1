extends EnemyBase

## 哥布林：血少速快，攻击后侧闪

var _strafe_timer: float = 0.0
var _strafe_dir: float = 1.0


func _ready() -> void:
	max_hp = 10
	attack_power = 5
	move_speed = 40.0
	chase_speed = 70.0
	detection_range = 70.0
	attack_range = 12.0
	attack_cooldown = 0.8
	gold_reward = 4
	soul_reward = 1
	xp_reward = 10
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		return
	if ai_state == AIState.DEAD:
		return
	_strafe_timer -= delta
	if _strafe_timer <= 0 and ai_state == AIState.CHASE:
		var dist = _get_distance_to_target()
		if dist < attack_range * 2.5 and dist > attack_range * 0.5:
			_do_strafe()
			_strafe_timer = randf_range(0.8, 1.5)


func _perform_attack() -> void:
	super._perform_attack()
	_do_strafe()


func _do_strafe() -> void:
	if not target or not is_instance_valid(target):
		return
	_strafe_dir *= -1.0
	var to_target = _get_direction_to_target()
	var perp = Vector2(-to_target.y, to_target.x) * _strafe_dir
	velocity = perp * chase_speed * 0.8

	var tw = create_tween()
	tw.tween_property(sprite, "position:x", 2.0 * _strafe_dir, 0.06)
	tw.tween_property(sprite, "position:x", 0.0, 0.06)
