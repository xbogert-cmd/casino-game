extends RefCounted
## Helpers for building the world out of primitives.

const MAGENTA := Color(1.0, 0.1, 0.65)
const CYAN := Color(0.1, 0.8, 1.0)
const AMBER := Color(1.0, 0.62, 0.25)


static func mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func neon(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func brass() -> StandardMaterial3D:
	return mat(Color(0.83, 0.62, 0.28), 0.3, 1.0)


static func wood() -> StandardMaterial3D:
	return mat(Color(0.11, 0.055, 0.035), 0.4)


static func mesh(parent: Node, m: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	if solid:
		var s := BoxShape3D.new()
		s.size = size
		body(parent, s, pos)
	return mesh(parent, m, pos, material)


static func cyl(parent: Node, radius: float, height: float, pos: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	if solid:
		var s := CylinderShape3D.new()
		s.radius = radius
		s.height = height
		body(parent, s, pos)
	return mesh(parent, m, pos, material)


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return mesh(parent, m, pos, material)


static func capsule(parent: Node, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return mesh(parent, m, pos, material)


static func ring(parent: Node, radius: float, thickness: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = radius - thickness
	m.outer_radius = radius
	return mesh(parent, m, pos, material)


static func text(parent: Node, s: String, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := TextMesh.new()
	m.text = s
	m.font_size = 64
	m.pixel_size = height / 64.0
	m.depth = 0.04
	return mesh(parent, m, pos, material)


static func body(parent: Node, shape: Shape3D, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	c.shape = shape
	b.add_child(c)
	b.position = pos
	parent.add_child(b)
	return b


static func light(parent: Node, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	parent.add_child(l)
	return l
