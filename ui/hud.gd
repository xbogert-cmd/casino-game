extends CanvasLayer
## Bankroll, debt, heat, the current objective, the interact prompt, toasts,
## and a full-screen message for big moments.

signal overlay_closed

const Style := preload("res://ui/style.gd")

var overlay_open := false
var hint: Label

var _bank: Label
var _debt: Label
var _heat: ProgressBar
var _objective: Label
var _prompt: Label
var _toast: Label
var _overlay: ColorRect
var _overlay_text: Label
var _last_heat := 0.0
var _toast_tween: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var stats := Style.panel()
	stats.position = Vector2(24, 24)
	root.add_child(stats)
	var col := VBoxContainer.new()
	stats.add_child(col)
	_bank = Style.label("", 28, Style.GOLD)
	_debt = Style.label("", 18, Color(1.0, 0.5, 0.5))
	col.add_child(_bank)
	col.add_child(_debt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	row.add_child(Style.label("HEAT", 16, Color(1, 1, 1, 0.7)))
	_heat = ProgressBar.new()
	_heat.custom_minimum_size = Vector2(200, 14)
	_heat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_heat.show_percentage = false
	_heat.add_theme_stylebox_override("background", Style.box(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 0))
	_heat.add_theme_stylebox_override("fill", Style.box(Color(1.0, 0.25, 0.2), Color.TRANSPARENT, 0))
	row.add_child(_heat)

	var goal := Style.panel(Color(0.1, 0.8, 1.0))
	root.add_child(goal)
	goal.anchor_left = 1.0
	goal.anchor_right = 1.0
	goal.offset_left = -444
	goal.offset_right = -24
	goal.offset_top = 24
	_objective = Style.label("", 18)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size.x = 380
	goal.add_child(_objective)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.7)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2

	_prompt = _centered(root, 22, 0.5, 70)
	_toast = _centered(root, 40, 0.22, 0)

	hint = Style.label("WASD move   Shift run   Mouse look   E interact   Esc free the mouse", 16, Color(1, 1, 1, 0.6))
	root.add_child(hint)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 24
	hint.offset_top = -44
	hint.offset_bottom = -20

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.78)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var box := Style.panel()
	center.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	box.add_child(inner)
	_overlay_text = Style.label("", 22)
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_text.custom_minimum_size.x = 640
	inner.add_child(_overlay_text)
	var done := Style.button("Continue")
	done.alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.pressed.connect(_close_overlay)
	inner.add_child(done)


## A centered label at a fraction of the screen height.
func _centered(root: Control, size: int, at: float, offset: float) -> Label:
	var l := Style.label("", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = at
	l.anchor_bottom = at
	l.offset_top = offset
	l.offset_bottom = offset + size * 1.5
	return l


func update(state, objective: String, prompt: String) -> void:
	_bank.text = "BANKROLL  " + Game.money(state.bankroll)
	_debt.text = "DEBT  " + Game.money(state.debt)
	_heat.value = state.heat
	_objective.text = objective
	_prompt.text = prompt
	if state.heat - _last_heat >= 3.0:
		Game.sfx("heat")
		_heat.modulate = Color(3, 3, 3)
		create_tween().tween_property(_heat, "modulate", Color.WHITE, 0.6)
	_last_heat = state.heat


func toast(text: String, color: Color) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.text = text
	_toast.modulate = color
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func show_overlay(text: String) -> void:
	_overlay_text.text = text
	_overlay.visible = true
	overlay_open = true


func _close_overlay() -> void:
	Game.sfx("click")
	_overlay.visible = false
	overlay_open = false
	overlay_closed.emit()
