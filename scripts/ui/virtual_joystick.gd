extends Control

# 虚拟摇杆：捕获触屏拖动，转为 move_* 输入动作
# 布局在屏幕左下角，触摸任意位置（摇杆区域内）开始拖动

const DEAD_ZONE: float = 8.0     # 最小偏移量（逻辑像素），低于此值不触发移动
const MAX_RADIUS: float = 40.0    # 摇杆可拖动的最大半径

var _touch_index: int = -1        # 当前占用的触点 index，-1 = 未激活
var _origin: Vector2 = Vector2.ZERO  # 触摸起始点（本地坐标）
var _knob_offset: Vector2 = Vector2.ZERO  # 当前手柄偏移

# 绘制用节点引用
var _bg: ColorRect
var _knob: ColorRect


func _ready() -> void:
	_bg = $BG
	_knob = $Knob
	_knob.position = _bg.position + (_bg.size - _knob.size) * 0.5


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _touch_index == -1:
			var local_pos := get_local_mouse_position()
			# 将屏幕坐标转换到本地坐标
			local_pos = get_global_transform().affine_inverse() * e.position
			if Rect2(Vector2.ZERO, size).has_point(local_pos):
				_touch_index = e.index
				_origin = local_pos
				_knob_offset = Vector2.ZERO
				_update_knob()
				get_viewport().set_input_as_handled()
		elif not e.pressed and e.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _touch_index:
			var local_pos := get_global_transform().affine_inverse() * e.position
			_knob_offset = (local_pos - _origin).limit_length(MAX_RADIUS)
			_update_knob()
			_emit_move_actions()
			get_viewport().set_input_as_handled()


func _release() -> void:
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	_update_knob()
	# 释放所有移动动作
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _update_knob() -> void:
	var center := _bg.position + _bg.size * 0.5
	_knob.position = center + _knob_offset - _knob.size * 0.5


func _emit_move_actions() -> void:
	var norm := _knob_offset
	if norm.length() < DEAD_ZONE:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		return

	var strength_x := norm.x / MAX_RADIUS
	var strength_y := norm.y / MAX_RADIUS

	if strength_x > 0.1:
		Input.action_press("move_right", abs(strength_x))
		Input.action_release("move_left")
	elif strength_x < -0.1:
		Input.action_press("move_left", abs(strength_x))
		Input.action_release("move_right")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	if strength_y > 0.1:
		Input.action_press("move_down", abs(strength_y))
		Input.action_release("move_up")
	elif strength_y < -0.1:
		Input.action_press("move_up", abs(strength_y))
		Input.action_release("move_down")
	else:
		Input.action_release("move_up")
		Input.action_release("move_down")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_release()
