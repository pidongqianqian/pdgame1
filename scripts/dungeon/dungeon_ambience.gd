extends CanvasLayer

const VIGNETTE_SHADER = "
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform float softness  : hint_range(0.1, 2.0) = 0.5;
uniform vec4  tint_color = vec4(0.0, 0.0, 0.02, 1.0);
void fragment() {
	vec2 uv  = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vig  = smoothstep(1.0 - softness, 1.0, dist * intensity);
	COLOR = vec4(tint_color.rgb, vig * 0.88);
}
"

const TORCH_SHADER = "
shader_type canvas_item;
uniform float time_offset = 0.0;
void fragment() {
	float flicker = sin(TIME * 8.0 + time_offset) * 0.12
	              + sin(TIME * 17.3 + time_offset * 2.0) * 0.06
	              + 0.82;
	COLOR = texture(TEXTURE, UV) * vec4(1.0, 1.0, 1.0, flicker);
}
"

var _vignette: ColorRect
var _dust_nodes: Array = []
var _torch_lights: Array = []
var _floor_overlay: ColorRect

# 每层的色调（RGB色偏）
const FLOOR_TINTS = {
	1: Color(0.0, 0.0, 0.02),   # 1-2层: 蓝黑
	3: Color(0.03, 0.0, 0.0),   # 3-4层: 暗红
	5: Color(0.02, 0.0, 0.04),  # 5+层: 深紫
}


func _ready() -> void:
	layer = 5
	_create_vignette()
	_create_floor_overlay()
	_spawn_dust_particles()
	_update_floor_theme()


func _create_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.62)
	mat.set_shader_parameter("softness", 0.50)
	_vignette.material = mat
	add_child(_vignette)


func _create_floor_overlay() -> void:
	_floor_overlay = ColorRect.new()
	_floor_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor_overlay.color = Color(0, 0, 0, 0)
	_floor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor_overlay)


func _update_floor_theme() -> void:
	var floor_num = GameManager.current_floor
	var tint: Color
	if floor_num >= 5:
		tint = FLOOR_TINTS[5]
	elif floor_num >= 3:
		tint = FLOOR_TINTS[3]
	else:
		tint = FLOOR_TINTS[1]

	var mat = _vignette.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tint_color",
			Vector4(tint.r, tint.g, tint.b, 1.0))


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
	_flicker_torches(delta)


func _animate_dust(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	for d in _dust_nodes:
		var node: ColorRect = d["node"]
		node.position.y -= d["speed"] * delta
		node.position.x += sin(t * 0.8 + d["phase"]) * d["drift"] * delta
		node.color.a = (sin(t * 1.2 + d["phase"]) * 0.1 + 0.22)
		if node.position.y < -4:
			node.position.y = 364.0
			node.position.x = randf_range(0, 800)


func _flicker_torches(delta: float) -> void:
	var t = Time.get_ticks_msec() / 1000.0
	for torch_data in _torch_lights:
		var light: PointLight2D = torch_data["light"]
		var offset: float = torch_data["offset"]
		if is_instance_valid(light):
			var flicker = sin(t * 7.5 + offset) * 0.12 + sin(t * 19.3 + offset) * 0.05
			light.energy = 0.65 + flicker
			light.position.x = torch_data["base_x"] + sin(t * 4.2 + offset) * 0.4


func add_torch_light(world_pos: Vector2) -> void:
	var light = PointLight2D.new()
	light.global_position = world_pos
	light.texture = _make_light_texture()
	light.texture_scale = 2.8
	light.color = Color(1.0, 0.72, 0.35)
	light.energy = 0.65
	light.blend_mode = PointLight2D.BLEND_MODE_ADD
	# 加入主场景而非 CanvasLayer
	get_tree().current_scene.add_child(light)
	_torch_lights.append({
		"light": light,
		"offset": randf_range(0, TAU),
		"base_x": world_pos.x,
	})


func _make_light_texture() -> GradientTexture2D:
	var tex = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	var g = Gradient.new()
	g.add_point(0.0, Color(1, 1, 1, 1))
	g.add_point(0.45, Color(1, 0.85, 0.5, 0.5))
	g.add_point(1.0, Color(1, 0.6, 0.2, 0))
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	return tex


func flash_transition(color: Color = Color.BLACK, duration: float = 0.35) -> void:
	_floor_overlay.color = Color(color.r, color.g, color.b, 0.0)
	var tween = create_tween()
	tween.tween_property(_floor_overlay, "color:a", 1.0, duration * 0.4)
	tween.tween_property(_floor_overlay, "color:a", 0.0, duration * 0.6)
