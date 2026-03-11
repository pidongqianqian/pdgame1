extends CanvasLayer

signal closed

var _player: Player = null
var _selected_item: Dictionary = {}
var _selected_index: int = -1
var _is_inventory_item: bool = true
var _inv_page: int = 0
const ITEMS_PER_PAGE = 7

var _root: PanelContainer
var _equip_list: VBoxContainer
var _item_list: VBoxContainer
var _detail_label: Label
var _actions_box: VBoxContainer
var _inv_header_label: Label
var _page_label: Label
var _prev_btn: Button
var _next_btn: Button


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.anchors_preset = Control.PRESET_FULL_RECT
	_root.offset_left = 20.0
	_root.offset_top = 10.0
	_root.offset_right = -20.0
	_root.offset_bottom = -10.0
	_root.add_theme_stylebox_override("panel", UITheme.make_panel(UITheme.COLORS["bg_dark"]))
	add_child(_root)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	_root.add_child(main_vbox)

	var title_bar = HBoxContainer.new()
	main_vbox.add_child(title_bar)

	var title_lbl = Label.new()
	title_lbl.text = "装备背包"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(title_lbl, UITheme.FONT_SIZE_HEADER, UITheme.COLORS["text_gold"])
	title_bar.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(50, 22)
	UITheme.style_button(close_btn, UITheme.FONT_SIZE_SMALL)
	close_btn.pressed.connect(_on_close)
	title_bar.add_child(close_btn)

	var top_row = HBoxContainer.new()
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(top_row)

	# Left column: Equipment
	var equip_panel = PanelContainer.new()
	equip_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equip_panel.size_flags_stretch_ratio = 0.4
	equip_panel.add_theme_stylebox_override("panel", UITheme.make_panel(UITheme.COLORS["bg_panel"]))
	top_row.add_child(equip_panel)

	var equip_inner = VBoxContainer.new()
	equip_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equip_inner.add_theme_constant_override("separation", 3)
	equip_panel.add_child(equip_inner)

	var equip_header = Label.new()
	equip_header.text = "已装备"
	UITheme.style_label(equip_header, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_gold"])
	equip_inner.add_child(equip_header)

	_equip_list = VBoxContainer.new()
	_equip_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_list.add_theme_constant_override("separation", 2)
	equip_inner.add_child(_equip_list)

	# Right column: Inventory
	var inv_panel = PanelContainer.new()
	inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_panel.size_flags_stretch_ratio = 0.6
	inv_panel.add_theme_stylebox_override("panel", UITheme.make_panel(UITheme.COLORS["bg_panel"]))
	inv_panel.clip_contents = true
	top_row.add_child(inv_panel)

	var inv_inner = VBoxContainer.new()
	inv_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_inner.add_theme_constant_override("separation", 3)
	inv_panel.add_child(inv_inner)

	var inv_header_row = HBoxContainer.new()
	inv_header_row.add_theme_constant_override("separation", 4)
	inv_inner.add_child(inv_header_row)

	_inv_header_label = Label.new()
	_inv_header_label.text = "背包"
	_inv_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(_inv_header_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_white"])
	inv_header_row.add_child(_inv_header_label)

	_prev_btn = Button.new()
	_prev_btn.text = "<"
	_prev_btn.custom_minimum_size = Vector2(22, 18)
	UITheme.style_button(_prev_btn, UITheme.FONT_SIZE_TINY)
	_prev_btn.pressed.connect(func(): _change_page(-1))
	inv_header_row.add_child(_prev_btn)

	_page_label = Label.new()
	_page_label.custom_minimum_size = Vector2(30, 0)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_page_label, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	inv_header_row.add_child(_page_label)

	_next_btn = Button.new()
	_next_btn.text = ">"
	_next_btn.custom_minimum_size = Vector2(22, 18)
	UITheme.style_button(_next_btn, UITheme.FONT_SIZE_TINY)
	_next_btn.pressed.connect(func(): _change_page(1))
	inv_header_row.add_child(_next_btn)

	var sell_row = HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 3)
	inv_inner.add_child(sell_row)

	var sell_common_btn = Button.new()
	sell_common_btn.text = "卖白装"
	sell_common_btn.custom_minimum_size = Vector2(50, 18)
	UITheme.style_button(sell_common_btn, UITheme.FONT_SIZE_TINY)
	sell_common_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	sell_common_btn.pressed.connect(func(): _batch_sell(0))
	sell_row.add_child(sell_common_btn)

	var sell_green_btn = Button.new()
	sell_green_btn.text = "卖绿装↓"
	sell_green_btn.custom_minimum_size = Vector2(54, 18)
	UITheme.style_button(sell_green_btn, UITheme.FONT_SIZE_TINY)
	sell_green_btn.add_theme_color_override("font_color", Color(0.5, 0.9, 0.4))
	sell_green_btn.pressed.connect(func(): _batch_sell(1))
	sell_row.add_child(sell_green_btn)

	var sell_blue_btn = Button.new()
	sell_blue_btn.text = "卖蓝装↓"
	sell_blue_btn.custom_minimum_size = Vector2(54, 18)
	UITheme.style_button(sell_blue_btn, UITheme.FONT_SIZE_TINY)
	sell_blue_btn.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	sell_blue_btn.pressed.connect(func(): _batch_sell(2))
	sell_row.add_child(sell_blue_btn)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_list.add_theme_constant_override("separation", 2)
	inv_inner.add_child(_item_list)

	# Bottom: Detail + Actions
	var bottom_panel = PanelContainer.new()
	bottom_panel.custom_minimum_size = Vector2(0, 56)
	bottom_panel.add_theme_stylebox_override("panel", UITheme.make_panel(UITheme.COLORS["bg_panel"]))
	main_vbox.add_child(bottom_panel)

	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(bottom_hbox)

	_detail_label = Label.new()
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(_detail_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	_detail_label.text = "选择物品查看详情"
	bottom_hbox.add_child(_detail_label)

	_actions_box = VBoxContainer.new()
	_actions_box.custom_minimum_size = Vector2(70, 0)
	_actions_box.add_theme_constant_override("separation", 3)
	_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_child(_actions_box)


func open() -> void:
	_player = GameManager.player_node as Player
	if not _player:
		return
	visible = true
	get_tree().paused = true
	_inv_page = 0
	_refresh()


func _on_close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("inventory"):
		_on_close()
		get_viewport().set_input_as_handled()


func _change_page(dir: int) -> void:
	if not _player:
		return
	var total = _player.stats.inventory.size()
	var max_page = maxi(0, (total - 1) / ITEMS_PER_PAGE)
	_inv_page = clampi(_inv_page + dir, 0, max_page)
	_refresh()


func _refresh() -> void:
	for child in _equip_list.get_children():
		child.queue_free()
	for child in _item_list.get_children():
		child.queue_free()
	_clear_actions()
	_detail_label.text = "选择物品查看详情"
	_detail_label.add_theme_color_override("font_color", UITheme.COLORS["text_dim"])

	if not _player:
		return

	var total = _player.stats.inventory.size()
	var max_page = maxi(0, (total - 1) / ITEMS_PER_PAGE) if total > 0 else 0
	_inv_page = clampi(_inv_page, 0, max_page)

	_inv_header_label.text = "背包 (%d/%d)" % [total, _player.stats.MAX_INVENTORY_SIZE]
	_page_label.text = "%d/%d" % [_inv_page + 1, max_page + 1]
	_prev_btn.disabled = _inv_page <= 0
	_next_btn.disabled = _inv_page >= max_page

	var slot_names = {0: "武器", 1: "头盔", 2: "护甲", 3: "靴子", 4: "饰品"}
	for slot_id in 5:
		if _player.stats.equipment.has(slot_id):
			var item = _player.stats.equipment[slot_id]
			_equip_list.add_child(_create_item_button(item, false, slot_id, slot_names.get(slot_id, "")))
		else:
			_equip_list.add_child(_create_empty_slot(slot_names.get(slot_id, "")))

	if total == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "（空）"
		UITheme.style_label(empty_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
		_item_list.add_child(empty_lbl)
	else:
		var start_idx = _inv_page * ITEMS_PER_PAGE
		var end_idx = mini(start_idx + ITEMS_PER_PAGE, total)
		for i in range(start_idx, end_idx):
			var item = _player.stats.inventory[i]
			_item_list.add_child(_create_item_button(item, true, i, ""))


func _create_empty_slot(slot_name: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.make_panel(UITheme.COLORS["bg_slot"]))
	panel.custom_minimum_size = Vector2(0, 20)
	var lbl = Label.new()
	lbl.text = "%s:  空" % slot_name
	UITheme.style_label(lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	panel.add_child(lbl)
	return panel


func _create_item_button(item: Dictionary, is_inv: bool, index: int, slot_prefix: String) -> Button:
	var btn = Button.new()
	var rarity: int = item.get("rarity", 0)
	var item_name = item.get("name", "???")

	if slot_prefix != "":
		btn.text = "%s: %s" % [slot_prefix, item_name]
	else:
		var rarity_name = item.get("rarity_name", "")
		btn.text = "%s %s" % [rarity_name, item_name]

	var rarity_bg = UITheme.RARITY_BG.get(rarity, UITheme.COLORS["bg_slot"])
	btn.add_theme_stylebox_override("normal", UITheme.make_panel(rarity_bg))
	btn.add_theme_stylebox_override("hover", UITheme.make_button_hover())
	btn.add_theme_stylebox_override("pressed", UITheme.make_button_pressed())
	btn.add_theme_stylebox_override("focus", UITheme.make_button_hover())
	btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	btn.add_theme_color_override("font_color", item.get("color", Color.WHITE))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 22)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	btn.pressed.connect(func():
		_selected_item = item
		_selected_index = index
		_is_inventory_item = is_inv
		_show_detail(item, is_inv)
	)
	btn.mouse_entered.connect(func():
		_show_detail(item, is_inv)
	)
	return btn


func _format_diff(label: String, new_val: int, old_val: int) -> String:
	var diff: int = new_val - old_val
	if diff > 0:
		return "%s+%d(↑%d)" % [label, new_val, diff]
	elif diff < 0:
		return "%s+%d(↓%d)" % [label, new_val, -diff]
	elif new_val > 0:
		return "%s+%d(=)" % [label, new_val]
	return ""


func _show_detail(item: Dictionary, is_inv: bool) -> void:
	var rarity_name = item.get("rarity_name", "未知")
	var slot_name = ItemDatabase.SLOT_NAMES.get(item.get("slot", 0), "未知")
	var name_str = item.get("name", "???")
	var color = item.get("color", Color.WHITE)

	var lines: Array[String] = ["[%s] %s  (%s)" % [rarity_name, name_str, slot_name]]

	var slot_id: int = item.get("slot", 0)
	var equipped: Dictionary = {}
	if _player and _player.stats.equipment.has(slot_id):
		equipped = _player.stats.equipment[slot_id]

	var has_compare: bool = is_inv and not equipped.is_empty() and equipped.get("uid", "") != item.get("uid", "")

	if has_compare:
		var parts: Array[String] = []
		var d_atk = _format_diff("攻击", item.get("attack", 0), equipped.get("attack", 0))
		var d_def = _format_diff("防御", item.get("defense", 0), equipped.get("defense", 0))
		var d_hp = _format_diff("生命", item.get("hp", 0), equipped.get("hp", 0))
		var d_spd = _format_diff("速度", item.get("speed", 0), equipped.get("speed", 0))
		for s in [d_atk, d_def, d_hp, d_spd]:
			if s != "":
				parts.append(s)
		if not parts.is_empty():
			lines.append("  ".join(parts))
		lines.append("对比: %s" % equipped.get("name", "???"))
	else:
		var stats: Array[String] = []
		if item.get("attack", 0) > 0:
			stats.append("攻击+%d" % item["attack"])
		if item.get("defense", 0) > 0:
			stats.append("防御+%d" % item["defense"])
		if item.get("hp", 0) > 0:
			stats.append("生命+%d" % item["hp"])
		var spd = item.get("speed", 0)
		if spd != 0:
			stats.append("速度%+d" % spd)
		if not stats.is_empty():
			lines.append("  ".join(stats))

	var sell_price: int = item.get("sell_price", 0)
	lines.append("售价 %d 金" % sell_price)

	_detail_label.text = "\n".join(lines)
	_detail_label.add_theme_color_override("font_color", color)

	_clear_actions()
	if is_inv:
		var equip_btn = Button.new()
		equip_btn.text = "装备"
		equip_btn.custom_minimum_size = Vector2(60, 22)
		UITheme.style_button(equip_btn, UITheme.FONT_SIZE_SMALL)
		equip_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
		equip_btn.pressed.connect(func():
			_player.stats.equip_item(_selected_item)
			_refresh()
		)
		_actions_box.add_child(equip_btn)

		var sell_btn = Button.new()
		sell_btn.text = "出售 +%d金" % sell_price
		sell_btn.custom_minimum_size = Vector2(60, 22)
		UITheme.style_button(sell_btn, UITheme.FONT_SIZE_SMALL)
		sell_btn.add_theme_color_override("font_color", Color(1.0, 0.80, 0.20))
		sell_btn.pressed.connect(func():
			_player.stats.remove_from_inventory(_selected_item)
			GameManager.add_gold(sell_price)
			_show_sell_flash(sell_price)
			_refresh()
		)
		_actions_box.add_child(sell_btn)

		var drop_btn = Button.new()
		drop_btn.text = "丢弃"
		drop_btn.custom_minimum_size = Vector2(60, 22)
		UITheme.style_button(drop_btn, UITheme.FONT_SIZE_SMALL)
		drop_btn.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))
		drop_btn.pressed.connect(func():
			_player.stats.remove_from_inventory(_selected_item)
			_refresh()
		)
		_actions_box.add_child(drop_btn)
	else:
		var unequip_btn = Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.custom_minimum_size = Vector2(60, 22)
		UITheme.style_button(unequip_btn, UITheme.FONT_SIZE_SMALL)
		unequip_btn.pressed.connect(func():
			_player.stats.unequip_item(_selected_index)
			_refresh()
		)
		_actions_box.add_child(unequip_btn)

		var sell_eq_btn = Button.new()
		sell_eq_btn.text = "出售 +%d金" % sell_price
		sell_eq_btn.custom_minimum_size = Vector2(60, 22)
		UITheme.style_button(sell_eq_btn, UITheme.FONT_SIZE_SMALL)
		sell_eq_btn.add_theme_color_override("font_color", Color(1.0, 0.80, 0.20))
		sell_eq_btn.pressed.connect(func():
			_player.stats.unequip_item(_selected_index)
			# unequip 会把装备放回背包，再从背包移除
			if _selected_item in _player.stats.inventory:
				_player.stats.remove_from_inventory(_selected_item)
			GameManager.add_gold(sell_price)
			_show_sell_flash(sell_price)
			_refresh()
		)
		_actions_box.add_child(sell_eq_btn)


func _show_sell_flash(amount: int) -> void:
	# 在详情区显示 "+X金" 飘字
	var flash = Label.new()
	flash.text = "+%d 金" % amount
	flash.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_BODY)
	flash.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	flash.position = _detail_label.global_position + Vector2(10, -4)
	flash.z_index = 100
	# 加到 root 容器上，让它浮在界面上方
	_root.add_child(flash)
	var tween = create_tween()
	tween.tween_property(flash, "position:y", flash.position.y - 18, 0.6)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.6)
	tween.tween_callback(flash.queue_free)


func _batch_sell(max_rarity: int) -> void:
	if not _player:
		return
	var to_sell: Array[Dictionary] = []
	for item in _player.stats.inventory:
		var r: int = item.get("rarity", 0)
		if r <= max_rarity and item.get("type", "") != "skill_scroll":
			to_sell.append(item)

	if to_sell.is_empty():
		_detail_label.text = "没有可出售的装备"
		_detail_label.add_theme_color_override("font_color", UITheme.COLORS["text_dim"])
		return

	var total_gold: int = 0
	var count: int = to_sell.size()
	for item in to_sell:
		total_gold += item.get("sell_price", 0)
		_player.stats.remove_from_inventory(item)
	GameManager.add_gold(total_gold)

	var rarity_label: String
	match max_rarity:
		0: rarity_label = "普通"
		1: rarity_label = "精良及以下"
		2: rarity_label = "稀有及以下"
		_: rarity_label = "装备"
	_detail_label.text = "已出售 %d 件%s装备，获得 %d 金" % [count, rarity_label, total_gold]
	_detail_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_show_sell_flash(total_gold)
	_refresh()


func _clear_actions() -> void:
	for child in _actions_box.get_children():
		child.queue_free()
