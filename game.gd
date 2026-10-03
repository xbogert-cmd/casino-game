extends Node
## Autoload. Holds the story state shared by every scene, and plays sound effects.

signal talk(who: String)
signal toast(text: String, color: Color)
signal caught
signal shift_over(text: String)

const StoryState := preload("res://logic/story_state.gd")
const Story := preload("res://logic/story.gd")
const Night := preload("res://logic/night.gd")

const SAVE := "user://save.json"

const RATE := 22050

var state := StoryState.new()
var story := Story.new()
var rng := RandomNumberGenerator.new()

## Screenshot runs start fresh and never touch the save file.
var no_save: bool = Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--shot"))

var _sounds := {}


func _ready() -> void:
	rng.randomize()
	story.load_dir("res://data/threads")
	_fresh_state()
	if not no_save and FileAccess.file_exists(SAVE):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if data is Dictionary:
			state.from_dict(data)
	_input_map()
	_make_sounds()
	var amb := AudioStreamPlayer.new()
	amb.stream = _sounds["room"]
	amb.volume_db = -16
	add_child(amb)
	amb.play()


func _process(delta: float) -> void:
	state.cool(delta)


## Full heat means security takes you aside. A consequence, not a game over.
func check_caught() -> bool:
	if state.heat < StoryState.MAX_HEAT:
		return false
	state.bankroll /= 2
	state.debt += 1000
	state.heat = 40.0
	state.flags["caught"] = true
	sfx("lose")
	caught.emit()
	return true


func _fresh_state() -> void:
	state = StoryState.new()
	state.threads.assign(["opening", "floor"])
	state.plan = {"customer": "teddy", "order": "lose", "event": "quiet", "job": {}}


func save() -> void:
	if not no_save:
		FileAccess.open(SAVE, FileAccess.WRITE).store_string(JSON.stringify(state.to_dict()))


func new_game() -> void:
	_fresh_state()
	save()
	get_tree().reload_current_scene.call_deferred()


## Tonight's customer at your table.
func customer() -> Dictionary:
	return Night.customer(state.plan)


## How much stacking the shoe costs tonight, as a multiplier.
func heat_mult() -> float:
	return Night.EVENTS[state.plan["event"]]["heat"]


## Called when your dealing shift ends. Night one is judged by the opening story;
## later nights are judged against Halloran's order.
func finish_shift(was_caught: bool) -> void:
	var t: Dictionary = state.tonight
	t["shift"] = "done"
	var job: Dictionary = state.plan.get("job", {})
	if state.night == 1:
		state.flags["shift_done"] = true
		state.flags["customer_lost"] = t["stack"] <= 200
		state.flags["customer_won"] = t["stack"] >= 800
		state.flags["caught_dealing"] = was_caught
	elif was_caught:
		state.apply({"rel": {"manager": -1}})
		state.apply(job.get("failure", {}))
	else:
		var r := Night.settle(state.plan, int(t["start"]), int(t["stack"]), int(t["stacked"]))
		state.apply(r["effects"])
		state.apply(job.get("success" if r["ok"] else "failure", {}))
		shift_over.emit(r["text"])


## Goes home: the next night is planned and saved.
func end_night() -> void:
	if state.night > 1 and state.tonight.get("shift", "pending") == "pending":
		state.apply({"rel": {"manager": -1}})  # you skipped your shift
	Night.end_night(state, rng)
	state.plan = Night.plan(state, story, rng)
	story.send_texts(state)
	save()
	get_tree().reload_current_scene.call_deferred()


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + "$" + s + out


func sfx(sound: String, pitch := 1.0, at = null) -> void:
	var p: Node = AudioStreamPlayer3D.new() if at is Vector3 else AudioStreamPlayer.new()
	p.stream = _sounds[sound]
	p.pitch_scale = pitch
	add_child(p)
	if at is Vector3:
		p.global_position = at
		p.unit_size = 4.0
	p.finished.connect(p.queue_free)
	p.play()


func _input_map() -> void:
	var keys := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "interact": KEY_E}
	for action in keys:
		InputMap.add_action(action)
		var e := InputEventKey.new()
		e.physical_keycode = keys[action]
		InputMap.action_add_event(action, e)


func _make_sounds() -> void:
	_sounds["card"] = _synth([0.0], 0.07, 55.0, 1.0)
	_sounds["chip"] = _synth([2600.0, 3400.0], 0.05, 45.0)
	_sounds["click"] = _synth([1200.0], 0.03, 90.0)
	_sounds["win"] = _synth([660.0, 880.0, 1320.0], 0.11, 12.0)
	_sounds["blackjack"] = _synth([660.0, 880.0, 1100.0, 1320.0, 1760.0], 0.09, 10.0)
	_sounds["lose"] = _synth([220.0, 165.0], 0.2, 9.0)
	_sounds["heat"] = _synth([98.0], 0.4, 7.0, 0.15)
	_sounds["slot"] = _synth([1047.0, 1319.0, 1568.0], 0.07, 18.0)
	_sounds["room"] = _room_tone()


## A run of decaying notes. A frequency of 0 with noise gives a soft burst.
func _synth(freqs: Array, note_len: float, decay: float, noise := 0.0) -> AudioStreamWAV:
	var per := int(note_len * RATE)
	var data := PackedByteArray()
	data.resize(per * freqs.size() * 2)
	for n in freqs.size():
		for i in per:
			var t := float(i) / RATE
			var v := sin(TAU * freqs[n] * t) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
			data.encode_s16((n * per + i) * 2, int(v * exp(-t * decay) * 12000.0))
	return _wav(data)


## Low rumble for the room, blended at the ends so the loop does not click.
func _room_tone() -> AudioStreamWAV:
	var count := RATE * 4
	var samples := PackedFloat32Array()
	samples.resize(count)
	var v := 0.0
	for i in count:
		v = clampf(v * 0.995 + randf_range(-1.0, 1.0) * 0.03, -1.0, 1.0)
		samples[i] = v
	var blend := 4000
	for i in blend:
		var k := float(i) / blend
		samples[count - blend + i] = lerpf(samples[count - blend + i], samples[0], k)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(samples[i] * 9000.0))
	var wav := _wav(data)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
