## A castle piece: a rigid box that breaks when a contact impulse per kilogram exceeds the
## material's threshold. Visuals come from Kenney kits fitted into the block's size.
class_name Block
extends RigidBody3D

signal broke(block: Block)

var material_name: String = "stone"
var size: Vector3 = Vector3.ONE
var style: String = ""
var tint: String = ""
var is_static_block: bool = false
var motion: Dictionary = {}
var base_position: Vector3
var break_threshold: float = -1.0
var spawn_time: float = 0.0
var is_fragment: bool = false
var frozen: bool = false
var _pending_break: float = -1.0

func setup(mat: String, sz: Vector3, st: String, static_block: bool, mo: Dictionary, fragment: bool = false, visual: Node3D = null) -> void:
    material_name = mat
    size = sz
    is_fragment = fragment
    var parts := st.split(":")
    style = parts[0] if parts.size() > 0 else ""
    tint = parts[1] if parts.size() > 1 else ""
    is_static_block = static_block
    motion = mo
    var spec: Dictionary = Tuning.MATERIALS[mat]
    var sphere := style == "boulder"
    var volume: float = (0.5236 * sz.x * sz.y * sz.z) if sphere else (sz.x * sz.y * sz.z)
    mass = maxf(spec.density * volume, 0.5)
    break_threshold = spec["break"]
    var shape := CollisionShape3D.new()
    if sphere:
        var s := SphereShape3D.new()
        s.radius = sz.x / 2.0
        shape.shape = s
    else:
        var b := BoxShape3D.new()
        b.size = sz
        shape.shape = b
    add_child(shape)
    var pm := PhysicsMaterial.new()
    pm.friction = spec.friction
    pm.bounce = spec.bounce
    physics_material_override = pm
    linear_damp = 0.05
    angular_damp = 0.1
    contact_monitor = true
    max_contacts_reported = 6
    add_to_group("blocks")
    if static_block:
        freeze = true
        freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC if not motion.is_empty() else RigidBody3D.FREEZE_MODE_STATIC
    else:
        add_to_group("dynamic")
    if visual:
        add_child(visual)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    if break_threshold < 0.0 or frozen or is_fragment:
        return
    var strongest := 0.0
    for i in state.get_contact_count():
        var imp: float = state.get_contact_impulse(i).length()
        if imp > strongest:
            strongest = imp
    if strongest > 0.0:
        var specific := strongest / maxf(mass, 0.1)
        if specific > break_threshold:
            _pending_break = specific

func _physics_process(_delta: float) -> void:
    if _pending_break > 0.0:
        _pending_break = -1.0
        break_now()

func break_now() -> void:
    if is_queued_for_deletion():
        return
    broke.emit(self)

## Frozen castles: static until the first shot.
func set_frozen(value: bool) -> void:
    if is_static_block:
        return
    frozen = value
    freeze = value
    freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
