extends EnemyBase

## Big Boss: 烈焰元素
## 特殊攻击: 火球投射、火焰喷吐(锥形)、延迟爆发(玩家脚下)、移动火焰轨迹
## 三阶段变化

enum Phase { PHASE_1, PHASE_2, PHASE_3 }

var phase: Phase = Phase.PHASE_1
var _fireball_cooldown: float = 0.0
var _breath_cooldown: float = 0.0
var _eruption_cooldown: float = 0.0
var _trail_timer: float = 0.0
var _leave_trail: bool = false

const FIREBALL_SPEED: float = 60.0


func _ready() -> void:
	max_hp = 160
	attack_power = 10
	move_speed = 25.0
	chase_speed = 32.0
	detection_range = 120.0
	attack_range = 70.0
	attack_cooldown = 1.5
	is_boss = true
	gold_reward = 65
	soul_reward = 13
	xp_reward = 75
	super._ready()


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_remote_enemy_process(delta)
		return

	_update_phase()
	_fireball_cooldown -= delta
	_breath_cooldown -= delta
	_eruption_cooldown -= delta

	if _leave_trail:
		_trail_timer -= delta
		if _trail_timer <= 0 and velocity.length() > 5.0:
			_spawn_fire_patch(global_position, 6.0, 2.5)
			_trail_timer = 0.4

	var dist = _get_distance_to_target()

	if _breath_cooldown <= 0 and dist < 35.0 and dist > 8.0:
		_fire_breath()
		_breath_cooldown = _get_breath_interval()
	elif _eruption_cooldown <= 0 and dist < 80.0 and phase != Phase.PHASE_1:
		_delayed_eruption()
		_eruption_cooldown = _get_eruption_interval()
	elif _fireball_cooldown <= 0 and dist < 90.0:
		_shoot_fireball()
		_fireball_cooldown = _get_fireball_interval()

	super._physics_process(delta)


func _update_phase() -> void:
	var hp_pct = float(current_hp) / float(max_hp)
	var new_phase = phase
	if hp_pct <= 0.25:
		new_phase = Phase.PHASE_3
	elif hp_pct <= 0.55:
		new_phase = Phase.PHASE_2
	if new_phase != phase:
		phase = new_phase
		_on_phase_change()


func _on_phase_change() -> void:
	match phase:
		Phase.PHASE_2:
			attack_power = 14
			chase_speed = 38.0
			_leave_trail = true
			sprite.modulate = Color(1.2, 0.8, 0.6)
		Phase.PHASE_3:
			attack_power = 18
			chase_speed = 45.0
			sprite.modulate = Color(1.5, 0.6, 0.4)
	_flash_phase()


func _flash_phase() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(2.0, 1.5, 0.5), 0.08)
	tw.tween_property(sprite, "modulate", sprite.modulate, 0.08)
	tw.set_loops(4)


func _get_fireball_interval() -> float:
	match phase:
		Phase.PHASE_3: return 1.0
		Phase.PHASE_2: return 1.5
		_: return 2.2

func _get_breath_interval() -> float:
	match phase:
		Phase.PHASE_3: return 4.0
		Phase.PHASE_2: return 6.0
		_: return 8.0

func _get_eruption_interval() -> float:
	match phase:
		Phase.PHASE_3: return 4.0
		_: return 7.0


func _perform_attack() -> void:
	_shoot_fireball()


func _shoot_fireball() -> void:
	if not target or not is_instance_valid(target):
		return
	var dir = _get_direction_to_target()
	var count = 1 if phase == Phase.PHASE_1 else (2 if phase == Phase.PHASE_2 else 3)

	for i in count:
		var angle_offset = 0.0
		if count > 1:
			angle_offset = (float(i) - float(count - 1) / 2.0) * 0.25
		_spawn_fireball(dir.rotated(angle_offset))


func _spawn_fireball(dir: Vector2) -> void:
	var proj = Area2D.new()
	proj.collision_layer = 0
	proj.collision_mask = 3

	var spr = ColorRect.new()
	spr.size = Vector2(4, 4)
	spr.position = Vector2(-2, -2)
	spr.color = Color(1.0, 0.4, 0.1, 0.9)
	proj.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 2.5
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

	var target_pos = global_position + dir * 100
	var tw = create_tween()
	tw.tween_property(proj, "global_position", target_pos, 100.0 / FIREBALL_SPEED)
	tw.tween_callback(proj.queue_free)


func _fire_breath() -> void:
	if not target or not is_instance_valid(target):
		return
	var base_dir = _get_direction_to_target()
	var breath_angles = [-0.4, -0.2, 0.0, 0.2, 0.4]
	var breath_range = 30.0

	for angle in breath_angles:
		var dir = base_dir.rotated(angle)
		var end_pos = global_position + dir * breath_range
		_spawn_fire_patch(global_position + dir * 10.0, 5.0, 1.5)
		_spawn_fire_patch(global_position + dir * 20.0, 5.0, 1.5)

	_play_attack_anim()

	var dmg = attack_power + 3
	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			var dist = global_position.distance_to(p.global_position)
			if dist > 35.0:
				continue
			var to_player = global_position.direction_to(p.global_position)
			if base_dir.dot(to_player) > 0.5:
				(p as Player).take_damage(dmg, to_player)
	else:
		if target and is_instance_valid(target) and target is Player:
			var dist = global_position.distance_to(target.global_position)
			if dist <= 35.0:
				var to_p = global_position.direction_to(target.global_position)
				if base_dir.dot(to_p) > 0.5:
					(target as Player).take_damage(dmg, to_p)


func _delayed_eruption() -> void:
	if not target or not is_instance_valid(target):
		return

	var positions: Array[Vector2] = [target.global_position]
	if phase == Phase.PHASE_3:
		for i in 2:
			positions.append(target.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)))

	for erupt_pos in positions:
		var warning = ColorRect.new()
		warning.size = Vector2(18, 18)
		warning.position = erupt_pos - Vector2(9, 9)
		warning.color = Color(1.0, 0.3, 0.0, 0.2)
		get_parent().add_child(warning)

		var blink = create_tween()
		blink.tween_property(warning, "color:a", 0.5, 0.25)
		blink.tween_property(warning, "color:a", 0.15, 0.25)
		blink.set_loops(3)

		_eruption_explode.call_deferred(erupt_pos, warning)


func _eruption_explode(pos: Vector2, warning: ColorRect) -> void:
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(warning):
		return

	warning.color = Color(1.0, 0.4, 0.0, 0.7)

	var dmg = attack_power + 6
	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			if p.global_position.distance_to(pos) <= 14.0:
				var dir = pos.direction_to(p.global_position)
				(p as Player).take_damage(dmg, dir)
	else:
		if target and is_instance_valid(target) and target is Player:
			if target.global_position.distance_to(pos) <= 14.0:
				var dir = pos.direction_to(target.global_position)
				(target as Player).take_damage(dmg, dir)

	var fade = create_tween()
	fade.tween_property(warning, "modulate:a", 0.0, 0.4)
	fade.tween_callback(warning.queue_free)

	_spawn_fire_patch(pos, 8.0, 3.0)


func _spawn_fire_patch(pos: Vector2, radius: float, duration: float) -> void:
	var patch = ColorRect.new()
	var size = radius * 2
	patch.size = Vector2(size, size)
	patch.position = pos - Vector2(radius, radius)
	patch.color = Color(1.0, 0.3, 0.0, 0.3)
	get_parent().add_child(patch)

	var tw = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(patch, "modulate:a", 0.0, 0.5)
	tw.tween_callback(patch.queue_free)
