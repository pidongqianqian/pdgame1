extends CanvasLayer

signal selection_made

var _player: Player
var _options: Array = []
var _mode: String = "passive"  # "passive" or "floor_reward"
var _closed: bool = false


func _process(_delta: float) -> void:
	if _closed:
		return
	if not _player or not is_instance_valid(_player):
		_force_close()
		return
	if _player.current_state == Player.State.DEAD:
		_force_close()


func _force_close() -> void:
	_closed = true
	if not NetworkManager.is_multiplayer_active():
		get_tree().paused = false
	selection_made.emit()


func setup_passive_select(p: Player) -> void:
	_player = p
	_mode = "passive"
	var exclude: Array = []
	for pid in p.stats.passive_stacks:
		if not SkillDatabase.PASSIVE_TALENTS[pid]["stackable"]:
			exclude.append(pid)
	_options = SkillDatabase.get_random_passives(3, exclude)
	_build_ui()


func setup_floor_reward(p: Player) -> void:
	_player = p
	_mode = "floor_reward"
	var exclude: Array = []
	for pid in p.stats.passive_stacks:
		if not SkillDatabase.PASSIVE_TALENTS[pid]["stackable"]:
			exclude.append(pid)
	_options = SkillDatabase.get_random_passives(3, exclude)
	_build_ui()


func _build_ui() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not NetworkManager.is_multiplayer_active():
		get_tree().paused = true

	# 半透明遮罩
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(overlay)
	var fade_tw = create_tween()
	fade_tw.tween_property(overlay, "color:a", 0.45, 0.3)

	# 中心面板
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -100
	panel.offset_bottom = 100
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.10, 0.96)
	sb.border_color = Color(0.5, 0.4, 0.8, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 标题
	var title = Label.new()
	if _mode == "passive":
		title.text = "升级！选择一个天赋 (Lv.%d)" % _player.stats.level
	else:
		title.text = "过层奖励！选择一个天赋"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, UITheme.FONT_SIZE_BODY, UITheme.COLORS["text_gold"])
	vbox.add_child(title)

	# 三个选项卡
	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 8)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_row)

	for option_id in _options:
		cards_row.add_child(_create_option_card(option_id))

	# 入场动画
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = Vector2(180, 100)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.35).set_delay(0.1)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_delay(0.1)


func _create_option_card(option_id: String) -> PanelContainer:
	var data: Dictionary = SkillDatabase.PASSIVE_TALENTS[option_id]
	var stacks: int = _player.stats.passive_stacks.get(option_id, 0)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 110)
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.08, 0.16, 0.9)
	card_sb.border_color = Color(0.4, 0.35, 0.6, 0.7)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(3)
	card_sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(icon_lbl, UITheme.FONT_SIZE_TITLE, Color.WHITE)
	vbox.add_child(icon_lbl)

	var name_lbl = Label.new()
	var display_name: String = data["name"]
	if stacks > 0:
		display_name += " x%d" % (stacks + 1)
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(name_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_gold"])
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(desc_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	vbox.add_child(desc_lbl)

	var btn = Button.new()
	btn.text = "  选择  "
	btn.custom_minimum_size = Vector2(0, 22)
	UITheme.style_button(btn, UITheme.FONT_SIZE_SMALL)
	btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	btn.add_theme_stylebox_override("normal", _make_select_btn_style(false))
	btn.add_theme_stylebox_override("hover", _make_select_btn_style(true))
	btn.pressed.connect(_on_option_selected.bind(option_id))
	vbox.add_child(btn)

	return card


func _on_option_selected(option_id: String) -> void:
	if not _player or not is_instance_valid(_player):
		if not NetworkManager.is_multiplayer_active():
			get_tree().paused = false
		selection_made.emit()
		return

	_player.stats.learn_passive(option_id)

	var data: Dictionary = SkillDatabase.PASSIVE_TALENTS[option_id]
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if not hud_nodes.is_empty() and hud_nodes[0].has_method("show_pickup_text"):
		hud_nodes[0].show_pickup_text(
			"习得天赋 [%s] %s" % [data["icon"], data["name"]],
			UITheme.COLORS["text_gold"]
		)

	if not NetworkManager.is_multiplayer_active():
		get_tree().paused = false
	selection_made.emit()


func _make_select_btn_style(hover: bool) -> StyleBoxFlat:
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.30, 0.20, 0.05, 0.9) if hover else Color(0.20, 0.14, 0.03, 0.8)
	sb_style.border_color = UITheme.COLORS["text_gold"]
	sb_style.set_border_width_all(1)
	sb_style.set_corner_radius_all(2)
	sb_style.set_content_margin_all(4)
	return sb_style
