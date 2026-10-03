extends RefCounted
## What makes one night differ from the next: who sits at your table, what the pit
## boss wants, what is happening on the floor, and where you stand with Sal.

const HANDS := 6
const WAGE := 150
const LOAN := 500
const LOAN_COST := 750
const MAX_MISSED := 3

## style: "basic" plays sensibly, "cautious" never risks a bust, "reckless" hits to 17.
const CUSTOMERS := {
	"teddy": {"name": "Teddy Briggs", "stack": 500, "bet": 100, "style": "basic",
		"blurb": "Deal me in. I need a good night."},
	"marge": {"name": "Marge Holloway", "stack": 300, "bet": 50, "style": "cautious",
		"blurb": "Thirty-one years teaching fourth grade. This is my one bad habit, dear."},
	"dmitri": {"name": "Dmitri Vance", "stack": 800, "bet": 100, "style": "reckless",
		"blurb": "Hit me until I say stop. I never say stop."},
	"paul": {"name": "Paul Reyes", "stack": 600, "bet": 100, "style": "basic",
		"blurb": "Just here for the cards. Nice shoe. Six decks? I thought so."},
	"kenji": {"name": "Kenji Sato", "stack": 400, "bet": 50, "style": "basic",
		"blurb": "First time in a place like this. Is it always this loud?"},
	"friend": {"name": "Mr. Castellano", "stack": 1000, "bet": 200, "style": "basic",
		"blurb": "Halloran says you're reliable. Let's find out."},
}
const WALK_INS := ["marge", "dmitri", "paul", "kenji"]

## heat: how much stacking the shoe costs tonight, as a multiplier.
const EVENTS := {
	"quiet": {"title": "A quiet night", "heat": 1.0,
		"text": "The floor is half empty. Nothing unusual."},
	"audit": {"title": "Audit night", "heat": 2.0,
		"text": "Two people in grey suits are walking the floor with clipboards. Stacking the shoe draws twice the heat tonight."},
	"flicker": {"title": "Bad wiring", "heat": 0.5,
		"text": "The lights keep cutting out, and the cameras with them. Stacking the shoe draws half the heat tonight."},
	"high_roller": {"title": "A whale at your table", "heat": 1.0,
		"text": "Your customer tonight plays five times the usual stakes. Halloran's rewards are doubled."},
	"promo": {"title": "Promo night", "heat": 1.0,
		"text": "Every slot machine is set loose tonight, to fill the floor."},
}
const EVENT_ODDS := {"quiet": 3.0, "audit": 1.0, "flicker": 1.0, "high_roller": 1.0, "promo": 1.0}

const ORDERS := {
	"none": "No instructions. Deal the game, keep the table full.",
	"lose": "This one leaves light. Take at least half the stack.",
	"win": "A friend of the house. The stack is up by half when the shift ends. You don't ask why.",
	"straight": "Deal it straight tonight. Not one stacked card. People are watching.",
}


## Tonight's plan: {"customer", "order", "event", "job"}. A story thread can force
## parts of it through a job; the rest is drawn at random.
static func plan(state, story, rng: RandomNumberGenerator) -> Dictionary:
	var job: Dictionary = story.job(state)
	var event: String = job.get("event", "")
	if event == "":
		var names := EVENT_ODDS.keys()
		event = names[rng.rand_weighted(PackedFloat32Array(EVENT_ODDS.values()))]
	var customer: String = job.get("customer", WALK_INS[rng.randi_range(0, WALK_INS.size() - 1)])
	var order: String = job.get("order", "")
	if order == "":
		if event == "audit":
			order = "straight"
		elif customer == "paul":
			order = "lose"  # Halloran thinks he counts cards
		else:
			order = ["none", "none", "lose", "straight"][rng.randi_range(0, 3)]
	return {"customer": customer, "order": order, "event": event, "job": job}


## The customer for a plan, with the stakes raised on a high-roller night.
static func customer(p: Dictionary) -> Dictionary:
	var c: Dictionary = CUSTOMERS[p["customer"]].duplicate()
	if p["event"] == "high_roller":
		c["stack"] *= 5
		c["bet"] *= 5
	return c


static func briefing(p: Dictionary) -> String:
	return ORDERS[p["order"]]


## How the shift went against the order: {"ok", "text", "effects"}.
## `start` and `end` are the customer's stack, `stacked` how often you cheated.
static func settle(p: Dictionary, start: int, end: int, stacked: int) -> Dictionary:
	var double := 2 if p["event"] == "high_roller" else 1
	var ok := true
	var text := "You dealt your shift."
	var fx := {"add": {"bankroll": WAGE}, "rel": {}}
	match p["order"]:
		"lose":
			ok = end * 2 <= start
			if ok:
				fx["add"]["debt"] = -1000 * double
				text = "The customer left light, as ordered. Halloran takes $%d off your debt." % (1000 * double)
			else:
				text = "The customer kept too much. Halloran wanted more."
		"win":
			ok = end * 2 >= start * 3
			if ok:
				fx["add"]["bankroll"] += 400 * double
				text = "The friend of the house left happy. An envelope with $%d finds your pocket." % (400 * double)
			else:
				text = "The friend of the house did not win enough. Halloran is unhappy."
		"straight":
			ok = stacked == 0
			if ok:
				fx["add"]["bankroll"] += 100
				text = "You dealt it clean while they watched. A $100 bonus."
			else:
				fx["add"]["heat"] = 20
				text = "You stacked the shoe on a night you were told not to. It was noticed."
	if p["order"] != "none":
		fx["rel"]["manager"] = 1 if ok else -1
	return {"ok": ok, "text": text + "\nWage: $%d." % WAGE, "effects": fx}


## Pays Sal as much of the current installment as you can afford. Returns the amount.
static func pay_sal(state) -> int:
	var n: int = mini(state.bankroll, state.installment)
	state.bankroll -= n
	state.installment -= n
	state.debt -= n
	return n


static func borrow(state) -> void:
	state.bankroll += LOAN
	state.debt += LOAN_COST


## Ends the night: the next one begins, heat fades, clocks move and Sal collects.
static func end_night(state, rng: RandomNumberGenerator) -> void:
	state.night += 1
	state.heat *= 0.5
	state.tonight = {}
	if state.flags.get("opening_done", false):
		state.threads.erase("opening")
	if state.debt <= 0:
		return
	if state.night == 2:
		_demand(state, 1500, 3, "First payment. $1,500 before night 5 starts. Pay from your phone. Don't make me send Lou.")
	elif "sal" in state.tick_clocks():
		if state.installment <= 0:
			var amount: int = [1000, 1500, 2000, 2500][rng.randi_range(0, 3)]
			var nights := rng.randi_range(2, 4)
			_demand(state, amount, nights, "Paid. Good. Next one is $%d before night %d starts." % [amount, state.night + nights])
		else:
			# Missed: Lou takes half of what you carry, and a penalty goes on the debt.
			state.missed += 1
			var penalty: int = state.installment / 2
			var seized: int = state.bankroll / 2
			state.bankroll -= seized
			state.debt = maxi(0, state.debt + penalty - seized)
			_demand(state, state.installment + 1000, 2,
				"You missed. Lou took $%d off you and I added $%d for my trouble. Now it's $%d in two nights. I am running out of patience." % [
					seized, penalty, state.installment + 1000])


static func _demand(state, amount: int, nights: int, message: String) -> void:
	state.installment = mini(amount, state.debt)
	state.clocks["sal"] = nights
	state.text("Sal", message)
