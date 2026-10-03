extends Node3D
## Puts the casino together: room, people, tables, player and UI.

const B := preload("res://world/build.gd")
const Casino := preload("res://world/casino.gd")
const Player := preload("res://player/player.gd")
const Npc := preload("res://npc/npc.gd")
const Prop := preload("res://world/prop.gd")
const Table := preload("res://tables/blackjack_table.gd")
const Hud := preload("res://ui/hud.gd")
const Dialogue := preload("res://ui/dialogue.gd")

const SUIT := Color(0.13, 0.13, 0.17)

var casino := Casino.new()
var player := Player.new()
var hud := Hud.new()
var dialogue := Dialogue.new()
var table_one := Table.new()
var table_two := Table.new()
var people := {}

var _seated := false
var _night_shown := false
var _shot := false
var _chime := 1.0


func _ready() -> void:
	add_child(casino)
	player.position = Vector3(0, 0.05, 6.5)
	add_child(player)
	add_child(hud)
	add_child(dialogue)
	_tables()
	_people()
	_ledger()

	Game.talk.connect(_talk)
	Game.toast.connect(hud.toast)
	Game.caught.connect(_on_caught)
	dialogue.closed.connect(_refresh)
	hud.overlay_closed.connect(_refresh)
	_refresh()
	_shot_mode()


func _tables() -> void:
	table_one.position = Vector3(-3.5, 0, 0)
	table_two.position = Vector3(3.5, 0, 0)
	table_two.dealer_mode = true
	table_two.accent = B.CYAN
	for t in [table_one, table_two]:
		t.player = player
		t.sat.connect(func(): _seated = true; _refresh())
		t.left.connect(func(): _seated = false; _refresh())
		add_child(t)


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
		{"skin": Color(0.82, 0.62, 0.5), "shirt": Color(0.9, 0.88, 0.85), "vest": Color(0.1, 0.08, 0.05), "bowtie": true, "bun": true})
	_person("customer", "Teddy Briggs", Vector3(3.5, 0, 1.2), PI,
		{"skin": Color(0.85, 0.68, 0.58), "shirt": Color(0.42, 0.43, 0.46), "pants": Color(0.12, 0.12, 0.16), "hair": Color(0.3, 0.2, 0.12)})
	_person("guard", "security", Vector3(10.1, 0, -3.0), -PI / 2,
		{"skin": Color(0.72, 0.55, 0.45), "shirt": SUIT, "pants": SUIT, "tie": Color(0.02, 0.02, 0.02), "bald": true, "beard": true, "glasses": true})
	_person("bartender", "the bartender", Vector3(-5.0, 0, -8.3), 0.0,
		{"skin": Color(0.5, 0.36, 0.28), "shirt": Color(0.9, 0.88, 0.85), "vest": Color(0.3, 0.03, 0.08), "hair": Color(0.03, 0.03, 0.03)})
	# People at the slots, for life.
	for z in [-4.5, 0.0, 3.0]:
		_person("", "", Vector3(-10.25, 0, z), -PI / 2,
			{"skin": Color.from_hsv(0.07, 0.4, randf_range(0.45, 0.9)), "shirt": Color.from_hsv(randf(), 0.5, 0.5), "hair": Color.from_hsv(0.08, 0.5, randf_range(0.05, 0.5))})
	_person("", "", Vector3(10.25, 0, 5.0), PI / 2,
		{"shirt": Color(0.5, 0.05, 0.1), "hair": Color(0.6, 0.45, 0.2)})


func _ledger() -> void:
	var stand := Prop.new()
	stand.who = "ledger"
	stand.label = "Look at the ledger"
	stand.position = Vector3(1.6, 0, -5.5)
	add_child(stand)
	B.box(stand, Vector3(0.6, 1.1, 0.45), Vector3(0, 0.55, 0), B.wood())
	B.box(stand, Vector3(0.66, 0.04, 0.5), Vector3(0, 1.12, 0), B.brass())
	B.box(stand, Vector3(0.32, 0.04, 0.24), Vector3(0, 1.16, 0), B.mat(Color(0.35, 0.04, 0.06), 0.6))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.66, 1.2, 0.5)
	B.body(stand, shape, Vector3(0, 0.6, 0)).set_meta("target", stand)


