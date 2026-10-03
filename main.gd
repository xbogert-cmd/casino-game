extends Node3D
## Puts the casino together for one night: room, people, tables, player and UI.
## Going home reloads this scene for the next night; the story lives in Game.state.

const B := preload("res://world/build.gd")
const Casino := preload("res://world/casino.gd")
const Player := preload("res://player/player.gd")
const Npc := preload("res://npc/npc.gd")
const Prop := preload("res://world/prop.gd")
const Table := preload("res://tables/blackjack_table.gd")
const Hud := preload("res://ui/hud.gd")
const Dialogue := preload("res://ui/dialogue.gd")
const Phone := preload("res://ui/phone.gd")
const Night := preload("res://logic/night.gd")

const SUIT := Color(0.13, 0.13, 0.17)
const WHITE_SHIRT := Color(0.9, 0.88, 0.85)
const CUSTOMER_LOOKS := {
	"teddy": {"skin": Color(0.85, 0.68, 0.58), "shirt": Color(0.42, 0.43, 0.46), "pants": Color(0.12, 0.12, 0.16), "hair": Color(0.3, 0.2, 0.12)},
	"marge": {"skin": Color(0.88, 0.72, 0.64), "shirt": Color(0.55, 0.3, 0.55), "hair": Color(0.8, 0.8, 0.82), "bun": true},
	"dmitri": {"skin": Color(0.8, 0.62, 0.5), "shirt": Color(0.6, 0.1, 0.1), "hair": Color(0.05, 0.05, 0.05), "beard": true},
	"paul": {"skin": Color(0.62, 0.45, 0.33), "shirt": Color(0.2, 0.3, 0.45), "hair": Color(0.04, 0.04, 0.04), "glasses": true},
	"kenji": {"skin": Color(0.86, 0.7, 0.55), "shirt": Color(0.85, 0.75, 0.3), "hair": Color(0.03, 0.03, 0.03)},
	"friend": {"skin": Color(0.75, 0.58, 0.46), "shirt": Color(0.75, 0.72, 0.65), "pants": Color(0.75, 0.72, 0.65), "hair": Color(0.2, 0.2, 0.22), "tie": Color(0.6, 0.45, 0.1)},
}

var casino := Casino.new()
var player := Player.new()
var hud := Hud.new()
var dialogue := Dialogue.new()
var phone := Phone.new()
var table_one := Table.new()
var table_two := Table.new()
var people := {}

var _seated := false
var _shot := false
var _chime := 1.0
var _flicker := 3.0
var _lights: Array[Node] = []


func _ready() -> void:
	add_child(casino)
	player.position = Vector3(0, 0.05, 6.5)
	add_child(player)
	add_child(hud)
	add_child(dialogue)
	add_child(phone)
	_tables()
	_people()
	_props()
	_lights = find_children("", "Light3D", true, false)

	Game.talk.connect(_talk)
	Game.toast.connect(hud.toast)
	Game.caught.connect(_on_caught)
	Game.shift_over.connect(func(text): hud.show_overlay("SHIFT OVER\n\n" + text))
	dialogue.closed.connect(_refresh)
	phone.closed.connect(_refresh)
	hud.overlay_closed.connect(_refresh)
	_night_card()
	_refresh()
	_shot_mode()


func _tables() -> void:
	table_one.position = Vector3(-3.5, 0, 0)
	table_two.position = Vector3(3.5, 0, 0)
	table_two.dealer_mode = true
	table_two.accent = B.CYAN
	add_child(table_one)
	add_child(table_two)
	var seats: Array = [table_one, table_two]
	seats.append_array(casino.slots)
	for t in seats:
		t.player = player
		t.sat.connect(func(): _seated = true; _refresh())
		t.left.connect(func(): _seated = false; _refresh())


func _person(who: String, display: String, pos: Vector3, yaw: float, look: Dictionary) -> void:
	var n := Npc.new()
	n.who = who
	n.display = display
	n.look = look
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	if who != "":
		people[who] = n


