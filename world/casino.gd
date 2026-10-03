extends Node3D
## The public casino floor: one room, built from primitives and lit with neon.

const B := preload("res://world/build.gd")
const Slot := preload("res://tables/slot_machine.gd")

const W := 24.0
const D := 18.0
const H := 5.0
const HW := W / 2.0
const HD := D / 2.0

var slots: Array[Node3D] = []


func _ready() -> void:
	_environment()
	_shell()
	_lights()
	for x in [-7.5, 7.5]:
		for z in [-4.6, 4.6]:
			_pillar(Vector3(x, 0, z))
	for i in 9:
		_slot(Vector3(-HW + 0.75, 0, -6.0 + i * 1.5), PI / 2)
	for i in 4:
		_slot(Vector3(HW - 0.75, 0, 2.0 + i * 1.5), -PI / 2)
	_bar()
	_vip_door()
	_table_canopy(Vector3(-3.5, 0, 0), B.MAGENTA)
	_table_canopy(Vector3(3.5, 0, 0), B.CYAN)
	_pit()
	_exit()
	_camera_dome(Vector3(4.7, H, -1.3))


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.07, 0.18)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssr_enabled = true
	env.ssao_enabled = true
	env.sdfgi_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.9, 0.85, 1.0)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var probe := ReflectionProbe.new()
	probe.size = Vector3(W, H, D)
	probe.position = Vector3(0, H / 2.0, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


func _noise_mat(base: StandardMaterial3D, kind: int, freq: float, colors: Array, scale: float) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.noise_type = kind
	noise.frequency = freq
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array(range(colors.size()).map(func(i): return i / float(colors.size() - 1)))
	ramp.colors = PackedColorArray(colors)
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = ramp
	tex.seamless = true
	base.albedo_color = Color.WHITE
	base.albedo_texture = tex
	base.uv1_triplanar = true
	base.uv1_scale = Vector3.ONE * scale
	return base


func _shell() -> void:
	var marble := _noise_mat(B.mat(Color.WHITE, 0.12), FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012,
		[Color(0.015, 0.015, 0.025), Color(0.03, 0.03, 0.05), Color(0.16, 0.14, 0.2), Color(0.03, 0.03, 0.05), Color(0.015, 0.015, 0.025)], 0.25)
	B.box(self, Vector3(W, 0.2, D), Vector3(0, -0.1, 0), marble, true)

	var carpet := _noise_mat(B.mat(Color.WHITE, 0.95), FastNoiseLite.TYPE_CELLULAR, 0.03,
		[Color(0.1, 0.02, 0.14), Color(0.3, 0.03, 0.12), Color(0.5, 0.32, 0.1), Color(0.3, 0.03, 0.12), Color(0.1, 0.02, 0.14)], 0.5)
	B.box(self, Vector3(13, 0.02, 7.5), Vector3(0, 0.01, 0.3), carpet)

	var wall := B.mat(Color(0.09, 0.05, 0.12), 0.65)
	var wood := B.wood()
	var brass := B.brass()
	B.box(self, Vector3(W, 0.2, D), Vector3(0, H + 0.1, 0), B.mat(Color(0.03, 0.02, 0.05), 0.8))
	for s in [-1.0, 1.0]:
		# Back and front walls.
		B.box(self, Vector3(W, H, 0.3), Vector3(0, H / 2.0, s * (HD + 0.15)), wall, true)
		B.box(self, Vector3(W, 1.1, 0.06), Vector3(0, 0.55, s * (HD - 0.03)), wood)
		B.box(self, Vector3(W, 0.04, 0.09), Vector3(0, 1.12, s * (HD - 0.045)), brass)
		B.box(self, Vector3(W - 0.4, 0.06, 0.06), Vector3(0, 4.7, s * (HD - 0.06)), B.neon(B.MAGENTA))
		for x in range(-10, 11, 4):
			B.box(self, Vector3(0.07, 3.2, 0.07), Vector3(x, 3.0, s * (HD - 0.05)), B.neon(B.CYAN if x % 8 == 0 else B.MAGENTA))
		# Side walls.
		B.box(self, Vector3(0.3, H, D), Vector3(s * (HW + 0.15), H / 2.0, 0), wall, true)
		B.box(self, Vector3(0.06, 1.1, D), Vector3(s * (HW - 0.03), 0.55, 0), wood)
		B.box(self, Vector3(0.09, 0.04, D), Vector3(s * (HW - 0.045), 1.12, 0), brass)
		B.box(self, Vector3(0.06, 0.06, D - 0.4), Vector3(s * (HW - 0.06), 4.7, 0), B.neon(B.CYAN))
		for z in [-7, -3.5, 0, 3.5, 7]:
			B.box(self, Vector3(0.07, 3.2, 0.07), Vector3(s * (HW - 0.05), 3.0, z), B.neon(B.MAGENTA if z == 0 else B.CYAN))


func _lights() -> void:
	B.light(self, Vector3(-9, 3.6, -6), B.MAGENTA, 2.5, 10)
	B.light(self, Vector3(9, 3.6, -6), B.CYAN, 2.5, 10)
	B.light(self, Vector3(-9, 3.6, 6), B.CYAN, 2.5, 10)
	B.light(self, Vector3(9, 3.6, 6), B.MAGENTA, 2.5, 10)
	B.light(self, Vector3(0, 4.0, 6), B.MAGENTA, 2.0, 9)
	B.light(self, Vector3(-9.5, 1.6, 0), Color(0.6, 0.3, 1.0), 2.0, 6)


func _spot(pos: Vector3, energy: float, angle := 42.0) -> void:
	var l := SpotLight3D.new()
	l.position = pos
	l.rotation.x = -PI / 2
	l.light_color = Color(1.0, 0.82, 0.6)
	l.light_energy = energy
	l.spot_range = 6.5
	l.spot_angle = angle
	l.shadow_enabled = true
	add_child(l)


func _pillar(pos: Vector3) -> void:
	B.cyl(self, 0.35, H, pos + Vector3(0, H / 2.0, 0), B.mat(Color(0.04, 0.03, 0.06), 0.2), true)
	B.cyl(self, 0.45, 0.3, pos + Vector3(0, 0.15, 0), B.brass())
	B.cyl(self, 0.45, 0.2, pos + Vector3(0, H - 0.1, 0), B.brass())
	B.ring(self, 0.44, 0.05, pos + Vector3(0, 3.1, 0), B.neon(B.CYAN, 4.0))
	B.ring(self, 0.44, 0.05, pos + Vector3(0, 3.5, 0), B.neon(B.MAGENTA, 4.0))


## Machines near the exit doors are loose: people walking in should see winners.
func _slot(pos: Vector3, yaw: float) -> void:
	var s := Slot.new()
	s.position = pos
	s.rotation.y = yaw
	s.loose = pos.z >= 3.0
	add_child(s)
	slots.append(s)


func _bar() -> void:
	var x := -6.0
	B.box(self, Vector3(6, 1.1, 0.7), Vector3(x, 0.55, -7.6), B.wood(), true)
	B.box(self, Vector3(6.2, 0.05, 0.85), Vector3(x, 1.125, -7.6), B.mat(Color(0.02, 0.02, 0.03), 0.1))
	B.box(self, Vector3(6, 0.04, 0.04), Vector3(x, 0.1, -7.23), B.neon(B.AMBER, 3.0))
	B.box(self, Vector3(5.6, 1.4, 0.04), Vector3(x, 1.95, -8.9), B.neon(B.AMBER, 1.1))
	for y in [1.45, 2.0]:
		B.box(self, Vector3(5.6, 0.05, 0.28), Vector3(x, y, -8.75), B.wood())
		for i in 22:
			var h := randf_range(0.2, 0.32)
			B.cyl(self, 0.04, h, Vector3(x - 2.6 + i * 0.247, y + 0.025 + h / 2.0, -8.75),
				B.mat(Color.from_hsv(randf(), 0.6, 0.25), 0.1))
	for i in 4:
		B.cyl(self, 0.17, 0.07, Vector3(x - 2.1 + i * 1.4, 0.72, -6.8), B.mat(Color(0.35, 0.03, 0.08), 0.5))
		B.cyl(self, 0.03, 0.7, Vector3(x - 2.1 + i * 1.4, 0.35, -6.8), B.brass())
	B.light(self, Vector3(x, 2.7, -7.4), B.AMBER, 2.0, 6)


func _vip_door() -> void:
	var z := -3.0
	var x := HW - 0.06
	var door := B.mat(Color(0.07, 0.035, 0.03), 0.35)
	for s in [-1.0, 1.0]:
		B.box(self, Vector3(0.1, 2.6, 1.0), Vector3(x, 1.3, z + s * 0.51), door)
		B.box(self, Vector3(0.05, 0.4, 0.05), Vector3(x - 0.07, 1.2, z + s * 0.1), B.brass())
		B.box(self, Vector3(0.16, 2.7, 0.14), Vector3(x, 1.35, z + s * 1.09), B.brass())
		B.cyl(self, 0.07, 0.5, Vector3(x - 0.05, 2.0, z + s * 1.6), B.neon(B.AMBER, 4.0))
		B.light(self, Vector3(x - 0.5, 2.0, z + s * 1.6), B.AMBER, 1.5, 4)
		B.cyl(self, 0.035, 0.95, Vector3(x - 1.4, 0.475, z + s * 1.2), B.brass(), true)
	B.box(self, Vector3(0.16, 0.14, 2.32), Vector3(x, 2.72, z), B.brass())
	B.box(self, Vector3(0.03, 0.03, 2.4), Vector3(x - 1.4, 0.86, z), B.mat(Color(0.45, 0.02, 0.06), 0.8))
	B.text(self, "VIP", 0.45, Vector3(x, 3.2, z), B.neon(B.AMBER, 4.0)).rotation.y = -PI / 2


func _table_canopy(pos: Vector3, color: Color) -> void:
	B.ring(self, 1.65, 0.1, pos + Vector3(0, 4.4, 0), B.neon(color, 4.0))
	B.cyl(self, 0.45, 0.3, pos + Vector3(0, 4.1, 0), B.neon(B.AMBER, 1.5))
	B.cyl(self, 0.5, 0.06, pos + Vector3(0, 4.28, 0), B.brass())
	B.cyl(self, 0.02, 0.7, pos + Vector3(0, 4.65, 0), B.brass())
	_spot(pos + Vector3(0, 3.9, 0), 3.5)


## The pit boss's corner at the back, under the big ring and the casino sign.
func _pit() -> void:
	B.ring(self, 2.7, 0.12, Vector3(0, 4.6, -5.2), B.neon(B.CYAN, 4.0))
	_spot(Vector3(0.6, 4.4, -4.9), 10.0, 50.0)
	B.text(self, "THE GILDED PALM", 0.7, Vector3(5.2, 3.3, -HD + 0.08), B.neon(B.MAGENTA, 4.0))
	B.light(self, Vector3(5.2, 3.3, -HD + 1.2), B.MAGENTA, 2.0, 7)


func _exit() -> void:
	var door := B.mat(Color(0.05, 0.04, 0.06), 0.3)
	for s in [-1.0, 1.0]:
		B.box(self, Vector3(1.0, 2.6, 0.1), Vector3(s * 0.51, 1.3, HD - 0.06), door)
	B.text(self, "EXIT", 0.3, Vector3(0, 2.95, HD - 0.08), B.neon(Color(0.2, 1.0, 0.4), 3.0)).rotation.y = PI


func _camera_dome(pos: Vector3) -> void:
	B.cyl(self, 0.16, 0.06, pos + Vector3(0, -0.03, 0), B.mat(Color(0.8, 0.8, 0.82), 0.4))
	B.sphere(self, 0.14, pos + Vector3(0, -0.08, 0), B.mat(Color(0.02, 0.02, 0.02), 0.05))
	var led := B.neon(Color(1, 0.05, 0.05), 6.0)
	B.sphere(self, 0.022, pos + Vector3(0.06, -0.2, 0.06), led)
	var tw := create_tween().set_loops()
	tw.tween_property(led, "emission_energy_multiplier", 0.2, 0.1).set_delay(1.0)
	tw.tween_property(led, "emission_energy_multiplier", 6.0, 0.1).set_delay(0.3)
