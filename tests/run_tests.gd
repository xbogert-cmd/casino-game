extends SceneTree
## Run with: godot --headless --path . --script res://tests/run_tests.gd

const Shoe := preload("res://logic/shoe.gd")
const Blackjack := preload("res://logic/blackjack.gd")
const StoryState := preload("res://logic/story_state.gd")
const Story := preload("res://logic/story.gd")
const Night := preload("res://logic/night.gd")
const Slots := preload("res://logic/slots.gd")

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
	_test_save_and_clocks()
	_test_threads()
	_test_night()
	_test_sal()
	_test_slots()
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


func _test_save_and_clocks() -> void:
	var s := StoryState.new()
	s.apply({"set": {"a": true}, "tonight": {"briefed": true}, "clock": {"sal": 2, "x": 1}, "text": {"from": "Sal", "text": "hi"}, "start": "floor"})
	s.apply({"start": "house"})
	ok(s.threads == ["house", "floor"], "a new thread goes in front of older ones")
	ok(s.tonight["briefed"] and s.unread == 1 and s.messages[0]["from"] == "Sal", "effects set tonight values and send texts")
	s.bankroll = 1234
	s.night = 3
	var copy := StoryState.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	ok(copy.bankroll == 1234 and copy.night == 3 and typeof(copy.night) == TYPE_INT, "save keeps whole numbers whole")
	ok(copy.flags["a"] and copy.threads == s.threads and copy.clocks["sal"] == 2, "save keeps flags, threads and clocks")
	ok(s.tick_clocks() == ["x"] and s.flags["x_due"] and s.clocks["sal"] == 1, "a clock that runs out sets its due flag")
	s.apply({"clock_add": {"sal": 2, "gone": 5}})
	ok(s.clocks["sal"] == 3 and not s.clocks.has("gone"), "clock_add only extends clocks that are running")
	ok(s.check({"rel_min": {"manager": 0}}) and not s.check({"rel_min": {"manager": 1}}), "rel_min condition")
	ok(s.check({"min": {"night": 3}}) and not s.check({"min": {"night": 4}}), "night can be used in conditions")


func _test_threads() -> void:
	var story := Story.new()
	story.load_dir("res://data/threads")
	for id in ["opening", "floor", "house", "inspector"]:
		ok(story.threads.has(id), "thread %s loads" % id)
	for p in story.problems():
		ok(false, p)

	var s := StoryState.new()
	s.threads.assign(["floor"])
	s.night = 2
	ok(story.entry("manager", s).is_empty(), "no special manager scene without his trust")
	s.rel["manager"] = 1
	ok(story.entry("manager", s)["node"] == "h_offer", "a trusted dealer gets the house offer")
	s.apply(story.node("floor", "h_offer")["choices"][0]["effects"])
	ok(s.threads[0] == "house" and story.job(s)["customer"] == "friend", "accepting starts the house thread and its job")
	ok(story.entry("manager", s).is_empty(), "the offer is made once")
	s.apply(story.job(s)["success"])
	ok(story.job(s).is_empty() and story.entry("manager", s)["node"] == "h_2", "finishing the job unlocks the next scene")

	s = StoryState.new()
	s.threads.assign(["floor"])
	s.flags["has_evidence"] = true
	story.send_texts(s)
	ok(s.messages.is_empty(), "no text about the ledger on night one")
	s.night = 2
	story.send_texts(s)
	story.send_texts(s)
	ok(s.messages.size() == 1 and s.threads[0] == "inspector", "the ledger text arrives once and starts the inspector thread")
	ok(story.entry("ines", s)["node"] == "i_1", "with evidence, Ines takes the pictures")
	s.apply(story.node("inspector", "i_1")["effects"])
	ok(story.job(s)["event"] == "audit" and story.job(s)["order"] == "straight", "Ines forces an audit night dealt straight")
	s.apply(story.node("inspector", "x_sold")["effects"])
	ok(not s.threads.has("inspector") and s.debt == 17000, "selling Ines out ends her thread and cuts the debt")


