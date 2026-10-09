## An orca, built from primitives and animated in code: it circles the ship with its dorsal
## fin cutting the water, arcs out for a breath (the only moment a cannonball can touch it),
## and now and then charges the hull. Three hits put it down: it rolls belly-up and sinks.
class_name Orca
extends AnimatableBody3D

signal died(orca: Orca)
signal rammed(orca: Orca, at: Vector3)

enum State { CIRCLE, SURFACE, RAM, FLEE, DYING }

const DEPTH := -0.9         # cruising depth: the fin and a sliver of back above the water
const LENGTH := 6.0

var state := State.CIRCLE
var hp := 3
var angle := 0.0
var home := -PI / 2.0       # dead ahead of the gun; the pod patrols the seaward arc
var radius := 18.0
var ang_speed := 0.35
var _phase := 0.0
var _t := 0.0
var _state_t := 0.0
var _tail: Node3D
var _body: Node3D
var _wake: CPUParticles3D
var _mats: Array[StandardMaterial3D] = []
var _ram_dir := Vector3.ZERO
var _sea: Sea
var _ship_pos := Vector3.ZERO
var _prev := Vector3.ZERO
var _splash_cool := 0.0

func setup(a: float, r: float, speed: float) -> void:
    home = a
    angle = a
    _phase = randf() * TAU
    radius = r
    ang_speed = speed
    sync_to_physics = false
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.8
    cap.height = LENGTH
    shape.shape = cap
    shape.rotation.x = PI / 2.0
    add_child(shape)
    add_to_group("orcas")
    _build()

func _mat(c: Color, rough := 0.35) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    _mats.append(m)
    return m

func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    parent.add_child(mi)
    return mi

func _build() -> void:
    _body = Node3D.new()
    add_child(_body)
    var black := _mat(Color(0.06, 0.07, 0.09))
    var white := _mat(Color(0.92, 0.94, 0.95))
    var grey := _mat(Color(0.45, 0.5, 0.55))
    var ball := SphereMesh.new()
    ball.radius = 1.0
    ball.height = 2.0
    # Body, snout and chin.
    _add(_body, ball, black, Vector3(0, 0, 0.2), Vector3(0.85, 0.9, 2.6))
    _add(_body, ball, black, Vector3(0, -0.05, -2.45), Vector3(0.58, 0.55, 0.8))
    _add(_body, ball, white, Vector3(0, -0.3, -2.5), Vector3(0.42, 0.3, 0.6))
    # White belly and the eye patches; the grey saddle behind the fin.
    _add(_body, ball, white, Vector3(0, -0.42, 0.1), Vector3(0.6, 0.5, 2.1))
    for side: float in [-1.0, 1.0]:
        _add(_body, ball, white, Vector3(side * 0.6, 0.28, -1.65), Vector3(0.26, 0.15, 0.5), Vector3(0, 0, side * -0.2))
        _add(_body, ball, black, Vector3(side * 0.85, -0.45, -1.0), Vector3(0.5, 0.07, 0.85), Vector3(0, side * 0.5, side * 0.45))
    _add(_body, ball, grey, Vector3(0, 0.72, 0.5), Vector3(0.5, 0.18, 0.85))
    # Dorsal fin.
    var fin := PrismMesh.new()
    fin.size = Vector3(0.14, 1.7, 1.1)
    _add(_body, fin, black, Vector3(0, 1.6, 0.25), Vector3.ONE, Vector3(0, PI / 2.0, 0))
    # Tail stock and flukes on a pivot, beating up and down.
    _tail = Node3D.new()
    _tail.position = Vector3(0, 0, 2.6)
    _body.add_child(_tail)
    _add(_tail, ball, black, Vector3(0, 0, 0.3), Vector3(0.35, 0.4, 0.8))
    for side: float in [-1.0, 1.0]:
        _add(_tail, ball, black, Vector3(side * 0.6, 0, 0.85), Vector3(0.75, 0.07, 0.5), Vector3(0, side * -0.35, 0))
    _wake = _make_wake()
    _body.add_child(_wake)

## The white vee the fin cuts through the water: how the player finds the pod.
func _make_wake() -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = 26
    p.lifetime = 1.1
    p.direction = Vector3(0, 0.6, 1)
    p.spread = 25.0
    p.initial_velocity_min = 1.2
    p.initial_velocity_max = 2.2
    p.gravity = Vector3(0, -2.5, 0)
    p.scale_amount_min = 0.25
    p.scale_amount_max = 0.6
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.75)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    p.position = Vector3(0, 0.9, 0.3)
    return p

## A cannonball found it. Three make a kill.
func damage(at: Vector3) -> bool:
    if state == State.DYING:
        return false
    hp -= 1
    for m in _mats:
        var base: Color = m.albedo_color
        m.albedo_color = Color(1.0, 0.3, 0.25)
        var tw := create_tween()
        tw.tween_property(m, "albedo_color", base, 0.35)
    Haptics.pop()
    if hp <= 0:
        state = State.DYING
        _state_t = 0.0
        died.emit(self)
        return true
    return false

