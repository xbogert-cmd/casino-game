extends CharacterBody3D
## First-person walker. `locked` stops movement and looking while a UI is open.

const EYE := 1.68
const LOOK := 0.0022

var cam := Camera3D.new()
var locked := false

var _ray := RayCast3D.new()
var _pitch := 0.0
var _bob := 0.0
var _tween: Tween


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	cam.position.y = EYE
	cam.fov = 72
	cam.near = 0.05
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 11.0
	attrs.dof_blur_far_transition = 8.0
	attrs.dof_blur_amount = 0.03
	cam.attributes = attrs
	add_child(cam)
	cam.make_current()

	_ray.target_position = Vector3(0, 0, -2.8)
	_ray.add_exception(self)
	cam.add_child(_ray)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and not locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-e.relative.x * LOOK)
		_pitch = clampf(_pitch - e.relative.y * LOOK, -1.4, 1.4)
		cam.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if not locked:
		var i := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(i.x, 0, i.y)).normalized()
	var speed := 5.0 if Input.is_key_pressed(KEY_SHIFT) else 3.0
	velocity.x = move_toward(velocity.x, dir.x * speed, delta * 30.0)
	velocity.z = move_toward(velocity.z, dir.z * speed, delta * 30.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	if not locked and dir != Vector3.ZERO:
		_bob += delta * speed * 2.4
		cam.position.y = EYE + sin(_bob) * 0.025


## The thing the player is looking at, if it can be interacted with.
func target() -> Object:
	if _ray.is_colliding():
		var c := _ray.get_collider()
		if c and c.has_meta("target"):
			return c.get_meta("target")
	return null


## Turns the body and eyes toward a world point.
func face(point: Vector3) -> void:
	var d := (point - (global_position + Vector3(0, EYE, 0))).normalized()
	rotation.y = atan2(-d.x, -d.z)
	_pitch = asin(d.y)
	cam.rotation.x = _pitch


## Moves the camera to a fixed view, such as a seat at a table.
func sit(view: Transform3D) -> void:
	var g := cam.global_transform
	cam.top_level = true
	cam.global_transform = g
	_move_cam("global_transform", view)


func stand() -> void:
	var g := cam.global_transform
	cam.top_level = false
	cam.global_transform = g
	_move_cam("transform", Transform3D(Basis.from_euler(Vector3(_pitch, 0, 0)), Vector3(0, EYE, 0)))


func _move_cam(property: String, to: Transform3D) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(cam, property, to, 0.6)
