extends Node3D
## A blackjack table. In player mode you play against the house. In dealer mode you
## deal to the customer and may stack the shoe, which raises heat.

signal sat
signal left
signal picked(i: int)

const B := preload("res://world/build.gd")
const Style := preload("res://ui/style.gd")
const Shoe := preload("res://logic/shoe.gd")
const Blackjack := preload("res://logic/blackjack.gd")

const TOP := 0.94
const BETS := [10, 20, 50, 100, 200, 500]
const HANDS := 6
const CUSTOMER_BET := 100
const RIG_DEAL_HEAT := 25.0
const RIG_CARD_HEAT := 12.0
const GOOD := Color(0.5, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.45)

var dealer_mode := false
var accent := B.MAGENTA
var player: Node
var customer_stack := 500
var hand_no := 0

var _shoe: Shoe
var _bj: Blackjack
var _bet_i := 2
var _hands := [[], []]  # card nodes: 0 = player or customer, 1 = dealer
var _chips: Array[Node] = []
var _layer := CanvasLayer.new()
var _info: Label
var _buttons: HBoxContainer
var _face := B.mat(Color(0.8, 0.79, 0.75), 0.6)
var _back := B.mat(Color(0.22, 0.02, 0.06), 0.5)
var _font := SystemFont.new()


func _ready() -> void:
	_shoe = Shoe.new(Game.rng)
	_bj = Blackjack.new(_shoe)
	_font.font_names = PackedStringArray(["Arial Unicode MS", "Apple Symbols", "Arial"])
	_build_table()
	_build_ui()


func prompt() -> String:
	if not dealer_mode:
		return "Play blackjack"
	var f: Dictionary = Game.state.flags
	if not f.get("mission_given", false) or f.get("shift_done", false) or f.get("customer_warned", false):
		return ""
	return "Deal at table two"


func interact() -> void:
	sat.emit()
	_layer.visible = true
	var eye := to_global(Vector3(0, 1.9, -1.2) if dealer_mode else Vector3(0, 1.6, 1.4))
	var aim := to_global(Vector3(0, TOP, 0.05 if dealer_mode else -0.15))
	player.sit(Transform3D(Basis.IDENTITY, eye).looking_at(aim))
	if dealer_mode:
		await _deal_loop()
	else:
		await _play_loop()
	_clear()
	_layer.visible = false
	player.stand()
	left.emit()


# --- Playing against the house ---

func _play_loop() -> void:
	while true:
		var bet: int = BETS[_bet_i]
		_info.text = "Table one.  Your bet: %s" % Game.money(bet)
		match await _ask(["Deal", "Lower bet", "Raise bet", "Leave the table"]):
			0:
				if Game.state.bankroll < bet:
					Game.toast.emit("You can't cover that bet.", BAD)
				else:
					await _player_hand(bet)
			1:
				_bet_i = maxi(0, _bet_i - 1)
			2:
				_bet_i = mini(BETS.size() - 1, _bet_i + 1)
			3:
				return


func _player_hand(bet: int) -> void:
	await _start_hand(bet)
	while _bj.phase == Blackjack.Phase.PLAYER:
		_info.text = _hands_text(true)
		var options := ["Hit", "Stand"]
		if _bj.can_double() and Game.state.bankroll >= bet * 2:
			options.append("Double")
		match await _ask(options):
			0:
				_bj.hit()
				await _deal_card(0, _bj.player[-1])
			1:
				_bj.stand()
			2:
				_bj.double_down()
				_stack_chips(_bj.bet)
				await _deal_card(0, _bj.player[-1])
	await _reveal_hole()
	while _bj.dealer_must_draw():
		_bj.dealer_draw()
		await _deal_card(1, _bj.dealer[-1])
	_bj.finish()
	_info.text = _hands_text(false)

	var pay := _bj.payout()
	Game.state.add("bankroll", pay)
	match _bj.result:
		"blackjack":
			Game.sfx("blackjack")
			Game.state.add("heat", 6)
			Game.toast.emit("Blackjack!  +%s" % Game.money(pay), Style.GOLD)
		"win":
			Game.sfx("win")
			Game.state.add("heat", 3)
			Game.toast.emit("You win  +%s" % Game.money(pay), GOOD)
		"push":
			Game.toast.emit("Push", Color.WHITE)
		_:
			Game.sfx("lose")
			Game.toast.emit(("Bust  " if _bj.result == "bust" else "House wins  ") + Game.money(pay), BAD)
	await _wait(1.8)
	_clear()


# --- Dealing to the customer ---