func begin_surface() -> void:
    if state == State.CIRCLE:
        state = State.SURFACE
        _state_t = 0.0

func begin_ram(ship_pos: Vector3) -> void:
    if state == State.CIRCLE:
        state = State.RAM
        _state_t = 0.0
        _ram_dir = (ship_pos - global_position)
        _ram_dir.y = 0.0
        _ram_dir = _ram_dir.normalized()

func begin_flee() -> void:
    if state != State.DYING:
        state = State.FLEE
        _state_t = 0.0

func tick(delta: float, sea: Sea, ship_pos: Vector3) -> void:
    _t += delta
    _state_t += delta
    _sea = sea
    _ship_pos = ship_pos
    var p := global_position
    var water := Tuning.SEA_LEVEL + (sea.height(p.x, p.z) if sea else 0.0)
    match state:
        State.CIRCLE:
            # Patrol a sweep of the arc around its home bearing, never drifting behind the ship.
            _phase += ang_speed * 1.6 * delta
            angle = home + sin(_phase) * 0.8
            var want := ship_pos + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
            want.y = water + DEPTH
            global_position = global_position.lerp(want, minf(delta * 2.0, 1.0))
        State.SURFACE:
            # The breath: the back and fin roll out of the water, a blow at the top, back
            # under. ~2.4 s exposed; only the arched back ever clears the surface.
            _phase += ang_speed * 1.1 * delta
            angle = home + sin(_phase) * 0.8
            var k := _state_t / 2.4
            var want := ship_pos + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
            want.y = water + DEPTH + (1.0 * sin(k * PI) if k < 1.0 else 0.0)
            global_position = global_position.lerp(want, minf(delta * 3.0, 1.0))
            if absf(k - 0.5) < 0.04:
                _blow()
            if (absf(k - 0.12) < 0.04 or absf(k - 0.88) < 0.04) and _splash_cool <= 0.0:
                _splash_cool = 0.6
                _surface_splash(water)
            if k >= 1.0:
                state = State.CIRCLE
        State.RAM:
            global_position += _ram_dir * 8.5 * delta
            global_position.y = lerpf(global_position.y, water - 0.4, minf(delta * 3.0, 1.0))
            var flat := ship_pos - global_position
            flat.y = 0.0
            if flat.length() < 3.4:
                rammed.emit(self, global_position + Vector3(0, 0.6, 0))
                state = State.CIRCLE
        State.FLEE:
            var away := (global_position - ship_pos)
            away.y = 0.0
            global_position += away.normalized() * 11.0 * delta
            global_position.y = move_toward(global_position.y, water - 6.0, delta * 2.5)
            if _state_t > 3.0:
                queue_free()
        State.DYING:
            # Belly up, a slow roll, and down into the dark.
            _body.rotation.z = move_toward(_body.rotation.z, PI, delta * 2.0)
            global_position.y = move_toward(global_position.y, water + 0.25 if _state_t < 1.6 else water - 8.0, delta * (0.8 if _state_t < 1.6 else 2.0))
            if _state_t > 5.0:
                queue_free()
            return
    _splash_cool = maxf(_splash_cool - delta, 0.0)
    if _wake:
        # Foam only while the fin actually cuts the waterline.
        _wake.emitting = absf(global_position.y - (water + DEPTH)) < 0.6
    # Face the way it swims, pitch with the climb, and beat the flukes.
    var vel := (global_position - _prev) / maxf(delta, 0.001)
    _prev = global_position
    if vel.length() > 0.5:
        var flat_speed := Vector2(vel.x, vel.z).length()
        _body.rotation.y = atan2(-vel.x, -vel.z) - global_rotation.y + PI
        _body.rotation.x = clampf(atan2(vel.y, flat_speed), -0.6, 0.6)
    _tail.rotation.x = sin(_t * 7.0) * 0.45

## White water thrown up where the back breaks the surface and where it slips under.
func _surface_splash(water: float) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = 24
    p.lifetime = 0.8
    p.explosiveness = 1.0
    p.direction = Vector3(0, 1, 0)
    p.spread = 55.0
    p.initial_velocity_min = 2.0
    p.initial_velocity_max = 4.5
    p.gravity = Vector3(0, -7, 0)
    p.scale_amount_min = 0.35
    p.scale_amount_max = 0.8
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.8)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    get_parent().add_child(p)
    p.global_position = Vector3(global_position.x, water + 0.1, global_position.z)
    p.emitting = true
    get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _blow() -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = 16
    p.lifetime = 0.6
    p.explosiveness = 1.0
    p.direction = Vector3(0, 1, 0)
    p.spread = 12.0
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 5.0
    p.gravity = Vector3(0, -4, 0)
    p.scale_amount_min = 0.2
    p.scale_amount_max = 0.45
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.7)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    p.position = Vector3(0, 1.0, -2.0)
    add_child(p)
    p.emitting = true
    get_tree().create_timer(1.0).timeout.connect(p.queue_free)