func _people() -> void:
	_person("manager", "Mr. Halloran", Vector3(0.2, 0, -5.2), 0.0,
		{"skin": Color(0.78, 0.6, 0.5), "shirt": SUIT, "pants": SUIT, "hair": Color(0.55, 0.55, 0.57), "tie": Color(0.5, 0.03, 0.08)})
	_person("dealer", "Mara", Vector3(-3.5, 0, -1.15), 0.0,
		{"skin": Color(0.82, 0.62, 0.5), "shirt": WHITE_SHIRT, "vest": Color(0.1, 0.08, 0.05), "bowtie": true, "bun": true})
	_person("guard", "security", Vector3(10.1, 0, -3.0), -PI / 2,
		{"skin": Color(0.72, 0.55, 0.45), "shirt": SUIT, "pants": SUIT, "tie": Color(0.02, 0.02, 0.02), "bald": true, "beard": true, "glasses": true})
	_person("bartender", "the bartender", Vector3(-5.0, 0, -8.3), 0.0,
		{"skin": Color(0.5, 0.36, 0.28), "shirt": WHITE_SHIRT, "vest": Color(0.3, 0.03, 0.08), "hair": Color(0.03, 0.03, 0.03)})
	_person("regular", "the regular", Vector3(-10.25, 0, -4.5), -PI / 2,
		{"skin": Color(0.7, 0.55, 0.45), "shirt": Color(0.35, 0.4, 0.3), "hair": Color(0.75, 0.75, 0.75)})
	# People at the slots, for life.
	for spot in [Vector3(-10.25, 0, 0), Vector3(-10.25, 0, 1.5)]:
		_person("", "", spot, -PI / 2,
			{"skin": Color.from_hsv(0.07, 0.4, randf_range(0.45, 0.9)), "shirt": Color.from_hsv(randf(), 0.5, 0.5), "hair": Color.from_hsv(0.08, 0.5, randf_range(0.05, 0.5))})
	_person("", "", Vector3(10.25, 0, 2.0), PI / 2, {"shirt": Color(0.5, 0.05, 0.1), "hair": Color(0.6, 0.45, 0.2)})

	# Tonight's customer waits at table two unless the shift is already over.
	if Game.state.tonight.get("shift", "pending") == "pending":
		var id: String = Game.state.plan["customer"]
		_person("customer", Night.CUSTOMERS[id]["name"], Vector3(3.5, 0, 1.2), PI, CUSTOMER_LOOKS[id])
	if Game.state.threads.has("inspector"):
		_person("ines", "the woman at the bar", Vector3(-3.6, 0, -6.6), PI * 0.75,
			{"skin": Color(0.84, 0.68, 0.55), "shirt": Color(0.15, 0.2, 0.3), "pants": Color(0.1, 0.1, 0.14), "hair": Color(0.05, 0.04, 0.04)})


func _prop(who: String, label: String, pos: Vector3, size: Vector3) -> Prop:
	var p := Prop.new()
	p.who = who
	p.label = label
	p.position = pos
	add_child(p)
	var shape := BoxShape3D.new()
	shape.size = size
	B.body(p, shape, Vector3(0, size.y / 2.0, 0)).set_meta("target", p)
	return p


func _props() -> void:
	var stand := _prop("ledger", "Look at the ledger", Vector3(1.6, 0, -5.5), Vector3(0.66, 1.2, 0.5))
	B.box(stand, Vector3(0.6, 1.1, 0.45), Vector3(0, 0.55, 0), B.wood())
	B.box(stand, Vector3(0.66, 0.04, 0.5), Vector3(0, 1.12, 0), B.brass())
	B.box(stand, Vector3(0.32, 0.04, 0.24), Vector3(0, 1.16, 0), B.mat(Color(0.35, 0.04, 0.06), 0.6))
	_prop("", "Go home", Vector3(0, 0, 8.9), Vector3(2.1, 2.6, 0.3)).action = _exit_door


func _process(delta: float) -> void:
	var prompt := ""
	if not player.locked:
		Game.check_caught()
		var t := player.target()
		if t and t.prompt() != "":
			prompt = "[E]  " + t.prompt()
	hud.update(Game.state, _objective(), prompt)

	# Slot machines chime now and then.
	_chime -= delta
	if _chime <= 0.0:
		_chime = randf_range(0.5, 2.5)
		Game.sfx("slot", randf_range(0.7, 1.4), casino.slots.pick_random().global_position + Vector3(0, 1.2, 0))

	# On a bad-wiring night the lights cut out for a moment.
	if Game.state.plan["event"] == "flicker":
		_flicker -= delta
		if _flicker <= 0.0:
			var dark: bool = _lights[0].visible
			for l in _lights:
				l.visible = not dark
			_flicker = randf_range(0.08, 0.3) if dark else randf_range(2.0, 7.0)


