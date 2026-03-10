extends CharacterBody2D
class_name Player

signal attacked(attack_area: Area2D)

enum State { IDLE, MOVE, ATTACK, DODGE, HURT, DEAD }

@export var stats: PlayerStats

var current_state: State = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN
var is_invincible: bool = false

var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _invincible_timer: float = 0.0
var _hurt_timer: float = 0.0

# 刺客二连斩状态
var _rogue_second_hit: bool = false
var _rogue_hit_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D

var _idle_texture: Texture2D
var _attack_texture: Texture2D
var _walk_textures: Array[Texture2D] = []
var _walk_frame: int = 0
var _walk_anim_timer: float = 0.0
const WALK_ANIM_SPEED = 0.15

var _class_color: Color = Color.WHITE

var initial_class: int = -1  # 多人模式下由 game_world 指定


func _ready() -> void:
	if not stats:
		stats = PlayerStats.new()

	# 多人模式：使用对应 peer 的职业；否则使用本地选择职业
	if NetworkManager.is_multiplayer_active():
		var my_authority: int = get_multiplayer_authority()
		var cls: int = NetworkManager.player_info.get(my_authority, {}).get("class", GameManager.current_class)
		if initial_class >= 0:
			cls = initial_class
		GameManager.current_class = cls
	stats.reset()
	stats.died.connect(_on_died)
	attack_area.monitoring = false
	attack_shape.disabled = true

	if NetworkManager.is_multiplayer_active():
		# 只有本地玩家才启用摄像头和键盘输入
		camera.enabled = is_multiplayer_authority()
		if not is_multiplayer_authority():
			set_physics_process(false)
	else:
		GameManager.player_node = self

	_load_textures()
	_apply_class_visuals()
	_create_player_light()


func _apply_class_visuals() -> void:
	var cd = GameManager.CLASS_DATA[GameManager.current_class]
	_class_color = cd["color"]
	sprite.modulate = _class_color


func _create_player_light() -> void:
	var light = PointLight2D.new()
	light.texture = _generate_light_texture()
	light.energy = 0.6
	light.texture_scale = 3.5
	light.color = _class_color if _class_color != Color.WHITE else Color(1.0, 0.92, 0.75)
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	add_child(light)


func _generate_light_texture() -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.5, Color(1, 1, 1, 0.4))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	tex.gradient = gradient
	tex.width = 64
	tex.height = 64
	return tex


func _load_textures() -> void:
	_idle_texture   = load("res://assets/sprites/player/player_idle.png")
	_attack_texture = load("res://assets/sprites/player/player_attack.png")
	var w1 = load("res://assets/sprites/player/player_walk1.png")
	var w2 = load("res://assets/sprites/player/player_walk2.png")
	if w1: _walk_textures.append(w1)
	if _idle_texture: _walk_textures.append(_idle_texture)
	if w2: _walk_textures.append(w2)
	if _idle_texture: _walk_textures.append(_idle_texture)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	match current_state:
		State.IDLE:   _state_idle()
		State.MOVE:   _state_move(delta)
		State.ATTACK: _state_attack(delta)
		State.DODGE:  _state_dodge(delta)
		State.HURT:   _state_hurt(delta)
		State.DEAD:
			# 多人观战：仍可移动（半透明幽灵状态）
			if NetworkManager.is_multiplayer_active() and is_multiplayer_authority():
				var dir = _get_input_direction()
				velocity = dir * stats.speed * 0.6
				move_and_slide()
			return
	_update_invincibility(delta)
	move_and_slide()


func _update_timers(delta: float) -> void:
	if _dodge_cooldown_timer > 0:
		_dodge_cooldown_timer -= delta
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta
	if _rogue_hit_timer > 0:
		_rogue_hit_timer -= delta


func _get_input_direction() -> Vector2:
	var dir = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	return dir.normalized()


func _state_idle() -> void:
	velocity = Vector2.ZERO
	if _idle_texture:
		sprite.texture = _idle_texture
	var dir = _get_input_direction()
	if dir != Vector2.ZERO:
		facing_direction = dir
		current_state = State.MOVE
		return
	# 游侠可以在静止时射击
	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0:
		_start_attack()
		return
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0:
		_start_dodge()
		return
	_update_sprite_direction()


