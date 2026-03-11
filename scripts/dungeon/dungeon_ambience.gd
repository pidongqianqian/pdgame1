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

var _theme_color: Color = Color(0.12, 0.08, 0.18)


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


func set_theme(theme_color: Color) -> void:
	_theme_color = theme_color
	_update_floor_theme()

	for d in _dust_nodes:
		var node: ColorRect = d["node"]
		node.color = Color(
			_theme_color.r * 4 + 0.5,
			_theme_color.g * 4 + 0.5,
			_theme_color.b * 4 + 0.5,
			node.color.a
		)


func _update_floor_theme() -> void:
	var floor_num: int = GameManager.current_floor
	var tint := Vector3(_theme_color.r, _theme_color.g, _theme_color.b)

	if _fog_material:
		_fog_material.set_shader_parameter("fog_tint", tint)
		var darkness_scale: float = 1.0 + floor_num * 0.02
		_fog_material.set_shader_parameter("edge_darkness",
			clampf(0.50 * darkness_scale, 0.0, 0.65))
		_fog_material.set_shader_parameter("base_darkness",
			clampf(0.18 + floor_num * 0.015, 0.0, 0.30))


func _spawn_dust_particles() -> void:
	var world_layer = CanvasLayer.new()
	world_layer.layer = 3
	add_child(world_layer)

	for i in 14:
		var dust = ColorRect.new()
		dust.size = Vector2(1, 1)
		dust.color = Color(0.7, 0.7, 0.9, randf_range(0.15, 0.35))
		dust.position = Vector2(randf_range(0, 800), randf_range(0, 400))
		dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world_layer.add_child(dust)
		_dust_nodes.append({
			"node": dust,
			"speed": randf_range(4.0, 14.0),
			"drift": randf_range(-8.0, 8.0),
			"phase": randf_range(0, TAU),
		})


func _process(delta: float) -> void:
	_animate_dust(delta)
	_update_torch_shader()


func _animate_dust(delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for d in _dust_nodes:
		var node: ColorRect = d["node"]
		node.position.y -= d["speed"] * delta
		node.position.x += sin(t * 0.8 + d["phase"]) * d["drift"] * delta
		node.color.a = (sin(t * 1.2 + d["phase"]) * 0.1 + 0.22)
		if node.position.y < -4:
			node.position.y = 364.0
			node.position.x = randf_range(0, 800)


func _update_torch_shader() -> void:
	if not _fog_material:
		return
	_fog_material.set_shader_parameter("time_val",
		Time.get_ticks_msec() / 1000.0)

	var viewport = get_viewport()
	if not viewport:
		return

	var canvas_xform: Transform2D = viewport.get_canvas_transform()
	var vp_size: Vector2 = viewport.get_visible_rect().size

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
