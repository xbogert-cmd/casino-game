extends RefCounted
## A blackjack shoe. A card is an int 0..51: rank = card % 13 (0 = ace, 12 = king),
## suit = card / 13. The top of the shoe is the end of the array.

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["♠", "♥", "♦", "♣"]

var rng: RandomNumberGenerator
var decks: int
var cards: Array[int] = []


func _init(p_rng: RandomNumberGenerator, p_decks := 6) -> void:
	rng = p_rng
	decks = p_decks
	shuffle()


func shuffle() -> void:
	cards.clear()
	for i in decks * 52:
		cards.append(i % 52)
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := cards[i]
		cards[i] = cards[j]
		cards[j] = t


## The last deck is never dealt, like a cut card.
func needs_shuffle() -> bool:
	return cards.size() < 52


func draw() -> int:
	if cards.is_empty():
		shuffle()
	return cards.pop_back()


## Cheat: moves cards of the given ranks to the top so they come out in that order.
func stack(ranks: Array) -> void:
	var placed := 0
	for i in range(ranks.size() - 1, -1, -1):
		for k in range(cards.size() - 1 - placed, -1, -1):
			if cards[k] % 13 == ranks[i]:
				var c := cards[k]
				cards.remove_at(k)
				cards.append(c)
				placed += 1
				break


static func suit(card: int) -> int:
	return floori(card / 13.0)


## Aces count 11 here; blackjack.gd lowers them to 1 when a hand would bust.
static func value(card: int) -> int:
	var r := card % 13
	if r == 0:
		return 11
	return mini(r + 1, 10)
