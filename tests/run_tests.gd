extends SceneTree
## Run with: godot --headless --path . --script res://tests/run_tests.gd

const Shoe := preload("res://logic/shoe.gd")
const Blackjack := preload("res://logic/blackjack.gd")
const StoryState := preload("res://logic/story_state.gd")
const Story := preload("res://logic/story.gd")

var _fails := 0
var _checks := 0


func _init() -> void:
	_test_totals()
	_test_shoe()
	_test_rounds()
	_test_cheats()
	_test_state()
	_test_story()
	_test_house_edge()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func ok(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: " + what)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A round with a shoe stacked so the cards come out as: player, dealer, player, dealer, then `rest`.
func _round(ranks: Array) -> Blackjack:
	var shoe := Shoe.new(_rng(1))
	shoe.stack(ranks)
	return Blackjack.new(shoe)


func _test_totals() -> void:
	ok(Blackjack.total([0, 12]) == 21, "ace + king is 21")
	ok(Blackjack.is_blackjack([0, 12]), "ace + king is blackjack")
	ok(not Blackjack.is_blackjack([4, 5, 9]), "three-card 21 is not blackjack")
	ok(Blackjack.total([0, 0, 8]) == 21, "two aces + 9 is 21")
	ok(Blackjack.total([0, 5, 9]) == 17, "ace drops to 1 when it would bust")
	ok(Blackjack.total([9, 10, 11]) == 30, "three face cards bust at 30")
	ok(Blackjack.is_soft([0, 5]), "ace + 6 is soft")
	ok(not Blackjack.is_soft([0, 5, 9]), "ace + 6 + 10 is hard")
	ok(Shoe.value(13 + 12) == 10 and Shoe.suit(13 + 12) == 1, "king of hearts: value and suit")


func _test_shoe() -> void:
	var shoe := Shoe.new(_rng(7))
	ok(shoe.cards.size() == 312, "six decks is 312 cards")
	var aces := shoe.cards.filter(func(c): return c % 13 == 0).size()
	ok(aces == 24, "six decks hold 24 aces")
	var other := Shoe.new(_rng(7))
	ok(shoe.cards == other.cards, "same seed gives the same shuffle")
	ok(shoe.cards != Shoe.new(_rng(8)).cards, "different seed gives a different shuffle")
	shoe.stack([9, 9, 0])
	ok(shoe.draw() % 13 == 9 and shoe.draw() % 13 == 9 and shoe.draw() % 13 == 0, "stack sets the draw order")
	ok(shoe.cards.size() == 309, "stacking neither adds nor loses cards")


func _test_rounds() -> void:
	var r := _round([0, 8, 12, 6])  # player A,K / dealer 9,7
	r.deal(100)
	ok(r.result == "blackjack" and r.payout() == 150, "blackjack pays 3:2")

	r = _round([0, 0, 12, 12])
	r.deal(100)
	ok(r.result == "push" and r.payout() == 0, "blackjack against blackjack pushes")

	r = _round([9, 0, 9, 12])  # player 20 / dealer blackjack
	r.deal(100)
	ok(r.result == "lose" and r.payout() == -100, "dealer blackjack beats 20")

	r = _round([9, 9, 5, 6, 9])  # player 10,6 then 10 / dealer 10,7
	r.deal(100)
	r.hit()
	ok(r.result == "bust" and r.payout() == -100, "player bust loses the bet")

	r = _round([9, 9, 8, 5, 9])  # player 19 / dealer 10,6 then 10
	r.deal(100)
	r.stand()
	r.finish()
	ok(r.result == "win" and r.payout() == 100, "dealer bust pays even money")

	r = _round([9, 9, 7, 6])  # player 18 / dealer 17
	r.deal(100)
	r.stand()
	ok(not r.dealer_must_draw(), "dealer stands on 17")
	r.finish()
	ok(r.result == "win", "18 beats 17")

	r = _round([9, 0, 7, 5])  # dealer A,6 = soft 17
	r.deal(100)
	r.stand()
	ok(not r.dealer_must_draw(), "dealer stands on soft 17")

	r = _round([9, 9, 6, 7])  # 17 against 18
	r.deal(100)
	r.stand()
	r.finish()
	ok(r.result == "lose", "17 loses to 18")

	r = _round([9, 9, 7, 7])
	r.deal(100)
	r.stand()
	r.finish()
	ok(r.result == "push", "equal totals push")

	r = _round([5, 9, 4, 6, 9])  # player 6,5 doubles into 21 / dealer 17
	r.deal(100)
	ok(r.can_double(), "can double on two cards")
	r.double_down()
	r.finish()
	ok(r.bet == 200 and r.result == "win" and r.payout() == 200, "double wins twice the bet")

	r = _round([4, 9, 5, 6, 9])  # player 5,6 hits to 21
	r.deal(100)
	r.hit()
	ok(r.phase == Blackjack.Phase.DEALER and not r.can_double(), "21 stands automatically")


func _test_cheats() -> void:
	ok(Blackjack.total([9, 5] + [Blackjack.pick_rank([9, 5], true)]) == 21, "best card for 16 makes 21")
	ok(Blackjack.total([9, 5] + [Blackjack.pick_rank([9, 5], false)]) > 21, "worst card for 16 busts")
	ok(Blackjack.pick_rank([4, 5], false) == 0, "worst card for 11 is an ace")
	ok(Blackjack.should_hit([9, 5], 9), "16 hits against a ten")
	ok(not Blackjack.should_hit([9, 5], 4), "16 stands against a five")
	ok(not Blackjack.should_hit([9, 6], 9), "17 always stands")


func _test_state() -> void:
	var s := StoryState.new()
	ok(s.check({}), "empty condition is true")
	ok(s.check({"flags": {"x": false}}), "unset flag counts as false")
	ok(not s.check({"flags": {"x": true}}), "unset flag is not true")
	s.apply({"set": {"x": true}, "add": {"heat": 30, "debt": -2000, "bankroll": 50}, "rel": {"manager": 1}, "start": "t"})
	ok(s.flags["x"] and s.heat == 30 and s.debt == 18000 and s.bankroll == 550, "effects change flags and stats")
	ok(s.rel["manager"] == 1 and s.threads.has("t"), "effects change relationships and threads")
	ok(s.check({"min": {"heat": 30}}) and not s.check({"min": {"heat": 31}}), "min condition")
	ok(s.check({"max": {"heat": 30}}) and not s.check({"max": {"heat": 29}}), "max condition")
	s.add("heat", 500)
	ok(s.heat == 100, "heat is capped at 100")
	s.add("bankroll", -99999)
	ok(s.bankroll == 0, "bankroll never goes below zero")
	s.cool(10.0)
	ok(s.heat < 100 and s.heat > 90, "heat cools slowly")
	s.apply({"end": "t"})
	ok(not s.threads.has("t"), "a thread can be ended")


func _test_story() -> void:
	var story := Story.new()
	story.load_dir("res://data/threads")
	ok(story.threads.has("opening"), "opening thread loads")
	for p in story.problems():
		ok(false, p)
	var s := StoryState.new()
	ok(story.entry("manager", s).is_empty(), "no dialogue while no thread is active")
	s.threads.append("opening")
	ok(story.entry("manager", s)["node"] == "m_intro", "manager starts with the intro")
	ok(story.objective(s).begins_with("Find"), "first objective is to find the manager")
	s.apply(story.choices("opening", "m_intro", s)[0]["effects"])
	ok(story.entry("manager", s)["node"] == "m_wait", "manager waits once the mission is given")
	ok(story.entry("customer", s)["node"] == "c_talk", "customer will talk once the mission is given")
	s.flags["shift_done"] = true
	s.flags["customer_lost"] = true
	ok(story.entry("manager", s)["node"] == "m_good", "manager is pleased when the customer lost")
	s.apply(story.node("opening", "m_good")["effects"])
	ok(s.debt == 18000 and story.entry("manager", s)["node"] == "m_done", "following orders cuts the debt and ends the night")

	s = StoryState.new()
	s.threads.append("opening")
	s.apply(story.node("opening", "c_warned")["effects"])
	ok(story.entry("manager", s)["node"] == "m_warned", "manager notices when the customer was warned")
	ok(story.entry("nobody", s).is_empty(), "unknown people have no dialogue")


## The house must keep a small edge under these rules, for a player who plays sensibly.
func _test_house_edge() -> void:
	var shoe := Shoe.new(_rng(42))
	var net := 0
	var hands := 200000
	for i in hands:
		if shoe.needs_shuffle():
			shoe.shuffle()
		var r := Blackjack.new(shoe)
		r.deal(10)
		while r.phase == Blackjack.Phase.PLAYER:
			var t := Blackjack.total(r.player)
			if r.can_double() and (t == 10 or t == 11) and Shoe.value(r.dealer[0]) < 10:
				r.double_down()
			elif Blackjack.should_hit(r.player, r.dealer[0]):
				r.hit()
			else:
				r.stand()
		r.finish()
		net += r.payout()
	var edge := -net / (hands * 10.0)
	print("house edge over %d hands: %.2f%%" % [hands, edge * 100.0])
	ok(edge > -0.01 and edge < 0.045, "house edge is between -1%% and 4.5%%, got %.4f" % edge)
