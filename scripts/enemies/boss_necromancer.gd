extends EnemyBase

## Big Boss: 亡灵法师
## 特殊攻击: 暗影飞弹(追踪)、传送、召唤骷髅小兵、死亡领域(AoE)
## 三阶段变化

enum Phase { PHASE_1, PHASE_2, PHASE_3 }

var phase: Phase = Phase.PHASE_1
var _bolt_cooldown: float = 0.0
var _teleport_cooldown: float = 0.0
var _summon_cooldown: float = 0.0
var _deathzone_cooldown: float = 0.0
var _is_teleporting: bool = false

const BOLT_SPEED: float = 50.0
const BOLT_TRACK_STRENGTH: float = 2.5

const SkeletonScene = preload("res://scenes/enemies/enemy_skeleton.tscn")


func _ready() -> void:
	max_hp = 150
	attack_power = 9
	move_speed = 20.0
	chase_speed = 25.0
	detection_range = 130.0
	attack_range = 90.0
	attack_cooldown = 2.0
	is_boss = true
	gold_reward = 60
	soul_reward = 12
	xp_reward = 70
	super._ready()


func _physics_process(delta: float) -> void:
	if ai_state == AIState.DEAD:
		return
	if NetworkManager.is_multiplayer_active() and not multiplayer.is_server():
		_remote_enemy_process(delta)
		return

	if _is_teleporting:
		velocity = Vector2.ZERO
		move_and_slide()
		_broadcast_sync(delta)
		return

	_update_phase()
	_bolt_cooldown -= delta
	_teleport_cooldown -= delta
	_summon_cooldown -= delta
	_deathzone_cooldown -= delta

	var dist = _get_distance_to_target()

	if _teleport_cooldown <= 0 and dist < 30.0:
		_do_teleport()
		_teleport_cooldown = _get_teleport_interval()
	elif _deathzone_cooldown <= 0 and dist < 60.0 and phase != Phase.PHASE_1:
		_cast_deathzone()
		_deathzone_cooldown = 8.0 if phase == Phase.PHASE_2 else 5.0
	elif _summon_cooldown <= 0:
		_summon_skeleton()
		_summon_cooldown = _get_summon_interval()
	elif _bolt_cooldown <= 0 and dist < 100.0:
		_shoot_dark_bolt()
		_bolt_cooldown = _get_bolt_interval()

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
			attack_power = 12
			sprite.modulate = Color(0.8, 0.5, 1.0)
		Phase.PHASE_3:
			attack_power = 16
			chase_speed = 35.0
			sprite.modulate = Color(0.6, 0.3, 0.9)
	_flash_phase()
	_do_teleport()


func _flash_phase() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	tw.tween_property(sprite, "modulate", sprite.modulate, 0.08)
	tw.set_loops(4)


func _get_bolt_interval() -> float:
	match phase:
		Phase.PHASE_3: return 1.2
		Phase.PHASE_2: return 1.8
		_: return 2.5

func _get_summon_interval() -> float:
	match phase:
		Phase.PHASE_3: return 5.0
		Phase.PHASE_2: return 8.0
		_: return 12.0

func _get_teleport_interval() -> float:
	match phase:
		Phase.PHASE_3: return 4.0
		Phase.PHASE_2: return 6.0
		_: return 10.0


func _perform_attack() -> void:
	_shoot_dark_bolt()