func _objective() -> String:
	var o: String = Game.story.objective(Game.state)
	if o != "":
		return o
	var t: Dictionary = Game.state.tonight
	if t.get("shift", "pending") != "pending":
		return "Your shift is done. Play, look around, or leave by the exit doors."
	if not t.get("briefed", false):
		return "Report to Halloran for tonight's table."
	return "Table two. " + Night.briefing(Game.state.plan)


func _unhandled_input(e: InputEvent) -> void:
	if _shot:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_TAB:
		if phone.is_open:
			phone.close()
		elif not player.locked:
			phone.open()
			_refresh()
		return
	if player.locked:
		return
	if e.is_action_pressed("interact"):
		var t := player.target()
		if t and t.prompt() != "":
			t.interact()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		_say("", "Paused.", [
			{"text": "Back to the floor."},
			{"text": "Start a new game. This erases your save.", "action": Game.new_game},
			{"text": "Quit.", "action": get_tree().quit},
		])


func _say(speaker: String, text: String, options: Array = []) -> void:
	dialogue.say(speaker, text, options)
	_refresh()


func _talk(who: String) -> void:
	var e: Dictionary = Game.story.entry(who, Game.state)
	if not e.is_empty():
		dialogue.open(e["thread"], e["node"])
		_refresh()
	elif who == "manager":
		_briefing()
	elif who == "customer":
		var c := Game.customer()
		_say(c["name"], c["blurb"])


## Halloran's instructions for tonight, when no story scene takes over.
func _briefing() -> void:
	var s = Game.state
	var options := []
	var text := "You're done for tonight. Go home, or go lose your wage like everyone else."
	if s.tonight.get("shift", "pending") == "pending":
		s.tonight["briefed"] = true
		text = "Table two. Tonight it's %s. %s" % [Game.customer()["name"], Night.briefing(s.plan)]
		options.append({"text": "Understood."})
	if s.threads.has("inspector") and s.flags.get("insp_met", false):
		if options.is_empty():
			options.append({"text": "Good night."})
		options.append({"text": "There's an investigator at the bar, asking about you.",
			"action": func(): dialogue.open("inspector", "x_sold"); _refresh()})
	_say("Mr. Halloran", text, options)


func _exit_door() -> void:
	var s = Game.state
	if s.night == 1 and not s.flags.get("opening_done", false):
		_say("", "You can't walk out on Halloran on your first night.")
		return
	var text := "Go home and end the night?"
	if s.night > 1 and s.tonight.get("shift", "pending") == "pending":
		text += " You haven't worked your shift. No wage, and Halloran will remember."
	_say("", text, [{"text": "Go home.", "action": Game.end_night}, {"text": "Stay."}])


func _on_caught() -> void:
	hud.show_overlay("CAUGHT\n\nA hand on your shoulder. Security walks you to the back room and explains, slowly, what happens to dealers who get noticed.\n\nThey take half your money and add $1,000 to your debt. If you were dealing, the shift is over and there is no wage.")
	_refresh()


## Called whenever a UI opens or closes: decides who has control, and reacts to what the story changed.
func _refresh() -> void:
	player.locked = dialogue.is_open or phone.is_open or _seated or hud.overlay_open
	hud.hint.visible = not player.locked
	if not _shot:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.locked else Input.MOUSE_MODE_CAPTURED
	if dialogue.is_open:
		return

	var s = Game.state
	Game.story.send_texts(s)
	# People who have left: a customer who was warned off, Ines if she was sold out.
	if people.has("customer") and s.tonight.get("shift", "pending") == "skipped":
		people["customer"].queue_free()
		people.erase("customer")
	if people.has("ines") and not s.threads.has("inspector"):
		people["ines"].queue_free()
		people.erase("ines")

	if s.flags.get("opening_done", false) and not s.flags.get("night_one_shown", false):
		s.flags["night_one_shown"] = true
		hud.show_overlay(_night_one_summary())
		_refresh()
	if not player.locked:
		Game.save()


