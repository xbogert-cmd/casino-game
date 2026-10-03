extends RefCounted
## One round of blackjack. Rules: dealer stands on all 17s, blackjack pays 3:2,
## double on the first two cards, no splitting or insurance.
## Cheating is done by stacking the shoe before a draw; this class never knows.

const Shoe := preload("res://logic/shoe.gd")

enum Phase { IDLE, PLAYER, DEALER, DONE }

var shoe
var player: Array[int] = []
var dealer: Array[int] = []
var bet := 0
var phase := Phase.IDLE
var result := ""  # "blackjack", "win", "push", "lose" or "bust"


func _init(p_shoe) -> void:
	shoe = p_shoe


static func total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c in hand:
		t += Shoe.value(c)
		if c % 13 == 0:
			aces += 1
	while t > 21 and aces > 0:
		t -= 10
		aces -= 1
	return t


static func is_soft(hand: Array) -> bool:
	var hard := 0
	for c in hand:
		hard += 1 if c % 13 == 0 else Shoe.value(c)
	return total(hand) != hard


static func is_blackjack(hand: Array) -> bool:
	return hand.size() == 2 and total(hand) == 21


## A simple player strategy, used by the customer and by the odds test.
static func should_hit(hand: Array, dealer_up: int) -> bool:
	var t := total(hand)
	if t <= 11 or (is_soft(hand) and t <= 17):
		return true
	if t >= 17:
		return false
	return Shoe.value(dealer_up) >= 7


## The rank a cheat would put next: the best card for this hand, or the worst.
static func pick_rank(hand: Array, good: bool) -> int:
	var best := 0
	var best_score := -INF
	for r in 13:
		var t := total(hand + [r])
		var score: float
		if good:
			score = t if t <= 21 else -t
		else:
			score = 100 + t if t > 21 else -t
		if score > best_score:
			best_score = score
			best = r
	return best


func deal(p_bet: int) -> void:
	bet = p_bet
	result = ""
	player = []
	dealer = []
	player.append(shoe.draw())
	dealer.append(shoe.draw())
	player.append(shoe.draw())
	dealer.append(shoe.draw())
	phase = Phase.PLAYER
	if is_blackjack(player) or is_blackjack(dealer):
		_settle()


func can_double() -> bool:
	return phase == Phase.PLAYER and player.size() == 2


func hit() -> void:
	assert(phase == Phase.PLAYER)
	player.append(shoe.draw())
	var t := total(player)
	if t > 21:
		_settle()
	elif t == 21:
		phase = Phase.DEALER


func stand() -> void:
	assert(phase == Phase.PLAYER)
	phase = Phase.DEALER


func double_down() -> void:
	assert(can_double())
	bet *= 2
	player.append(shoe.draw())
	if total(player) > 21:
		_settle()
	else:
		phase = Phase.DEALER


func dealer_must_draw() -> bool:
	return phase == Phase.DEALER and total(dealer) < 17


func dealer_draw() -> void:
	dealer.append(shoe.draw())


## Plays out the dealer's remaining draws and settles the round.
func finish() -> void:
	while dealer_must_draw():
		dealer_draw()
	if phase != Phase.DONE:
		_settle()


## Net change to the player's money for the settled round.
func payout() -> int:
	match result:
		"blackjack":
			return bet * 3 / 2
		"win":
			return bet
		"push":
			return 0
	return -bet


func _settle() -> void:
	var p := total(player)
	var d := total(dealer)
	if is_blackjack(player):
		result = "push" if is_blackjack(dealer) else "blackjack"
	elif p > 21:
		result = "bust"
	elif is_blackjack(dealer):
		result = "lose"
	elif d > 21 or p > d:
		result = "win"
	elif p < d:
		result = "lose"
	else:
		result = "push"
	phase = Phase.DONE
