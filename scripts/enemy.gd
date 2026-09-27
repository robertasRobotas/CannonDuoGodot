## An enemy figure: squat body, horns, angry brows, red eyes, a spinning marker overhead.
## Pops when hit hard, or when knocked off its perch (touches the ground or falls a metre).
class_name Enemy
extends RigidBody3D

signal popped(enemy: Enemy)

const COLORS := [Color(0.98, 0.42, 0.40), Color(0.98, 0.78, 0.32), Color(0.74, 0.66, 0.90), Color(0.62, 0.88, 0.80)]

var radius: float = 0.28
var base_position: Vector3
var spawn_time: float = 0.0
var frozen: bool = false
var marker: Node3D
var body_color: Color
var _pending_pop := false
var _level_time_ref: Callable

func setup(r: float, index: int, level_time: Callable) -> void:
    radius = r
    _level_time_ref = level_time
    body_color = COLORS[index % COLORS.size()]
    mass = 4.0
    var shape := CollisionShape3D.new()
    var s := SphereShape3D.new()
    s.radius = r
    shape.shape = s
    add_child(shape)
    var pm := PhysicsMaterial.new()
    pm.friction = 0.7
    pm.bounce = 0.25
    physics_material_override = pm
    angular_damp = 0.5
    contact_monitor = true
    max_contacts_reported = 4
    add_to_group("enemies")
    add_to_group("dynamic")
    body_entered.connect(_on_body_entered)
    _build_visual()

func _build_visual() -> void:
    var skin := Models.flat_material(body_color, 0.6)
    var dark := Models.flat_material(Color(0.16, 0.14, 0.22), 0.7)
    var bone := Models.flat_material(Color(1.0, 0.96, 0.88), 0.5)
    var eye := Models.flat_material(Color(1, 0.95, 0.7), 0.3)
    var pupil := Models.flat_material(Color(0.6, 0.05, 0.05), 0.2)
    var cape := Models.flat_material(Color(0.42, 0.30, 0.52), 0.9)
    var r := radius
    _add(SphereMesh.new(), skin, Vector3.ZERO, Vector3(r * 2, r * 1.84, r * 2))
    _add(_cyl(r * 0.9, r * 0.8), skin, Vector3(0, -r * 0.5, 0))
    _add(_cyl(r * 0.98, r * 0.12), dark, Vector3(0, -r * 0.86, 0))
    var cape_mesh := BoxMesh.new()
    cape_mesh.size = Vector3(r * 1.5, r * 1.4, r * 0.1)
    _add(cape_mesh, cape, Vector3(0, -r * 0.35, -r * 0.85), Vector3.ONE, Vector3(-0.15, 0, 0))
    for side: float in [-1.0, 1.0]:
        _add(_cone(r * 0.18, r * 0.7), bone, Vector3(side * r * 0.55, r * 1.05, -r * 0.1), Vector3.ONE, Vector3(0, 0, side * -0.55))
        var ex := side * r * 0.36
        _add(SphereMesh.new(), eye, Vector3(ex, r * 0.18, r * 0.8), Vector3(r * 0.4, r * 0.3, r * 0.32))
        _add(SphereMesh.new(), pupil, Vector3(ex, r * 0.16, r * 0.95), Vector3(r * 0.18, r * 0.18, r * 0.18))
        var brow := BoxMesh.new()
        brow.size = Vector3(r * 0.42, r * 0.1, r * 0.1)
        _add(brow, dark, Vector3(ex, r * 0.36, r * 0.86), Vector3.ONE, Vector3(0, 0, side * 0.45))
    var grin := BoxMesh.new()
    grin.size = Vector3(r * 0.8, r * 0.14, r * 0.08)
    _add(grin, dark, Vector3(0, -r * 0.18, r * 0.9))
    for x: float in [-0.22, 0.22]:
        _add(_cone(r * 0.06, r * 0.2), bone, Vector3(x * r, -r * 0.3, r * 0.92), Vector3.ONE, Vector3(PI, 0, 0))
    # Marker: two cones tip to tip, unlit red, spinning above the head.
    marker = Node3D.new()
    var mm := StandardMaterial3D.new()
    mm.albedo_color = Color(1.0, 0.25, 0.2)
    mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var top := MeshInstance3D.new()
    top.mesh = _cone(r * 0.2, r * 0.35)
    top.material_override = mm
    top.position = Vector3(0, r * 0.5, 0)
    var bottom := MeshInstance3D.new()
    bottom.mesh = _cone(r * 0.2, r * 0.35)
    bottom.material_override = mm
    bottom.rotation.x = PI
    bottom.position = Vector3(0, r * 0.15, 0)
    marker.add_child(top)
    marker.add_child(bottom)
    marker.position = Vector3(0, r * 2.9, 0)
    add_child(marker)

func _cyl(r: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = r
    c.bottom_radius = r
    c.height = h
    return c

func _cone(r: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = 0.0
    c.bottom_radius = r
    c.height = h
    return c

func _add(mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    add_child(mi)
    return mi

func _process(delta: float) -> void:
    if marker:
        marker.rotation.y += delta * 2.5
        marker.position.y = radius * 2.9 + sin(Time.get_ticks_msec() / 250.0) * 0.06
        marker.global_rotation.x = 0
        marker.global_rotation.z = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if frozen:
        return
    var now: float = _level_time_ref.call()
    var strongest := 0.0
    var touches_projectile := false
    for i in state.get_contact_count():
        var imp: float = state.get_contact_impulse(i).length()
        if imp > strongest:
            strongest = imp
        var other := state.get_contact_collider_object(i)
        if other is Node and (other as Node).is_in_group("projectile"):
            touches_projectile = true
    if now - spawn_time < Tuning.TARGET_GRACE and not touches_projectile:
        return
    if strongest / maxf(mass, 0.1) > Tuning.TARGET_BREAK_IMPULSE:
        _pending_pop = true

func _on_body_entered(body: Node) -> void:
    if frozen:
        return
    if body.is_in_group("ground") and global_position.distance_to(base_position) > Tuning.TARGET_GROUND_POP_DISTANCE:
        _pending_pop = true

func _physics_process(_delta: float) -> void:
    if not frozen and base_position.y - global_position.y > Tuning.TARGET_FALL_POP:
        _pending_pop = true
    if _pending_pop:
        _pending_pop = false
        pop()

func pop() -> void:
    if is_queued_for_deletion():
        return
    popped.emit(self)

func set_frozen(value: bool) -> void:
    frozen = value
    freeze = value
    freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
