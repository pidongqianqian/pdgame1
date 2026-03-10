extends EnemyBase

enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }

var boss_phase: BossPhase = BossPhase.PHASE_1
var _charge_timer: float = 0.0
var _is_charging: bool = false
var _spin_attack_timer: float = 0.0
var _phase_changed: bool = false


func _ready() -> void:
	max_hp = 120
	attack_power = 10
	move_speed = 30.0
	chase_speed = 40.0
	detection_range = 120.0
	attack_range = 16.0
	attack_cooldown = 1.2
	is_boss = true
	gold_reward = 50
	soul_reward = 10
	super._ready()
	sprite.modulate = Color(1.0, 0.85, 0.85)


func _physics_process(delta: float) -> void:
	_update_phase()
	if _is_charging:
		_process_charge(delta)
		move_and_slide()
		return
	super._physics_process(delta)

	_charge_timer -= delta
	if _charge_timer <= 0 and ai_state == AIState.CHASE and boss_phase != BossPhase.PHASE_1:
		_start_charge()
		_charge_timer = 5.0 if boss_phase == BossPhase.PHASE_2 else 3.5


func _update_phase() -> void:
	var hp_pct = float(current_hp) / float(max_hp)
	var new_phase = boss_phase
	if hp_pct <= 0.3:
		new_phase = BossPhase.PHASE_3
	elif hp_pct <= 0.6:
		new_phase = BossPhase.PHASE_2

	if new_phase != boss_phase:
		boss_phase = new_phase
		_on_phase_change()


func _on_phase_change() -> void:
	match boss_phase:
		BossPhase.PHASE_2:
			chase_speed = 50.0
			attack_power = 14
			attack_cooldown = 0.9
			sprite.modulate = Color(1.2, 0.7, 0.7)
		BossPhase.PHASE_3:
			chase_speed = 60.0
			attack_power = 18
			attack_cooldown = 0.7
			sprite.modulate = Color(1.5, 0.5, 0.5)
	_flash_phase_change()


func _flash_phase_change() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", sprite.modulate, 0.1)
	tween.set_loops(3)


func _start_charge() -> void:
	if not target:
		return
	_is_charging = true
	var dir = _get_direction_to_target()
	velocity = dir * chase_speed * 3.0
	sprite.modulate = Color(2, 1, 1)
	await get_tree().create_timer(0.5).timeout
	_is_charging = false
	sprite.modulate = Color(1.0, 0.85, 0.85) if boss_phase == BossPhase.PHASE_1 else sprite.modulate


func _process_charge(_delta: float) -> void:
	var bodies = hitbox.get_overlapping_bodies() if hitbox else []
	for body in bodies:
		if body is Player:
			var dir = body.global_position.direction_to(global_position)
			(body as Player).take_damage(attack_power + 5, -dir)
			_is_charging = false


func _perform_attack() -> void:
	super._perform_attack()
	if boss_phase == BossPhase.PHASE_3 and randf() > 0.5:
		_aoe_attack()


func _aoe_attack() -> void:
	if not target:
		return
	var dist = _get_distance_to_target()
	if dist <= attack_range * 2.5 and target is Player:
		var dir = global_position.direction_to(target.global_position)
		(target as Player).take_damage(int(attack_power * 0.7), -dir)

	var ring = Node2D.new()
	ring.global_position = global_position
	get_parent().add_child(ring)
	var ring_sprite = ColorRect.new()
	ring_sprite.size = Vector2(30, 30)
	ring_sprite.position = Vector2(-15, -15)
	ring_sprite.color = Color(1, 0.2, 0.2, 0.4)
	ring.add_child(ring_sprite)
	var tween = create_tween()
	tween.tween_property(ring_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)
