extends CanvasLayer

var _selected_class: int = GameManager.PlayerClass.WARRIOR
var _cards: Array[PanelContainer] = []
var _confirm_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.04, 0.10, 1.0)
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24; root.offset_right = -24
	root.offset_top  = 12; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# 标题
	var title = Label.new()
	title.text = "选择你的职业"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, UITheme.FONT_SIZE_HEADER, UITheme.COLORS["text_gold"])
	root.add_child(title)

	var sub = Label.new()
	sub.text = "每种职业有独特的攻击方式和闪避技能"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(sub, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	root.add_child(sub)

	# 职业卡片行
	var cards_row = HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 10)
	root.add_child(cards_row)

	for cls in GameManager.CLASS_DATA:
		var card = _make_card(cls)
		cards_row.add_child(card)
		_cards.append(card)

	# 底部确认行 —— 固定高度，不参与拉伸
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.custom_minimum_size = Vector2(0, 36)
	root.add_child(bottom)

	var back_btn = Button.new()
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(90, 26)
	UITheme.style_button(back_btn, UITheme.FONT_SIZE_BODY)
	back_btn.pressed.connect(_on_back)
	bottom.add_child(back_btn)

	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(160, 30)
	UITheme.style_button(_confirm_btn, UITheme.FONT_SIZE_HEADER)
	_confirm_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	_confirm_btn.pressed.connect(_on_confirm)
	bottom.add_child(_confirm_btn)

	_select_class(GameManager.PlayerClass.WARRIOR)


func _make_card(cls: int) -> PanelContainer:
	var data = GameManager.CLASS_DATA[cls]
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(inner)

	# 职业图标
	var icon_lbl = Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", data["color"])
	inner.add_child(icon_lbl)

	# 职业名
	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(name_lbl, UITheme.FONT_SIZE_HEADER, data["color"])
	inner.add_child(name_lbl)

	# 称号
	var title_lbl = Label.new()
	title_lbl.text = data["title"]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	inner.add_child(title_lbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(data["color"].r, data["color"].g, data["color"].b, 0.3)
	inner.add_child(sep)

	# 属性条
	_add_stat_bar(inner, "生命", data["max_hp"],   130, Color(0.85, 0.2, 0.2))
	_add_stat_bar(inner, "攻击", data["attack"],    20, Color(1.0,  0.7, 0.2))
	_add_stat_bar(inner, "防御", data["defense"],    8, Color(0.3,  0.6, 1.0))
	_add_stat_bar(inner, "速度", int(data["speed"]), 78, Color(0.3,  1.0, 0.5))

	var sep2 = ColorRect.new()
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.color = Color(data["color"].r, data["color"].g, data["color"].b, 0.2)
	inner.add_child(sep2)

	# 描述
	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(desc_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	inner.add_child(desc_lbl)

	# 点击选中
	var btn_overlay = Button.new()
	btn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_overlay.flat = true
	btn_overlay.add_theme_stylebox_override("normal",   StyleBoxEmpty.new())
	btn_overlay.add_theme_stylebox_override("hover",    StyleBoxEmpty.new())
	btn_overlay.add_theme_stylebox_override("pressed",  StyleBoxEmpty.new())
	btn_overlay.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	btn_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_overlay.pressed.connect(func(): _select_class(cls))
	card.add_child(btn_overlay)

	return card


func _add_stat_bar(parent: VBoxContainer, label: String, value: int, max_val: int, color: Color) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(28, 0)
	UITheme.style_label(lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	row.add_child(lbl)

	var bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 5)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.15, 0.12, 0.20)
	row.add_child(bar_bg)

	var bar_fill = ColorRect.new()
	var ratio = clampf(float(value) / float(max_val), 0.0, 1.0)
	bar_fill.size = Vector2(ratio, 5)
	bar_fill.size_flags_horizontal = Control.SIZE_FILL
	bar_fill.color = color
	bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.offset_right = ratio * 100.0 - 100.0
	bar_bg.add_child(bar_fill)


func _select_class(cls: int) -> void:
	_selected_class = cls
	var data = GameManager.CLASS_DATA[cls]

	_confirm_btn.text = "出发！以%s之名" % data["name"]
	_confirm_btn.add_theme_color_override("font_color", data["color"])

	for i in _cards.size():
		var card = _cards[i]
		var is_selected = (i == cls)
		var cd = GameManager.CLASS_DATA[i]

		var sb = StyleBoxFlat.new()
		if is_selected:
			sb.bg_color = Color(
				cd["color"].r * 0.18,
				cd["color"].g * 0.18,
				cd["color"].b * 0.18, 0.95)
			sb.border_color = cd["color"]
			sb.set_border_width_all(2)
		else:
			sb.bg_color = Color(0.09, 0.07, 0.14, 0.85)
			sb.border_color = Color(0.28, 0.22, 0.38, 0.6)
			sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", sb)

		var scale_tween = create_tween()
		if is_selected:
			scale_tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.12)
		else:
			scale_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.08)


func _on_confirm() -> void:
	GameManager.current_class = _selected_class
	var main = get_tree().current_scene
	if main.has_method("start_game"):
		main.start_game()


func _on_back() -> void:
	var main = get_tree().current_scene
	if main.has_method("return_to_title"):
		main.return_to_title()
