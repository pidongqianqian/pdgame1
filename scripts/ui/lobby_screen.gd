extends CanvasLayer

const CLASS_ICONS = { 0: "⚔", 1: "✦", 2: "➶", 3: "匕" }
const CLASS_NAMES = { 0: "战士", 1: "法师", 2: "游侠", 3: "刺客" }
const CLASS_COLORS = {
	0: Color(0.55, 0.75, 1.0),
	1: Color(0.75, 0.45, 1.0),
	2: Color(0.45, 1.0, 0.55),
	3: Color(1.0, 0.55, 0.35),
}

var _status_label: Label
var _player_rows: Dictionary = {}
var _player_list: VBoxContainer
var _start_btn: Button
var _ip_input: LineEdit
var _ready_btn: Button
var _connection_panel: VBoxContainer
var _lobby_panel: VBoxContainer
var _cloud_panel: VBoxContainer
var _cloud_room_list: VBoxContainer
var _cloud_code_label: Label
var _cloud_url_input: LineEdit
var _cloud_code_input: LineEdit
var _selected_class: int = GameManager.current_class

# 云房间加入状态
var _pending_cloud: Dictionary = {}  # {code, lan_ip, wan_ip, port, tried_lan}
var _is_cloud_joining: bool = false


func _ready() -> void:
	NetworkManager.lobby_state_changed.connect(_refresh_player_list)
	NetworkManager.connected_to_host.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)
	NetworkManager.all_players_ready.connect(_on_all_ready)
	NetworkManager.game_start_requested.connect(_on_game_start)
	CloudRoomAPI.room_created.connect(_on_cloud_room_created)
	CloudRoomAPI.room_joined.connect(_on_cloud_room_joined)
	CloudRoomAPI.rooms_listed.connect(_on_cloud_rooms_listed)
	CloudRoomAPI.request_failed.connect(_on_cloud_error)
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

	var title = Label.new()
	title.text = "多人游戏大厅"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title, UITheme.FONT_SIZE_HEADER, UITheme.COLORS["text_gold"])
	root.add_child(title)

	_status_label = Label.new()
	_status_label.text = "选择连接方式"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_status_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	root.add_child(_status_label)

	# ── 连接面板 ────────────────────────────────────────────
	_connection_panel = VBoxContainer.new()
	_connection_panel.add_theme_constant_override("separation", 8)
	root.add_child(_connection_panel)

	# 局域网行
	var lan_label = Label.new()
	lan_label.text = "局域网"
	UITheme.style_label(lan_label, UITheme.FONT_SIZE_SMALL, Color(0.6, 0.85, 1.0))
	_connection_panel.add_child(lan_label)

	var lan_row = HBoxContainer.new()
	lan_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lan_row.add_theme_constant_override("separation", 8)
	_connection_panel.add_child(lan_row)

	var host_btn = Button.new()
	host_btn.text = "🏠 创建局域网房间"
	host_btn.custom_minimum_size = Vector2(140, 26)
	UITheme.style_button(host_btn, UITheme.FONT_SIZE_BODY)
	host_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	host_btn.pressed.connect(_on_host_pressed)
	lan_row.add_child(host_btn)

	var ip_lbl = Label.new()
	ip_lbl.text = "IP加入："
	UITheme.style_label(ip_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	lan_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "192.168.x.x"
	_ip_input.custom_minimum_size = Vector2(100, 22)
	_ip_input.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	lan_row.add_child(_ip_input)

	var join_btn = Button.new()
	join_btn.text = "加入"
	join_btn.custom_minimum_size = Vector2(50, 26)
	UITheme.style_button(join_btn, UITheme.FONT_SIZE_BODY)
	join_btn.pressed.connect(_on_join_pressed)
	lan_row.add_child(join_btn)

	# 云房间行
	var cloud_sep = HSeparator.new()
	var sep_sb = StyleBoxFlat.new()
	sep_sb.bg_color = Color(0.3, 0.2, 0.5, 0.3)
	sep_sb.set_content_margin_all(0)
	sep_sb.content_margin_top = 1
	sep_sb.content_margin_bottom = 1
	cloud_sep.add_theme_stylebox_override("separator", sep_sb)
	_connection_panel.add_child(cloud_sep)

	var cloud_label = Label.new()
	cloud_label.text = "☁ 云房间（跨网络）"
	UITheme.style_label(cloud_label, UITheme.FONT_SIZE_SMALL, Color(0.5, 0.8, 1.0))
	_connection_panel.add_child(cloud_label)

	# 服务器地址配置
	var url_row = HBoxContainer.new()
	url_row.alignment = BoxContainer.ALIGNMENT_CENTER
	url_row.add_theme_constant_override("separation", 6)
	_connection_panel.add_child(url_row)

	var url_lbl = Label.new()
	url_lbl.text = "服务器："
	UITheme.style_label(url_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	url_row.add_child(url_lbl)

	_cloud_url_input = LineEdit.new()
	_cloud_url_input.text = CloudRoomAPI.api_url
	_cloud_url_input.placeholder_text = "http://your-server:8080"
	_cloud_url_input.custom_minimum_size = Vector2(180, 20)
	_cloud_url_input.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_TINY)
	_cloud_url_input.text_changed.connect(func(txt: String): CloudRoomAPI.set_api_url(txt))
	url_row.add_child(_cloud_url_input)

	# 云房间操作行
	var cloud_row = HBoxContainer.new()
	cloud_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cloud_row.add_theme_constant_override("separation", 6)
	_connection_panel.add_child(cloud_row)

	var create_cloud_btn = Button.new()
	create_cloud_btn.text = "☁ 创建云房间"
	create_cloud_btn.custom_minimum_size = Vector2(110, 26)
	UITheme.style_button(create_cloud_btn, UITheme.FONT_SIZE_BODY)
	create_cloud_btn.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	create_cloud_btn.pressed.connect(_on_cloud_create_pressed)
	cloud_row.add_child(create_cloud_btn)

	var browse_btn = Button.new()
	browse_btn.text = "浏览房间"
	browse_btn.custom_minimum_size = Vector2(80, 26)
	UITheme.style_button(browse_btn, UITheme.FONT_SIZE_BODY)
	browse_btn.pressed.connect(_on_cloud_browse_pressed)
	cloud_row.add_child(browse_btn)

	var code_lbl = Label.new()
	code_lbl.text = "房间码："
	UITheme.style_label(code_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	cloud_row.add_child(code_lbl)

	_cloud_code_input = LineEdit.new()
	_cloud_code_input.placeholder_text = "ABCD12"
	_cloud_code_input.custom_minimum_size = Vector2(65, 22)
	_cloud_code_input.max_length = 6
	_cloud_code_input.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SMALL)
	cloud_row.add_child(_cloud_code_input)

	var code_join_btn = Button.new()
	code_join_btn.text = "加入"
	code_join_btn.custom_minimum_size = Vector2(50, 26)
	UITheme.style_button(code_join_btn, UITheme.FONT_SIZE_BODY)
	code_join_btn.pressed.connect(_on_cloud_code_join)
	cloud_row.add_child(code_join_btn)

	# ── 云房间列表面板 ──────────────────────────────────────
	_cloud_panel = VBoxContainer.new()
	_cloud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cloud_panel.add_theme_constant_override("separation", 4)
	_cloud_panel.visible = false
	root.add_child(_cloud_panel)

	var list_header = HBoxContainer.new()
	list_header.add_theme_constant_override("separation", 8)
	_cloud_panel.add_child(list_header)

	var list_title = Label.new()
	list_title.text = "☁ 可加入的云房间"
	list_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(list_title, UITheme.FONT_SIZE_SMALL, Color(0.5, 0.8, 1.0))
	list_header.add_child(list_title)

	var refresh_btn = Button.new()
	refresh_btn.text = "⟳ 刷新"
	refresh_btn.custom_minimum_size = Vector2(60, 22)
	UITheme.style_button(refresh_btn, UITheme.FONT_SIZE_TINY)
	refresh_btn.pressed.connect(_on_cloud_browse_pressed)
	list_header.add_child(refresh_btn)

	var close_list_btn = Button.new()
	close_list_btn.text = "✕"
	close_list_btn.custom_minimum_size = Vector2(22, 22)
	UITheme.style_button(close_list_btn, UITheme.FONT_SIZE_TINY)
	close_list_btn.pressed.connect(func(): _cloud_panel.visible = false)
	list_header.add_child(close_list_btn)

	_cloud_room_list = VBoxContainer.new()
	_cloud_room_list.add_theme_constant_override("separation", 3)
	_cloud_room_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cloud_panel.add_child(_cloud_room_list)

	# ── 游戏房间面板 ─────────────────────────────────────────
	_lobby_panel = VBoxContainer.new()
	_lobby_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_panel.add_theme_constant_override("separation", 5)
	_lobby_panel.visible = false
	root.add_child(_lobby_panel)

	_cloud_code_label = Label.new()
	_cloud_code_label.text = ""
	_cloud_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cloud_code_label.visible = false
	UITheme.style_label(_cloud_code_label, UITheme.FONT_SIZE_BODY, Color(0.5, 0.85, 1.0))
	_lobby_panel.add_child(_cloud_code_label)

	var plist_title = Label.new()
	plist_title.text = "玩家列表（最多4人）"
	UITheme.style_label(plist_title, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	_lobby_panel.add_child(plist_title)

	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 4)
	_player_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lobby_panel.add_child(_player_list)

	# 职业选择
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
# LAN handlers
# ══════════════════════════════════════════════════════════════

func _on_host_pressed() -> void:
	var err = NetworkManager.create_server()
	if err != OK:
		var hint: String = "创建房间失败（错误 %d）" % err
		if err == 20:
			hint += "\n端口 %d 可能被占用，或网络不可用" % NetworkManager.DEFAULT_PORT
		_set_status(hint, Color(1, 0.3, 0.3))
		return
	NetworkManager.is_cloud_room = false
	var ip = NetworkManager.get_local_ip()
	_set_status("局域网房间已创建！IP：%s  等待玩家加入…" % ip, Color(0.5, 1.0, 0.5))
	_cloud_code_label.visible = false
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
	if _is_cloud_joining:
		var code: String = _pending_cloud.get("code", "")
		_is_cloud_joining = false
		_pending_cloud = {}
		NetworkManager.is_cloud_room = true
		if not code.is_empty():
			CloudRoomAPI.join_room(code)
		_set_status("已加入云房间！", Color(0.5, 1.0, 0.5))
	else:
		_set_status("已加入房间！", Color(0.5, 1.0, 0.5))
	_cloud_panel.visible = false
	_show_lobby()


func _on_connection_failed() -> void:
	if _is_cloud_joining:
		_is_cloud_joining = false
		_pending_cloud = {}
		_set_status("连接云服务器失败，请检查房间是否仍在线", Color(1, 0.3, 0.3))
		return
	_set_status("连接失败，请检查IP地址", Color(1, 0.3, 0.3))


func _on_host_disconnected() -> void:
	_hide_lobby()
	_show_disconnect_notice()


# ══════════════════════════════════════════════════════════════
# Cloud room handlers
# ══════════════════════════════════════════════════════════════

func _on_cloud_create_pressed() -> void:
	var url = _cloud_url_input.text.strip_edges()
	if url.is_empty():
		_set_status("请先输入云服务器地址", Color(1, 0.5, 0.3))
		return
	CloudRoomAPI.set_api_url(url)
	_set_status("正在创建云房间…", UITheme.COLORS["text_dim"])

	var err = NetworkManager.create_server()
	if err != OK:
		var hint: String = "创建本地服务器失败（错误 %d）" % err
		if err == 20:
			hint += "\n端口 %d 可能被占用，或网络不可用" % NetworkManager.DEFAULT_PORT
		_set_status(hint, Color(1, 0.3, 0.3))
		return
	NetworkManager.is_cloud_room = true
	CloudRoomAPI.create_room("像素深渊")


func _on_cloud_room_created(room: Dictionary) -> void:
	var code: String = room.get("room_code", "???")
	var relay_port: int = room.get("relay_port", 0)
	if relay_port > 0:
		var cloud_ip: String = _extract_host_from_url(CloudRoomAPI.api_url)
		NetworkManager.start_relay_bridge(cloud_ip, relay_port)
	_set_status("云房间已创建！", Color(0.5, 1.0, 0.5))
	_cloud_code_label.text = "☁ 房间码：%s  （分享给好友加入）" % code
	_cloud_code_label.visible = true
	_cloud_panel.visible = false
	_show_lobby()


func _on_cloud_browse_pressed() -> void:
	var url = _cloud_url_input.text.strip_edges()
	if url.is_empty():
		_set_status("请先输入云服务器地址", Color(1, 0.5, 0.3))
		return
	CloudRoomAPI.set_api_url(url)
	_set_status("正在获取房间列表…", UITheme.COLORS["text_dim"])
	_cloud_panel.visible = true
	CloudRoomAPI.list_rooms()


func _on_cloud_rooms_listed(rooms: Array) -> void:
	for child in _cloud_room_list.get_children():
		child.queue_free()

	if rooms.is_empty():
		var empty = Label.new()
		empty.text = "暂无可用房间"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_label(empty, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
		_cloud_room_list.add_child(empty)
		_set_status("没有找到可用房间", UITheme.COLORS["text_dim"])
		return

	# 过滤掉离线房间
	var active_rooms: Array = []
	for room in rooms:
		var st: String = room.get("status", "waiting")
		if st != "offline" and st != "closed":
			active_rooms.append(room)

	if active_rooms.is_empty():
		var empty = Label.new()
		empty.text = "暂无可用房间"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_label(empty, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
		_cloud_room_list.add_child(empty)
		_set_status("没有找到可用房间", UITheme.COLORS["text_dim"])
		return

	_set_status("找到 %d 个房间" % active_rooms.size(), Color(0.5, 0.8, 1.0))

	for room in active_rooms:
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.07, 0.18, 0.85)
		sb.border_color = Color(0.3, 0.5, 0.7, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", sb)
		_cloud_room_list.add_child(card)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)

		var code_lbl = Label.new()
		code_lbl.text = room.get("room_code", "?")
		code_lbl.custom_minimum_size = Vector2(55, 0)
		UITheme.style_label(code_lbl, UITheme.FONT_SIZE_SMALL, Color(0.5, 0.85, 1.0))
		hbox.add_child(code_lbl)

		var name_lbl = Label.new()
		name_lbl.text = room.get("room_name", "未知")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(name_lbl, UITheme.FONT_SIZE_SMALL, Color(0.85, 0.8, 0.95))
		hbox.add_child(name_lbl)

		var count_lbl = Label.new()
		count_lbl.text = "%d/%d" % [room.get("cur_players", 0), room.get("max_players", 4)]
		UITheme.style_label(count_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
		hbox.add_child(count_lbl)

		var status_text: String = room.get("status", "waiting")
		var status_lbl = Label.new()
		status_lbl.text = "等待中" if status_text == "waiting" else "游戏中"
		UITheme.style_label(status_lbl, UITheme.FONT_SIZE_TINY,
			Color(0.5, 1.0, 0.5) if status_text == "waiting" else Color(1.0, 0.7, 0.3))
		hbox.add_child(status_lbl)

		var join_btn = Button.new()
		join_btn.text = "加入"
		join_btn.custom_minimum_size = Vector2(45, 22)
		join_btn.disabled = (status_text != "waiting") or (room.get("cur_players", 0) >= room.get("max_players", 4))
		UITheme.style_button(join_btn, UITheme.FONT_SIZE_TINY)
		var room_code: String = room.get("room_code", "")
		var host_lan: String = room.get("host_lan_ip", "")
		var host_wan: String = room.get("host_ip", "")
		var host_port: int = room.get("host_port", 7777)
		var r_port: int = room.get("relay_port", 0)
		join_btn.pressed.connect(func(): _join_cloud_room(room_code, host_lan, host_wan, host_port, r_port))
		hbox.add_child(join_btn)


func _on_cloud_code_join() -> void:
	var code: String = _cloud_code_input.text.strip_edges().to_upper()
	if code.is_empty():
		_set_status("请输入房间码", Color(1, 0.5, 0.3))
		return
	var url = _cloud_url_input.text.strip_edges()
	if url.is_empty():
		_set_status("请先输入云服务器地址", Color(1, 0.5, 0.3))
		return
	CloudRoomAPI.set_api_url(url)
	_set_status("正在查找房间 %s…" % code, UITheme.COLORS["text_dim"])
	_fetch_room_then_connect(code)


func _on_cloud_room_joined(_room: Dictionary) -> void:
	pass


func _join_cloud_room(code: String, lan_ip: String, wan_ip: String, port: int, relay_port: int = 0) -> void:
	_start_cloud_connect(code, lan_ip, wan_ip, port, relay_port)


func _fetch_room_then_connect(code: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, status_code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or status_code != 200:
			_set_status("房间不存在或已关闭", Color(1, 0.3, 0.3))
			return
		var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
		if parsed == null:
			_set_status("服务器返回无效数据", Color(1, 0.3, 0.3))
			return
		var lan_ip: String = parsed.get("host_lan_ip", "")
		var wan_ip: String = parsed.get("host_ip", "")
		var port: int = parsed.get("host_port", 7777)
		var r_port: int = parsed.get("relay_port", 0)
		_start_cloud_connect(code, lan_ip, wan_ip, port, r_port)
	)
	http.request(CloudRoomAPI.api_url + "/api/rooms/" + code)


func _start_cloud_connect(code: String, lan_ip: String, wan_ip: String, port: int, relay_port: int = 0) -> void:
	_is_cloud_joining = true
	_pending_cloud = {"code": code}

	var connect_ip: String = ""
	var connect_port: int = port

	# 有中继端口时优先走中继
	if relay_port > 0:
		connect_ip = _extract_host_from_url(CloudRoomAPI.api_url)
		connect_port = relay_port
		_set_status("正在通过中继服务器连接…", UITheme.COLORS["text_dim"])
	elif not wan_ip.is_empty():
		connect_ip = wan_ip
		_set_status("正在连接 %s…" % wan_ip, UITheme.COLORS["text_dim"])
	elif not lan_ip.is_empty():
		connect_ip = lan_ip
		_set_status("正在尝试局域网连接 %s…" % lan_ip, UITheme.COLORS["text_dim"])
	else:
		_is_cloud_joining = false
		_set_status("无法获取房间地址", Color(1, 0.3, 0.3))
		return

	var err = NetworkManager.join_server(connect_ip, connect_port)
	if err != OK:
		_is_cloud_joining = false
		_pending_cloud = {}
		_set_status("连接失败：%d" % err, Color(1, 0.3, 0.3))


func _extract_host_from_url(url: String) -> String:
	var s: String = url
	# 去掉协议头
	if s.begins_with("http://"):
		s = s.substr(7)
	elif s.begins_with("https://"):
		s = s.substr(8)
	# 去掉路径
	var slash_idx: int = s.find("/")
	if slash_idx >= 0:
		s = s.substr(0, slash_idx)
	# 去掉端口号
	var colon_idx: int = s.rfind(":")
	if colon_idx >= 0:
		s = s.substr(0, colon_idx)
	return s


func _on_cloud_error(error: String) -> void:
	_set_status(error, Color(1, 0.3, 0.3))


# ══════════════════════════════════════════════════════════════
# Common handlers
# ══════════════════════════════════════════════════════════════

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
	_cloud_panel.visible = false
	_lobby_panel.visible = true
	_ready_btn.visible = true
	_refresh_player_list()


func _hide_lobby() -> void:
	_connection_panel.visible = true
	_lobby_panel.visible = false
	_cloud_panel.visible = false
	_ready_btn.visible = false
	_start_btn.visible = false
	_cloud_code_label.visible = false


func _set_status(text: String, color: Color = Color.WHITE) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _refresh_player_list() -> void:
	for child in _player_list.get_children():
		if child != _cloud_code_label:
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

	if _start_btn:
		var all_ready = true
		for pid in NetworkManager.player_info:
			if not NetworkManager.player_info[pid].get("ready", false):
				all_ready = false
				break
		_start_btn.visible = NetworkManager.is_hosting and all_ready and not NetworkManager.player_info.is_empty()


func _show_disconnect_notice() -> void:
	var notice = CanvasLayer.new()
	notice.layer = 30
	notice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(notice)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	notice.add_child(overlay)
	var fade_tw = create_tween()
	fade_tw.tween_property(overlay, "color:a", 0.55, 0.4)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -145
	panel.offset_right = 145
	panel.offset_top = -65
	panel.offset_bottom = 65
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.14, 0.95)
	sb.border_color = Color(1.0, 0.5, 0.2, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	notice.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.text = "⚠"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	vbox.add_child(icon_lbl)

	var title_lbl = Label.new()
	title_lbl.text = "房主已离开"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title_lbl, UITheme.FONT_SIZE_HEADER, Color(1.0, 0.7, 0.3))
	vbox.add_child(title_lbl)

	var body_lbl = Label.new()
	body_lbl.text = "房间已解散，即将返回主菜单…"
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(body_lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	vbox.add_child(body_lbl)

	var countdown_lbl = Label.new()
	countdown_lbl.text = "3 秒后自动返回…"
	countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(countdown_lbl, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	vbox.add_child(countdown_lbl)

	var btn = Button.new()
	btn.text = "  立即返回  "
	btn.custom_minimum_size = Vector2(120, 26)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.style_button(btn, UITheme.FONT_SIZE_BODY)
	btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	btn.pressed.connect(func():
		notice.queue_free()
		NetworkManager.disconnect_all()
		var main = get_tree().current_scene
		if main and main.has_method("return_to_title"):
			main.return_to_title()
	)
	vbox.add_child(btn)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size / 2
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.35)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

	for i in range(3, 0, -1):
		if not is_instance_valid(countdown_lbl):
			return
		countdown_lbl.text = "%d 秒后自动返回…" % i
		await get_tree().create_timer(1.0).timeout

	if is_instance_valid(notice):
		notice.queue_free()
	NetworkManager.disconnect_all()
	var main = get_tree().current_scene
	if main and main.has_method("return_to_title"):
		main.return_to_title()
