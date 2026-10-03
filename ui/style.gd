extends RefCounted
## Shared look for the UI: dark glass panels with a neon edge.

const ACCENT := Color(1.0, 0.1, 0.65)
const GOLD := Color(1.0, 0.8, 0.4)


static func box(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func panel(accent := ACCENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.04, 0.02, 0.07, 0.88), Color(accent, 0.8)))
	return p


static func label(text: String, size := 20, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.05, 0.16, 0.95), Color(1, 1, 1, 0.25), 1))
	b.add_theme_stylebox_override("hover", box(Color(0.3, 0.05, 0.25, 0.95), ACCENT, 1))
	b.add_theme_stylebox_override("pressed", box(Color(0.5, 0.05, 0.35, 0.95), ACCENT, 1))
	return b
