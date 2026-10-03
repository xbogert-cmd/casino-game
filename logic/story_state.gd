extends RefCounted
## Everything the story can read or change: money, debt, heat, flags,
## relationships and which threads are active.

const STATS := ["bankroll", "debt", "heat"]
const MAX_HEAT := 100.0
const COOL_PER_SECOND := 0.15

var bankroll := 500
var debt := 20000
var heat := 0.0
var flags := {}
var rel := {}
var threads: Array[String] = []


## A condition: {"flags": {name: bool}, "min": {stat: n}, "max": {stat: n}}.
## A flag that was never set counts as false. An empty condition is always true.
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
	return true


## Effects: {"set": {flag: value}, "add": {stat: n}, "rel": {who: n},
## "start": thread, "end": thread}.
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
	if fx.has("start") and not threads.has(fx["start"]):
		threads.append(fx["start"])
	if fx.has("end"):
		threads.erase(fx["end"])


func add(stat: String, n: float) -> void:
	match stat:
		"bankroll":
			bankroll = maxi(0, bankroll + int(n))
		"debt":
			debt = maxi(0, debt + int(n))
		"heat":
			heat = clampf(heat + n, 0.0, MAX_HEAT)
		_:
			push_error("Unknown stat: " + stat)


func cool(delta: float) -> void:
	heat = maxf(0.0, heat - delta * COOL_PER_SECOND)
