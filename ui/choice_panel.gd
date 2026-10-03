extends CanvasLayer
## A panel at the bottom of the screen with a line of text and numbered buttons.
## Used by anything you sit down at. `extra` is a row for custom content.

signal picked(i: int)

const Style := preload("res://ui/style.gd")

var accent := Style.ACCENT
var info: Label
var extra := HBoxContainer.new()

var _buttons := HBoxContainer.new()


func _ready() -> void:
	visible = false
	var panel := Style.panel(accent)
	add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -36
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	info = Style.label("", 24)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extra.alignment = BoxContainer.ALIGNMENT_CENTER
	extra.add_theme_constant_override("separation", 16)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 10)
	col.add_child(extra)
	col.add_child(info)
	col.add_child(_buttons)


## Shows numbered buttons and waits for one to be picked.
func ask(options: Array) -> int:
	for i in options.size():
		var b := Style.button("%d   %s" % [i + 1, options[i]])
		b.pressed.connect(picked.emit.bind(i))
		_buttons.add_child(b)
	var choice: int = await picked
	for b in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()
	Game.sfx("click")
	return choice


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not e.pressed or e.echo:
		return
	var i: int = e.keycode - KEY_1
	if i >= 0 and i < _buttons.get_child_count():
		get_viewport().set_input_as_handled()
		picked.emit(i)
