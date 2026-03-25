extends CharacterBody2D
class_name Player

signal attacked(attack_area: Area2D)

enum State { IDLE, MOVE, ATTACK, DODGE, HURT, DEAD }

@export var stats: PlayerStats

var current_state: State = State.IDLE
var facing_direction: Vector2 = Vector2.DOWN
var is_invincible: bool = false
var is_invisible: bool = false

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
var _walk1_texture: Texture2D
var _walk2_texture: Texture2D
var _walk_anim_timer: float = 0.0
var _walk_frame: int = 0  # 0=idle, 1=walk1, 2=idle, 3=walk2
const WALK_ANIM_SPEED = 0.15
const WALK_FRAME_DURATION = 0.12

var _class_color: Color = Color.WHITE
var _base_sprite_scale: Vector2 = Vector2.ONE
var _weapon_sprite: Sprite2D
var _weapon_base_offset: Vector2 = Vector2(6, 0)
var skill_manager: SkillManager

var initial_class: int = -1  # 多人模式下由 game_world 指定

var _is_local: bool = true
var _sync_timer: float = 0.0
const SYNC_INTERVAL: float = 1.0 / 20.0  # 20 Hz

# Remote interpolation
var _remote_target_pos: Vector2 = Vector2.ZERO
var _remote_target_dir: Vector2 = Vector2.DOWN
var _remote_state: int = State.IDLE


func _ready() -> void:
	if not stats:
		stats = PlayerStats.new()

	if NetworkManager.is_multiplayer_active():
		_is_local = is_multiplayer_authority()
		var my_authority: int = get_multiplayer_authority()
		var cls: int = NetworkManager.player_info.get(my_authority, {}).get("class", GameManager.current_class)
		if initial_class >= 0:
			cls = initial_class
		else:
			initial_class = cls
		if _is_local:
			GameManager.current_class = cls
		camera.enabled = _is_local
		_remote_target_pos = global_position
	else:
		if initial_class < 0:
			initial_class = GameManager.current_class
		GameManager.player_node = self

	stats.reset()
	stats.died.connect(_on_died)
	attack_area.monitoring = false
	attack_shape.disabled = true

	_load_textures()
	_apply_class_visuals()
	_base_sprite_scale = sprite.scale
	_create_weapon_sprite()
	_setup_skill_manager()


func _get_class() -> int:
	return initial_class if initial_class >= 0 else GameManager.current_class


func _apply_class_visuals() -> void:
	var cd = GameManager.CLASS_DATA[_get_class()]
	_class_color = cd["color"]
	sprite.modulate = Color.WHITE



func _load_textures() -> void:
	var cls: int = _get_class()
	var name_map: Dictionary = {
		GameManager.PlayerClass.WARRIOR: "warrior",
		GameManager.PlayerClass.MAGE:    "mage",
		GameManager.PlayerClass.RANGER:  "ranger",
		GameManager.PlayerClass.ROGUE:   "rogue",
	}
	var char_name: String = name_map.get(cls, "warrior")
	var base_path: String = "res://assets/sprites/player/"
	_idle_texture = load(base_path + char_name + ".png")
	_walk1_texture = load(base_path + char_name + "_walk1.png")
	_walk2_texture = load(base_path + char_name + "_walk2.png")
	if _idle_texture:
		sprite.texture = _idle_texture


func _create_weapon_sprite() -> void:
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.z_index = 1
	var weapon_map: Dictionary = {
		GameManager.PlayerClass.WARRIOR: "res://assets/sprites/items/sword_icon.png",
		GameManager.PlayerClass.MAGE:    "res://assets/sprites/items/staff.png",
		GameManager.PlayerClass.RANGER:  "res://assets/sprites/items/bow.png",
		GameManager.PlayerClass.ROGUE:   "res://assets/sprites/items/dagger.png",
	}
	var tex_path: String = weapon_map.get(_get_class(), "res://assets/sprites/items/sword_icon.png")
	var tex = load(tex_path)
	if tex:
		_weapon_sprite.texture = tex
	_weapon_sprite.scale = Vector2(0.5, 0.5)
	add_child(_weapon_sprite)
	_update_weapon_transform()


func _setup_skill_manager() -> void:
	skill_manager = SkillManager.new()
	skill_manager.name = "SkillManager"
	skill_manager.setup(self)
	add_child(skill_manager)


