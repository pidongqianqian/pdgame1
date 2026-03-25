extends CanvasLayer

const DUNGEON_FOG_SHADER = "
shader_type canvas_item;

uniform float inner_radius : hint_range(0.0, 1.0) = 0.45;
uniform float outer_radius : hint_range(0.0, 1.5) = 1.0;
uniform float edge_darkness : hint_range(0.0, 1.0) = 0.72;
uniform float base_darkness : hint_range(0.0, 1.0) = 0.35;
uniform vec3  fog_tint = vec3(0.02, 0.01, 0.05);
uniform float time_val = 0.0;

uniform int   torch_count = 0;
uniform vec2  torch_uvs[48];
uniform float torch_radius = 0.38;

void fragment() {
	vec2 uv = UV - 0.5;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	uv.x *= aspect;
	float dist = length(uv) * 2.0;

	float fog = smoothstep(inner_radius, outer_radius, dist);
	float breath = sin(time_val * 1.8) * 0.02 + sin(time_val * 3.7) * 0.01;
	fog = clamp(fog + breath, 0.0, 1.0);
	float darkness = mix(base_darkness, edge_darkness, fog);

	float player_glow = 1.0 - smoothstep(0.0, 0.38, dist);
	float player_flicker = sin(time_val * 5.5) * 0.04
	                     + sin(time_val * 12.3) * 0.02
	                     + sin(time_val * 21.0) * 0.01;
	player_glow *= (0.75 + player_flicker);
	darkness *= (1.0 - player_glow * 0.8);

	float total_torch = 0.0;
	for (int i = 0; i < 48; i++) {
		if (i >= torch_count) break;
		vec2 t_uv = torch_uvs[i] - 0.5;
		t_uv.x *= aspect;
		float t_dist = length(uv - t_uv) * 2.0;
		float flicker = sin(time_val * 5.0 + float(i) * 2.5) * 0.04
		              + sin(time_val * 11.0 + float(i) * 1.7) * 0.025
		              + sin(time_val * 23.0 + float(i) * 3.1) * 0.012;
		float radius = torch_radius + flicker;
		float glow = 1.0 - smoothstep(0.0, radius, t_dist);
		total_torch = max(total_torch, glow);
	}
	darkness *= (1.0 - total_torch * 0.88);

	vec3 torch_warm = vec3(0.35, 0.15, 0.03);
	vec3 final_tint = mix(fog_tint, torch_warm, total_torch * 0.8);

	COLOR = vec4(final_tint, darkness);
}
"

var _fog_rect: ColorRect
var _fog_material: ShaderMaterial
var _dust_nodes: Array = []
var _torch_positions: Array = []
var _torch_sprites: Array = []
var _floor_overlay: ColorRect
var _particle_layer: CanvasLayer

var _theme_color: Color = Color(0.12, 0.08, 0.18)
var _theme_id: int = 0  # 0=crypt, 1=forest, 2=inferno, 3=necropolis

var _frame_counter: int = 0
var _cached_canvas_xform: Transform2D
var _cached_vp_size: Vector2


func _ready() -> void:
	layer = 5
	_create_fog_overlay()
	_create_floor_overlay()
	_spawn_dust_particles()
	_update_floor_theme()


func _create_fog_overlay() -> void:
	_fog_rect = ColorRect.new()
	_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = DUNGEON_FOG_SHADER
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = shader
	_fog_material.set_shader_parameter("inner_radius", 0.50)
	_fog_material.set_shader_parameter("outer_radius", 1.10)
	_fog_material.set_shader_parameter("edge_darkness", 0.50)
	_fog_material.set_shader_parameter("base_darkness", 0.18)
	_fog_material.set_shader_parameter("torch_radius", 0.38)
	_fog_rect.material = _fog_material
	add_child(_fog_rect)


func _create_floor_overlay() -> void:
	_floor_overlay = ColorRect.new()
	_floor_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor_overlay.color = Color(0, 0, 0, 0)
	_floor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor_overlay)


