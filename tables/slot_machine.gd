extends Node3D
## A slot machine, built facing +Z. The reels are honest; the last one only takes
## longer to stop when the first two match, the way real machines build suspense.

signal sat
signal left

const B := preload("res://world/build.gd")
const Style := preload("res://ui/style.gd")
const Slots := preload("res://logic/slots.gd")
const ChoicePanel := preload("res://ui/choice_panel.gd")

const BETS := [5, 10, 25, 50]
const COLORS := [Color(1.0, 0.25, 0.25), Color(1.0, 0.8, 0.4), Color(1.0, 0.95, 0.4),
	Color(0.4, 0.8, 1.0), Color(1.0, 0.4, 0.7), Color(0.9, 0.15, 0.3)]

var loose := false
var player: Node

var _bet_i := 1
var _panel := ChoicePanel.new()
var _reels: Array[Label] = []
var _topper: StandardMaterial3D


func _ready() -> void:
	var shell := B.mat(Color(0.05, 0.05, 0.07), 0.25, 0.6)
	B.box(self, Vector3(0.78, 1.75, 0.6), Vector3(0, 0.875, 0), shell)
	_topper = B.neon(Color.from_hsv(randf(), 0.85, 1.0), 2.5)
	B.box(self, Vector3(0.8, 0.32, 0.5), Vector3(0, 1.93, 0.02), _topper)
	B.box(self, Vector3(0.62, 0.56, 0.03), Vector3(0, 1.25, 0.305), B.neon(Color(0.08, 0.03, 0.2), 1.0))
	for col in 3:
		for row in 3:
			B.box(self, Vector3(0.15, 0.13, 0.02), Vector3(-0.19 + col * 0.19, 1.08 + row * 0.17, 0.325),
				B.neon(Color.from_hsv(randf(), 0.8, 1.0), 1.8))
	B.box(self, Vector3(0.78, 0.08, 0.3), Vector3(0, 0.85, 0.42), shell)
	B.box(self, Vector3(0.12, 0.03, 0.08), Vector3(0.2, 0.9, 0.45), B.neon(Color(1, 0.2, 0.2), 2.0))
	B.cyl(self, 0.18, 0.07, Vector3(0, 0.62, 1.0), B.mat(Color(0.35, 0.03, 0.08), 0.5))
	B.cyl(self, 0.03, 0.6, Vector3(0, 0.3, 1.0), B.brass())
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.78, 1.75, 0.6)
	B.body(self, shape, Vector3(0, 0.875, 0)).set_meta("target", self)

	var tw := create_tween().set_loops()
	var t := randf_range(0.4, 1.3)
	tw.tween_property(_topper, "emission_energy_multiplier", 4.5, t)
	tw.tween_property(_topper, "emission_energy_multiplier", 1.5, t)

	_panel.accent = Style.GOLD
	add_child(_panel)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Unicode MS", "Apple Symbols", "Arial"])
	for i in 3:
		var l := Style.label("7", 72)
		l.add_theme_font_override("font", font)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(170, 100)
		_reels.append(l)
		_panel.extra.add_child(l)
		_show(i, randi() % Slots.SYMBOLS.size())


func is_loose() -> bool:
	return loose or Game.state.plan.get("event", "") == "promo"


## Once the regular has told you the trick, you can tell which machines are which.
func prompt() -> String:
	if not Game.state.flags.get("knows_loose_slots", false):
		return "Play the slots"
	return "Play the slots (%s machine)" % ("loose" if is_loose() else "tight")


func interact() -> void:
	sat.emit()
	_panel.visible = true
	player.sit(Transform3D(Basis.IDENTITY, to_global(Vector3(0, 1.4, 2.0))).looking_at(to_global(Vector3(0, 1.15, 0))))
	await _play_loop()
	_panel.visible = false
	player.stand()
	left.emit()


func _play_loop() -> void:
	while true:
		var bet: int = BETS[_bet_i]
		_panel.info.text = "Bet: %s" % Game.money(bet)
		match await _panel.ask(["Spin", "Lower bet", "Raise bet", "Leave the machine"]):
			0:
				if Game.state.bankroll < bet:
					Game.toast.emit("You can't cover that bet.", Color(1.0, 0.45, 0.45))
				else:
					await _spin(bet)
			1:
				_bet_i = maxi(0, _bet_i - 1)
			2:
				_bet_i = mini(BETS.size() - 1, _bet_i + 1)
			3:
				return


func _show(reel: int, symbol: int) -> void:
	_reels[reel].text = Slots.SYMBOLS[symbol]
	_reels[reel].add_theme_color_override("font_color", COLORS[symbol])


func _spin(bet: int) -> void:
	Game.state.add("bankroll", -bet)
	_panel.info.text = "..."
	var result := Slots.spin(Game.rng, is_loose())
	var tease := result[0] == result[1]
	var stops := [10, 18, 40 if tease else 26]
	for tick in stops[2] + 1:
		for r in 3:
			if tick < stops[r]:
				_show(r, randi() % Slots.SYMBOLS.size())
			elif tick == stops[r]:
				_show(r, result[r])
				Game.sfx("chip", 0.8 + r * 0.15)
		Game.sfx("click", 1.5)
		await _panel.wait(0.11 if tick > 26 else 0.05)

	var win := bet * Slots.payout(result)
	Game.state.add("bankroll", win)
	if win >= bet * 30:
		Game.sfx("blackjack")
		Game.toast.emit("JACKPOT  +%s" % Game.money(win), Style.GOLD)
	elif win > bet:
		Game.sfx("win")
		Game.toast.emit("Winner  +%s" % Game.money(win), Color(0.5, 1.0, 0.6))
	elif win == bet:
		# A "win" that only returns the bet still gets the lights and the chime.
		Game.sfx("win", 1.2)
		Game.toast.emit("Winner  +%s" % Game.money(win), Color(0.5, 1.0, 0.6))
	else:
		_panel.info.text = "No win."
		await _panel.wait(0.4)
