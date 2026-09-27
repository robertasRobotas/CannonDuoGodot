## A seagull wheeling in a slow circle: a small white body and two grey-tipped wings that
## flap, then glide.
class_name Seagull
extends Node3D

var _center: Vector3
var _radius := 8.0
var _speed := 0.35
var _angle := 0.0
var _flap := 0.0
var _wings: Array[Node3D] = []

static var _white: StandardMaterial3D
static var _grey: StandardMaterial3D

func setup(center: Vector3, radius: float, speed: float) -> void:
    _center = center
    _radius = radius
    _speed = speed
    _angle = randf() * TAU
    _flap = randf() * TAU
    if _white == null:
        _white = Models.flat_material(Color(0.96, 0.96, 0.94), 0.8)
        _grey = Models.flat_material(Color(0.45, 0.47, 0.5), 0.8)
    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.07
    cap.height = 0.42
    body.mesh = cap
    body.material_override = _white
    body.rotation.x = PI / 2.0
    add_child(body)
    for side: float in [-1.0, 1.0]:
        var pivot := Node3D.new()
        pivot.position = Vector3(side * 0.05, 0.02, 0)
        var wing := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.42, 0.012, 0.14)
        wing.mesh = bm
        wing.material_override = _white
        wing.position = Vector3(side * 0.21, 0, 0)
        pivot.add_child(wing)
        var tip := MeshInstance3D.new()
        var tm := BoxMesh.new()
        tm.size = Vector3(0.16, 0.013, 0.1)
        tip.mesh = tm
        tip.material_override = _grey
        tip.position = Vector3(side * 0.48, 0, 0.01)
        pivot.add_child(tip)
        add_child(pivot)
        _wings.append(pivot)

func _process(delta: float) -> void:
    _angle += _speed * delta
    var p := _center + Vector3(cos(_angle) * _radius, sin(_angle * 0.7) * 0.6, sin(_angle) * _radius)
    var ahead := _center + Vector3(cos(_angle + 0.1 * signf(_speed)) * _radius, p.y - _center.y, sin(_angle + 0.1 * signf(_speed)) * _radius)
    position = p
    if p.distance_to(ahead) > 0.001:
        look_at(ahead, Vector3.UP)
    rotation.z = -0.35 * signf(_speed)   # bank into the turn
    # Flap for a while, then glide.
    _flap += delta * 9.0
    var gliding := fmod(_flap, 12.0) > 7.0
    var a := 0.12 if gliding else sin(_flap) * 0.55
    _wings[0].rotation.z = a
    _wings[1].rotation.z = -a
