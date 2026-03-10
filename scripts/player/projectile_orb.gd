extends Area2D

var damage: int = 10
var vel: Vector2 = Vector2.ZERO
var homing_strength: float = 0.06
var max_penetrate: int = 2
var owner_ref: Node2D = null  # 发射者（用于生成命中特效）

var _hit_count: int = 0
var _target: Node2D = null
var _lifetime: float = 1.8
var _gfx: Node2D


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)

	_gfx = Node2D.new()
	add_child(_gfx)

	# 紫色光球（多层同心矩形模拟圆）
	for r in [6, 4, 2]:
		var ring = ColorRect.new()
		ring.size = Vector2(r * 2, r * 2)
		ring.position = Vector2(-r, -r)
		if r == 6:
			ring.color = Color(0.55, 0.25, 1.0, 0.55)
		elif r == 4:
			ring.color = Color(0.75, 0.40, 1.0, 0.80)
		else:
			ring.color = Color(1.0,  0.80, 1.0, 1.00)
		_gfx.add_child(ring)

	# 外发光晕
	var glow = ColorRect.new()
	glow.size = Vector2(14, 14)
	glow.position = Vector2(-7, -7)
	glow.color = Color(0.6, 0.3, 1.0, 0.25)
	add_child(glow)

	# 旋转动画
	var spin = create_tween().set_loops()
	spin.tween_property(_gfx, "rotation", TAU, 0.5)

	# 定时销毁
	var timer = get_tree().create_timer(_lifetime)
	timer.timeout.connect(_on_expire)


func setup(dir: Vector2, dmg: int, speed: float, penetrate: int, owner_node: Node2D) -> void:
	vel = dir * speed
	damage = dmg
	max_penetrate = penetrate
	owner_ref = owner_node
	rotation = dir.angle()
	_find_nearest_target()


func _find_nearest_target() -> void:
	if not is_inside_tree(): return
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest_dist = INF
	for e in enemies:
		if not is_instance_valid(e): continue
		var d = global_position.distance_to(e.global_position)
		if d < nearest_dist and d < 140:
			nearest_dist = d
			_target = e


func _physics_process(delta: float) -> void:
	# 追踪最近敌人
	if _target and is_instance_valid(_target):
		var desired = global_position.direction_to(_target.global_position) * vel.length()
		vel = vel.lerp(desired, homing_strength)

	global_position += vel * delta
	rotation = vel.angle()


func _on_body_entered(body: Node2D) -> void:
	if not (body is EnemyBase): return
	if (body as EnemyBase).ai_state == EnemyBase.AIState.DEAD: return

	_hit_count += 1
	var dir = vel.normalized()
	(body as EnemyBase).take_damage(damage, dir)

	if owner_ref and is_instance_valid(owner_ref):
		if owner_ref.has_method("_spawn_hit_effect"):
			owner_ref._spawn_hit_effect(body.global_position)
		if owner_ref.has_method("_camera_shake"):
			owner_ref._camera_shake(2.0, 0.10)
		if owner_ref.has_method("_freeze_frame"):
			owner_ref._freeze_frame(0.03)

	if _hit_count >= max_penetrate:
		_on_expire()


func _on_expire() -> void:
	if not is_inside_tree(): return
	set_deferred("monitoring", false)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