func _check_skill_input() -> void:
	if current_state == State.DEAD or current_state == State.HURT:
		return
	if Input.is_action_just_pressed("skill_1"):
		if skill_manager and skill_manager.can_use_skill(SkillDatabase.SkillSlot.SKILL_U):
			skill_manager.use_skill(SkillDatabase.SkillSlot.SKILL_U)
			if NetworkManager.is_multiplayer_active():
				_rpc_broadcast_skill.rpc(SkillDatabase.SkillSlot.SKILL_U, global_position, facing_direction)
	if Input.is_action_just_pressed("skill_2"):
		if skill_manager and skill_manager.can_use_skill(SkillDatabase.SkillSlot.SKILL_L):
			skill_manager.use_skill(SkillDatabase.SkillSlot.SKILL_L)
			if NetworkManager.is_multiplayer_active():
				_rpc_broadcast_skill.rpc(SkillDatabase.SkillSlot.SKILL_L, global_position, facing_direction)


func _remote_process(delta: float) -> void:
	global_position = global_position.lerp(_remote_target_pos, 15.0 * delta)
	facing_direction = _remote_target_dir
	var prev_state: int = current_state
	current_state = _remote_state as State

	_update_weapon_transform()
	_update_sprite_direction()

	if current_state == State.MOVE:
		_walk_anim_timer += delta
		_update_walk_frame()
		var phase: float = _walk_anim_timer / WALK_ANIM_SPEED
		sprite.position.y = -abs(sin(phase * PI)) * 1.5
		sprite.scale = _base_sprite_scale
		sprite.rotation = 0.0
	elif current_state == State.IDLE:
		sprite.position = Vector2.ZERO
		sprite.scale = _base_sprite_scale
		sprite.rotation = 0.0
		_walk_anim_timer = 0.0
		_walk_frame = -1
		if _idle_texture:
			sprite.texture = _idle_texture
	elif current_state == State.DEAD:
		if prev_state != State.DEAD:
			sprite.modulate = Color(0.5, 0.1, 0.1, 0.3)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync_pos(pos: Vector2, dir: Vector2, state: int) -> void:
	_remote_target_pos = pos
	_remote_target_dir = dir
	_remote_state = state


