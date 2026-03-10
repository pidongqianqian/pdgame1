extends CanvasLayer

var _player: Player = null

var _hp_bar: Control
var _hp_fill: ColorRect
var _hp_bg: ColorRect
var _hp_label: Label
var _floor_label: Label
var _gold_label: Label
var _souls_label: Label
var _pickup_label: Label
var _pickup_timer: float = 0.0

# 多人模式下其他玩家的 HP 条（peer_id -> {bar, fill, label}）
var _mp_player_bars: Dictionary = {}
var _mp_bar_container: VBoxContainer = null

const BAR_WIDTH = 100
const BAR_HEIGHT = 10


func _ready() -> void:
	add_to_group("hud")
	GameManager.floor_changed.connect(_on_floor_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.souls_changed.connect(_on_souls_changed)
	_build_hud()
	_update_floor_display()
	_update_gold_display()
	_update_souls_display()


func _build_hud() -> void:
	var cls_data = GameManager.CLASS_DATA[GameManager.current_class]
	var cls_color: Color = cls_data["color"]

	var top_left = HBoxContainer.new()
	top_left.position = Vector2(8, 4)
	top_left.add_theme_constant_override("separation", 6)
	add_child(top_left)

	# 职业标签
	var cls_label = Label.new()
	cls_label.text = "[%s]" % cls_data["name"]
	UITheme.style_label(cls_label, UITheme.FONT_SIZE_TINY, cls_color)
	top_left.add_child(cls_label)

	var hp_icon = Label.new()
	hp_icon.text = "♥"
	UITheme.style_label(hp_icon, UITheme.FONT_SIZE_BODY, UITheme.COLORS["hp_red"])
	top_left.add_child(hp_icon)

	_hp_bar = Control.new()
	_hp_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT + 6)
	top_left.add_child(_hp_bar)

	var bar_border = ColorRect.new()
	bar_border.size = Vector2(BAR_WIDTH + 2, BAR_HEIGHT + 2)
	bar_border.position = Vector2(-1, 2)
	bar_border.color = UITheme.COLORS["border"]
	_hp_bar.add_child(bar_border)

	_hp_bg = ColorRect.new()
	_hp_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_bg.position = Vector2(0, 3)
	_hp_bg.color = UITheme.COLORS["hp_bg"]
	_hp_bar.add_child(_hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_fill.position = Vector2(0, 3)
	_hp_fill.color = UITheme.COLORS["hp_red"]
	_hp_bar.add_child(_hp_fill)

	_hp_label = Label.new()
	_hp_label.position = Vector2(0, -1)
	_hp_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT + 6)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_label(_hp_label, UITheme.FONT_SIZE_TINY, Color.WHITE)
	_hp_bar.add_child(_hp_label)

	# 右侧信息面板 —— 锚定到右上角，宽度自适应
	var top_right = VBoxContainer.new()
	top_right.anchor_left   = 1.0
	top_right.anchor_right  = 1.0
	top_right.anchor_top    = 0.0
	top_right.anchor_bottom = 0.0
	top_right.offset_left   = -162
	top_right.offset_right  = -8
	top_right.offset_top    = 4
	top_right.offset_bottom = 70
	top_right.add_theme_constant_override("separation", 2)
	add_child(top_right)

	_floor_label = Label.new()
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_floor_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_white"])
	top_right.add_child(_floor_label)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_gold_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_gold"])
	top_right.add_child(_gold_label)

	_souls_label = Label.new()
	_souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(_souls_label, UITheme.FONT_SIZE_SMALL, Color(0.6, 0.7, 1.0))
	top_right.add_child(_souls_label)

	# 拾取提示 —— 锚定底部居中
	_pickup_label = Label.new()
	_pickup_label.anchor_left   = 0.5
	_pickup_label.anchor_right  = 0.5
	_pickup_label.anchor_top    = 1.0
	_pickup_label.anchor_bottom = 1.0
	_pickup_label.offset_left   = -160
	_pickup_label.offset_right  = 160
	_pickup_label.offset_top    = -38
	_pickup_label.offset_bottom = -18
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_label.modulate.a = 0.0
	UITheme.style_label(_pickup_label, UITheme.FONT_SIZE_SMALL, Color.WHITE)
	add_child(_pickup_label)

	# 操作提示 —— 锚定底部居中，紧贴最底部
	var tip_text = _get_class_tip(GameManager.current_class)
	var tip_lbl = Label.new()
	tip_lbl.text = tip_text
	tip_lbl.anchor_left   = 0.0
	tip_lbl.anchor_right  = 1.0
	tip_lbl.anchor_top    = 1.0
	tip_lbl.anchor_bottom = 1.0
	tip_lbl.offset_left   = 8
	tip_lbl.offset_right  = -8
	tip_lbl.offset_top    = -16
	tip_lbl.offset_bottom = -2
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(tip_lbl, UITheme.FONT_SIZE_TINY, Color(cls_color.r, cls_color.g, cls_color.b, 0.45))
	add_child(tip_lbl)

	# 多人模式：其他玩家 HP 条面板（左侧）
	if NetworkManager.is_multiplayer_active():
		_mp_bar_container = VBoxContainer.new()
		_mp_bar_container.position = Vector2(8, 30)
		_mp_bar_container.add_theme_constant_override("separation", 4)
		add_child(_mp_bar_container)


func _get_class_tip(cls: int) -> String:
	match cls:
		GameManager.PlayerClass.WARRIOR: return "WASD移动  J=宽弧挥砍  K=翻滚闪避  I=背包"
		GameManager.PlayerClass.MAGE:    return "WASD移动  J=追踪魔法弹  K=短距闪现  I=背包"
		GameManager.PlayerClass.RANGER:  return "WASD移动  J=穿透箭矢(可移动射)  K=侧步闪避  I=背包"
		GameManager.PlayerClass.ROGUE:   return "WASD移动  J=二连斩  K=穿刺冲锋(造成伤害)  I=背包"
	return "WASD移动  J攻击  K闪避  I背包"


