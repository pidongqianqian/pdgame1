extends EnemyBase

## Mini Boss: 巨型史莱姆
## 特殊攻击: 地面震击(AoE)、酸液喷射、低血量狂暴

var _slam_cooldown: float = 0.0
var _acid_cooldown: float = 0.0
var _is_slamming: bool = false
var _enraged: bool = false

const SLAM_INTERVAL: float = 5.0
const ACID_INTERVAL: float = 3.5
const SLAM_RADIUS: float = 30.0
const ACID_SPEED: float = 55.0


func _ready() -> void:
	max_hp = 80
	attack_power = 7
	move_speed = 18.0
	chase_speed = 28.0
	detection_range = 90.0
	attack_range = 14.0
	attack_cooldown = 1.3
	is_boss = true
	gold_reward = 30
	soul_reward = 5
	xp_reward = 40
	super._ready()
	sprite.modulate = Color(0.6, 1.0, 0.4)


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_remote_enemy_process(delta)
		return

	if _is_slamming:
		velocity = Vector2.ZERO
		move_and_slide()
		_broadcast_sync(delta)
		return

	_slam_cooldown -= delta
	_acid_cooldown -= delta

	_check_enrage()

	if ai_state == AIState.CHASE and _slam_cooldown <= 0 and _get_distance_to_target() < 50.0:
		_do_slam()
		_slam_cooldown = SLAM_INTERVAL * (0.6 if _enraged else 1.0)
	elif ai_state == AIState.CHASE and _acid_cooldown <= 0 and _get_distance_to_target() < 70.0:
		_shoot_acid()
		_acid_cooldown = ACID_INTERVAL * (0.6 if _enraged else 1.0)

	super._physics_process(delta)


func _check_enrage() -> void:
	if _enraged:
		return
	if float(current_hp) / float(max_hp) <= 0.3:
		_enraged = true
		chase_speed = 42.0
		attack_cooldown = 0.8
		sprite.modulate = Color(0.4, 0.85, 0.2)
		_flash_phase_change()


func _flash_phase_change() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	tw.tween_property(sprite, "modulate", Color(0.4, 0.85, 0.2), 0.08)
	tw.set_loops(4)


func _do_slam() -> void:
	if not target:
		return
	_is_slamming = true

	var tw = create_tween()
	tw.tween_property(sprite, "position:y", -10.0, 0.3).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_callback(_slam_impact)


func _slam_impact() -> void:
	_is_slamming = false
	_spawn_slam_vfx()

	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= SLAM_RADIUS:
				var dir = global_position.direction_to(p.global_position)
				(p as Player).take_damage(attack_power + 3, dir)
	else:
		if target and is_instance_valid(target) and target is Player:
			var dist = global_position.distance_to(target.global_position)
			if dist <= SLAM_RADIUS:
				var dir = global_position.direction_to(target.global_position)
				(target as Player).take_damage(attack_power + 3, dir)


func _spawn_slam_vfx() -> void:
	var ring = ColorRect.new()
	ring.size = Vector2(SLAM_RADIUS * 2, SLAM_RADIUS * 2)
	ring.position = global_position - Vector2(SLAM_RADIUS, SLAM_RADIUS)
	ring.color = Color(0.3, 0.8, 0.1, 0.35)
	get_parent().add_child(ring)
	var tw = create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)


func _shoot_acid() -> void:
	if not target:
		return
	var dir = _get_direction_to_target()
	var projectile = Area2D.new()
	projectile.collision_layer = 0
	projectile.collision_mask = 3

	var spr = Sprite2D.new()
	var tex = load("res://assets/sprites/projectiles/acid_spit.png")
	if tex:
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.rotation = dir.angle()
	projectile.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 3.0
	col.shape = shape
	projectile.add_child(col)

	projectile.global_position = global_position
	get_parent().add_child(projectile)

	var dmg = attack_power
	projectile.body_entered.connect(func(body):
		if body is Player:
			(body as Player).take_damage(dmg, dir)
		projectile.queue_free()
	)

	var target_pos = global_position + dir * 80
	var tw = create_tween()
	tw.tween_property(projectile, "global_position", target_pos, 80.0 / ACID_SPEED)
	tw.tween_callback(projectile.queue_free)
