extends EnemyBase

## Mini Boss: 鹿人
## 特殊攻击: 鹿角横扫(宽弧)、冲锋撞击、低血量狂暴

var _charge_cooldown: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _enraged: bool = false

const CHARGE_INTERVAL: float = 5.0
const CHARGE_SPEED: float = 130.0
const SWEEP_RANGE: float = 20.0


func _ready() -> void:
	max_hp = 70
	attack_power = 9
	move_speed = 30.0
	chase_speed = 45.0
	detection_range = 100.0
	attack_range = 16.0
	attack_cooldown = 1.0
	is_boss = true
	gold_reward = 28
	soul_reward = 5
	xp_reward = 38
	super._ready()


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_remote_enemy_process(delta)
		return

	if _is_charging:
		_process_charge(delta)
		move_and_slide()
		_broadcast_sync(delta)
		return

	_charge_cooldown -= delta
	_check_enrage()

	if ai_state == AIState.CHASE and _charge_cooldown <= 0:
		var dist = _get_distance_to_target()
		if dist > 25.0 and dist < 80.0:
			_start_charge()
			_charge_cooldown = CHARGE_INTERVAL * (0.5 if _enraged else 1.0)

	super._physics_process(delta)


func _check_enrage() -> void:
	if _enraged:
		return
	if float(current_hp) / float(max_hp) <= 0.35:
		_enraged = true
		chase_speed = 60.0
		attack_power = 13
		attack_cooldown = 0.7
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 0.8, 0.8), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tw.set_loops(4)


func _perform_attack() -> void:
	_antler_sweep()


func _antler_sweep() -> void:
	_play_attack_anim()
	var dmg = attack_power + (3 if _enraged else 0)
	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			if p.global_position.distance_to(global_position) <= SWEEP_RANGE:
				var dir = global_position.direction_to(p.global_position)
				(p as Player).take_damage(dmg, dir * 1.3)
	else:
		if target and is_instance_valid(target) and target is Player:
			if target.global_position.distance_to(global_position) <= SWEEP_RANGE:
				var dir = global_position.direction_to(target.global_position)
				(target as Player).take_damage(dmg, dir * 1.3)

	var vfx = ColorRect.new()
	vfx.size = Vector2(SWEEP_RANGE * 2, SWEEP_RANGE * 2)
	vfx.position = global_position - Vector2(SWEEP_RANGE, SWEEP_RANGE)
	vfx.color = Color(0.6, 0.4, 0.2, 0.2)
	get_parent().add_child(vfx)
	var tw = create_tween()
	tw.tween_property(vfx, "modulate:a", 0.0, 0.3)
	tw.tween_callback(vfx.queue_free)


func _start_charge() -> void:
	if not target:
		return
	_is_charging = true
	_charge_dir = _get_direction_to_target()
	velocity = _charge_dir * CHARGE_SPEED
	sprite.modulate = Color(1.5, 1.2, 0.8)

	await get_tree().create_timer(0.45).timeout
	_is_charging = false
	sprite.modulate = Color.WHITE


func _process_charge(_delta: float) -> void:
	velocity = _charge_dir * CHARGE_SPEED
	if not hitbox:
		return
	for body in hitbox.get_overlapping_bodies():
		if body is Player:
			var dir = global_position.direction_to(body.global_position)
			(body as Player).take_damage(attack_power + 5, dir * 1.5)
			_is_charging = false
