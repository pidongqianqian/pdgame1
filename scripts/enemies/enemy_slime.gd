extends EnemyBase

var _jump_timer: float = 0.0
var _is_jumping: bool = false


func _ready() -> void:
	max_hp = 15
	attack_power = 4
	move_speed = 20.0
	chase_speed = 35.0
	detection_range = 60.0
	attack_range = 12.0
	attack_cooldown = 1.5
	gold_reward = 3
	soul_reward = 1
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		return
	_jump_timer -= delta
	if _jump_timer <= 0 and ai_state == AIState.CHASE:
		_jump_timer = randf_range(1.0, 2.0)
		_do_jump()


func _do_jump() -> void:
	var dist = _get_distance_to_target()
	if dist < attack_range * 1.5:
		return
	_is_jumping = true
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", -5.0, 0.12)
	tween.tween_property(sprite, "position:y", 0.0, 0.12)
	tween.tween_callback(func(): _is_jumping = false)

	sprite.modulate = Color(0.8, 1.2, 0.8)
	var color_tw = create_tween()
	color_tw.tween_property(sprite, "modulate", Color.WHITE, 0.24)

	var jump_speed = chase_speed * 1.3
	velocity = _get_direction_to_target() * jump_speed