func set_theme(theme_color: Color, theme_id: int = 0) -> void:
	_theme_color = theme_color
	_theme_id = theme_id
	_update_floor_theme()
	_rebuild_dust_particles()


func _update_floor_theme() -> void:
	var floor_num: int = GameManager.current_floor
	var tint := Vector3(_theme_color.r, _theme_color.g, _theme_color.b)

	if _fog_material:
		_fog_material.set_shader_parameter("fog_tint", tint)
		var darkness_scale: float = 1.0 + floor_num * 0.02
		_fog_material.set_shader_parameter("edge_darkness",
			clampf(0.50 * darkness_scale, 0.0, 0.72))
		_fog_material.set_shader_parameter("base_darkness",
			clampf(0.18 + floor_num * 0.015, 0.0, 0.35))


func _spawn_dust_particles() -> void:
	_particle_layer = CanvasLayer.new()
	_particle_layer.layer = 3
	add_child(_particle_layer)
	_rebuild_dust_particles()


func _rebuild_dust_particles() -> void:
	for d in _dust_nodes:
		if is_instance_valid(d["node"]):
			d["node"].queue_free()
	_dust_nodes.clear()

	if not _particle_layer:
		return

	match _theme_id:
		0:
			_spawn_crypt_dust()
		1:
			_spawn_forest_leaves()
		2:
			_spawn_inferno_embers()
		3:
			_spawn_necro_wisps()


func _spawn_crypt_dust() -> void:
	for i in 14:
		var dust = ColorRect.new()
		dust.size = Vector2(1, 1)
		dust.color = Color(0.7, 0.7, 0.9, randf_range(0.15, 0.35))
		dust.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(dust)
		_dust_nodes.append({
			"node": dust, "type": "rise",
			"speed": randf_range(4.0, 14.0),
			"drift": randf_range(-8.0, 8.0),
			"phase": randf_range(0, TAU),
		})


func _spawn_forest_leaves() -> void:
	var leaf_colors = [
		Color(0.3, 0.6, 0.15, 0.45),
		Color(0.5, 0.7, 0.2, 0.4),
		Color(0.6, 0.55, 0.1, 0.35),
		Color(0.25, 0.5, 0.1, 0.4),
	]
	for i in 18:
		var leaf = ColorRect.new()
		leaf.size = Vector2(randi_range(2, 3), 1)
		leaf.color = leaf_colors[randi() % leaf_colors.size()]
		leaf.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		leaf.rotation = randf_range(0, TAU)
		leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(leaf)
		_dust_nodes.append({
			"node": leaf, "type": "fall",
			"speed": randf_range(6.0, 18.0),
			"drift": randf_range(-15.0, 15.0),
			"phase": randf_range(0, TAU),
			"spin": randf_range(-1.5, 1.5),
		})
	# 少量孢子光点
	for i in 6:
		var spore = ColorRect.new()
		spore.size = Vector2(1, 1)
		spore.color = Color(0.6, 1.0, 0.4, randf_range(0.2, 0.4))
		spore.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		spore.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(spore)
		_dust_nodes.append({
			"node": spore, "type": "float",
			"speed": randf_range(2.0, 6.0),
			"drift": randf_range(-6.0, 6.0),
			"phase": randf_range(0, TAU),
		})


