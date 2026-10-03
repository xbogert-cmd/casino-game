extends CanvasLayer
## Shows one story node at a time. Choices apply their effects to the story state.

signal closed

const Style := preload("res://ui/style.gd")

var is_open := false

var _thread := ""
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _options: Array = []


func _ready() -> void:
	visible = false
	var panel := Style.panel()
	add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_bottom = -40
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_speaker = Style.label("", 20, Style.ACCENT)
	_text = Style.label("", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 900
	_choices = VBoxContainer.new()
	col.add_child(_speaker)
	col.add_child(_text)
	col.add_child(_choices)


func open(thread: String, node_id: String) -> void:
	_thread = thread
	is_open = true
	visible = true
	_show(node_id)


## Shows a line that is not in the story data. Options are {"text", "action": Callable};
## the action runs after the dialogue closes.
func say(speaker: String, text: String, options: Array = []) -> void:
	is_open = true
	visible = true
	_present(speaker, text, options)


func _show(node_id: String) -> void:
	var n: Dictionary = Game.story.node(_thread, node_id)
	Game.state.apply(n.get("effects", {}))
	_present(n.get("speaker", ""), n["text"], Game.story.choices(_thread, node_id, Game.state))


func _present(speaker: String, text: String, options: Array) -> void:
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_text.text = text
	_options = options if not options.is_empty() else [{"text": "Leave."}]
	for b in _choices.get_children():
		_choices.remove_child(b)
		b.queue_free()
	for i in _options.size():
		var b := Style.button("%d   %s" % [i + 1, _options[i]["text"]])
		b.pressed.connect(_choose.bind(i))
		_choices.add_child(b)


func _choose(i: int) -> void:
	var c: Dictionary = _options[i]
	Game.sfx("click")
	Game.state.apply(c.get("effects", {}))
	if c.has("goto"):
		_show(c["goto"])
		return
	is_open = false
	visible = false
	closed.emit()
	if c.has("action"):
		c["action"].call()


func _unhandled_key_input(e: InputEvent) -> void:
	if not is_open or not e.pressed or e.echo:
		return
	var i: int = e.keycode - KEY_1
	if i >= 0 and i < _options.size():
		get_viewport().set_input_as_handled()
		_choose(i)
