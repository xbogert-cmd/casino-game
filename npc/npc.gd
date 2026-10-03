extends Node3D
## A stylized person built from primitives, facing +Z. Their head follows the player
## when close. `who` links them to story dialogue; leave it empty for background people.

const B := preload("res://world/build.gd")

var who := ""
var display := ""
var look: Dictionary = {}

var _head := Node3D.new()
var _torso: Node3D
var _t := randf() * 10.0


## look: skin, shirt, pants, hair (Colors), and optional vest (Color), tie (Color),
## bowtie, glasses, beard, bun, bald (bools).
func _ready() -> void:
	var skin := B.mat(look.get("skin", Color(0.8, 0.6, 0.48)), 0.6)
	var shirt := B.mat(look.get("shirt", Color(0.85, 0.85, 0.85)), 0.8)
	var pants := B.mat(look.get("pants", Color(0.06, 0.06, 0.08)), 0.8)
	var hair := B.mat(look.get("hair", Color(0.08, 0.06, 0.05)), 0.5)
	var dark := B.mat(Color(0.03, 0.03, 0.03), 0.3)

	for s in [-1.0, 1.0]:
		B.capsule(self, 0.085, 0.86, Vector3(s * 0.1, 0.45, 0), pants)
		B.box(self, Vector3(0.12, 0.07, 0.27), Vector3(s * 0.1, 0.035, 0.05), dark)
		var arm := B.capsule(self, 0.065, 0.62, Vector3(s * 0.285, 1.13, 0), shirt)
		arm.rotation.z = s * 0.1
		B.sphere(self, 0.07, Vector3(s * 0.315, 0.8, 0), skin)

	_torso = B.capsule(self, 0.2, 0.7, Vector3(0, 1.15, 0), shirt)
	_torso.scale.z = 0.72
	if look.has("vest"):
		var vest := B.capsule(self, 0.21, 0.6, Vector3(0, 1.12, 0), B.mat(look["vest"], 0.5, 0.2))
		vest.scale.z = 0.74
	if look.has("tie"):
		B.box(self, Vector3(0.05, 0.34, 0.02), Vector3(0, 1.27, 0.15), B.mat(look["tie"], 0.6))
	if look.get("bowtie", false):
		for s in [-1.0, 1.0]:
			B.box(self, Vector3(0.07, 0.05, 0.02), Vector3(s * 0.04, 1.47, 0.13), dark)
	B.cyl(self, 0.06, 0.12, Vector3(0, 1.53, 0), skin)

	_head.position.y = 1.6
	add_child(_head)
	B.sphere(_head, 0.17, Vector3(0, 0.12, 0), skin).scale = Vector3(1, 1.12, 1.05)
	for s in [-1.0, 1.0]:
		B.sphere(_head, 0.032, Vector3(s * 0.065, 0.15, 0.148), B.mat(Color(0.95, 0.95, 0.95), 0.3))
		B.sphere(_head, 0.017, Vector3(s * 0.065, 0.15, 0.175), dark)
		B.box(_head, Vector3(0.07, 0.014, 0.02), Vector3(s * 0.065, 0.2, 0.16), hair).rotation.z = s * -0.15
	B.sphere(_head, 0.026, Vector3(0, 0.1, 0.18), skin)
	B.box(_head, Vector3(0.07, 0.012, 0.02), Vector3(0, 0.035, 0.158), B.mat(Color(0.3, 0.1, 0.1), 0.6))
	if not look.get("bald", false):
		B.sphere(_head, 0.18, Vector3(0, 0.17, -0.04), hair).scale = Vector3(1.04, 0.95, 1.02)
	if look.get("bun", false):
		B.sphere(_head, 0.085, Vector3(0, 0.32, -0.08), hair)
	if look.get("beard", false):
		B.sphere(_head, 0.13, Vector3(0, 0.02, 0.06), hair).scale = Vector3(1.05, 0.7, 0.9)
	if look.get("glasses", false):
		B.box(_head, Vector3(0.29, 0.055, 0.03), Vector3(0, 0.15, 0.165), dark)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	B.body(self, shape, Vector3(0, 0.9, 0)).set_meta("target", self)


func _process(delta: float) -> void:
	_t += delta
	_torso.scale.x = 1.0 + sin(_t * 1.6) * 0.012
	var yaw := 0.0
	var cam := get_viewport().get_camera_3d()
	if cam and global_position.distance_to(cam.global_position) < 5.0:
		var local := to_local(cam.global_position)
		yaw = clampf(atan2(local.x, local.z), -1.2, 1.2)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, delta * 4.0)


func prompt() -> String:
	return "Talk to " + display if who != "" else ""


func interact() -> void:
	Game.talk.emit(who)
