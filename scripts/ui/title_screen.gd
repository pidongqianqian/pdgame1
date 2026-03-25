extends CanvasLayer

var _title_label: Label
var _subtitle_label: Label
var _particles: Array[Dictionary] = []
const MAX_PARTICLES = 25


func _ready() -> void:
	_build_ui()
	_start_animations()
	_init_particles()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.offset_right = 640
	bg.offset_bottom = 360
	bg.color = Color(0.06, 0.04, 0.10, 1)
	add_child(bg)

	var particle_layer = Control.new()
	particle_layer.name = "ParticleLayer"
	particle_layer.anchors_preset = Control.PRESET_FULL_RECT
	particle_layer.offset_right = 640
	particle_layer.offset_bottom = 360
	particle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particle_layer)

	var center = VBoxContainer.new()
	center.anchors_preset = Control.PRESET_CENTER
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -120
	center.offset_top = -80
	center.offset_right = 120
	center.offset_bottom = 80
	center.add_theme_constant_override("separation", 6)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	_title_label = Label.new()
	_title_label.text = "像素深渊"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_title_label, 28, Color(0.91, 0.27, 0.38))
	center.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "PIXEL  ABYSS"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_subtitle_label, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	center.add_child(_subtitle_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)

	# 如果有未完成的存档，显示"继续"按钮
	if SaveManager.has_active_run():
		var run = SaveManager.get_run_summary()
		var floor_num: int = run.get("floor", 1)

		var continue_btn = Button.new()
		continue_btn.text = "继续冒险  (第 %d 层)" % floor_num
		continue_btn.custom_minimum_size = Vector2(200, 32)
		UITheme.style_button(continue_btn, UITheme.FONT_SIZE_HEADER)
		continue_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
		continue_btn.pressed.connect(_on_continue_pressed)
		center.add_child(continue_btn)

	var has_save: bool = SaveManager.has_active_run()
	var start_btn = Button.new()
	start_btn.text = "新游戏" if has_save else "开始冒险"
	start_btn.custom_minimum_size = Vector2(160, 28)
	UITheme.style_button(start_btn, UITheme.FONT_SIZE_BODY if has_save else UITheme.FONT_SIZE_HEADER)
	if not has_save:
		start_btn.add_theme_color_override("font_color", UITheme.COLORS["text_gold"])
	start_btn.pressed.connect(_on_start_pressed)
	center.add_child(start_btn)

	var mp_btn = Button.new()
	mp_btn.text = "多人游戏"
	mp_btn.custom_minimum_size = Vector2(160, 28)
	UITheme.style_button(mp_btn, UITheme.FONT_SIZE_BODY)
	mp_btn.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	mp_btn.pressed.connect(_on_multiplayer_pressed)
	center.add_child(mp_btn)

	var quit_btn = Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(160, 28)
	UITheme.style_button(quit_btn, UITheme.FONT_SIZE_BODY)
	quit_btn.pressed.connect(_on_quit_pressed)
	center.add_child(quit_btn)

	var ver_label = Label.new()
	ver_label.text = "v0.1 MVP"
	ver_label.anchor_left   = 0.0
	ver_label.anchor_bottom = 1.0
	ver_label.anchor_top    = 1.0
	ver_label.offset_left   = 8
	ver_label.offset_top    = -20
	ver_label.offset_bottom = -4
	UITheme.style_label(ver_label, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	add_child(ver_label)

	var tip_label = Label.new()
	tip_label.text = "WASD移动  J攻击  K闪避  I背包"
	tip_label.anchor_left   = 0.0
	tip_label.anchor_right  = 1.0
	tip_label.anchor_top    = 1.0
	tip_label.anchor_bottom = 1.0
	tip_label.offset_left   = 0
	tip_label.offset_right  = 0
	tip_label.offset_top    = -20
	tip_label.offset_bottom = -4
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(tip_label, UITheme.FONT_SIZE_TINY, UITheme.COLORS["text_dim"])
	add_child(tip_label)


func _start_animations() -> void:
	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.8).set_delay(0.3)
	tween.parallel().tween_property(_title_label, "position:y", 0, 0.8).from(8)
	tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5)

	var pulse = create_tween()
	pulse.set_loops()
	pulse.tween_property(_title_label, "modulate", Color(1.15, 1.15, 1.15, 1.0), 1.5)
	pulse.tween_property(_title_label, "modulate", Color(1, 1, 1, 1), 1.5)


func _init_particles() -> void:
	for i in MAX_PARTICLES:
		_spawn_particle()


func _spawn_particle() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var p = {
		"x": randf_range(0, vp_size.x),
		"y": randf_range(0, vp_size.y),
		"speed": randf_range(5.0, 15.0),
		"size": randf_range(1, 3),
		"alpha": randf_range(0.1, 0.35),
		"drift": randf_range(-8.0, 8.0),
	}
	_particles.append(p)

	var rect = ColorRect.new()
	rect.size = Vector2(p["size"], p["size"])
	rect.position = Vector2(p["x"], p["y"])
	rect.color = Color(0.5, 0.4, 0.7, p["alpha"])
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("ParticleLayer"):
		$ParticleLayer.add_child(rect)


func _process(delta: float) -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var particle_layer = get_node_or_null("ParticleLayer")
	if not particle_layer:
		return
	var idx = 0
	for child in particle_layer.get_children():
		if idx >= _particles.size():
			break
		var p = _particles[idx]
		p["y"] -= p["speed"] * delta
		p["x"] += p["drift"] * delta
		if p["y"] < -5:
			p["y"] = vp_size.y + 5
			p["x"] = randf_range(0, vp_size.x)
		child.position = Vector2(p["x"], p["y"])
		idx += 1


func _on_continue_pressed() -> void:
	var main = get_tree().current_scene
	if main.has_method("start_game"):
		main.start_game()


func _on_start_pressed() -> void:
	var main = get_tree().current_scene
	if SaveManager.has_active_run():
		# 新游戏：先弹确认
		_confirm_new_game()
	elif main.has_method("go_to_class_select"):
		main.go_to_class_select()


func _confirm_new_game() -> void:
	# 弹出确认对话框
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -130; panel.offset_right = 130
	panel.offset_top = -60; panel.offset_bottom = 60
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.14, 0.97)
	sb.border_color = Color(0.6, 0.4, 0.8, 0.8)
	sb.set_border_width_all(2); sb.set_corner_radius_all(5)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "开始新游戏将覆盖当前存档\n确定要放弃现有进度吗？"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(lbl, UITheme.FONT_SIZE_SMALL, UITheme.COLORS["text_dim"])
	vbox.add_child(lbl)

	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var confirm = Button.new()
	confirm.text = "确定"
	confirm.custom_minimum_size = Vector2(80, 28)
	UITheme.style_button(confirm, UITheme.FONT_SIZE_BODY)
	confirm.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	confirm.pressed.connect(func():
		overlay.queue_free()
		SaveManager.clear_run()
		var main = get_tree().current_scene
		if main.has_method("go_to_class_select"):
			main.go_to_class_select()
	)
	row.add_child(confirm)

	var cancel = Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size = Vector2(80, 28)
	UITheme.style_button(cancel, UITheme.FONT_SIZE_BODY)
	cancel.pressed.connect(func(): overlay.queue_free())
	row.add_child(cancel)


func _on_multiplayer_pressed() -> void:
	var main = get_tree().current_scene
	if main.has_method("go_to_lobby"):
		main.go_to_lobby()


func _on_quit_pressed() -> void:
	get_tree().quit()
