## A shark from primitives: grey back, white belly, a tall dorsal fin cutting the water.
## Circles its patch of bay; sent after a swimmer it closes fast, takes him under and dives.
class_name Shark
extends Node3D

signal caught(target: Node3D)

enum State { CIRCLE, HUNT, DIVE }

var state := State.CIRCLE
var center := Vector3.ZERO
var radius := 8.0
var angle := 0.0
var ang_speed := 0.5
var _target: Node3D
var _t := 0.0
var _state_t := 0.0
var _tail: Node3D
var _body: Node3D
var _prev := Vector3.ZERO

func setup(c: Vector3, r: float, a: float, speed: float) -> void:
    center = c
    radius = r
    angle = a
    ang_speed = speed
    _build()
    position = center + Vector3(cos(angle) * radius, -0.3, sin(angle) * radius)

func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = Models.flat_material(color, 0.45)
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    parent.add_child(mi)
    return mi

func _build() -> void:
    _body = Node3D.new()
    add_child(_body)
    var grey := Color(0.36, 0.4, 0.45)
    var white := Color(0.85, 0.87, 0.88)
    var ball := SphereMesh.new()
    ball.radius = 1.0
    ball.height = 2.0
    _add(_body, ball, grey, Vector3(0, 0, 0), Vector3(0.42, 0.4, 1.5))
    _add(_body, ball, grey, Vector3(0, -0.02, -1.45), Vector3(0.3, 0.26, 0.55))
    _add(_body, ball, white, Vector3(0, -0.18, 0.1), Vector3(0.34, 0.25, 1.25))
    var fin := PrismMesh.new()
    fin.size = Vector3(0.08, 0.75, 0.7)
    _add(_body, fin, grey, Vector3(0, 0.62, 0.1), Vector3.ONE, Vector3(0, PI / 2.0, 0))
    for side: float in [-1.0, 1.0]:
        _add(_body, ball, grey, Vector3(side * 0.45, -0.1, -0.3), Vector3(0.4, 0.05, 0.22), Vector3(0, side * 0.6, side * 0.2))
    _tail = Node3D.new()
    _tail.position = Vector3(0, 0, 1.45)
    _body.add_child(_tail)
    _add(_tail, ball, grey, Vector3(0, 0, 0.25), Vector3(0.18, 0.2, 0.5))
    var tf := PrismMesh.new()
    tf.size = Vector3(0.06, 0.9, 0.5)
    _add(_tail, tf, grey, Vector3(0, 0.1, 0.7), Vector3.ONE, Vector3(0, PI / 2.0, 0))

func hunt(target: Node3D) -> void:
    _target = target
    state = State.HUNT
    _state_t = 0.0

func tick(delta: float, sea: Sea) -> void:
    _t += delta
    _state_t += delta
    var p := global_position
    var water := Tuning.SEA_LEVEL + (sea.height(p.x, p.z) if sea else 0.0)
    match state:
        State.CIRCLE:
            angle += ang_speed * delta
            var want := center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
            want.y = water - 0.3
            global_position = global_position.lerp(want, minf(delta * 2.0, 1.0))
        State.HUNT:
            if _target == null or not is_instance_valid(_target):
                state = State.CIRCLE
            else:
                var goal := _target.global_position
                var flat := Vector3(goal.x - p.x, 0, goal.z - p.z)
                if flat.length() < 0.9:
                    caught.emit(_target)
                    _target = null
                    state = State.DIVE
                    _state_t = 0.0
                else:
                    global_position += flat.normalized() * 6.5 * delta
                    global_position.y = lerpf(global_position.y, water - 0.25, minf(delta * 4.0, 1.0))
        State.DIVE:
            global_position.y = move_toward(global_position.y, water - 2.6 if _state_t < 1.8 else water - 0.3, delta * 2.0)
            var away := Vector3(cos(angle) * radius, 0, sin(angle) * radius) + center - global_position
            away.y = 0.0
            if away.length() > 0.5:
                global_position += away.normalized() * 3.0 * delta
            if _state_t > 3.5:
                state = State.CIRCLE
    var vel := (global_position - _prev) / maxf(delta, 0.001)
    _prev = global_position
    if vel.length() > 0.3:
        _body.rotation.y = atan2(-vel.x, -vel.z) + PI
    _tail.rotation.y = sin(_t * (9.0 if state == State.HUNT else 5.0)) * 0.5
