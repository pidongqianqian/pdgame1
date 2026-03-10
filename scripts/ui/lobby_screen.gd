extends CanvasLayer

# 职业图标/名称映射
const CLASS_ICONS = { 0: "⚔", 1: "✦", 2: "➶", 3: "匕" }
const CLASS_NAMES = { 0: "战士", 1: "法师", 2: "游侠", 3: "刺客" }
const CLASS_COLORS = {
	0: Color(0.55, 0.75, 1.0),
	1: Color(0.75, 0.45, 1.0),
	2: Color(0.45, 1.0, 0.55),
	3: Color(1.0, 0.55, 0.35),
}

var _status_label: Label
var _player_rows: Dictionary = {}   # peer_id -> HBoxContainer
var _player_list: VBoxContainer
var _start_btn: Button
var _ip_input: LineEdit
var _ready_btn: Button
var _connection_panel: VBoxContainer
var _lobby_panel: VBoxContainer
var _selected_class: int = GameManager.current_class


func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_refresh_player_list)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)
	NetworkManager.all_players_ready.connect(_on_all_ready)
	NetworkManager.game_start_requested.connect(_on_game_start)
	_build_ui()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.04, 0.10, 1.0)
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30; root.offset_right = -30
	root.offset_top = 14; root.offset_bottom = -14
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# 标题
	var title = Label.new()
	title.text = "多人游戏大厅"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, UITheme.FONT_SIZE_HEADER, UITheme.COLORS["text_gold"])
	root.add_child(title)

	# 状态标签
	_status_label = Label.new()
	_status_label.text = "选择主机或加入游戏"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_status_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	root.add_child(_status_label)

	# ── 连接面板 ────────────────────────────────────────────
	_connection_panel = VBoxContainer.new()
	_connection_panel.add_theme_constant_override("separation", 6)
	root.add_child(_connection_panel)

	var host_row = HBoxContainer.new()
	host_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_row.add_theme_constant_override("separation", 10)
	_connection_panel.add_child(host_row)

	var host_btn = Button.new()
	host_btn.text = "🏠 创建房间"
	host_btn.custom_minimum_size = Vector2(120, 28)
	UITheme.style_button(host_btn, UITheme.FONT_SIZE_BODY)
	host_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	host_btn.pressed.connect(_on_host_pressed)
	host_row.add_child(host_btn)

	var ip_lbl = Label.new()
	ip_lbl.text = "或输入IP加入："
	UITheme.style_label(ip_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	host_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "192.168.x.x"
	_ip_input.custom_minimum_size = Vector2(110, 24)
	_ip_input.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	host_row.add_child(_ip_input)

	var join_btn = Button.new()
	join_btn.text = "加入"
	join_btn.custom_minimum_size = Vector2(55, 28)
	UITheme.style_button(join_btn, UITheme.FONT_SIZE_BODY)
	join_btn.pressed.connect(_on_join_pressed)
	host_row.add_child(join_btn)

	# ── 玩家列表面板 ─────────────────────────────────────────
	_lobby_panel = VBoxContainer.new()
	_lobby_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_panel.add_theme_constant_override("separation", 5)
	_lobby_panel.visible = false
	root.add_child(_lobby_panel)

	var list_title = Label.new()
	list_title.text = "玩家列表（最多4人）"
	UITheme.style_label(list_title, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	_lobby_panel.add_child(list_title)

	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 4)
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_panel.add_child(_player_list)

	# ── 职业选择 ─────────────────────────────────────────────
	var class_row = HBoxContainer.new()
	class_row.alignment = BoxContainer.ALIGNMENT_CENTER
	class_row.add_theme_constant_override("separation", 8)
	_lobby_panel.add_child(class_row)

	var cls_lbl = Label.new()
	cls_lbl.text = "选择职业："
	UITheme.style_label(cls_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	class_row.add_child(cls_lbl)

	for cls in range(4):
		var btn = Button.new()
		btn.text = "%s %s" % [CLASS_ICONS[cls], CLASS_NAMES[cls]]
		btn.custom_minimum_size = Vector2(72, 24)
		btn.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
		btn.add_theme_color_override("font_color", CLASS_COLORS[cls])
		UITheme.style_button(btn, UITheme.FONT_SIZE_SMALL)
		btn.pressed.connect(func(): _on_class_selected(cls))
		class_row.add_child(btn)

	# ── 底部按钮行 ────────────────────────────────────────────
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.custom_minimum_size = Vector2(0, 34)
	bottom.add_theme_constant_override("separation", 14)
	root.add_child(bottom)

	var back_btn = Button.new()
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(88, 26)
	UITheme.style_button(back_btn, UITheme.FONT_SIZE_BODY)
	back_btn.pressed.connect(_on_back)
	bottom.add_child(back_btn)

	_ready_btn = Button.new()
	_ready_btn.text = "✓ 准备就绪"
	_ready_btn.custom_minimum_size = Vector2(110, 26)
	_ready_btn.visible = false
	UITheme.style_button(_ready_btn, UITheme.FONT_SIZE_BODY)
	_ready_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_ready_btn.pressed.connect(_on_ready_pressed)
	bottom.add_child(_ready_btn)

	_start_btn = Button.new()
	_start_btn.text = "  开始游戏  ▶"
	_start_btn.custom_minimum_size = Vector2(130, 30)
	_start_btn.visible = false
	UITheme.style_button(_start_btn, UITheme.FONT_SIZE_HEADER)
	_start_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	_start_btn.pressed.connect(_on_start_pressed)
	bottom.add_child(_start_btn)


# ══════════════════════════════════════════════════════════════
# Event handlers
# ══════════════════════════════════════════════════════════════

func _on_host_pressed() -> void:
	var err = NetworkManager.create_server()
	if err != OK:
		_set_status("创建房间失败：%d" % err, Color(1, 0.3, 0.3))
		return
	var ip = NetworkManager.get_local_ip()
	_set_status("房间已创建！你的IP：%s  等待玩家加入…" % ip, Color(0.5, 1.0, 0.5))
	_show_lobby()


func _on_join_pressed() -> void:
	var ip = _ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	_set_status("正在连接 %s…" % ip, UITheme.COLORS["text_dim"])
	var err = NetworkManager.join_server(ip)
	if err != OK:
		_set_status("连接失败：%d" % err, Color(1, 0.3, 0.3))


func _on_connected() -> void:
	_set_status("已加入房间！", Color(0.5, 1.0, 0.5))
	_show_lobby()


func _on_connection_failed() -> void:
	_set_status("连接失败，请检查IP地址", Color(1, 0.3, 0.3))


func _on_host_disconnected() -> void:
	_set_status("主机断开连接", Color(1, 0.5, 0.3))
	_hide_lobby()


func _on_class_selected(cls: int) -> void:
	_selected_class = cls
	GameManager.current_class = cls
	NetworkManager.set_local_class(cls)
	_refresh_player_list()


func _on_ready_pressed() -> void:
	var my_id = NetworkManager.get_local_peer_id()
	var is_ready = not (NetworkManager.player_info.get(my_id, {}).get("ready", false))
	NetworkManager.set_local_ready(is_ready)
	_ready_btn.text = "✓ 取消准备" if is_ready else "✓ 准备就绪"
	_ready_btn.add_theme_color_override("font_color",
		UITheme.COLORS["text_gold"] if is_ready else Color(0.5, 1.0, 0.5))


func _on_all_ready() -> void:
	if NetworkManager.is_hosting:
		_start_btn.visible = true


func _on_start_pressed() -> void:
	NetworkManager.host_start_game()


func _on_game_start() -> void:
	var main = get_tree().current_scene
	if main.has_method("start_game"):
		main.start_game()


func _on_back() -> void:
	NetworkManager.disconnect_all()
	var main = get_tree().current_scene
	if main.has_method("return_to_title"):
		main.return_to_title()


# ══════════════════════════════════════════════════════════════
# UI helpers
# ══════════════════════════════════════════════════════════════

func _show_lobby() -> void:
	_connection_panel.visible = false
	_lobby_panel.visible = true
	_ready_btn.visible = true
	_refresh_player_list()


func _hide_lobby() -> void:
	_connection_panel.visible = true
	_lobby_panel.visible = false
	_ready_btn.visible = false
	_start_btn.visible = false


func _set_status(text: String, color: Color = Color.WHITE) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _refresh_player_list() -> void:
	# Clear existing rows
	for child in _player_list.get_children():
		child.queue_free()
	_player_rows.clear()

	var my_id = NetworkManager.get_local_peer_id()
	for peer_id in NetworkManager.get_sorted_peer_ids():
		var info: Dictionary = NetworkManager.player_info.get(peer_id, {})
		var cls: int = info.get("class", 0)
		var rdy: bool = info.get("ready", false)
		var is_me: bool = (peer_id == my_id)

		var row = PanelContainer.new()
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.09, 0.18, 0.85) if is_me else Color(0.08, 0.06, 0.12, 0.7)
		sb.border_color = CLASS_COLORS[cls] if is_me else Color(0.3, 0.25, 0.4, 0.5)
		sb.set_border_width_all(1 if is_me else 0)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(6)
		row.add_theme_stylebox_override("panel", sb)
		_player_list.add_child(row)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		row.add_child(hbox)

		var icon_lbl = Label.new()
		icon_lbl.text = CLASS_ICONS.get(cls, "?")
		icon_lbl.add_theme_font_size_override("font_size", 16)
		icon_lbl.add_theme_color_override("font_color", CLASS_COLORS.get(cls, Color.WHITE))
		icon_lbl.custom_minimum_size = Vector2(20, 0)
		hbox.add_child(icon_lbl)

		var name_lbl = Label.new()
		var tag = " (你)" if is_me else ""
		var host_tag = " [主机]" if (peer_id == 1) else ""
		name_lbl.text = "%s%s%s" % [CLASS_NAMES.get(cls, "未知"), tag, host_tag]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(name_lbl, UITheme.FONT_SIZE_SMALL,
			CLASS_COLORS.get(cls, Color.WHITE) if is_me else UITheme.COLORS["text_dim"])
		hbox.add_child(name_lbl)

		var ready_lbl = Label.new()
		ready_lbl.text = "✓ 就绪" if rdy else "…等待"
		UITheme.style_label(ready_lbl, UITheme.FONT_SIZE_TINY,
			Color(0.5, 1.0, 0.5) if rdy else UITheme.COLORS["text_dim"])
		hbox.add_child(ready_lbl)

		_player_rows[peer_id] = row

	# Update start button visibility
	if _start_btn:
		var all_ready = true
		for pid in NetworkManager.player_info:
			if not NetworkManager.player_info[pid].get("ready", false):
				all_ready = false
				break
		_start_btn.visible = NetworkManager.is_hosting and all_ready and not NetworkManager.player_info.is_empty()