func _spawn_inferno_embers() -> void:
	var ember_colors = [
		Color(1.0, 0.6, 0.1, 0.5),
		Color(1.0, 0.4, 0.05, 0.55),
		Color(1.0, 0.8, 0.2, 0.4),
	]
	for i in 20:
		var ember = ColorRect.new()
		ember.size = Vector2(1, 1)
		ember.color = ember_colors[randi() % ember_colors.size()]
		ember.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(ember)
		_dust_nodes.append({
			"node": ember, "type": "rise_fast",
			"speed": randf_range(12.0, 30.0),
			"drift": randf_range(-12.0, 12.0),
			"phase": randf_range(0, TAU),
		})
	# 热浪摇曳大粒子
	for i in 4:
		var heat = ColorRect.new()
		heat.size = Vector2(3, 2)
		heat.color = Color(1.0, 0.5, 0.15, 0.12)
		heat.position = Vector2(randf_range(0, 800), randf_range(200, 400))
		heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(heat)
		_dust_nodes.append({
			"node": heat, "type": "rise",
			"speed": randf_range(3.0, 8.0),
			"drift": randf_range(-20.0, 20.0),
			"phase": randf_range(0, TAU),
		})


func _spawn_necro_wisps() -> void:
	var wisp_colors = [
		Color(0.6, 0.3, 0.9, 0.3),
		Color(0.4, 0.5, 1.0, 0.25),
		Color(0.8, 0.4, 1.0, 0.2),
	]
	for i in 10:
		var wisp = ColorRect.new()
		wisp.size = Vector2(2, 2)
		wisp.color = wisp_colors[randi() % wisp_colors.size()]
		wisp.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		wisp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(wisp)
		_dust_nodes.append({
			"node": wisp, "type": "float",
			"speed": randf_range(1.5, 5.0),
			"drift": randf_range(-10.0, 10.0),
			"phase": randf_range(0, TAU),
		})
	# 暗尘
	for i in 8:
		var dust = ColorRect.new()
		dust.size = Vector2(1, 1)
		dust.color = Color(0.5, 0.4, 0.6, randf_range(0.15, 0.3))
		dust.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particle_layer.add_child(dust)
		_dust_nodes.append({
			"node": dust, "type": "rise",
			"speed": randf_range(3.0, 10.0),
			"drift": randf_range(-6.0, 6.0),
			"phase": randf_range(0, TAU),
		})


func _process(delta: float) -> void:
	_frame_counter += 1
	# time_val 每帧更新保持火把闪烁流畅
	if _fog_material:
		_fog_material.set_shader_parameter("time_val", Time.get_ticks_msec() / 1000.0)
	# 粒子每 2 帧更新，视觉上无差异但节省一半 CPU
	if _frame_counter % 2 == 0:
		_animate_dust(delta * 2.0)
	# 火把 UV 每 3 帧检查一次，只在摄像机移动时重建
	if _frame_counter % 3 == 0:
		_update_torch_shader()


