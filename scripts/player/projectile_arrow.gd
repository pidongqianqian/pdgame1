extends Area2D

var damage: int = 14
var vel: Vector2 = Vector2.ZERO
var max_penetrate: int = 2
var owner_ref: Node2D = null

var _hit_count: int = 0
var _lifetime: float = 0.7


func _ready() -> void:
	add_to_group("player_projectiles")
	body_entered.connect(_on_body_entered)

	var timer = get_tree().create_timer(_lifetime)
	timer.timeout.connect(queue_free)


func setup(dir: Vector2, dmg: int, speed: float, penetrate: int, owner_node: Node2D) -> void:
	vel = dir * speed
	damage = dmg
	max_penetrate = penetrate
	owner_ref = owner_node

	# 箭矢精灵
	var arrow_sprite = Sprite2D.new()
	var bow_tex = load("res://assets/sprites/items/bow.png")
	if bow_tex:
		arrow_sprite.texture = bow_tex
		arrow_sprite.scale = Vector2(0.6, 0.6)
	else:
		var shaft = ColorRect.new()
		shaft.size = Vector2(10, 2)
		shaft.position = Vector2(-5, -1)
		shaft.color = Color(0.5, 1.0, 0.55)
		add_child(shaft)
	arrow_sprite.modulate = Color(0.7, 1.0, 0.7)
	add_child(arrow_sprite)

	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	global_position += vel * delta


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
			owner_ref._camera_shake(1.5, 0.08)

	# 箭矢命中闪光
	var flash = ColorRect.new()
	flash.size = Vector2(5, 5)
	flash.position = Vector2(-2.5, -2.5)
	flash.color = Color(0.7, 1.0, 0.6, 0.9)
	get_parent().add_child(flash)
	flash.global_position = body.global_position
	var ftw = create_tween()
	ftw.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.08)
	ftw.parallel().tween_property(flash, "modulate:a", 0.0, 0.10)
	ftw.tween_callback(flash.queue_free)

	if _hit_count >= max_penetrate:
		queue_free()
