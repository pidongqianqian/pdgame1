extends CharacterBody2D
class_name EnemyBase

signal died_in_room(room_index: int, pos: Vector2, is_boss: bool, gold: int)

enum AIState { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

@export var max_hp: int = 20
@export var attack_power: int = 5
@export var move_speed: float = 30.0
@export var chase_speed: float = 45.0
@export var detection_range: float = 80.0
@export var attack_range: float = 14.0
@export var attack_cooldown: float = 1.0
@export var is_boss: bool = false
@export var soul_reward: int = 1
@export var gold_reward: int = 5

const SEPARATION_RADIUS = 20.0
const SEPARATION_FORCE = 120.0
const PLAYER_MIN_DIST = 12.0
const PLAYER_PUSH_FORCE = 140.0

var current_hp: int
var ai_state: AIState = AIState.IDLE
var room_index: int = -1
var target: Node2D = null

var _attack_cd_timer: float = 0.0
var _patrol_direction: Vector2 = Vector2.ZERO
var _patrol_timer: float = 0.0
var _hurt_timer: float = 0.0
var _idle_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	current_hp = max_hp
	_idle_timer = randf_range(0.5, 2.0)
	add_to_group("enemies")
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	# 多人模式下只有 Host (peer_id=1) 运行 AI
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		return
	_update_timers(delta)
	_find_target()
	match ai_state:
		AIState.IDLE:
			_state_idle(delta)
		AIState.PATROL:
			_state_patrol(delta)
		AIState.CHASE:
			_state_chase(delta)
		AIState.ATTACK:
			_state_attack(delta)
		AIState.HURT:
			_state_hurt(delta)

	var sep = _get_separation_force()
	velocity += sep
	move_and_slide()

	# Host 每帧广播位置给所有客户端
	if NetworkManager.is_multiplayer_active():
		_rpc_sync_pos.rpc(global_position, int(ai_state))


func _get_separation_force() -> Vector2:
	var force = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		if (other as EnemyBase).ai_state == AIState.DEAD:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < SEPARATION_RADIUS and dist > 0.1:
			var away = (global_position - other.global_position).normalized()
			var strength = (1.0 - dist / SEPARATION_RADIUS) * SEPARATION_FORCE
			force += away * strength

	if target and is_instance_valid(target):
		var dist_to_player = global_position.distance_to(target.global_position)
		if dist_to_player < PLAYER_MIN_DIST and dist_to_player > 0.1:
			var away = (global_position - target.global_position).normalized()
			var strength = (1.0 - dist_to_player / PLAYER_MIN_DIST) * PLAYER_PUSH_FORCE
			force += away * strength

	return force


func _update_timers(delta: float) -> void:
	if _attack_cd_timer > 0:
		_attack_cd_timer -= delta


func _find_target() -> void:
	if NetworkManager.is_multiplayer_active():
		# 找最近的存活玩家
		var nearest: Node2D = null
		var nearest_dist: float = INF
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			var d: float = global_position.distance_to(p.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = p
		target = nearest
	else:
		if not GameManager.player_node or not is_instance_valid(GameManager.player_node):
			target = null
			return
		target = GameManager.player_node


func _get_distance_to_target() -> float:
	if not target:
		return INF
	return global_position.distance_to(target.global_position)


func _get_direction_to_target() -> Vector2:
	if not target:
		return Vector2.ZERO
	return global_position.direction_to(target.global_position)


func _state_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	_idle_timer -= delta
	if _get_distance_to_target() <= detection_range:
		ai_state = AIState.CHASE
		return
	if _idle_timer <= 0:
		ai_state = AIState.PATROL
		_patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_patrol_timer = randf_range(1.0, 3.0)


func _state_patrol(delta: float) -> void:
	velocity = _patrol_direction * move_speed
	_patrol_timer -= delta
	if _get_distance_to_target() <= detection_range:
		ai_state = AIState.CHASE
		return
	if _patrol_timer <= 0:
		ai_state = AIState.IDLE
		_idle_timer = randf_range(0.5, 2.0)
	_update_sprite_facing()


func _state_chase(delta: float) -> void:
	var dist = _get_distance_to_target()
	if dist > detection_range * 1.5:
		ai_state = AIState.IDLE
		_idle_timer = 1.0
		return
	if dist <= attack_range and _attack_cd_timer <= 0:
		ai_state = AIState.ATTACK
		return
	var dir = _get_direction_to_target()
	if dist <= attack_range:
		velocity = Vector2.ZERO
	else:
		velocity = dir * chase_speed
	_update_sprite_facing()


func _state_attack(_delta: float) -> void:
	velocity = Vector2.ZERO
	_perform_attack()
	_attack_cd_timer = attack_cooldown
	ai_state = AIState.CHASE


func _perform_attack() -> void:
	if target and target is Player and _get_distance_to_target() <= attack_range * 1.3:
		var dir = _get_direction_to_target()
		(target as Player).take_damage(attack_power, dir)
		_play_attack_anim()


func _play_attack_anim() -> void:
	var tween = create_tween()
	var lunge = _get_direction_to_target() * 3.0
	tween.tween_property(sprite, "position", lunge, 0.06)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.08)

	sprite.modulate = Color(1.3, 0.8, 0.8)
	var color_tween = create_tween()
	color_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _state_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
	if _hurt_timer <= 0:
		ai_state = AIState.CHASE


func take_damage(amount: int, from_dir: Vector2 = Vector2.ZERO) -> void:
	if ai_state == AIState.DEAD:
		return
	# 多人模式下只有 Host 处理伤害
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_rpc_request_damage.rpc_id(1, amount, from_dir)
		return
	current_hp -= amount
	_show_damage_number(amount)
	if current_hp <= 0:
		_die()
		return
	ai_state = AIState.HURT
	_hurt_timer = 0.2
	velocity = from_dir * 80
	_flash_white()

	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.05)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.05)


@rpc("any_peer", "call_local", "reliable")
func _rpc_request_damage(amount: int, from_dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	take_damage(amount, from_dir)


@rpc("authority", "call_remote", "unreliable")
func _rpc_sync_pos(pos: Vector2, state: int) -> void:
	global_position = pos
	ai_state = state as AIState


func _die() -> void:
	ai_state = AIState.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	GameManager.add_souls(soul_reward)
	died_in_room.emit(room_index, global_position, is_boss, gold_reward)

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.3), 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _flash_white() -> void:
	sprite.modulate = Color(3, 3, 3, 1)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func _update_sprite_facing() -> void:
	if velocity.x < -0.1:
		sprite.flip_h = true
	elif velocity.x > 0.1:
		sprite.flip_h = false


func _show_damage_number(amount: int) -> void:
	var label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.position = Vector2(-4 + randf_range(-3, 3), -14)
	label.z_index = 100
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 12, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(label, "scale", Vector2(1.2, 1.2), 0.08)
	tween.tween_callback(label.queue_free)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player and ai_state != AIState.DEAD:
		var dir = global_position.direction_to(body.global_position)
		(body as Player).take_damage(attack_power, dir)