func _state_move(delta: float) -> void:
	var dir = _get_input_direction()
	if dir == Vector2.ZERO:
		current_state = State.IDLE
		return
	facing_direction = dir

	# 游侠攻击时不停步
	var cls = GameManager.current_class
	if cls == GameManager.PlayerClass.RANGER and Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0:
		velocity = dir * stats.get_total_speed()
		_start_attack()
		return

	velocity = dir * stats.get_total_speed()

	_walk_anim_timer += delta
	if _walk_anim_timer >= WALK_ANIM_SPEED:
		_walk_anim_timer = 0.0
		_walk_frame = (_walk_frame + 1) % _walk_textures.size()
		if not _walk_textures.is_empty():
			sprite.texture = _walk_textures[_walk_frame]

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0:
		_start_attack()
		return
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0:
		_start_dodge()
		return
	_update_sprite_direction()


# ═══════════════════════════════════════════════════════════════
# 攻击分发
# ═══════════════════════════════════════════════════════════════

func _start_attack() -> void:
	match GameManager.current_class:
		GameManager.PlayerClass.WARRIOR: _attack_warrior()
		GameManager.PlayerClass.MAGE:    _attack_mage()
		GameManager.PlayerClass.RANGER:  _attack_ranger()
		GameManager.PlayerClass.ROGUE:   _attack_rogue()


# ── 战士：宽弧横扫，击退敌人 ──────────────────────────────────
func _attack_warrior() -> void:
	current_state = State.ATTACK
	_attack_timer = stats.attack_cooldown
	velocity = facing_direction * 3.0  # 轻微前冲
	if _attack_texture: sprite.texture = _attack_texture

	# 宽大攻击范围
	attack_area.position = facing_direction * 12
	var rect = attack_shape.shape as RectangleShape2D
	if rect:
		rect.size = Vector2(18, 18)
	attack_area.monitoring = true
	attack_shape.disabled = false

	_spawn_warrior_slash()
	_camera_shake(2.5, 0.12)

	var tween = create_tween()
	tween.tween_property(sprite, "position", facing_direction * 3.0, 0.06)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.12)

	_deal_attack_damage(stats.get_total_attack(), 1.5)  # 1.5x 击退
	_attack_cooldown_timer = stats.attack_cooldown


# ── 法师：发射追踪魔法弹 ──────────────────────────────────────
func _attack_mage() -> void:
	_attack_cooldown_timer = stats.attack_cooldown
	if _attack_texture: sprite.texture = _attack_texture

	# 法师攻击不锁动作，可以边移动边释放
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.06)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

	_spawn_magic_orb(facing_direction, stats.get_total_attack())
	_camera_shake(1.0, 0.08)


func _spawn_magic_orb(dir: Vector2, dmg: int) -> void:
	var orb_script = load("res://scripts/player/projectile_orb.gd")
	var orb = Area2D.new()
	orb.set_script(orb_script)
	orb.collision_layer = 0
	orb.collision_mask = 4

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	orb.add_child(col)

	orb.global_position = global_position + dir * 8
	get_parent().add_child(orb)
	orb.setup(dir, dmg, 110.0, 2, self)


# ── 游侠：射出穿透长箭 ────────────────────────────────────────
func _attack_ranger() -> void:
	_attack_cooldown_timer = stats.attack_cooldown
	if _attack_texture: sprite.texture = _attack_texture

	var tween = create_tween()
	tween.tween_property(sprite, "position", -facing_direction * 1.5, 0.05)  # 蓄力后仰
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.08)

	_spawn_arrow(facing_direction, stats.get_total_attack())


func _spawn_arrow(dir: Vector2, dmg: int) -> void:
	var arrow_script = load("res://scripts/player/projectile_arrow.gd")
	var arrow = Area2D.new()
	arrow.set_script(arrow_script)
	arrow.collision_layer = 0
	arrow.collision_mask = 4

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(10, 3)
	col.shape = shape
	col.rotation = dir.angle()
	arrow.add_child(col)

	arrow.global_position = global_position + dir * 10
	get_parent().add_child(arrow)
	arrow.setup(dir, dmg, 160.0, 2, self)