func _test_night() -> void:
	var story := Story.new()
	story.load_dir("res://data/threads")
	var s := StoryState.new()
	s.threads.assign(["floor"])
	ok(Night.plan(s, story, _rng(5)) == Night.plan(s, story, _rng(5)), "same seed gives the same night")
	var seen := {}
	for i in 200:
		var p := Night.plan(s, story, _rng(i))
		seen[p["event"]] = true
		seen[p["customer"]] = true
		ok(Night.CUSTOMERS.has(p["customer"]) and Night.EVENTS.has(p["event"]) and Night.ORDERS.has(p["order"]), "plan %d is valid" % i)
		if p["event"] == "audit":
			ok(p["order"] == "straight", "audit nights are dealt straight")
	ok(seen.size() == Night.EVENTS.size() + Night.WALK_INS.size(), "every event and walk-in customer turns up")
	ok(not seen.has("friend") and not seen.has("teddy"), "story customers never walk in at random")

	s.flags["house_1"] = true
	s.threads.push_front("house")
	var forced := Night.plan(s, story, _rng(1))
	ok(forced["customer"] == "friend" and forced["order"] == "win", "a thread job overrides the random plan")

	var p := {"customer": "marge", "order": "lose", "event": "quiet", "job": {}}
	ok(Night.settle(p, 300, 150, 2)["ok"] and Night.settle(p, 300, 150, 2)["effects"]["add"]["debt"] == -1000, "taking half the stack fulfils a lose order")
	ok(not Night.settle(p, 300, 200, 0)["ok"], "taking less than half does not")
	ok(Night.settle(p, 300, 200, 0)["effects"]["add"]["bankroll"] == Night.WAGE, "a failed order still pays the wage")
	p["event"] = "high_roller"
	ok(Night.settle(p, 1500, 0, 0)["effects"]["add"]["debt"] == -2000 and Night.customer(p)["stack"] == 1500, "a high roller doubles the reward and plays five times the stakes")
	p = {"customer": "friend", "order": "win", "event": "quiet", "job": {}}
	ok(Night.settle(p, 1000, 1500, 3)["ok"] and not Night.settle(p, 1000, 1400, 3)["ok"], "a win order needs the stack up by half")
	p["order"] = "straight"
	ok(Night.settle(p, 1000, 900, 0)["ok"] and not Night.settle(p, 1000, 900, 1)["ok"], "a straight order fails on any stacked card")
	ok(Blackjack.wants_card([9, 1], 5, "reckless") and not Blackjack.wants_card([9, 1], 9, "cautious"), "play styles differ on 12")


func _test_sal() -> void:
	var s := StoryState.new()
	s.heat = 60
	s.tonight["x"] = 1
	Night.end_night(s, _rng(1))
	ok(s.night == 2 and s.heat == 30 and s.tonight.is_empty(), "a new night halves the heat and clears the night's scratch")
	ok(s.installment == 1500 and s.clocks["sal"] == 3 and s.messages.size() == 1, "Sal makes his first demand on night two")
	s.bankroll = 1000
	ok(Night.pay_sal(s) == 1000 and s.bankroll == 0 and s.installment == 500 and s.debt == 19000, "paying Sal comes off the installment and the debt")
	Night.borrow(s)
	ok(s.bankroll == 500 and s.debt == 19750, "a loan costs more than it gives")
	Night.end_night(s, _rng(1))
	Night.end_night(s, _rng(1))
	ok(s.missed == 0 and s.clocks["sal"] == 1, "nothing happens before the deadline")
	Night.end_night(s, _rng(1))
	ok(s.missed == 1 and s.bankroll == 250 and s.installment == 1500 and s.clocks["sal"] == 2, "a missed payment costs half your cash and raises the next demand")
	ok(s.debt == 19750 + 250 - 250, "the penalty is added and the seized cash comes off")
	s.bankroll = 5000
	Night.pay_sal(s)
	Night.end_night(s, _rng(1))
	Night.end_night(s, _rng(1))
	ok(s.missed == 1 and s.installment >= 1000 and s.clocks.has("sal"), "a paid installment leads to the next demand")
	s.debt = 0
	s.installment = 0
	s.clocks.clear()
	Night.end_night(s, _rng(1))
	ok(not s.clocks.has("sal"), "Sal stops once the debt is gone")


func _test_slots() -> void:
	ok(Slots.payout([0, 0, 0]) == 200 and Slots.payout([5, 5, 5]) == 5, "three of a kind pays by symbol")
	ok(Slots.payout([5, 5, 1]) == 2 and Slots.payout([5, 2, 5]) == 1 and Slots.payout([1, 5, 5]) == 0, "cherries pay from the first reel only")
	ok(Slots.payout([1, 1, 2]) == 0, "two of a kind pays nothing")
	var tight := Slots.rtp(false)
	var loose := Slots.rtp(true)
	print("slots pay back: tight %.1f%%, loose %.1f%%" % [tight * 100.0, loose * 100.0])
	ok(tight > 0.86 and tight < 0.90, "tight machines pay back 86-90%%, got %.4f" % tight)
	ok(loose > 0.95 and loose < 0.99, "loose machines pay back 95-99%%, got %.4f" % loose)
	var rng := _rng(3)
	var paid := 0
	var spins := 300000
	for i in spins:
		paid += Slots.payout(Slots.spin(rng, false))
	ok(absf(float(paid) / spins - tight) < 0.03, "simulated spins match the worked-out payback")
