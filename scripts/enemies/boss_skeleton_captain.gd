extends EnemyBase

## Mini Boss: 骷髅队长
## 特殊攻击: 三向箭矢散射、盾牌冲锋(击退)、低血量强化

var _spread_cooldown: float = 0.0
var _charge_cooldown: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _strengthened: bool = false

const SPREAD_INTERVAL: float = 3.0
const CHARGE_INTERVAL: float = 6.0
const PROJECTILE_SPEED: float = 65.0
const CHARGE_SPEED: float = 120.0


func _ready() -> void:
	max_hp = 60
	attack_power = 8
	move_speed = 28.0
	chase_speed = 38.0
	detection_range = 100.0
	attack_range = 50.0
	attack_cooldown = 1.8
	is_boss = true
	gold_reward = 25
	soul_reward = 4
	xp_reward = 35
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

	_spread_cooldown -= delta
	_charge_cooldown -= delta

	_check_strengthen()

	if ai_state == AIState.CHASE and _charge_cooldown <= 0 and _get_distance_to_target() < 60.0 and _get_distance_to_target() > 20.0:
		_start_charge()
		_charge_cooldown = CHARGE_INTERVAL * (0.65 if _strengthened else 1.0)
	elif ai_state == AIState.CHASE and _spread_cooldown <= 0 and _get_distance_to_target() < 80.0:
		_shoot_spread()
		_spread_cooldown = SPREAD_INTERVAL * (0.6 if _strengthened else 1.0)

	super._physics_process(delta)


func _check_strengthen() -> void:
	if _strengthened:
		return
	if float(current_hp) / float(max_hp) <= 0.4:
		_strengthened = true
		chase_speed = 50.0
		attack_power = 11
		attack_cooldown = 1.2
		_flash_strengthen()


func _flash_strengthen() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(1.5, 1.5, 2.0), 0.1)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tw.set_loops(3)


func _perform_attack() -> void:
	if not target:
		return
	_shoot_projectile(_get_direction_to_target())


func _shoot_spread() -> void:
	if not target:
		return
	var base_dir = _get_direction_to_target()
	var spread_angle = 0.35  # ~20 degrees
	_shoot_projectile(base_dir)
	_shoot_projectile(base_dir.rotated(spread_angle))
	_shoot_projectile(base_dir.rotated(-spread_angle))


func _shoot_projectile(dir: Vector2) -> void:
	var projectile = Area2D.new()
	projectile.collision_layer = 0
	projectile.collision_mask = 3

	var spr = Sprite2D.new()
	var tex = load("res://assets/sprites/projectiles/bolt_purple.png")
	if tex:
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.rotation = dir.angle()
	projectile.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 2.0
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

	var target_pos = global_position + dir * 90
	var tw = create_tween()
	tw.tween_property(projectile, "global_position", target_pos, 90.0 / PROJECTILE_SPEED)
	tw.tween_callback(projectile.queue_free)


func _start_charge() -> void:
	if not target:
		return
	_is_charging = true
	_charge_dir = _get_direction_to_target()
	velocity = _charge_dir * CHARGE_SPEED
	sprite.modulate = Color(1.5, 1.5, 2.0)

	await get_tree().create_timer(0.4).timeout
	_is_charging = false
	sprite.modulate = Color.WHITE



func _process_charge(_delta: float) -> void:
	velocity = _charge_dir * CHARGE_SPEED
	if not hitbox:
		return
	for body in hitbox.get_overlapping_bodies():
		if body is Player:
			var dir = global_position.direction_to(body.global_position)
			(body as Player).take_damage(attack_power + 4, dir * 1.5)
			_is_charging = false
