## One of Grimhorn's pirates holding a fort: horned helmet, braided beard, scowl. Most shake a
## cutlass at the ship; `armed` ones carry a blunderbuss and fire back; `boss` is Grimhorn
## himself, bigger, cloaked, and he takes a harder hit. A spinning marker floats overhead.
## Pops when hit hard, or when knocked off its perch (touches the ground or falls a metre).
class_name Enemy
extends RigidBody3D

signal popped(enemy: Enemy)
signal fired(from: Vector3, velocity: Vector3)

const COLORS := [Color(0.72, 0.12, 0.10), Color(0.14, 0.22, 0.45), Color(0.20, 0.36, 0.22), Color(0.58, 0.42, 0.14)]   # pirate shirts

var radius: float = 0.28
var base_position: Vector3
var spawn_time: float = 0.0
var frozen: bool = false
var marker: Node3D
var body_color: Color
var index := 0
var armed := false
var boss := false
var next_fire := 0.0
var sword_arm: Node3D
var _pending_pop := false
var _level_time_ref: Callable
var _shake_phase := 0.0

func setup(r: float, i: int, level_time: Callable) -> void:
    radius = r
    _level_time_ref = level_time
    index = i
    body_color = Color(0.22, 0.12, 0.10) if boss else COLORS[i % COLORS.size()]
    mass = 12.0 if boss else 4.0
    next_fire = Tuning.ENEMY_FIRST_SHOT_DELAY + 2.0 + randf() * 3.0
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

static var _mats: Dictionary = {}