# ── 刺客：极速二连斩 ──────────────────────────────────────────
func _attack_rogue() -> void:
	current_state = State.ATTACK
	_attack_timer = stats.attack_cooldown * 0.7
	velocity = facing_direction * 5.0

	if _attack_texture: sprite.texture = _attack_texture

	# 第一斩（左偏）
	var left_offset = Vector2(-facing_direction.y, facing_direction.x) * 5
	attack_area.position = facing_direction * 12 + left_offset
	var rect = attack_shape.shape as RectangleShape2D
	if rect: rect.size = Vector2(12, 10)
	attack_area.monitoring = true
	attack_shape.disabled = false

	_spawn_rogue_slash(left_offset, Color(1.0, 0.6, 0.2))
	_deal_attack_damage(int(stats.get_total_attack() * 0.7), 0.8)
	_attack_cooldown_timer = stats.attack_cooldown

	# 0.12秒后第二斩（右偏）
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self) or current_state == State.DEAD: return

	var right_offset = Vector2(facing_direction.y, -facing_direction.x) * 5
	attack_area.position = facing_direction * 12 + right_offset
	_spawn_rogue_slash(right_offset, Color(1.0, 0.85, 0.3))
	_deal_attack_damage(int(stats.get_total_attack() * 0.9), 1.0)
	_camera_shake(2.0, 0.10)
	_freeze_frame(0.03)


func _spawn_rogue_slash(offset: Vector2, color: Color) -> void:
	var slash = Node2D.new()
	slash.position = facing_direction * 10 + offset
	add_child(slash)
	for i in 4:
		var line = ColorRect.new()
		var angle = deg_to_rad(-30 + i * 20) + facing_direction.angle()
		line.size = Vector2(7, 1)
		line.position = Vector2(cos(angle) * 3, sin(angle) * 3)
		line.rotation = angle
		line.color = Color(color.r, color.g, color.b, 1.0 - i * 0.15)
		slash.add_child(line)
	var tween = create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(slash.queue_free)


# ─── 共用攻击伤害结算 ─────────────────────────────────────────
func _deal_attack_damage(dmg: int, knockback_mult: float = 1.0) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(self) or current_state == State.DEAD:
		return
	var bodies = attack_area.get_overlapping_bodies()
	var hit_any = false
	for body in bodies:
		if body is EnemyBase and (body as EnemyBase).ai_state != EnemyBase.AIState.DEAD:
			var dir = global_position.direction_to(body.global_position)
			(body as EnemyBase).take_damage(dmg, dir * knockback_mult)
			_spawn_hit_effect(body.global_position)
			hit_any = true
	if hit_any and GameManager.current_class != GameManager.PlayerClass.ROGUE:
		_camera_shake(2.0, 0.12)
		_freeze_frame(0.04)


func _spawn_warrior_slash() -> void:
	var slash = Node2D.new()
	slash.position = facing_direction * 14
	slash.rotation = facing_direction.angle()
	add_child(slash)
	# 宽弧：7条线覆盖140°
	for i in 7:
		var line = ColorRect.new()
		var angle = deg_to_rad(-70 + i * 23)
		line.size = Vector2(10, 2)
		line.position = Vector2(cos(angle) * 5, sin(angle) * 5)
		line.rotation = angle
		line.color = Color(0.7, 0.85, 1.0, 1.0 - i * 0.08)
		slash.add_child(line)
	var tween = create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.25)
	tween.parallel().tween_property(slash, "scale", Vector2(1.4, 1.4), 0.25)
	tween.tween_callback(slash.queue_free)


func _state_attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer <= 0:
		attack_area.monitoring = false
		attack_shape.disabled = true
		current_state = State.IDLE


# ═══════════════════════════════════════════════════════════════
# 闪避分发
# ═══════════════════════════════════════════════════════════════

func _start_dodge() -> void:
	match GameManager.current_class:
		GameManager.PlayerClass.WARRIOR: _dodge_warrior()
		GameManager.PlayerClass.MAGE:    _dodge_mage()
		GameManager.PlayerClass.RANGER:  _dodge_ranger()
		GameManager.PlayerClass.ROGUE:   _dodge_rogue()


