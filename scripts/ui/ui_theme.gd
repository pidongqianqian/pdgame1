extends Node

const COLORS = {
	"bg_dark": Color(0.08, 0.06, 0.12, 0.95),
	"bg_panel": Color(0.12, 0.10, 0.18, 0.92),
	"bg_slot": Color(0.16, 0.14, 0.22, 0.8),
	"bg_slot_hover": Color(0.22, 0.18, 0.30, 0.9),
	"bg_selected": Color(0.28, 0.22, 0.38, 0.95),
	"border": Color(0.35, 0.30, 0.45, 0.8),
	"border_light": Color(0.50, 0.45, 0.60, 0.6),
	"text_white": Color(0.92, 0.90, 0.95),
	"text_dim": Color(0.55, 0.50, 0.65),
	"text_gold": Color(1.0, 0.85, 0.3),
	"hp_red": Color(0.85, 0.2, 0.2),
	"hp_bg": Color(0.25, 0.08, 0.08),
	"mp_blue": Color(0.2, 0.4, 0.85),
	"mp_bg": Color(0.08, 0.1, 0.25),
	"xp_green": Color(0.3, 0.8, 0.3),
}

const RARITY_BG = {
	0: Color(0.20, 0.18, 0.24, 0.6),
	1: Color(0.12, 0.22, 0.12, 0.6),
	2: Color(0.12, 0.16, 0.28, 0.6),
	3: Color(0.22, 0.10, 0.28, 0.6),
	4: Color(0.30, 0.18, 0.08, 0.6),
}

const FONT_SIZE_TITLE = 22
const FONT_SIZE_HEADER = 16
const FONT_SIZE_BODY = 13
const FONT_SIZE_SMALL = 11
const FONT_SIZE_TINY = 9


static func make_panel(color: Color = COLORS["bg_panel"]) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = COLORS["border"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(6)
	return sb


static func make_button_normal() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLORS["bg_slot"]
	sb.border_color = COLORS["border"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return sb


static func make_button_hover() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLORS["bg_slot_hover"]
	sb.border_color = COLORS["border_light"]
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return sb


static func make_button_pressed() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = COLORS["bg_selected"]
	sb.border_color = Color(0.6, 0.5, 0.8, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(4)
	return sb


static func style_button(btn: Button, font_size: int = FONT_SIZE_BODY) -> void:
	btn.add_theme_stylebox_override("normal", make_button_normal())
	btn.add_theme_stylebox_override("hover", make_button_hover())
	btn.add_theme_stylebox_override("pressed", make_button_pressed())
	btn.add_theme_stylebox_override("focus", make_button_hover())
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", COLORS["text_white"])
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


static func style_label(lbl: Label, font_size: int = FONT_SIZE_BODY, color: Color = COLORS["text_white"]) -> void:
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
