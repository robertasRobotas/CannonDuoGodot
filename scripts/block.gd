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
## Whether a hard knock (a fall from a height, a plank landing on it, a wall shoved by a
## ball) can set powder off. A level may turn it off. Set by Level from "tnt_knock".
static var powder_knocks := true
## Whether a ball striking close by (not touching) sets powder off. A level may turn it
## off, so its kegs go only to a ball that touches them, a knock, or another blast. Set
## by Level from "tnt_spark".
static var powder_sparks := true
## Powder that goes off from a fall: when set (metres per second, from the level's
## "tnt_fall" drop height), a keg explodes on any solid contact while it, or whatever
## strikes it, is moving at least this fast, as after a drop from that height. A slow
## shove (a wall pushed by a ball) does nothing. Below zero, the old impulse rule holds.
static var powder_fall_speed := -1.0
var _prev_speed := 0.0   # last frame's speed, so a landing is judged by the fall before it
var motion: Dictionary = {}
var base_position: Vector3
var break_threshold: float = -1.0
var spawn_time: float = 0.0
var is_fragment: bool = false
var frozen: bool = false
var _pending_break: float = -1.0
var _settle_until := 0.0
var cage_id := -1   # bars of a prisoner's cage: breaking one frees them
var burning := false
var burn_time := 0.0
var _flames: CPUParticles3D
var smouldering := false
var hit_point := Vector3.ZERO   # where the last ball struck (global), for the break pattern
var hit_known := false

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
    elif style == "mound":
        # A hillfort mound: its sloping sides are part of the solid.
        var cp := ConvexPolygonShape3D.new()
        cp.points = Mound.hull(sz)
        shape.shape = cp
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
    var ball := false
    var settling := Time.get_ticks_msec() / 1000.0 < _settle_until
    for i in state.get_contact_count():
        var imp: float = state.get_contact_impulse(i).length()
        if imp > strongest:
            strongest = imp
        var other := state.get_contact_collider_object(i)
        if other is Node and (other as Node).is_in_group("projectile"):
            ball = true
            hit_point = state.get_contact_local_position(i)
            hit_known = true
    if material_name == "timber":
        return   # log walls shrug off balls and knocks; only a blast splits them (see Level.explode)
    if material_name == "tnt" and not ball and powder_fall_speed > 0.0 and powder_knocks and not is_static_block:
        # The fall rule: a landing, or something landing on it, fast enough.
        var fast := _prev_speed >= powder_fall_speed
        for i in state.get_contact_count():
            if state.get_contact_collider_velocity_at_position(i).length() >= powder_fall_speed:
                fast = true
        _prev_speed = state.linear_velocity.length()
        if fast and strongest / maxf(mass, 0.1) > 0.6 and not settling:
            _pending_break = strongest / maxf(mass, 0.1)
        return
    _prev_speed = state.linear_velocity.length()
    if strongest > 0.0:
        var specific := strongest / maxf(mass, 0.1)
        # Powder goes up when a cannonball hits it (or a blast reaches it, see Level.explode);
        # a knock from a falling plank or a shaken floor is not enough.
        var needed := break_threshold if (material_name != "tnt" or ball) else Tuning.TNT_KNOCK_BREAK
        # Just woken: pieces press into place against each other; only a ball breaks them yet.
        if settling and not ball:
            return
        if material_name == "tnt" and not ball and not powder_knocks:
            return
        if specific > needed:
            _pending_break = specific

## Fire shot: wood smoulders, flames grow, and after BURN_TIME the piece gives way.
func ignite() -> void:
    if burning or not (material_name in ["wood", "timber"]) or is_queued_for_deletion():
        return
    if get_tree().get_nodes_in_group("burning").size() >= Tuning.MAX_BURNING:
        return
    burning = true
    burn_time = 0.0
    add_to_group("burning")
    if frozen:
        set_frozen.call_deferred(false)
    _flames = CPUParticles3D.new()
    _flames.amount = 18
    _flames.lifetime = 0.7
    _flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    _flames.emission_box_extents = size * 0.45
    _flames.direction = Vector3(0, 1, 0)
    _flames.spread = 15.0
    _flames.initial_velocity_min = 0.4
    _flames.initial_velocity_max = 1.2
    _flames.gravity = Vector3(0, 1.2, 0)
    _flames.scale_amount_min = 0.35
    _flames.scale_amount_max = 0.7
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.7, 0.25, 0.95))
    ramp.set_color(1, Color(0.3, 0.1, 0.05, 0.0))
    _flames.color_ramp = ramp
    _flames.mesh = QuadMesh.new()
    _flames.material_override = _particle_material("flash03.png", true)
    add_child(_flames)

