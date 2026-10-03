extends RefCounted
## Everything the story can read or change: money, debt, heat, flags,
## relationships, clocks, texts and which threads are active.

const MAX_HEAT := 100.0
const COOL_PER_SECOND := 0.15
## What gets written to the save file.
const SAVED := ["bankroll", "debt", "heat", "night", "installment", "missed", "unread",
	"flags", "rel", "threads", "clocks", "messages", "sent", "tonight", "plan"]

var bankroll := 500
var debt := 20000
var heat := 0.0
var night := 1
var installment := 0  # what Sal wants before the "sal" clock runs out
var missed := 0  # payments to Sal that were missed
var unread := 0
var flags := {}
var rel := {}
var threads: Array[String] = []  # first has priority
var clocks := {}  # name -> nights left
var messages: Array = []  # texts on the phone: {"from", "text", "night"}
var sent := {}  # ids of story texts already delivered
var tonight := {}  # scratch for the current night, cleared when it ends
var plan := {}  # tonight's customer, order and event


## A condition: {"flags": {name: value}, "min": {stat: n}, "max": {stat: n},
## "rel_min": {who: n}}. A flag that was never set counts as false.
## An empty condition is always true.
func check(when: Dictionary) -> bool:
	var want: Dictionary = when.get("flags", {})
	for k in want:
		if flags.get(k, false) != want[k]:
			return false
	var lo: Dictionary = when.get("min", {})
	for k in lo:
		if get(k) < lo[k]:
			return false
	var hi: Dictionary = when.get("max", {})
	for k in hi:
		if get(k) > hi[k]:
			return false
	var liked: Dictionary = when.get("rel_min", {})
	for k in liked:
		if rel.get(k, 0) < liked[k]:
			return false
	return true


## Effects: {"set": {flag: value}, "add": {stat: n}, "rel": {who: n},
## "tonight": {key: value}, "clock": {name: nights}, "clock_add": {name: nights},
## "text": {"from", "text"}, "start": thread, "end": thread}.
func apply(fx: Dictionary) -> void:
	var sets: Dictionary = fx.get("set", {})
	for k in sets:
		flags[k] = sets[k]
	var adds: Dictionary = fx.get("add", {})
	for k in adds:
		add(k, adds[k])
	var rels: Dictionary = fx.get("rel", {})
	for k in rels:
		rel[k] = rel.get(k, 0) + rels[k]
	tonight.merge(fx.get("tonight", {}), true)
	clocks.merge(fx.get("clock", {}), true)
	var more: Dictionary = fx.get("clock_add", {})
	for k in more:
		if clocks.has(k):
			clocks[k] += more[k]
	if fx.has("text"):
		text(fx["text"]["from"], fx["text"]["text"])
	if fx.has("start") and not threads.has(fx["start"]):
		threads.push_front(fx["start"])
	if fx.has("end"):
		threads.erase(fx["end"])


func add(stat: String, n: float) -> void:
	match stat:
		"bankroll":
			bankroll = maxi(0, bankroll + int(n))
		"debt":
			debt = maxi(0, debt + int(n))
			installment = mini(installment, debt)
		"heat":
			heat = clampf(heat + n, 0.0, MAX_HEAT)
		_:
			push_error("Unknown stat: " + stat)


func cool(delta: float) -> void:
	heat = maxf(0.0, heat - delta * COOL_PER_SECOND)


## Puts a message on the phone.
func text(from: String, body: String) -> void:
	messages.append({"from": from, "text": body, "night": night})
	unread += 1


## Moves every clock one night on. Returns the clocks that ran out; each also sets
## the flag "<name>_due".
func tick_clocks() -> Array[String]:
	var due: Array[String] = []
	for k in clocks.keys():
		clocks[k] -= 1
		if clocks[k] <= 0:
			clocks.erase(k)
			flags[k + "_due"] = true
			due.append(k)
	return due


func to_dict() -> Dictionary:
	var d := {}
	for k in SAVED:
		d[k] = get(k)
	return d


## Loads a saved game. JSON turns whole numbers into floats, so they are turned back.
func from_dict(d: Dictionary) -> void:
	for k in SAVED:
		if not d.has(k):
			continue
		if k == "threads":
			threads.assign(d[k])
		elif get(k) is int:
			set(k, int(d[k]))
		else:
			set(k, d[k])