# ── 战士：普通翻滚 ────────────────────────────────────────────
func _dodge_warrior() -> void:
	current_state = State.DODGE
	_dodge_timer = stats.dodge_duration
	is_invincible = true
	_invincible_timer = stats.dodge_duration + 0.1
	velocity = facing_direction * stats.dodge_speed

	sprite.modulate = Color(_class_color.r * 0.7, _class_color.g * 0.7, _class_color.b * 0.7, 0.5)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.2), 0.05)
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.1)
	_spawn_dodge_afterimage(_class_color)


# ── 法师：短距闪现（瞬移） ────────────────────────────────────
func _dodge_mage() -> void:
	_dodge_cooldown_timer = stats.dodge_cooldown
	is_invincible = true
	_invincible_timer = 0.3

	# 闪现特效（原位）
	_spawn_blink_effect(global_position)

	# 瞬移到目标位置
	var blink_dist = 48.0
	var target = global_position + facing_direction * blink_dist
	global_position = target
	velocity = Vector2.ZERO

	# 落点特效
	_spawn_blink_effect(global_position)

	sprite.modulate = Color(0.8, 0.5, 1.0, 0.6)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", _class_color, 0.25)


func _spawn_blink_effect(pos: Vector2) -> void:
	var fx = Node2D.new()
	fx.global_position = pos
	get_parent().add_child(fx)
	for i in 8:
		var p = ColorRect.new()
		p.size = Vector2(2, 2)
		var angle = TAU / 8 * i
		p.position = Vector2(cos(angle) * 6, sin(angle) * 6)
		p.color = Color(0.8, 0.5, 1.0, 0.9)
		fx.add_child(p)
		var tw = create_tween()
		tw.tween_property(p, "position", p.position * 2.5, 0.2)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.2)
	var tw2 = create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_callback(fx.queue_free)


# ── 游侠：快速侧步（保持速度） ───────────────────────────────
func _dodge_ranger() -> void:
	current_state = State.DODGE
	_dodge_timer = stats.dodge_duration
	is_invincible = true
	_invincible_timer = stats.dodge_duration

	# 侧向移动（垂直于面向方向）
	var input_dir = _get_input_direction()
	var dodge_dir = input_dir if input_dir != Vector2.ZERO else facing_direction
	velocity = dodge_dir * stats.dodge_speed

	sprite.modulate = Color(_class_color.r, _class_color.g, _class_color.b, 0.4)
	_spawn_dodge_afterimage(Color(0.4, 1.0, 0.5, 0.5))


# ── 刺客：穿刺冲锋（冲过敌人造成伤害）────────────────────────
func _dodge_rogue() -> void:
	current_state = State.DODGE
	_dodge_timer = stats.dodge_duration + 0.05
	is_invincible = true
	_invincible_timer = stats.dodge_duration + 0.05
	velocity = facing_direction * stats.dodge_speed * 1.2

	sprite.modulate = Color(0.2, 0.2, 0.2, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.04)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)

	_spawn_dodge_afterimage(Color(1.0, 0.4, 0.2, 0.6))
	_rogue_dash_damage()


func _rogue_dash_damage() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(self): return
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e): continue
		if (e as EnemyBase).ai_state == EnemyBase.AIState.DEAD: continue
		if global_position.distance_to(e.global_position) < 14:
			var dir = global_position.direction_to(e.global_position)
			(e as EnemyBase).take_damage(int(stats.get_total_attack() * 0.5), dir)
			_spawn_hit_effect(e.global_position)


func _state_dodge(delta: float) -> void:
	_dodge_timer -= delta
	if _dodge_timer <= 0:
		_dodge_cooldown_timer = stats.dodge_cooldown
		is_invincible = false
		sprite.modulate = _class_color
		current_state = State.IDLE
		# 游侠/战士保持部分速度
		if GameManager.current_class == GameManager.PlayerClass.RANGER:
			velocity *= 0.3


func _spawn_dodge_afterimage(color: Color = Color(0.5, 0.7, 1.0, 0.5)) -> void:
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = global_position
	ghost.flip_h = sprite.flip_h
	ghost.modulate = color
	ghost.z_index = -1
	get_parent().add_child(ghost)

	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