func _shoot_dark_bolt() -> void:
	if not target or not is_instance_valid(target):
		return
	var dir = _get_direction_to_target()
	var bolt = Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 3

	var spr = Sprite2D.new()
	var tex = load("res://assets/sprites/projectiles/orb_purple.png")
	if tex:
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bolt.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 3.0
	col.shape = shape
	bolt.add_child(col)

	bolt.global_position = global_position
	get_parent().add_child(bolt)

	var dmg = attack_power
	var hit = false
	bolt.body_entered.connect(func(body):
		if hit:
			return
		if body is Player:
			hit = true
			(body as Player).take_damage(dmg, dir)
			bolt.queue_free()
	)

	var bolt_target = target
	var elapsed: float = 0.0
	var bolt_vel: Vector2 = dir * BOLT_SPEED
	bolt.set_meta("vel", bolt_vel)
	bolt.set_meta("target", bolt_target)
	bolt.set_meta("elapsed", elapsed)
	bolt.set_meta("hit", false)

	var script_node = bolt
	bolt.set_process(true)
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	bolt.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(script_node):
			return
		var t = script_node.get_meta("target")
		if t and is_instance_valid(t):
			var desired = script_node.global_position.direction_to(t.global_position) * BOLT_SPEED
			var v: Vector2 = script_node.get_meta("vel")
			v = v.lerp(desired, 0.08)
			script_node.set_meta("vel", v)
			script_node.global_position += v * 0.05
		else:
			script_node.global_position += (script_node.get_meta("vel") as Vector2) * 0.05
		var e: float = script_node.get_meta("elapsed") + 0.05
		script_node.set_meta("elapsed", e)
		if e > 3.0:
			script_node.queue_free()
	)


func _do_teleport() -> void:
	_is_teleporting = true
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_teleport_reappear)


func _teleport_reappear() -> void:
	if not target or not is_instance_valid(target):
		_is_teleporting = false
		return
	var angle = randf() * TAU
	var dist = randf_range(40.0, 70.0)
	var new_pos = target.global_position + Vector2(cos(angle), sin(angle)) * dist
	global_position = new_pos
	_is_teleporting = false

	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 1.0, 0.2)

	_spawn_teleport_vfx(new_pos)


func _spawn_teleport_vfx(pos: Vector2) -> void:
	var vfx = ColorRect.new()
	vfx.size = Vector2(16, 16)
	vfx.position = pos - Vector2(8, 8)
	vfx.color = Color(0.5, 0.2, 0.9, 0.5)
	get_parent().add_child(vfx)
	var tw = create_tween()
	tw.tween_property(vfx, "modulate:a", 0.0, 0.4)
	tw.tween_callback(vfx.queue_free)


func _summon_skeleton() -> void:
	var count = 1 if phase == Phase.PHASE_1 else 2
	for i in count:
		var angle = randf() * TAU
		var dist = randf_range(20.0, 35.0)
		var spos = global_position + Vector2(cos(angle), sin(angle)) * dist

		var skel = SkeletonScene.instantiate()
		skel.name = "Summon_%d_%d" % [randi(), i]
		skel.position = spos
		skel.room_index = room_index
		if NetworkManager.is_multiplayer_active():
			skel.set_multiplayer_authority(1)
		get_parent().add_child(skel)

		_spawn_teleport_vfx(spos)


func _cast_deathzone() -> void:
	if not target or not is_instance_valid(target):
		return
	var zone_pos = target.global_position
	var warning = ColorRect.new()
	warning.size = Vector2(28, 28)
	warning.position = zone_pos - Vector2(14, 14)
	warning.color = Color(0.6, 0.1, 0.8, 0.25)
	get_parent().add_child(warning)

	var blink_tw = create_tween()
	blink_tw.tween_property(warning, "color:a", 0.5, 0.3)
	blink_tw.tween_property(warning, "color:a", 0.2, 0.3)
	blink_tw.set_loops(2)

	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(warning):
		return

	warning.color = Color(0.7, 0.1, 1.0, 0.6)

	var dmg = attack_power + 5
	if NetworkManager.is_multiplayer_active():
		for peer_id in GameManager.player_nodes:
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			if (p as Player).current_state == Player.State.DEAD:
				continue
			if p.global_position.distance_to(zone_pos) <= 18.0:
				var dir = zone_pos.direction_to(p.global_position)
				(p as Player).take_damage(dmg, dir)
	else:
		if target and is_instance_valid(target) and target is Player:
			if target.global_position.distance_to(zone_pos) <= 18.0:
				var dir = zone_pos.direction_to(target.global_position)
				(target as Player).take_damage(dmg, dir)

	var fade_tw = create_tween()
	fade_tw.tween_property(warning, "modulate:a", 0.0, 0.5)
	fade_tw.tween_callback(warning.queue_free)