@rpc("any_peer", "call_remote", "reliable")
func _rpc_broadcast_skill(slot: int, pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	_remote_target_pos = pos
	facing_direction = dir
	if skill_manager:
		var peer_cls: int = _get_class()
		var skill_id: String = SkillDatabase.get_skill_for_slot(peer_cls, slot)
		if skill_id == "":
			return
		var data: Dictionary = SkillDatabase.ACTIVE_SKILLS[skill_id]
		skill_manager._execute_skill(skill_id, data)


@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_attack(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	_remote_target_pos = pos
	facing_direction = dir
	_update_sprite_direction()
	_play_remote_attack_effects()


@rpc("authority", "call_remote", "reliable")
func _rpc_broadcast_dodge(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	_remote_target_pos = pos
	facing_direction = dir
	_update_sprite_direction()
	_spawn_dodge_afterimage(_class_color)


func _play_remote_attack_effects() -> void:
	match _get_class():
		GameManager.PlayerClass.WARRIOR:
			_spawn_warrior_slash()
			_animate_weapon_swing(0.3, 120.0)
			var tw = create_tween()
			tw.tween_property(sprite, "position", facing_direction * 3.0, 0.06)
			tw.tween_property(sprite, "position", Vector2.ZERO, 0.12)
		GameManager.PlayerClass.MAGE:
			_animate_weapon_thrust(0.2)
			var tw = create_tween()
			tw.tween_property(sprite, "scale", _base_sprite_scale * 1.2, 0.06)
			tw.tween_property(sprite, "scale", _base_sprite_scale, 0.08)
			_spawn_remote_projectile(facing_direction, Color(0.5, 0.3, 1.0, 0.9), 90.0)
		GameManager.PlayerClass.RANGER:
			_animate_weapon_thrust(0.18)
			var tw = create_tween()
			tw.tween_property(sprite, "position", -facing_direction * 1.5, 0.05)
			tw.tween_property(sprite, "position", Vector2.ZERO, 0.08)
			_spawn_remote_projectile(facing_direction, Color(0.9, 0.8, 0.5, 0.9), 130.0)
		GameManager.PlayerClass.ROGUE:
			var left_offset = Vector2(-facing_direction.y, facing_direction.x) * 5
			_spawn_rogue_slash(left_offset, Color(1.0, 0.6, 0.2))
			_animate_weapon_swing(0.12, 80.0)


func _spawn_remote_projectile(dir: Vector2, color: Color, speed: float) -> void:
	var proj = Node2D.new()
	var visual = ColorRect.new()
	visual.size = Vector2(6, 4)
	visual.position = Vector2(-3, -2)
	visual.rotation = dir.angle()
	visual.color = color
	proj.add_child(visual)
	proj.global_position = global_position + dir * 10
	get_parent().add_child(proj)
	var duration: float = 100.0 / speed
	var tw = create_tween()
	tw.tween_property(proj, "global_position", proj.global_position + dir * 100, duration)
	tw.parallel().tween_property(visual, "modulate:a", 0.0, duration)
	tw.tween_callback(proj.queue_free)


func _update_weapon_transform() -> void:
	if not _weapon_sprite:
		return
	if current_state == State.DEAD:
		_weapon_sprite.visible = false
		return
	_weapon_sprite.visible = true

	var cls: int = _get_class()
	var offset: Vector2
	var rot: float

	if abs(facing_direction.x) >= abs(facing_direction.y):
		if facing_direction.x >= 0:
			offset = Vector2(7, 1)
			rot = 0.0
			_weapon_sprite.flip_h = false
			_weapon_sprite.z_index = 1
		else:
			offset = Vector2(-7, 1)
			rot = 0.0
			_weapon_sprite.flip_h = true
			_weapon_sprite.z_index = 1
	else:
		if facing_direction.y > 0:
			offset = Vector2(5, 4)
			rot = deg_to_rad(25)
			_weapon_sprite.z_index = 1
		else:
			offset = Vector2(-5, -2)
			rot = deg_to_rad(75)
			_weapon_sprite.z_index = -1

	if cls == GameManager.PlayerClass.MAGE:
		offset *= 0.85
		rot += deg_to_rad(15)
	elif cls == GameManager.PlayerClass.RANGER:
		rot += deg_to_rad(10)

	_weapon_sprite.position = offset
	_weapon_sprite.rotation = rot


func _physics_process(delta: float) -> void:
	if NetworkManager.is_multiplayer_active() and not _is_local:
		_remote_process(delta)
		return

	_update_timers(delta)
	_update_weapon_transform()
	match current_state:
		State.IDLE:   _state_idle()
		State.MOVE:   _state_move(delta)
		State.ATTACK: _state_attack(delta)
		State.DODGE:  _state_dodge(delta)
		State.HURT:   _state_hurt(delta)
		State.DEAD:
			if NetworkManager.is_multiplayer_active() and _is_local:
				var dir = _get_input_direction()
				velocity = dir * stats.speed * 0.6
				move_and_slide()
			return
	_update_invincibility(delta)
	move_and_slide()

	if NetworkManager.is_multiplayer_active() and _is_local:
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			_rpc_sync_pos.rpc(global_position, facing_direction, current_state)


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
	sprite.position = Vector2.ZERO
	sprite.scale = _base_sprite_scale
	sprite.rotation = 0.0
	_walk_anim_timer = 0.0
	_walk_frame = -1
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
	_check_skill_input()
	_update_sprite_direction()


func _state_move(delta: float) -> void:
	var dir = _get_input_direction()
	if dir == Vector2.ZERO:
		current_state = State.IDLE
		return
	facing_direction = dir

	# 游侠攻击时不停步
	var cls = _get_class()
	if cls == GameManager.PlayerClass.RANGER and Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0:
		velocity = dir * stats.get_total_speed()
		_start_attack()
		return

	velocity = dir * stats.get_total_speed()

	_walk_anim_timer += delta
	_update_walk_frame()
	var phase: float = _walk_anim_timer / WALK_ANIM_SPEED
	sprite.position.y = -abs(sin(phase * PI)) * 1.5
	sprite.scale = _base_sprite_scale
	sprite.rotation = 0.0

	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0:
		_start_attack()
		return
	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0:
		_start_dodge()
		return
	_check_skill_input()
	_update_sprite_direction()


func _update_walk_frame() -> void:
	var new_frame: int = int(_walk_anim_timer / WALK_FRAME_DURATION) % 4
	if new_frame == _walk_frame:
		return
	_walk_frame = new_frame
	match _walk_frame:
		0, 2:
			sprite.texture = _idle_texture
		1:
			if _walk1_texture:
				sprite.texture = _walk1_texture
		3:
			if _walk2_texture:
				sprite.texture = _walk2_texture


# ═══════════════════════════════════════════════════════════════
# 攻击分发
# ═══════════════════════════════════════════════════════════════

func _start_attack() -> void:
	if is_invisible:
		is_invisible = false
		sprite.modulate.a = 1.0
	if NetworkManager.is_multiplayer_active() and _is_local:
		_rpc_broadcast_attack.rpc(global_position, facing_direction)
	match _get_class():
		GameManager.PlayerClass.WARRIOR: _attack_warrior()
		GameManager.PlayerClass.MAGE:    _attack_mage()
		GameManager.PlayerClass.RANGER:  _attack_ranger()
		GameManager.PlayerClass.ROGUE:   _attack_rogue()


# ── 战士：宽弧横扫，击退敌人 ──────────────────────────────────
func _attack_warrior() -> void:
	current_state = State.ATTACK
	_attack_timer = stats.attack_cooldown
	velocity = facing_direction * 3.0
	sprite.position = Vector2.ZERO
	sprite.scale = _base_sprite_scale
	sprite.rotation = 0.0

	attack_area.position = facing_direction * 12
	var rect = attack_shape.shape as RectangleShape2D
	if rect:
		rect.size = Vector2(18, 18)
	attack_area.monitoring = true
	attack_shape.disabled = false

	_spawn_warrior_slash()
	_animate_weapon_swing(0.3, 120.0)
	_camera_shake(2.5, 0.12)

	var tween = create_tween()
	tween.tween_property(sprite, "scale", _base_sprite_scale * Vector2(1.25, 0.8), 0.05)
	tween.parallel().tween_property(sprite, "position", facing_direction * 5.0, 0.05)
	tween.tween_property(sprite, "scale", _base_sprite_scale * Vector2(0.9, 1.1), 0.06)
	tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.1)
	tween.tween_property(sprite, "scale", _base_sprite_scale, 0.06)

	_deal_attack_damage(stats.get_total_attack(), 1.5)
	_attack_cooldown_timer = stats.attack_cooldown


# ── 法师：发射追踪魔法弹 ──────────────────────────────────────
func _attack_mage() -> void:
	_attack_cooldown_timer = stats.attack_cooldown
	sprite.rotation = 0.0

	var tween = create_tween()
	tween.tween_property(sprite, "position", -facing_direction * 2.0, 0.04)
	tween.parallel().tween_property(sprite, "scale", _base_sprite_scale * Vector2(0.85, 1.15), 0.04)
	tween.tween_property(sprite, "position", facing_direction * 2.0, 0.06)
	tween.parallel().tween_property(sprite, "scale", _base_sprite_scale * 1.2, 0.06)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.08)
	tween.parallel().tween_property(sprite, "scale", _base_sprite_scale, 0.08)

	_animate_weapon_thrust(0.2)
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
	orb.setup(dir, dmg, 90.0, 2, self)


# ── 游侠：射出穿透长箭 ────────────────────────────────────────
func _attack_ranger() -> void:
	_attack_cooldown_timer = stats.attack_cooldown
	sprite.rotation = 0.0

	var tween = create_tween()
	tween.tween_property(sprite, "scale", _base_sprite_scale * Vector2(0.85, 1.1), 0.04)
	tween.parallel().tween_property(sprite, "position", -facing_direction * 2.5, 0.04)
	tween.tween_property(sprite, "scale", _base_sprite_scale * Vector2(1.15, 0.9), 0.04)
	tween.parallel().tween_property(sprite, "position", facing_direction * 1.0, 0.04)
	tween.tween_property(sprite, "scale", _base_sprite_scale, 0.06)
	tween.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.06)

	_animate_weapon_thrust(0.18)
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
	arrow.setup(dir, dmg, 130.0, 2, self)