func _night_one_summary() -> String:
	var f: Dictionary = Game.state.flags
	var lines := {
		"followed": "You did what Halloran asked. Teddy Briggs went home light.",
		"helped": "You dealt Teddy Briggs a winning night. Halloran saw it.",
		"failed": "Teddy Briggs kept his chips. Halloran is not pleased.",
		"caught": "Security caught you stacking the shoe.",
		"warned": "You warned Teddy Briggs, and he left before a card was dealt.",
	}
	var text: String = "END OF YOUR FIRST SHIFT\n\n" + lines.get(f.get("outcome", ""), "")
	if f.get("has_evidence", false):
		text += "\nYou have photographs of Halloran's ledger."
	text += "\n\nBankroll: %s\nDebt to Sal: %s" % [Game.money(Game.state.bankroll), Game.money(Game.state.debt)]
	text += "\n\nPlay the tables and slots if you like. When you're ready, leave by the exit doors to end the night."
	return text


## Shown once at the start of each night after the first, and for the two endings.
func _night_card() -> void:
	var s = Game.state
	if s.missed >= Night.MAX_MISSED:
		hud.show_overlay("SAL'S PATIENCE RAN OUT\n\nThree missed payments. Lou is waiting by your car, and this time he isn't here for your wallet.\n\nThis run is over. A new game starts when you continue.")
		hud.overlay_closed.connect(Game.new_game, CONNECT_ONE_SHOT)
		return
	if s.night == 1 or s.tonight.get("card", false):
		return
	s.tonight["card"] = true
	if s.debt <= 0 and not s.flags.get("cleared", false):
		s.flags["cleared"] = true
		hud.show_overlay("YOU'RE CLEAR\n\nThe debt is paid. Sal sends one last text: \"We're square. Don't come back.\"\n\nYou could walk out of the Gilded Palm tonight and never deal another card. You can also keep playing.")
	var e: Dictionary = Night.EVENTS[s.plan["event"]]
	var text: String = "NIGHT %d\n\n%s\n%s" % [s.night, e["title"].to_upper(), e["text"]]
	if s.unread > 0:
		text += "\n\nYou have %d new message%s. Press Tab for your phone." % [s.unread, "" if s.unread == 1 else "s"]
	hud.show_overlay(text + "\n\nReport to Halloran for tonight's table.")


## For checking visuals: `godot --path . -- --shot=out.png [--stage=NAME] [--cam=x,y,z,lx,ly,lz]`
## saves a screenshot after the lighting has settled, then quits. It never touches the save.
func _shot_mode() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if not args.has("shot"):
		return
	_shot = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if args.has("cam"):
		var v := Array(args["cam"].split(",")).map(func(x): return float(x))
		player.position = Vector3(v[0], v[1], v[2])
		player.face(Vector3(v[3], v[4], v[5]))
	var s = Game.state
	match args.get("stage", ""):
		"talk":
			_talk("manager")
		"table":
			table_one.interact()
			await get_tree().create_timer(1.0).timeout
			table_one.panel.picked.emit(0)
		"dealer":
			s.flags["mission_given"] = true
			s.tonight["briefed"] = true
			table_two.interact()
			await get_tree().create_timer(1.0).timeout
			table_two.panel.picked.emit(1)
		"slots":
			casino.slots[8].interact()
			await get_tree().create_timer(1.0).timeout
			casino.slots[8]._panel.picked.emit(0)
		"phone":
			Night.end_night(s, Game.rng)
			phone.open()
			_refresh()
		"brief":
			s.flags["opening_done"] = true
			Night.end_night(s, Game.rng)
			s.plan = Night.plan(s, Game.story, Game.rng)
			_talk("manager")
		"reload":  # goes home after night one; the reloaded scene takes the screenshot
			if s.night == 1:
				s.flags["opening_done"] = true
				s.flags["has_evidence"] = true
				Game.end_night()
				return
		"nights":  # plays several nights dealing straight, to check the loop runs
			Engine.time_scale = 10.0
			for n in int(args.get("nights", "4")):
				s.tonight["briefed"] = true
				table_two.interact()
				while _seated:
					await get_tree().create_timer(0.2).timeout
					table_two.panel.picked.emit(0)
				print("night %d: %s, %s, %s. bankroll %d debt %d heat %d rel %s threads %s" % [
					s.night, s.plan["customer"], s.plan["order"], s.plan["event"], s.bankroll, s.debt, s.heat, s.rel, s.threads])
				s.flags["opening_done"] = true
				s.rel["manager"] = 1
				Night.end_night(s, Game.rng)
				s.plan = Night.plan(s, Game.story, Game.rng)
				Game.story.send_texts(s)
			Engine.time_scale = 1.0
			_night_card()
	for i in int(args.get("frames", "200")):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("fps: ", Engine.get_frames_per_second())
	get_tree().quit()