# ═══════════════════════════════════════════════════════════════
# 受伤 / 死亡
# ═══════════════════════════════════════════════════════════════

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if NetworkManager.is_multiplayer_active():
		# 只有本节点的 authority 处理伤害，通过 RPC 传递给拥有者
		_net_take_damage.rpc_id(get_multiplayer_authority(), amount, knockback_dir)
		return
	_apply_damage(amount, knockback_dir)


@rpc("any_peer", "call_local", "reliable")
func _net_take_damage(amount: int, knockback_dir: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	_apply_damage(amount, knockback_dir)


func _apply_damage(amount: int, knockback_dir: Vector2) -> void:
	if is_invincible or current_state == State.DEAD or current_state == State.DODGE:
		return
	var actual = stats.take_damage(amount)
	is_invincible = true
	_invincible_timer = stats.invincible_duration
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 80
	current_state = State.HURT
	_hurt_timer = 0.2

	_camera_shake(3.0, 0.15)
	sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)
	_show_damage_number(actual)


func _state_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
	if _hurt_timer <= 0:
		sprite.modulate = _class_color
		current_state = State.IDLE


func _update_invincibility(delta: float) -> void:
	if is_invincible:
		_invincible_timer -= delta
		sprite.modulate.a = 0.35 if fmod(_invincible_timer, 0.1) < 0.05 else 1.0
		if _invincible_timer <= 0:
			is_invincible = false
			sprite.modulate = _class_color


func _on_died() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	Engine.time_scale = 1.0

	_camera_shake(4.0, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 0.1, 0.1, 1.0), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.3, 0.8)

	if NetworkManager.is_multiplayer_active():
		var peer_id: int = get_multiplayer_authority()
		NetworkManager.register_player_death(peer_id)
		# 进入观战模式：半透明，禁碰撞，允许自由移动
		tween.tween_callback(_enter_spectate_mode)
	else:
		tween.tween_callback(func(): GameManager.player_died.emit())


func _enter_spectate_mode() -> void:
	collision_shape.disabled = true
	hurtbox.monitoring = false
	set_physics_process(true)
	# 重新启用移动但不能攻击（通过 State.DEAD 阻止攻击）
	# 半透明已由死亡动画设置


func revive() -> void:
	if current_state != State.DEAD:
		return
	stats.hp = stats.max_hp / 2
	current_state = State.IDLE
	is_invincible = false
	_invincible_timer = 0.0
	collision_shape.disabled = false
	hurtbox.monitoring = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", _class_color, 0.4)


# ═══════════════════════════════════════════════════════════════
# 视觉辅助
# ═══════════════════════════════════════════════════════════════

func _spawn_hit_effect(pos: Vector2) -> void:
	var cls_color = _class_color
	var effect = Node2D.new()
	effect.global_position = pos
	effect.z_index = 50
	get_parent().add_child(effect)

	for i in 6:
		var particle = ColorRect.new()
		particle.size = Vector2(2, 2)
		particle.position = Vector2(-1, -1)
		var angle = randf() * TAU
		var dist = randf_range(2, 6)
		particle.color = [Color.WHITE, cls_color, Color(1, 0.9, 0.4)][randi() % 3]
		effect.add_child(particle)
		var tween = create_tween()
		var target_pos = Vector2(cos(angle) * dist, sin(angle) * dist)
		tween.tween_property(particle, "position", target_pos, 0.2)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.2)

	var flash = ColorRect.new()
	flash.size = Vector2(6, 6)
	flash.position = Vector2(-3, -3)
	flash.color = Color(1, 1, 1, 0.8)
	effect.add_child(flash)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(2.5, 2.5), 0.08)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	flash_tween.tween_callback(effect.queue_free)


func _camera_shake(intensity: float, duration: float) -> void:
	if not camera: return
	var tween = create_tween()
	var steps = 4
	for i in steps:
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", offset, duration / steps)
	tween.tween_property(camera, "offset", Vector2.ZERO, duration / steps)


func _freeze_frame(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration * 0.05).timeout
	if is_instance_valid(self):
		Engine.time_scale = 1.0


func _update_sprite_direction() -> void:
	if facing_direction.x < 0:
		sprite.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false


func _show_damage_number(amount: int) -> void:
	var label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	label.position = Vector2(-4, -16)
	label.z_index = 100
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 14, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_callback(label.queue_free)