# ── 刺客：极速二连斩 ──────────────────────────────────────────
func _attack_rogue() -> void:
	current_state = State.ATTACK
	_attack_timer = stats.attack_cooldown * 0.7
	velocity = facing_direction * 5.0
	sprite.position = Vector2.ZERO
	sprite.scale = _base_sprite_scale
	sprite.rotation = 0.0

	var atk_tw = create_tween()
	atk_tw.tween_property(sprite, "scale", _base_sprite_scale * Vector2(1.3, 0.75), 0.03)
	atk_tw.parallel().tween_property(sprite, "position", facing_direction * 4.0, 0.03)
	atk_tw.tween_property(sprite, "scale", _base_sprite_scale * Vector2(0.9, 1.1), 0.05)
	atk_tw.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.08)
	atk_tw.tween_property(sprite, "scale", _base_sprite_scale, 0.05)

	var left_offset = Vector2(-facing_direction.y, facing_direction.x) * 5
	attack_area.position = facing_direction * 12 + left_offset
	var rect = attack_shape.shape as RectangleShape2D
	if rect: rect.size = Vector2(12, 10)
	attack_area.monitoring = true
	attack_shape.disabled = false

	_spawn_rogue_slash(left_offset, Color(1.0, 0.6, 0.2))
	_animate_weapon_swing(0.12, 80.0)
	_deal_attack_damage(int(stats.get_total_attack() * 0.7), 0.8)
	_attack_cooldown_timer = stats.attack_cooldown

	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self) or current_state == State.DEAD: return

	var right_offset = Vector2(facing_direction.y, -facing_direction.x) * 5
	attack_area.position = facing_direction * 12 + right_offset
	_spawn_rogue_slash(right_offset, Color(1.0, 0.85, 0.3))
	_animate_weapon_swing(0.12, -80.0)
	_deal_attack_damage(int(stats.get_total_attack() * 0.9), 1.0)
	_camera_shake(2.0, 0.10)
	_freeze_frame(0.03)