func _deal_loop() -> void:
	while hand_no < HANDS and customer_stack >= CUSTOMER_BET:
		_info.text = "Hand %d of %d.  Teddy has %s and bets %s." % [
			hand_no + 1, HANDS, Game.money(customer_stack), Game.money(CUSTOMER_BET)]
		match await _ask(["Deal straight", "Stack the deal against him (+25 heat)", "Stack the deal for him (+25 heat)", "Step away"]):
			1:
				_shoe.stack([9, 12, 5, 11])  # he gets 16, the house gets 20
				Game.state.add("heat", RIG_DEAL_HEAT)
			2:
				_shoe.stack([10, 9, 12, 5])  # he gets 20, the house gets 16
				Game.state.add("heat", RIG_DEAL_HEAT)
			3:
				return
		hand_no += 1
		await _customer_hand()
		if Game.check_caught():
			Game.state.flags["caught_dealing"] = true
			break
	Game.state.flags["shift_done"] = true
	Game.state.flags["customer_lost"] = customer_stack <= 200
	Game.state.flags["customer_won"] = customer_stack >= 800


func _customer_hand() -> void:
	await _start_hand(CUSTOMER_BET)
	while _bj.phase == Blackjack.Phase.PLAYER:
		if not Blackjack.should_hit(_bj.player, _bj.dealer[0]):
			_info.text = _hands_text(true) + "\nTeddy waves it off. He stands."
			await _wait(1.1)
			_bj.stand()
			break
		_info.text = _hands_text(true) + "\nTeddy taps the felt. He wants a card."
		var c := await _ask(["Deal the next card", "Deal him a bad card (+12 heat)", "Deal him a good card (+12 heat)"])
		if c > 0:
			_shoe.stack([Blackjack.pick_rank(_bj.player, c == 2)])
			Game.state.add("heat", RIG_CARD_HEAT)
		_bj.hit()
		await _deal_card(0, _bj.player[-1])
	await _reveal_hole()
	while _bj.dealer_must_draw():
		_info.text = _hands_text(false) + "\nThe house has to draw."
		var c := await _ask(["Draw the next card", "Draw a good card for the house (+12 heat)", "Draw a bad card for the house (+12 heat)"])
		if c > 0:
			_shoe.stack([Blackjack.pick_rank(_bj.dealer, c == 1)])
			Game.state.add("heat", RIG_CARD_HEAT)
		_bj.dealer_draw()
		await _deal_card(1, _bj.dealer[-1])
	_bj.finish()
	_info.text = _hands_text(false)

	var pay := _bj.payout()
	customer_stack += pay
	if pay > 0:
		Game.sfx("win")
		Game.toast.emit("Teddy wins %s" % Game.money(pay), GOOD)
	elif pay < 0:
		Game.sfx("lose")
		Game.toast.emit("Teddy loses %s" % Game.money(-pay), BAD)
	else:
		Game.toast.emit("Push", Color.WHITE)
	await _wait(1.8)
	_clear()


# --- Shared steps ---

func _start_hand(bet: int) -> void:
	if _shoe.needs_shuffle():
		_shoe.shuffle()
		_info.text = "Shuffling the shoe..."
		await _wait(0.8)
	_bj.deal(bet)
	_stack_chips(bet)
	await _deal_card(0, _bj.player[0])
	await _deal_card(1, _bj.dealer[0])
	await _deal_card(0, _bj.player[1])
	await _deal_card(1, _bj.dealer[1], false)


func _hands_text(hide_hole: bool) -> String:
	var them := "Teddy" if dealer_mode else "You"
	var house := "House (you)" if dealer_mode else "Dealer"
	var d := "%d + ?" % Shoe.value(_bj.dealer[0]) if hide_hole else str(Blackjack.total(_bj.dealer))
	return "%s: %d          %s: %s" % [them, Blackjack.total(_bj.player), house, d]


## Shows numbered buttons and waits for one to be picked.
func _ask(options: Array) -> int:
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


func _unhandled_key_input(e: InputEvent) -> void:
	if not _layer.visible or not e.pressed or e.echo:
		return
	var i: int = e.keycode - KEY_1
	if i >= 0 and i < _buttons.get_child_count():
		get_viewport().set_input_as_handled()
		picked.emit(i)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- Cards and chips on the felt ---

## Cards are laid out to read left to right from wherever you are sitting.
func _slot(side: int, i: int) -> Vector3:
	var flip := -1.0 if dealer_mode else 1.0
	return Vector3((-0.24 + i * 0.17) * flip, TOP + 0.004 + i * 0.001, 0.36 if side == 0 else -0.3)


