extends Control

# 右侧触控按钮区：攻击、闪避、技能1、技能2
# 使用原生 InputEventScreenTouch 处理，支持多指同时按，不依赖鼠标模拟

const BUTTON_DEFS: Array = [
	{"action": "attack",  "label": "攻击",  "color": Color(0.9, 0.3, 0.3, 0.80), "radius": 36},
	{"action": "dodge",   "label": "闪避",  "color": Color(0.3, 0.7, 0.9, 0.75), "radius": 28},
	{"action": "skill_1", "label": "技能1", "color": Color(0.7, 0.3, 0.9, 0.75), "radius": 26},
	{"action": "skill_2", "label": "技能2", "color": Color(0.9, 0.6, 0.2, 0.75), "radius": 26},
]

# 每个按钮的布局（中心点，本地坐标）
const BUTTON_CENTERS: Array = [
	Vector2(116, 56),   # 攻击：右下主按钮
	Vector2(36,  76),   # 闪避：攻击左下
	Vector2(116, -6),   # 技能1：攻击上方
	Vector2(52,  20),   # 技能2：技能1左边
]

# 触点 index -> 按钮 index 的映射（支持多指）
var _touch_to_btn: Dictionary = {}

# 按钮视觉节点
var _btn_visuals: Array = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_visuals()


func _build_visuals() -> void:
	for i in BUTTON_DEFS.size():
		var def: Dictionary = BUTTON_DEFS[i]
		var radius: int = def["radius"]
		var center: Vector2 = BUTTON_CENTERS[i]

		var btn_node := ColorRect.new()
		btn_node.size = Vector2(radius * 2, radius * 2)
		btn_node.position = center - Vector2(radius, radius)
		btn_node.color = def["color"]
		btn_node.mouse_filter = MOUSE_FILTER_IGNORE

		# 圆形外观用 StyleBoxFlat 不能直接给 ColorRect，改用 Panel
		var panel := PanelContainer.new()
		panel.size = Vector2(radius * 2, radius * 2)
		panel.position = center - Vector2(radius, radius)
		panel.mouse_filter = MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = def["color"]
		sb.corner_radius_top_left = radius
		sb.corner_radius_top_right = radius
		sb.corner_radius_bottom_left = radius
		sb.corner_radius_bottom_right = radius
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.35)
		panel.add_theme_stylebox_override("panel", sb)

		var lbl := Label.new()
		lbl.text = def["label"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

		add_child(panel)
		_btn_visuals.append(panel)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var local_pos := get_global_transform().affine_inverse() * e.position
		if e.pressed:
			var btn_idx := _hit_test(local_pos)
			if btn_idx >= 0:
				_touch_to_btn[e.index] = btn_idx
				Input.action_press(BUTTON_DEFS[btn_idx]["action"])
				_set_pressed_visual(btn_idx, true)
				get_viewport().set_input_as_handled()
		else:
			if _touch_to_btn.has(e.index):
				var btn_idx: int = _touch_to_btn[e.index]
				_touch_to_btn.erase(e.index)
				# 只有没有其他手指按着同一按钮时才释放
				if not _touch_to_btn.values().has(btn_idx):
					Input.action_release(BUTTON_DEFS[btn_idx]["action"])
					_set_pressed_visual(btn_idx, false)
				get_viewport().set_input_as_handled()


func _hit_test(local_pos: Vector2) -> int:
	for i in BUTTON_DEFS.size():
		var radius: int = BUTTON_DEFS[i]["radius"]
		var center: Vector2 = BUTTON_CENTERS[i]
		if local_pos.distance_to(center) <= radius:
			return i
	return -1


func _set_pressed_visual(btn_idx: int, pressed: bool) -> void:
	if btn_idx >= _btn_visuals.size():
		return
	var panel: PanelContainer = _btn_visuals[btn_idx]
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not sb:
		return
	var base_color: Color = BUTTON_DEFS[btn_idx]["color"]
	sb.bg_color = base_color.lightened(0.25) if pressed else base_color


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		for btn_idx in _touch_to_btn.values():
			Input.action_release(BUTTON_DEFS[btn_idx]["action"])
		_touch_to_btn.clear()