func _spawn_rogue_slash(offset: Vector2, _color: Color) -> void:
	var slash_pos: Vector2 = global_position + facing_direction * 10 + offset
	VfxManager.play_at("fx_slash", slash_pos, "orange", 0.3, 45.0)


# ─── 共用攻击伤害结算 ─────────────────────────────────────────
func _deal_attack_damage(dmg: int, knockback_mult: float = 1.0) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(self) or current_state == State.DEAD:
		return
	# 暴击判定
	var crit: bool = false
	var crit_chance: float = stats.get_passive_value("crit_chance")
	if crit_chance > 0.0 and randf() < crit_chance:
		crit = true
		dmg *= 2
	var bodies = attack_area.get_overlapping_bodies()
	var hit_any = false
	for body in bodies:
		if body is EnemyBase and (body as EnemyBase).ai_state != EnemyBase.AIState.DEAD:
			var dir = global_position.direction_to(body.global_position)
			(body as EnemyBase).take_damage(dmg, dir * knockback_mult)
			_spawn_hit_effect(body.global_position)
			if crit:
				_show_crit_text(body.global_position)
			hit_any = true
	if hit_any and _get_class() != GameManager.PlayerClass.ROGUE:
		_camera_shake(2.0, 0.12)
		_freeze_frame(0.04)


func _spawn_warrior_slash() -> void:
	var slash_pos: Vector2 = global_position + facing_direction * 12
	VfxManager.play_at("fx_spiral", slash_pos, "red", 0.4, 35.0)


func _state_attack(delta: float) -> void:
	_attack_timer -= delta
	# 攻击期间仍允许移动（不锁方向），只是速度减半
	var dir = _get_input_direction()
	if dir != Vector2.ZERO:
		velocity = dir * stats.get_total_speed() * 0.5
		facing_direction = dir
		_update_sprite_direction()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
	if _attack_timer <= 0:
		attack_area.monitoring = false
		attack_shape.disabled = true
		current_state = State.IDLE


# ═══════════════════════════════════════════════════════════════
# 闪避分发
# ═══════════════════════════════════════════════════════════════

func _start_dodge() -> void:
	if NetworkManager.is_multiplayer_active() and _is_local:
		_rpc_broadcast_dodge.rpc(global_position, facing_direction)
	match _get_class():
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
	tween.tween_property(sprite, "scale", _base_sprite_scale * Vector2(0.8, 1.2), 0.05)
	tween.tween_property(sprite, "scale", _base_sprite_scale, 0.1)
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
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)


func _spawn_blink_effect(pos: Vector2) -> void:
	VfxManager.play_at("fx_ring_expand", pos, "cyan", 0.35, 40.0)


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
	tween.tween_property(sprite, "scale", _base_sprite_scale * Vector2(1.3, 0.7), 0.04)
	tween.tween_property(sprite, "scale", _base_sprite_scale, 0.08)

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
		sprite.modulate = Color.WHITE
		current_state = State.IDLE
		# 游侠/战士保持部分速度
		if _get_class() == GameManager.PlayerClass.RANGER:
			velocity *= 0.3