func _process(delta: float) -> void:
	if not _player and GameManager.player_node:
		_player = GameManager.player_node as Player
		if _player and _player.stats:
			_player.stats.hp_changed.connect(_on_hp_changed)
			_update_hp_display(_player.stats.current_hp, _player.stats.get_total_max_hp())
	elif _player and _player.stats:
		_update_hp_display(_player.stats.current_hp, _player.stats.get_total_max_hp())

	# 多人模式：更新/创建其他玩家的 HP 条
	if NetworkManager.is_multiplayer_active() and _mp_bar_container:
		var my_id: int = NetworkManager.get_local_peer_id()
		for peer_id in GameManager.player_nodes:
			if peer_id == my_id:
				continue
			var p: Node2D = GameManager.player_nodes[peer_id]
			if not p or not is_instance_valid(p):
				continue
			var pl: Player = p as Player
			if not pl or not pl.stats:
				continue
			if not _mp_player_bars.has(peer_id):
				_create_mp_player_bar(peer_id, pl)
			else:
				_update_mp_player_bar(peer_id, pl)

	if _pickup_timer > 0:
		_pickup_timer -= delta
		if _pickup_timer <= 0:
			var tw = create_tween()
			tw.tween_property(_pickup_label, "modulate:a", 0.0, 0.4)


func _create_mp_player_bar(peer_id: int, pl: Player) -> void:
	var cls_idx: int = NetworkManager.player_info.get(peer_id, {}).get("class", 0)
	var cls_color: Color = GameManager.CLASS_DATA[cls_idx]["color"]
	var cls_name: String = GameManager.CLASS_DATA[cls_idx]["name"]

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_mp_bar_container.add_child(row)

	var name_lbl = Label.new()
	name_lbl.text = "[%s]" % cls_name
	UITheme.style_label(name_lbl, UITheme.FONT_SIZE_TINY, cls_color)
	row.add_child(name_lbl)

	var bar_ctrl = Control.new()
	bar_ctrl.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT + 4)
	row.add_child(bar_ctrl)

	var bg = ColorRect.new()
	bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bg.position = Vector2(0, 2)
	bg.color = UITheme.COLORS["hp_bg"]
	bar_ctrl.add_child(bg)

	var fill = ColorRect.new()
	fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	fill.position = Vector2(0, 2)
	fill.color = cls_color
	bar_ctrl.add_child(fill)

	var lbl = Label.new()
	lbl.position = Vector2(0, -1)
	lbl.size = Vector2(BAR_WIDTH, BAR_HEIGHT + 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_label(lbl, UITheme.FONT_SIZE_TINY, Color.WHITE)
	bar_ctrl.add_child(lbl)

	_mp_player_bars[peer_id] = {"row": row, "fill": fill, "label": lbl, "name_lbl": name_lbl}
	_update_mp_player_bar(peer_id, pl)


func _update_mp_player_bar(peer_id: int, pl: Player) -> void:
	if not _mp_player_bars.has(peer_id):
		return
	var entry: Dictionary = _mp_player_bars[peer_id]
	var fill: ColorRect = entry["fill"]
	var lbl: Label = entry["label"]
	var name_lbl: Label = entry["name_lbl"]
	var ratio: float = float(pl.stats.current_hp) / float(maxi(pl.stats.get_total_max_hp(), 1))
	fill.size.x = BAR_WIDTH * ratio
	lbl.text = "%d/%d" % [pl.stats.current_hp, pl.stats.get_total_max_hp()]
	# 观战标记
	if pl.current_state == Player.State.DEAD:
		name_lbl.text = "[观战]"
		fill.color = Color(0.4, 0.4, 0.4)
	else:
		var cls_idx: int = NetworkManager.player_info.get(peer_id, {}).get("class", 0)
		var cls_color: Color = GameManager.CLASS_DATA[cls_idx]["color"]
		name_lbl.text = "[%s]" % GameManager.CLASS_DATA[cls_idx]["name"]
		fill.color = cls_color if ratio > 0.5 else (Color(0.9, 0.5, 0.2) if ratio > 0.25 else Color(1.0, 0.2, 0.2))


func _on_hp_changed(current: int, max_val: int) -> void:
	_update_hp_display(current, max_val)


func _update_hp_display(current: int, max_val: int) -> void:
	var ratio = float(current) / float(maxi(max_val, 1))
	_hp_fill.size.x = BAR_WIDTH * ratio
	_hp_label.text = "%d/%d" % [current, max_val]

	if ratio < 0.25:
		_hp_fill.color = Color(1.0, 0.2, 0.2)
	elif ratio < 0.5:
		_hp_fill.color = Color(0.9, 0.5, 0.2)
	else:
		_hp_fill.color = UITheme.COLORS["hp_red"]


func _on_floor_changed(_floor_num: int) -> void:
	_update_floor_display()

func _update_floor_display() -> void:
	_floor_label.text = "深渊 第%d层" % GameManager.current_floor

func _on_gold_changed(_amount: int) -> void:
	_update_gold_display()

func _update_gold_display() -> void:
	_gold_label.text = "金 %d" % GameManager.gold

func _on_souls_changed(_amount: int) -> void:
	_update_souls_display()

func _update_souls_display() -> void:
	_souls_label.text = "魂 %d" % GameManager.souls


func show_pickup_text(text: String, color: Color = Color.WHITE) -> void:
	_pickup_label.text = text
	_pickup_label.add_theme_color_override("font_color", color)
	_pickup_label.modulate.a = 1.0
	_pickup_timer = 2.0