func _process(delta: float) -> void:
	var prompt := ""
	if not player.locked:
		Game.check_caught()
		var t := player.target()
		if t and t.prompt() != "":
			prompt = "[E]  " + t.prompt()
	hud.update(Game.state, Game.story.objective(Game.state), prompt)

	# Slot machines chime now and then.
	_chime -= delta
	if _chime <= 0.0:
		_chime = randf_range(0.5, 2.5)
		Game.sfx("slot", randf_range(0.7, 1.4), casino.slot_positions.pick_random())


func _unhandled_input(e: InputEvent) -> void:
	if player.locked or _shot:
		return
	if e.is_action_pressed("interact"):
		var t := player.target()
		if t and t.prompt() != "":
			t.interact()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _talk(who: String) -> void:
	var e: Dictionary = Game.story.entry(who, Game.state)
	if not e.is_empty():
		dialogue.open(e["thread"], e["node"])
		_refresh()


func _on_caught() -> void:
	hud.show_overlay("CAUGHT\n\nA hand on your shoulder. Security walks you to the back room and explains, slowly, what happens to dealers who get noticed.\n\nThey take half your money and add $1,000 to your debt. They will be watching you more closely now.")
	_refresh()


## Called whenever a UI opens or closes: decides who has control, and what the story changed.
func _refresh() -> void:
	player.locked = dialogue.is_open or _seated or hud.overlay_open
	hud.hint.visible = not player.locked
	if not _shot:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if player.locked else Input.MOUSE_MODE_CAPTURED

	var f: Dictionary = Game.state.flags
	if people.has("customer") and not dialogue.is_open and f.get("customer_warned", false):
		people["customer"].queue_free()
		people.erase("customer")
	if f.get("opening_done", false) and not _night_shown and not dialogue.is_open:
		_night_shown = true
		hud.show_overlay(_night_summary())
		_refresh()


func _night_summary() -> String:
	var f: Dictionary = Game.state.flags
	var lines := {
		"followed": "You did what Halloran asked. Teddy Briggs went home light.",
		"helped": "You dealt Teddy Briggs a winning night. Halloran saw it.",
		"failed": "Teddy Briggs kept his chips. Halloran is not pleased.",
		"caught": "Security caught you stacking the shoe.",
		"warned": "You warned Teddy Briggs, and he left before a card was dealt.",
	}
	var text: String = "END OF NIGHT ONE\n\n" + lines.get(f.get("outcome", ""), "")
	if f.get("has_evidence", false):
		text += "\nYou have photographs of Halloran's ledger."
	text += "\n\nBankroll: %s\nDebt to Sal: %s" % [Game.money(Game.state.bankroll), Game.money(Game.state.debt)]
	text += "\n\nThis is the end of the first slice. You can keep playing table one."
	return text


## For checking visuals: `godot --path . -- --shot=out.png [--stage=table|dealer|talk|shift|night] [--cam=x,y,z,lx,ly,lz]`
## saves a screenshot after the lighting has settled, then quits.
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
		var v := Array(args["cam"].split(",")).map(func(s): return float(s))
		player.position = Vector3(v[0], v[1], v[2])
		player.face(Vector3(v[3], v[4], v[5]))
	match args.get("stage", ""):
		"talk":
			_talk("manager")
		"table":
			table_one.interact()
			await get_tree().create_timer(1.0).timeout
			table_one.picked.emit(0)
		"dealer":
			Game.state.flags["mission_given"] = true
			table_two.interact()
			await get_tree().create_timer(1.0).timeout
			table_two.picked.emit(1)
		"shift":  # deals a whole straight shift, then reports to the manager
			Game.state.flags["mission_given"] = true
			table_two.interact()
			while _seated:
				await get_tree().create_timer(0.25).timeout
				table_two.picked.emit(0)
			print("flags: ", Game.state.flags, " stack: ", table_two.customer_stack)
			_talk("manager")
		"night":
			Game.state.apply(Game.story.node("opening", "m_good")["effects"])
			_refresh()
	for i in int(args.get("frames", "200")):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("fps: ", Engine.get_frames_per_second())
	get_tree().quit()
