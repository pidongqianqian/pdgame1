extends EnemyBase

const PROJECTILE_SPEED = 70.0
var _shoot_timer: float = 0.0


func _ready() -> void:
	max_hp = 12
	attack_power = 6
	move_speed = 25.0
	chase_speed = 30.0
	detection_range = 90.0
	attack_range = 60.0
	attack_cooldown = 2.0
	gold_reward = 5
	soul_reward = 1
	super._ready()


func _perform_attack() -> void:
	if not target:
		return
	_shoot_projectile()


func _shoot_projectile() -> void:
	var dir = _get_direction_to_target()
	var projectile = Area2D.new()
	projectile.collision_layer = 0
	projectile.collision_mask = 3

	var spr = Sprite2D.new()
	var tex = load("res://assets/sprites/projectiles/arrow_fire.png")
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

	projectile.body_entered.connect(func(body):
		if body is Player:
			(body as Player).take_damage(attack_power, dir)
		projectile.queue_free()
	)

	var tween = create_tween()
	var target_pos = global_position + dir * 100
	tween.tween_property(projectile, "global_position", target_pos, 100.0 / PROJECTILE_SPEED)
	tween.tween_callback(projectile.queue_free)