## Blown rubble that still glows: a few weak tongues of flame, a thread of smoke and a dim
## red light, dying away over `duration` seconds. The piece itself does not burn up.
func smoulder(duration: float = randf_range(9.0, 16.0)) -> void:
    if smouldering or is_queued_for_deletion():
        return
    if get_tree().get_nodes_in_group("embers").size() >= Tuning.MAX_EMBERS:
        return
    smouldering = true
    add_to_group("embers")
    var reach := size * 0.3
    var fire := CPUParticles3D.new()
    fire.amount = 7
    fire.lifetime = 0.6
    fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    fire.emission_box_extents = reach
    fire.direction = Vector3(0, 1, 0)
    fire.spread = 20.0
    fire.initial_velocity_min = 0.2
    fire.initial_velocity_max = 0.6
    fire.gravity = Vector3(0, 0.8, 0)
    fire.scale_amount_min = 0.14
    fire.scale_amount_max = 0.3
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.6, 0.2, 0.9))
    ramp.set_color(1, Color(0.35, 0.08, 0.03, 0.0))
    fire.color_ramp = ramp
    fire.mesh = QuadMesh.new()
    fire.material_override = _particle_material("flash03.png", true)
    fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(fire)
    var smoke := CPUParticles3D.new()
    smoke.amount = 6
    smoke.lifetime = 2.4
    smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    smoke.emission_box_extents = reach
    smoke.direction = Vector3(0.1, 1, 0)
    smoke.spread = 15.0
    smoke.initial_velocity_min = 0.3
    smoke.initial_velocity_max = 0.7
    smoke.gravity = Vector3(0.15, 0.35, 0)
    smoke.angle_min = 0.0
    smoke.angle_max = 360.0
    smoke.scale_amount_min = 0.3
    smoke.scale_amount_max = 0.5
    var grow := Curve.new()
    grow.add_point(Vector2(0, 0.5))
    grow.add_point(Vector2(1, 2.0))
    smoke.scale_amount_curve = grow
    var sramp := Gradient.new()
    sramp.set_color(0, Color(0.3, 0.28, 0.26, 0.0))
    sramp.add_point(0.2, Color(0.3, 0.28, 0.26, 0.4))
    sramp.set_color(sramp.get_point_count() - 1, Color(0.45, 0.45, 0.47, 0.0))
    smoke.color_ramp = sramp
    smoke.mesh = QuadMesh.new()
    smoke.material_override = _particle_material("blackSmoke16.png", false)
    smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(smoke)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.45, 0.15)
    light.light_energy = 0.9
    light.omni_range = 2.2
    light.shadow_enabled = false
    add_child(light)
    var flicker := light.create_tween().set_loops()
    flicker.tween_property(light, "light_energy", 0.6, 0.11)
    flicker.tween_property(light, "light_energy", 1.0, 0.09)
    flicker.tween_property(light, "light_energy", 0.8, 0.15)
    # Die down: the flames go first, the smoke and the glow linger a little longer.
    var t := get_tree().create_timer(duration)
    t.timeout.connect(func():
        if not is_instance_valid(self):
            return
        fire.emitting = false
        flicker.kill()
        var fade := light.create_tween()
        fade.tween_property(light, "light_energy", 0.0, 3.0)
        get_tree().create_timer(3.0).timeout.connect(func():
            if is_instance_valid(smoke):
                smoke.emitting = false
            if is_instance_valid(light):
                light.queue_free()
            if is_instance_valid(fire):
                fire.queue_free()
            if is_instance_valid(self):
                remove_from_group("embers")
                smouldering = false)
        get_tree().create_timer(6.0).timeout.connect(func():
            if is_instance_valid(smoke):
                smoke.queue_free()))

## An unshaded billboard card for flames (additive) or smoke (plain alpha).
static func _particle_material(texture: String, additive: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/" + texture)
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if additive:
        m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    return m

func _physics_process(delta: float) -> void:
    if burning:
        burn_time += delta
        if _flames:
            _flames.scale_amount_max = 0.7 + burn_time * 0.25
        if burn_time >= Tuning.BURN_TIME:
            burning = false
            break_now()
            return
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
    if not value:
        _settle_until = Time.get_ticks_msec() / 1000.0 + Tuning.SETTLE_GRACE
