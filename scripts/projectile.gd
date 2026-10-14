## A cannonball. TNT balls explode on first contact, chain shot snaps any wood it hits, fire
## shot sets wood burning.
class_name Projectile
extends RigidBody3D

signal exploded(position: Vector3)
signal splashed(position: Vector3)
signal hit(body: Node)
signal smashed(position: Vector3)

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
    if t == "chain":
        _build_chain_shot(spec)
    else:
        var mi := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = spec.radius
        sm.height = spec.radius * 2
        mi.mesh = sm
        mi.material_override = Models.flat_material(spec.color, 0.4 if t == "iron" else 0.8, 0.6 if t == "iron" else 0.0)
        if t == "fire":
            var m := mi.material_override as StandardMaterial3D
            m.emission_enabled = true
            m.emission = Color(1.0, 0.45, 0.1)
            m.emission_energy_multiplier = 2.5
            _add_flame_trail()
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

## Bar shot: two half balls on a short iron bar, tumbling in flight.
func _build_chain_shot(spec: Dictionary) -> void:
    var iron := Models.flat_material(spec.color, 0.45, 0.6)
    for side: float in [-1.0, 1.0]:
        var b := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = spec.radius * 0.75
        sm.height = spec.radius * 1.5
        b.mesh = sm
        b.material_override = iron
        b.position = Vector3(side * spec.radius * 1.1, 0, 0)
        add_child(b)
    var bar := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = spec.radius * 0.18
    cm.bottom_radius = spec.radius * 0.18
    cm.height = spec.radius * 2.2
    bar.mesh = cm
    bar.material_override = iron
    bar.rotation.z = PI / 2.0
    add_child(bar)
    angular_velocity = Vector3(0, 14.0, 3.0)

func _add_flame_trail() -> void:
    var p := CPUParticles3D.new()
    p.amount = 40
    p.lifetime = 0.45
    p.local_coords = false
    p.direction = Vector3(0, 1, 0)
    p.spread = 30.0
    p.initial_velocity_min = 0.2
    p.initial_velocity_max = 0.8
    p.gravity = Vector3(0, 1.5, 0)
    p.scale_amount_min = 0.35
    p.scale_amount_max = 0.6
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
    ramp.set_color(1, Color(0.6, 0.2, 0.05, 0.0))
    p.color_ramp = ramp
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/flash03.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    add_child(p)

func _on_body_entered(body: Node) -> void:
    hit.emit(body)
    if body is Orca and not _done:
        _done = true
        (body as Orca).damage(global_position)
        queue_free()
        return
    if body is Balloon and not _done:
        _done = true
        (body as Balloon).puncture(global_position)
        queue_free()
        return
    if body is Block:
        var b := body as Block
        # A heavy ball at speed smashes through wood, whatever its size.
        if b.material_name == "wood" and not b.is_fragment and not b.frozen and linear_velocity.length() > 8.0 and type != "wood":
            b.call_deferred("break_now")
            smashed.emit(global_position)
        elif type == "chain" and b.material_name == "wood" and not b.is_fragment:
            b.call_deferred("break_now")
        elif type == "fire" and b.material_name == "wood":
            b.call_deferred("ignite")
    if (type == "tnt" or type == "shell") and not _done:
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