func _deal_card(side: int, card: int, face_up := true) -> void:
	var n := Node3D.new()
	B.box(n, Vector3(0.15, 0.003, 0.21), Vector3.ZERO, _face if face_up else _back)
	var l := Label3D.new()
	l.text = "%s\n%s" % [Shoe.RANKS[card % 13], Shoe.SUITS[Shoe.suit(card)]]
	l.font = _font
	l.font_size = 96
	l.pixel_size = 0.0009
	l.line_spacing = -24
	l.outline_size = 0
	l.modulate = Color(0.75, 0.05, 0.1) if Shoe.suit(card) in [1, 2] else Color(0.05, 0.05, 0.07)
	l.rotation.x = -PI / 2
	l.position.y = 0.0025
	l.visible = face_up
	n.add_child(l)
	if dealer_mode:
		n.rotation.y = PI
	n.position = Vector3(0.8, TOP + 0.1, -0.3)
	add_child(n)
	_hands[side].append(n)
	Game.sfx("card", randf_range(0.9, 1.15))
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position", _slot(side, _hands[side].size() - 1), 0.22)
	await tw.finished
	await _wait(0.14)


func _reveal_hole() -> void:
	var n: Node3D = _hands[1][1]
	Game.sfx("card", 0.8)
	var tw := create_tween()
	tw.tween_property(n, "scale:x", 0.05, 0.1)
	await tw.finished
	n.get_child(0).material_override = _face
	n.get_child(1).visible = true
	tw = create_tween()
	tw.tween_property(n, "scale:x", 1.0, 0.1)
	await tw.finished
	await _wait(0.3)


func _stack_chips(amount: int) -> void:
	for c in _chips:
		c.queue_free()
	_chips.clear()
	Game.sfx("chip")
	var color := Color(0.15, 0.3, 0.9)
	if amount >= 500:
		color = Color(0.5, 0.15, 0.7)
	elif amount >= 100:
		color = Color(0.05, 0.05, 0.05)
	elif amount >= 50:
		color = Color(0.8, 0.1, 0.12)
	for i in clampi(amount / 50 + 2, 2, 9):
		_chips.append(B.cyl(self, 0.034, 0.011, Vector3(0, TOP + 0.006 + i * 0.012, 0.08), B.mat(color, 0.4)))


func _clear() -> void:
	for side in _hands:
		for n in side:
			n.queue_free()
	_hands = [[], []]
	for c in _chips:
		c.queue_free()
	_chips.clear()


# --- Building the table ---

func _build_table() -> void:
	var oval := Vector3(1, 1, 0.75)
	var felt := B.mat(Color(0.02, 0.22, 0.14), 0.95)
	B.cyl(self, 1.15, 0.06, Vector3(0, TOP - 0.03, 0), felt).scale = oval
	B.cyl(self, 1.24, 0.1, Vector3(0, TOP - 0.07, 0), B.wood()).scale = oval
	B.ring(self, 1.25, 0.07, Vector3(0, TOP - 0.01, 0), B.mat(Color(0.05, 0.03, 0.03), 0.35)).scale = Vector3(1, 0.6, 0.75)
	B.ring(self, 1.1, 0.012, Vector3(0, TOP + 0.001, 0), B.brass()).scale = Vector3(1, 0.3, 0.75)
	B.cyl(self, 0.32, 0.86, Vector3(0, 0.43, 0), B.wood())
	B.cyl(self, 0.62, 0.06, Vector3(0, 0.03, 0), B.brass())
	B.ring(self, 0.9, 0.03, Vector3(0, 0.8, 0), B.neon(accent, 4.0)).scale = oval
	B.light(self, Vector3(0, 0.5, 0), accent, 1.2, 3.0)

	# Chip tray and shoe on the dealer's side.
	B.box(self, Vector3(0.56, 0.03, 0.16), Vector3(0, TOP + 0.015, -0.52), B.mat(Color(0.03, 0.03, 0.03), 0.3))
	var chip_colors := [Color(0.9, 0.9, 0.9), Color(0.8, 0.1, 0.12), Color(0.1, 0.5, 0.2), Color(0.05, 0.05, 0.05), Color(0.5, 0.15, 0.7)]
	for i in chip_colors.size():
		B.cyl(self, 0.034, 0.04, Vector3(-0.2 + i * 0.1, TOP + 0.05, -0.52), B.mat(chip_colors[i], 0.4))
	B.box(self, Vector3(0.15, 0.11, 0.28), Vector3(0.8, TOP + 0.055, -0.36), B.mat(Color(0.02, 0.02, 0.02), 0.15))

	var note := Label3D.new()
	note.text = "BLACKJACK PAYS 3 TO 2"
	note.font_size = 48
	note.pixel_size = 0.0011
	note.outline_size = 0
	note.modulate = Color(0.85, 0.7, 0.35)
	note.rotation.x = -PI / 2
	note.rotation.y = PI if dealer_mode else 0.0
	note.position = Vector3(0, TOP + 0.002, -0.08)
	add_child(note)

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.0, 1.8)
	B.body(self, shape, Vector3(0, 0.5, 0)).set_meta("target", self)


func _build_ui() -> void:
	_layer.visible = false
	add_child(_layer)
	var panel := Style.panel(accent)
	_layer.add_child(panel)
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
	_info = Style.label("", 24)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 10)
	col.add_child(_info)
	col.add_child(_buttons)
