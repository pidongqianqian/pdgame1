extends CharacterBody2D
class_name EnemyBase

signal died_in_room(room_index: int, pos: Vector2, is_boss: bool, gold: int, xp_reward: int, killer_peer: int)

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
@export var xp_reward: int = 12

const SEPARATION_RADIUS = 16.0
const SEPARATION_FORCE = 60.0
const PLAYER_MIN_DIST = 8.0
const PLAYER_PUSH_FORCE = 35.0

var current_hp: int
var ai_state: AIState = AIState.IDLE
var room_index: int = -1
var target: Node2D = null

var _last_attacker_peer: int = 0
var _attack_cd_timer: float = 0.0
var _patrol_direction: Vector2 = Vector2.ZERO
var _patrol_timer: float = 0.0
var _hurt_timer: float = 0.0
var _idle_timer: float = 0.0

# 状态异常
var _freeze_timer: float = 0.0
var _slow_timer: float = 0.0
var _slow_percent: float = 0.0
var _is_frozen: bool = false

# Multiplayer sync
var _sync_timer: float = 0.0
const ENEMY_SYNC_INTERVAL: float = 1.0 / 15.0
var _remote_target_pos: Vector2 = Vector2.ZERO
var _oob_check_timer: float = 0.0
const OOB_CHECK_INTERVAL: float = 0.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	current_hp = max_hp
	_idle_timer = randf_range(0.5, 2.0)
	_remote_target_pos = global_position
	add_to_group("enemies")
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_remote_enemy_process(delta)
		return

	_oob_check_timer -= delta
	if _oob_check_timer <= 0.0:
		_oob_check_timer = OOB_CHECK_INTERVAL
		_check_out_of_bounds()

	_update_debuffs(delta)
	if _is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		_broadcast_sync(delta)
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
	if _slow_timer > 0.0:
		velocity *= (1.0 - _slow_percent)
	move_and_slide()
	_broadcast_sync(delta)


func _remote_enemy_process(delta: float) -> void:
	global_position = global_position.lerp(_remote_target_pos, 15.0 * delta)
	if _remote_target_pos.x < global_position.x - 0.1:
		sprite.flip_h = true
	elif _remote_target_pos.x > global_position.x + 0.1:
		sprite.flip_h = false


func _broadcast_sync(delta: float) -> void:
	if not NetworkManager.is_multiplayer_active():
		return
	_sync_timer += delta
	if _sync_timer >= ENEMY_SYNC_INTERVAL:
		_sync_timer = 0.0
		_rpc_sync_pos.rpc(global_position, int(ai_state))


func _check_out_of_bounds() -> void:
	var dungeon = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if not dungeon or not dungeon.has_method("is_floor_at"):
		return
	if not dungeon.is_floor_at(global_position):
		var safe_pos: Vector2
		if room_index >= 0 and dungeon.has_method("get_room_center"):
			safe_pos = dungeon.get_room_center(room_index)
		else:
			safe_pos = Vector2(160, 160)
		global_position = safe_pos
		velocity = Vector2.ZERO


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
		var nearest: Node2D = null
		var nearest_dist: float = INF
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			if (p as Player).is_invisible:
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
		var pl: Player = GameManager.player_node as Player
		if pl.is_invisible:
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
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_rpc_request_damage.rpc_id(1, amount, from_dir)
		_show_damage_number(amount)
		_flash_white()
		return
	var attacker: int = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active() else 0
	_apply_host_damage(amount, from_dir, attacker)


func _apply_host_damage(amount: int, from_dir: Vector2, attacker_peer: int) -> void:
	if ai_state == AIState.DEAD:
		return
	_last_attacker_peer = attacker_peer
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
	var sender: int = multiplayer.get_remote_sender_id()
	_apply_host_damage(amount, from_dir, sender)


@rpc("authority", "call_remote", "unreliable")
func _rpc_sync_pos(pos: Vector2, state: int) -> void:
	_remote_target_pos = pos
	ai_state = state as AIState


func _die() -> void:
	ai_state = AIState.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	GameManager.add_souls(soul_reward)
	var xp: int = xp_reward if not is_boss else randi_range(50, 80)
	died_in_room.emit(room_index, global_position, is_boss, gold_reward, xp, _last_attacker_peer)

	if NetworkManager.is_multiplayer_active() and multiplayer.is_server():
		_rpc_remote_die.rpc()

	_play_death_anim()


func _play_death_anim() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.3), 0.15)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


@rpc("authority", "call_remote", "reliable")
func _rpc_remote_die() -> void:
	if ai_state == AIState.DEAD:
		return
	ai_state = AIState.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	_play_death_anim()


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


func _update_debuffs(delta: float) -> void:
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_is_frozen = false
			sprite.modulate = Color.WHITE
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_percent = 0.0
			if not _is_frozen:
				sprite.modulate = Color.WHITE


func apply_freeze(duration: float) -> void:
	_freeze_timer = duration
	_is_frozen = true
	sprite.modulate = Color(0.4, 0.7, 1.0)


func apply_slow(duration: float, percent: float = 0.5) -> void:
	_slow_timer = duration
	_slow_percent = percent
	if not _is_frozen:
		sprite.modulate = Color(0.6, 0.8, 1.0)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player and ai_state != AIState.DEAD:
		if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
			return
		var dir = global_position.direction_to(body.global_position)
		(body as Player).take_damage(attack_power, dir)
