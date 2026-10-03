extends CanvasLayer
## Your phone: texts, what Sal wants and when, and the buttons to pay or borrow.

signal closed

const Style := preload("res://ui/style.gd")
const Night := preload("res://logic/night.gd")

var is_open := false

var _summary: Label
var _messages: VBoxContainer
var _pay: Button
var _borrow: Button


func _ready() -> void:
	visible = false
	var panel := Style.panel(Color(0.1, 0.8, 1.0))
	add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -560
	panel.offset_right = -24
	panel.offset_top = 110
	panel.offset_bottom = -24
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(Style.label("PHONE", 20, Color(0.1, 0.8, 1.0)))
	_summary = Style.label("", 20, Style.GOLD)
	col.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_messages = VBoxContainer.new()
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 14)
	scroll.add_child(_messages)
	_pay = Style.button("")
	_pay.pressed.connect(func(): Night.pay_sal(Game.state); Game.sfx("chip"); _fill())
	_borrow = Style.button("Borrow %s from Sal  (adds %s to your debt)" % [Game.money(Night.LOAN), Game.money(Night.LOAN_COST)])
	_borrow.pressed.connect(func(): Night.borrow(Game.state); Game.sfx("chip"); _fill())
	var done := Style.button("Put the phone away  [Tab]")
	done.pressed.connect(close)
	col.add_child(_pay)
	col.add_child(_borrow)
	col.add_child(done)


func open() -> void:
	is_open = true
	visible = true
	Game.state.unread = 0
	Game.sfx("click")
	_fill()


func close() -> void:
	is_open = false
	visible = false
	closed.emit()


func _fill() -> void:
	var s = Game.state
	_summary.text = "You owe Sal %s." % Game.money(s.debt)
	if s.clocks.has("sal"):
		var nights := int(s.clocks["sal"])
		if s.installment > 0:
			_summary.text += "\nHe wants %s before night %d starts." % [Game.money(s.installment), s.night + nights]
		else:
			_summary.text += "\nThis payment is covered."
	var can_pay: int = mini(s.bankroll, s.installment)
	_pay.text = "Pay Sal %s" % Game.money(can_pay)
	_pay.disabled = can_pay <= 0

	for c in _messages.get_children():
		_messages.remove_child(c)
		c.queue_free()
	if s.messages.is_empty():
		_messages.add_child(Style.label("No messages.", 18, Color(1, 1, 1, 0.6)))
	for i in range(s.messages.size() - 1, -1, -1):
		var m: Dictionary = s.messages[i]
		var l := Style.label("%s  ·  night %d\n%s" % [m["from"], int(m["night"]), m["text"]], 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 480
		_messages.add_child(l)