func _spawn_dodge_afterimage(color: Color = Color(0.5, 0.7, 1.0, 0.5)) -> void:
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = global_position
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
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
	if actual == 0:
		_show_evade_text()
		return
	# 荆棘反弹
	var thorns_pct: float = stats.get_passive_value("thorns_percent")
	if thorns_pct > 0.0 and knockback_dir != Vector2.ZERO:
		var thorns_dmg: int = maxi(1, int(actual * thorns_pct))
		var attacker_pos: Vector2 = global_position - knockback_dir.normalized() * 20
		var enemies = get_tree().get_nodes_in_group("enemies")
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(attacker_pos) < 24:
				(e as EnemyBase).take_damage(thorns_dmg, -knockback_dir)
				break
	is_invincible = true
	_invincible_timer = stats.invincible_duration
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 80
	current_state = State.HURT
	_hurt_timer = 0.2

	VfxManager.play_at("fx_burst", global_position, "red", 0.3, 40.0)
	_camera_shake(3.0, 0.15)
	sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)
	_show_damage_number(actual)


func _state_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
	if _hurt_timer <= 0:
		sprite.modulate = Color.WHITE
		current_state = State.IDLE


func _update_invincibility(delta: float) -> void:
	if is_invincible:
		_invincible_timer -= delta
		sprite.modulate.a = 0.35 if fmod(_invincible_timer, 0.1) < 0.05 else 1.0
		if _invincible_timer <= 0:
			is_invincible = false
			sprite.modulate = Color.WHITE


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
	stats.current_hp = stats.max_hp / 2
	stats.hp_changed.emit(stats.current_hp, stats.get_total_max_hp())
	current_state = State.IDLE
	is_invincible = false
	_invincible_timer = 0.0
	collision_shape.disabled = false
	hurtbox.monitoring = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)


# ═══════════════════════════════════════════════════════════════
# 武器动画
# ═══════════════════════════════════════════════════════════════

func _animate_weapon_swing(duration: float, arc_degrees: float) -> void:
	if not _weapon_sprite:
		return
	var start_rot: float = _weapon_sprite.rotation - deg_to_rad(arc_degrees * 0.4)
	var end_rot: float = _weapon_sprite.rotation + deg_to_rad(arc_degrees * 0.6)
	var forward_offset: Vector2 = facing_direction * 4

	var tween = create_tween()
	tween.tween_property(_weapon_sprite, "rotation", start_rot, duration * 0.15).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_weapon_sprite, "rotation", end_rot, duration * 0.35).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(_weapon_sprite, "position",
		_weapon_sprite.position + forward_offset, duration * 0.35).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_weapon_sprite, "position",
		_weapon_sprite.position, duration * 0.5).set_trans(Tween.TRANS_QUAD)


func _animate_weapon_thrust(duration: float) -> void:
	if not _weapon_sprite:
		return
	var thrust_offset: Vector2 = facing_direction * 6
	var base_pos: Vector2 = _weapon_sprite.position

	var tween = create_tween()
	tween.tween_property(_weapon_sprite, "position",
		base_pos + thrust_offset, duration * 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_weapon_sprite, "position",
		base_pos, duration * 0.7).set_trans(Tween.TRANS_QUAD)


# ═══════════════════════════════════════════════════════════════
# 视觉辅助
# ═══════════════════════════════════════════════════════════════

func _spawn_hit_effect(pos: Vector2) -> void:
	var color_map: Dictionary = {
		GameManager.PlayerClass.WARRIOR: "red",
		GameManager.PlayerClass.MAGE: "cyan",
		GameManager.PlayerClass.RANGER: "green",
		GameManager.PlayerClass.ROGUE: "orange",
	}
	var fx_color: String = color_map.get(_get_class(), "orange")
	VfxManager.play_at("fx_burst", pos, fx_color, 0.35, 40.0)


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


func _show_evade_text() -> void:
	var label = Label.new()
	label.text = "闪避!"
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	label.position = Vector2(-6, -18)
	label.z_index = 101
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 12, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func _show_crit_text(pos: Vector2) -> void:
	var label = Label.new()
	label.text = "暴击!"
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	label.global_position = pos + Vector2(-8, -20)
	label.z_index = 101
	get_parent().add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 16, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


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
