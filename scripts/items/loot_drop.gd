extends Area2D

var item_data: Dictionary = {}
var _bob_tween: Tween
var _name_label: Label
var _glow_sprite: Sprite2D

@onready var sprite: Sprite2D = $Sprite2D

# 稀有度对应的发光颜色和强度
const RARITY_GLOW = {
	0: {"color": Color(0.7, 0.7, 0.8),  "energy": 0.20},  # 普通 - 微蓝白
	1: {"color": Color(0.3, 0.9, 0.3),  "energy": 0.35},  # 精良 - 绿
	2: {"color": Color(0.3, 0.5, 1.0),  "energy": 0.50},  # 稀有 - 蓝
	3: {"color": Color(0.7, 0.2, 1.0),  "energy": 0.65},  # 史诗 - 紫
	4: {"color": Color(1.0, 0.55, 0.1), "energy": 0.85},  # 传说 - 橙金
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var rarity: int = item_data.get("rarity", 0)
	var item_color = item_data.get("color", Color.WHITE)

	var icon_path: String = item_data.get("icon", "")
	if icon_path != "":
		var tex = load(icon_path)
		if tex:
			sprite.texture = tex
			sprite.modulate = Color.WHITE
	elif item_data.has("color"):
		sprite.modulate = item_color

	var drop_scale: float = 0.5
	if OS.has_feature("android") or OS.has_feature("mobile"):
		drop_scale = 1.0
	sprite.scale = Vector2(drop_scale, drop_scale)

	# 物品名称标签
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-32, 9)
	_name_label.size = Vector2(64, 12)
	_name_label.add_theme_font_size_override("font_size", 5)
	_name_label.add_theme_color_override("font_color", item_color)
	_name_label.text = item_data.get("name", "")
	add_child(_name_label)

	# 发光效果（稀有度越高越亮）
	_create_glow_light(rarity)

	# 传说/史诗物品加粒子光晕
	if rarity >= 3:
		_create_sparkle_effect(rarity)

	_start_bob_animation()


func _create_glow_light(rarity: int) -> void:
	var glow_data = RARITY_GLOW.get(rarity, RARITY_GLOW[0])

	var size: int = 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = size / 2.0
	var max_r: float = size / 2.0
	for y in size:
		for x in size:
			var dx: float = x - center + 0.5
			var dy: float = y - center + 0.5
			var dist: float = sqrt(dx * dx + dy * dy) / max_r
			var a: float = 0.0
			if dist < 1.0:
				var t: float = 1.0 - dist
				a = t * t * 0.65
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))

	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = ImageTexture.create_from_image(img)
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var glow_scale: float = 0.6 + rarity * 0.15
	_glow_sprite.scale = Vector2(glow_scale, glow_scale)
	_glow_sprite.modulate = Color(glow_data["color"].r, glow_data["color"].g,
		glow_data["color"].b, glow_data["energy"])
	_glow_sprite.z_index = -1
	add_child(_glow_sprite)

	var pulse := create_tween()
	pulse.set_loops()
	var hi_a: float = glow_data["energy"] * 1.3
	var lo_a: float = glow_data["energy"] * 0.6
	pulse.tween_property(_glow_sprite, "modulate:a", hi_a, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_glow_sprite, "modulate:a", lo_a, 0.8).set_trans(Tween.TRANS_SINE)


func _create_sparkle_effect(rarity: int) -> void:
	var glow_data = RARITY_GLOW.get(rarity, RARITY_GLOW[0])
	var sparkle_count = 3 + (rarity - 3) * 2

	for i in sparkle_count:
		var sp = ColorRect.new()
		sp.size = Vector2(1, 1)
		sp.color = glow_data["color"]
		sp.color.a = 0.0
		add_child(sp)

		var delay = randf_range(0, 1.5)
		var tween = create_tween()
		tween.set_loops()
		tween.tween_interval(delay)

		var angle = randf() * TAU
		var radius = randf_range(3.0, 7.0)
		var tx = cos(angle) * radius
		var ty = sin(angle) * radius

		sp.position = Vector2(tx, ty)
		tween.tween_property(sp, "color:a", 0.9, 0.3)
		tween.tween_property(sp, "position", Vector2(tx * 1.8, ty * 1.8 - 3), 0.5)
		tween.tween_property(sp, "color:a", 0.0, 0.3)
		tween.tween_property(sp, "position", Vector2(tx, ty), 0.0)


func _start_bob_animation() -> void:
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(sprite, "position:y", -3.0, 0.55).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(sprite, "position:y",  0.0, 0.55).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		var player_node = body as Player
		# 技能卷轴直接使用，不占背包
		if item_data.get("type", "") == "skill_scroll":
			var pid: String = item_data.get("passive_id", "")
			if pid != "":
				player_node.stats.learn_passive(pid)
			_pickup_effect()
			return
		if player_node.stats.add_to_inventory(item_data):
			_pickup_effect()
		else:
			_show_full_message()


func _pickup_effect() -> void:
	set_deferred("monitoring", false)

	var rarity_name = item_data.get("rarity_name", "")
	var item_name   = item_data.get("name", "")
	var color       = item_data.get("color", Color.WHITE)

	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if not hud_nodes.is_empty():
		var hud_node = hud_nodes[0]
		if hud_node.has_method("show_pickup_text"):
			hud_node.show_pickup_text("获得 [%s] %s" % [rarity_name, item_name], color)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.15)
	tween.parallel().tween_property(self, "position:y", position.y - 14, 0.18)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func _show_full_message() -> void:
	_name_label.text = "背包已满!"
	_name_label.add_theme_color_override("font_color", Color.RED)
	var tween = create_tween()
	tween.tween_property(_name_label, "modulate:a", 0.0, 1.0)
	tween.tween_property(_name_label, "modulate:a", 1.0, 0.0)