static func _m(key: String, color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
    if not _mats.has(key):
        _mats[key] = Models.flat_material(color, rough, metal)
    return _mats[key]

func _build_visual() -> void:
    var shirt := Models.flat_material(body_color, 0.8)
    var skin := _m("skin", Color(0.93, 0.70, 0.55), 0.7)
    var dark := _m("dark", Color(0.10, 0.08, 0.08))
    var beard := _m("beard", Color(0.55, 0.28, 0.10), 0.95) if index % 2 == 0 else _m("beard2", Color(0.25, 0.15, 0.08), 0.95)
    var white := _m("white", Color(1.0, 0.97, 0.92), 0.5)
    var steel := _m("steel", Color(0.62, 0.64, 0.68), 0.3, 0.85)
    var horn := _m("horn", Color(0.95, 0.9, 0.78), 0.45)
    var gold := _m("gold", Color(0.85, 0.7, 0.2), 0.3, 0.8)
    var eye_red := _m("eye", Color(0.8, 0.1, 0.05), 0.3)
    var r := radius
    # Body: tunic with a fur collar and a belt with a gold buckle.
    _add(SphereMesh.new(), shirt, Vector3(0, -r * 0.1, 0), Vector3(r * 2, r * 1.7, r * 2))
    _add(_cyl(r * 0.96, r * 0.16), dark, Vector3(0, -r * 0.55, 0))
    _add(BoxMesh.new(), gold, Vector3(0, -r * 0.55, r * 0.95), Vector3(r * 0.22, r * 0.16, r * 0.06))
    _add(SphereMesh.new(), _m("fur", Color(0.42, 0.32, 0.22), 1.0), Vector3(0, r * 0.18, 0), Vector3(r * 1.9, r * 0.45, r * 1.9))
    if boss:
        var cape := BoxMesh.new()
        cape.size = Vector3(r * 1.7, r * 1.8, r * 0.1)
        _add(cape, _m("cape", Color(0.55, 0.05, 0.05), 0.9), Vector3(0, -r * 0.2, -r * 0.9), Vector3.ONE, Vector3(-0.18, 0, 0))
    # Face: angry eyes under a heavy brow, a big nose, a braided beard.
    _add(SphereMesh.new(), skin, Vector3(0, r * 0.42, r * 0.42), Vector3(r * 1.25, r * 0.95, r * 0.9))
    _add(SphereMesh.new(), beard, Vector3(0, r * 0.08, r * 0.72), Vector3(r * 1.1, r * 0.6, r * 0.45))
    for k in 2:
        _add(_cyl(r * 0.1, r * 0.4), beard, Vector3((k - 0.5) * r * 0.36, -r * 0.3, r * 0.82))
        _add(SphereMesh.new(), gold, Vector3((k - 0.5) * r * 0.36, -r * 0.52, r * 0.82), Vector3(r * 0.14, r * 0.1, r * 0.14))
    _add(SphereMesh.new(), skin, Vector3(0, r * 0.4, r * 0.9), Vector3(r * 0.24, r * 0.22, r * 0.22))
    for side: float in [-1.0, 1.0]:
        _add(SphereMesh.new(), white, Vector3(side * r * 0.25, r * 0.56, r * 0.8), Vector3(r * 0.22, r * 0.18, r * 0.12))
        _add(SphereMesh.new(), eye_red, Vector3(side * r * 0.25, r * 0.55, r * 0.86), Vector3(r * 0.1, r * 0.1, r * 0.08))
        var brow := BoxMesh.new()
        brow.size = Vector3(r * 0.38, r * 0.1, r * 0.1)
        _add(brow, beard, Vector3(side * r * 0.25, r * 0.72, r * 0.84), Vector3.ONE, Vector3(0, 0, side * 0.5))
    var mouth := BoxMesh.new()
    mouth.size = Vector3(r * 0.42, r * 0.09, r * 0.06)
    _add(mouth, dark, Vector3(0, r * 0.2, r * 0.97))
    # Horned helmet: an iron cap with a rim, a nose guard and two curving horns.
    _add(SphereMesh.new(), steel, Vector3(0, r * 0.82, 0), Vector3(r * 1.36, r * 0.95, r * 1.36))
    _add(_cyl(r * 0.7, r * 0.1), steel, Vector3(0, r * 0.62, 0))
    var nose_guard := BoxMesh.new()
    nose_guard.size = Vector3(r * 0.1, r * 0.34, r * 0.06)
    _add(nose_guard, steel, Vector3(0, r * 0.6, r * 0.72))
    var hl := 1.6 if boss else 1.0
    for side: float in [-1.0, 1.0]:
        _add(_cone(r * 0.16 * hl, r * 0.45 * hl), horn, Vector3(side * r * 0.72, r * 0.95, 0), Vector3.ONE, Vector3(0, 0, side * -1.05))
        _add(_cone(r * 0.11 * hl, r * 0.4 * hl), horn, Vector3(side * r * (0.95 + 0.25 * hl), r * (1.2 + 0.2 * hl), 0), Vector3.ONE, Vector3(0, 0, side * -0.25))
    if boss:
        _add(_cyl(r * 0.72, r * 0.14), gold, Vector3(0, r * 0.66, 0))
    # Right hand: a cutlass to shake, or a blunderbuss that fires.
    sword_arm = Node3D.new()
    sword_arm.position = Vector3(r * 0.9, r * 0.1, r * 0.1)
    add_child(sword_arm)
    var fist := MeshInstance3D.new()
    fist.mesh = SphereMesh.new()
    fist.material_override = skin
    fist.scale = Vector3(r * 0.36, r * 0.36, r * 0.36)
    fist.position = Vector3(r * 0.25, r * 0.35, 0)
    sword_arm.add_child(fist)
    if armed:
        var stock := MeshInstance3D.new()
        var sm := BoxMesh.new()
        sm.size = Vector3(r * 0.2, r * 0.2, r * 0.7)
        stock.mesh = sm
        stock.material_override = _m("gunwood", Color(0.35, 0.2, 0.1))
        stock.position = Vector3(r * 0.25, r * 0.35, r * 0.15)
        sword_arm.add_child(stock)
        var barrel := MeshInstance3D.new()
        var bm := CylinderMesh.new()
        bm.top_radius = r * 0.13
        bm.bottom_radius = r * 0.07
        bm.height = r * 1.0
        barrel.mesh = bm
        barrel.material_override = gold
        barrel.rotation.x = PI / 2.0
        barrel.position = Vector3(r * 0.25, r * 0.4, r * 0.85)
        sword_arm.add_child(barrel)
    else:
        var blade := MeshInstance3D.new()
        var blm := BoxMesh.new()
        blm.size = Vector3(r * 0.1, r * 1.5, r * 0.03)
        blade.mesh = blm
        blade.material_override = _m("blade", Color(0.78, 0.8, 0.84), 0.25, 0.9)
        blade.position = Vector3(r * 0.3, r * 1.15, 0)
        blade.rotation.z = -0.25
        sword_arm.add_child(blade)
        var guard_bar := MeshInstance3D.new()
        var gm := BoxMesh.new()
        gm.size = Vector3(r * 0.4, r * 0.07, r * 0.07)
        guard_bar.mesh = gm
        guard_bar.material_override = gold
        guard_bar.position = Vector3(r * 0.26, r * 0.5, 0)
        sword_arm.add_child(guard_bar)
    _shake_phase = randf() * TAU
    # Marker: two cones tip to tip, unlit red (gold for Grimhorn), spinning above the head.
    marker = Node3D.new()
    var mm := StandardMaterial3D.new()
    mm.albedo_color = Color(1.0, 0.8, 0.2) if boss else Color(1.0, 0.25, 0.2)
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
    if sword_arm:
        _shake_phase += delta
        if armed:
            sword_arm.rotation.x = -0.25 + sin(_shake_phase * 1.5) * 0.08
        else:
            # Shake the cutlass at the ship: quick jabs in bursts.
            var burst := fmod(_shake_phase, 2.6) < 1.1
            sword_arm.rotation.z = (0.55 + sin(_shake_phase * 18.0) * 0.35) if burst else 0.3
    if marker:
        marker.rotation.y += delta * 2.5
        marker.position.y = radius * 2.9 + sin(Time.get_ticks_msec() / 250.0) * 0.06
        marker.global_rotation.x = 0
        marker.global_rotation.z = 0

## Armed pirates fire a blunderbuss ball at the ship every so often.
func tick_gun(delta: float, target: Vector3) -> void:
    if not armed or frozen or is_queued_for_deletion():
        return
    next_fire -= delta
    if next_fire > 0.0:
        return
    next_fire = randf_range(8.0, 12.0)
    var origin := global_position + Vector3(0, radius * 0.5, radius * 1.2)
    var aim := target + Vector3(randf_range(-1.5, 1.5), randf_range(-0.3, 0.6), randf_range(-1.0, 1.0))
    fired.emit(origin, EnemyGun.solve(origin, aim, Tuning.ENEMY_BALL_SPEED * 0.9))

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
    var needed := Tuning.TARGET_BREAK_IMPULSE * (2.5 if boss else 1.0)
    if strongest / maxf(mass, 0.1) > needed:
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
