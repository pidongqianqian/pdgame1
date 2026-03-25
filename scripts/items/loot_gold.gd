extends Area2D

var gold_amount: int = 5

const COLORS_BY_VALUE = [
	{"min": 1,  "max": 9,   "color": Color(0.95, 0.80, 0.20), "size": 3},  # 小铜钱
	{"min": 10, "max": 29,  "color": Color(1.00, 0.88, 0.30), "size": 4},  # 金币
	{"min": 30, "max": 999, "color": Color(1.00, 0.95, 0.55), "size": 5},  # 大金币
]

var _label: Label


func _ready() -> void:
	var cfg = COLORS_BY_VALUE[0]
	for c in COLORS_BY_VALUE:
		if gold_amount >= c["min"] and gold_amount <= c["max"]:
			cfg = c; break

	collision_layer = 0
	collision_mask  = 2  # 检测玩家层

	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = float(cfg["size"]) + 1.0
	col.shape = shape
	add_child(col)

	var coin_tex = load("res://assets/sprites/items/gold_coin.png")
	var coin = Sprite2D.new()
	if coin_tex:
		coin.texture = coin_tex
		coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var coin_scale: float = float(cfg["size"]) / 16.0
	if OS.has_feature("android") or OS.has_feature("mobile"):
		coin_scale *= 2.0
	coin.scale = Vector2(coin_scale, coin_scale)
	add_child(coin)

	# 金额标签
	_label = Label.new()
	_label.text = "+%d" % gold_amount
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-12, -(cfg["size"] * 2 + 8))
	_label.size = Vector2(24, 10)
	_label.add_theme_font_size_override("font_size", 5)
	_label.add_theme_color_override("font_color", cfg["color"])
	_label.modulate.a = 0.0
	add_child(_label)

	# 入场动画：从上方落下并弹跳
	var start_y = position.y - randf_range(8, 18)
	position.y = start_y
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + (position.y - start_y) * -1 + randf_range(2, 6), 0.25).set_trans(Tween.TRANS_BOUNCE)

	var shimmer = create_tween().set_loops()
	shimmer.tween_property(coin, "modulate", Color(1.2, 1.2, 0.9), 0.4)
	shimmer.tween_property(coin, "modulate", Color.WHITE, 0.4)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	set_deferred("monitoring", false)

	GameManager.add_gold(gold_amount)

	# 显示 +X 文字飘上去
	_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(_label, "position:y", _label.position.y - 12, 0.5)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, 0.5)

	# 金币消失动画
	var coin_tween = create_tween()
	coin_tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.06)
	coin_tween.tween_property(self, "scale", Vector2(0.0, 0.0), 0.12)
	coin_tween.tween_callback(queue_free)
