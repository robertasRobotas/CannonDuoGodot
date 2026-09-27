## A cannonball. TNT balls explode on first contact.
class_name Projectile
extends RigidBody3D

signal exploded(position: Vector3)
signal splashed(position: Vector3)

var type: String = "iron"
var spawn_time: float = 0.0
var origin: Vector3
var _done := false

func setup(t: String, velocity: Vector3) -> void:
    type = t
    var spec: Dictionary = Tuning.AMMO[t]
    mass = spec.mass
    var shape := CollisionShape3D.new()
    var s := SphereShape3D.new()
    s.radius = spec.radius
    shape.shape = s
    add_child(shape)
    var pm := PhysicsMaterial.new()
    pm.friction = 0.5
    pm.bounce = spec.bounce
    physics_material_override = pm
    continuous_cd = true
    linear_damp = 0.01
    contact_monitor = true
    max_contacts_reported = 4
    add_to_group("projectile")
    add_to_group("dynamic")
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = spec.radius
    sm.height = spec.radius * 2
    mi.mesh = sm
    mi.material_override = Models.flat_material(spec.color, 0.4 if t == "iron" else 0.8, 0.6 if t == "iron" else 0.0)
    add_child(mi)
    if t == "tnt":
        var band := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = spec.radius * 1.02
        cm.bottom_radius = spec.radius * 1.02
        cm.height = spec.radius * 0.5
        band.mesh = cm
        band.material_override = Models.flat_material(Color(1.0, 0.96, 0.88), 0.6)
        add_child(band)
    linear_velocity = velocity
    body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node) -> void:
    if type == "tnt" and not _done:
        _done = true
        exploded.emit(global_position)
        queue_free()

func check_lifetime(now: float, sea_level: float, open_sea: bool, cannon_pos: Vector3) -> void:
    if _done:
        return
    var p := global_position
    var in_sea := (open_sea or p.z > Tuning.SHORE_Z) and p.y < sea_level + 0.1
    if in_sea:
        _done = true
        splashed.emit(Vector3(p.x, sea_level, p.z))
        queue_free()
        return
    if now - spawn_time > Tuning.PROJECTILE_LIFETIME or p.y < -6.0 or p.distance_to(cannon_pos) > Tuning.PROJECTILE_MAX_DISTANCE:
        _done = true
        queue_free()

func is_resting() -> bool:
    var p := global_position
    var speed := linear_velocity.length()
    return speed < 0.15 or (p.y < 0.25 and speed < 1.0)