func _animate_dust(delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for d in _dust_nodes:
		var node: ColorRect = d["node"]
		if not is_instance_valid(node):
			continue
		var ptype: String = d.get("type", "rise")
		var base_alpha: float = node.color.a

		match ptype:
			"rise":
				node.position.y -= d["speed"] * delta
				node.position.x += sin(t * 0.8 + d["phase"]) * d["drift"] * delta
				node.color.a = clampf(sin(t * 1.2 + d["phase"]) * 0.1 + 0.22, 0.05, 0.5)
				if node.position.y < -4:
					node.position.y = 400.0
					node.position.x = randf_range(0, 800)

			"rise_fast":
				node.position.y -= d["speed"] * delta
				node.position.x += sin(t * 2.0 + d["phase"]) * d["drift"] * delta
				var flicker: float = sin(t * 8.0 + d["phase"]) * 0.2
				node.color.a = clampf(0.35 + flicker, 0.1, 0.6)
				if node.position.y < -4:
					node.position.y = randf_range(350, 420)
					node.position.x = randf_range(0, 800)

			"fall":
				node.position.y += d["speed"] * delta
				node.position.x += sin(t * 0.6 + d["phase"]) * d["drift"] * delta
				if d.has("spin"):
					node.rotation += d["spin"] * delta
				node.color.a = clampf(sin(t * 0.8 + d["phase"]) * 0.1 + 0.35, 0.1, 0.5)
				if node.position.y > 410:
					node.position.y = randf_range(-20, -5)
					node.position.x = randf_range(0, 800)

			"float":
				node.position.y += sin(t * 0.5 + d["phase"]) * d["speed"] * delta
				node.position.x += cos(t * 0.3 + d["phase"]) * d["drift"] * delta
				node.color.a = clampf(sin(t * 0.7 + d["phase"]) * 0.15 + 0.25, 0.05, 0.45)
				if node.position.x < -10:
					node.position.x = 810.0
				elif node.position.x > 810:
					node.position.x = -10.0
				if node.position.y < -10:
					node.position.y = 410.0
				elif node.position.y > 410:
					node.position.y = -10.0


func _update_torch_shader() -> void:
	if not _fog_material:
		return

	var viewport = get_viewport()
	if not viewport:
		return

	var canvas_xform: Transform2D = viewport.get_canvas_transform()
	var vp_size: Vector2 = viewport.get_visible_rect().size

	# 只有摄像机真正移动时才重建 UV 数组
	if canvas_xform == _cached_canvas_xform and vp_size == _cached_vp_size:
		return
	_cached_canvas_xform = canvas_xform
	_cached_vp_size = vp_size

	var uvs := PackedVector2Array()
	var count: int = 0
	for pos in _torch_positions:
		if count >= 48:
			break
		var screen_pos: Vector2 = canvas_xform * (pos as Vector2)
		uvs.append(screen_pos / vp_size)
		count += 1

	while uvs.size() < 48:
		uvs.append(Vector2(-10.0, -10.0))

	_fog_material.set_shader_parameter("torch_count", count)
	_fog_material.set_shader_parameter("torch_uvs", uvs)


func add_torch_light(world_pos: Vector2) -> void:
	_torch_positions.append(world_pos)
	_spawn_torch_sprite(world_pos)


func clear_torches() -> void:
	_torch_positions.clear()
	for s in _torch_sprites:
		if is_instance_valid(s):
			s.queue_free()
	_torch_sprites.clear()


func _spawn_torch_sprite(world_pos: Vector2) -> void:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return

	var torch_tex = load("res://assets/sprites/objects/torch.png")
	if not torch_tex:
		return

	# 火把精灵动画
	var spr = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	frames.add_animation("flicker")
	frames.set_animation_speed("flicker", 6.0)
	frames.set_animation_loop("flicker", true)

	var atlas_w: int = torch_tex.get_width()
	var frame_w: int = 16
	var frame_count: int = atlas_w / frame_w

	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas = torch_tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, 16)
		frames.add_frame("flicker", atlas)

	spr.sprite_frames = frames
	spr.global_position = world_pos + Vector2(0, -4)
	spr.z_index = 5
	spr.play("flicker")
	scene_root.add_child(spr)
	_torch_sprites.append(spr)

	# 火把暖色光晕 (PointLight2D)
	var light = PointLight2D.new()
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.texture = _make_torch_glow_texture()
	light.global_position = world_pos
	light.texture_scale = 7.0
	light.color = Color(1.0, 0.7, 0.3)
	light.energy = 0.75
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	scene_root.add_child(light)
	_torch_sprites.append(light)


func _make_torch_glow_texture() -> ImageTexture:
	var size: int = 128
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = size / 2.0
	var max_r: float = size / 2.0
	for y in size:
		for x in size:
			var dx: float = x - center + 0.5
			var dy: float = y - center + 0.5
			var dist: float = sqrt(dx * dx + dy * dy) / max_r
			var alpha: float = 0.0
			if dist < 0.85:
				var t: float = 1.0 - dist / 0.85
				alpha = t * t * 0.6
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


func flash_transition(color: Color = Color.BLACK, duration: float = 0.35) -> void:
	_floor_overlay.color = Color(color.r, color.g, color.b, 0.0)
	var tween = create_tween()
	tween.tween_property(_floor_overlay, "color:a", 1.0, duration * 0.4)
	tween.tween_property(_floor_overlay, "color:a", 0.0, duration * 0.6)
