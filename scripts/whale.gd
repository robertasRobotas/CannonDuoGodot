## The great whale, built from primitives: a grey-blue humpback with a pale throat, long white
## flippers and wide flukes. It rises out of the deep beneath the ship, carries it clear of the
## pod on its back, and settles away again. Animated entirely in code.
class_name Whale
extends Node3D

const LENGTH := 16.0

var _t := 0.0
var _tail: Node3D
var _fins: Array[Node3D] = []

func _ready() -> void:
    var body_c := Color(0.2, 0.26, 0.34)
    var belly_c := Color(0.78, 0.8, 0.82)
    var ball := SphereMesh.new()
    ball.radius = 1.0
    ball.height = 2.0
    _add(self, ball, body_c, Vector3(0, 0, 0.6), Vector3(2.2, 1.9, 6.4))
    _add(self, ball, body_c, Vector3(0, -0.1, -6.2), Vector3(1.7, 1.5, 2.4))      # head
    _add(self, ball, belly_c, Vector3(0, -1.0, -3.0), Vector3(1.6, 1.1, 4.2))     # throat pleats
    # Little dorsal hump and knuckles along the spine.
    _add(self, ball, body_c, Vector3(0, 1.7, 2.6), Vector3(0.5, 0.35, 1.0))
    for i in 3:
        _add(self, ball, body_c, Vector3(0, 1.55 - i * 0.12, 3.8 + i * 0.8), Vector3(0.3, 0.18, 0.4))
    # Long white flippers.
    for side: float in [-1.0, 1.0]:
        var pivot := Node3D.new()
        pivot.position = Vector3(side * 1.9, -0.7, -3.4)
        add_child(pivot)
        _add(pivot, ball, belly_c, Vector3(side * 2.2, 0, 0), Vector3(2.5, 0.16, 0.8), Vector3(0, side * -0.35, side * 0.25))
        _fins.append(pivot)
    # Tail stock and the wide flukes.
    _tail = Node3D.new()
    _tail.position = Vector3(0, 0.2, 6.6)
    add_child(_tail)
    _add(_tail, ball, body_c, Vector3(0, 0, 0.8), Vector3(0.8, 0.7, 1.8))
    for side: float in [-1.0, 1.0]:
        _add(_tail, ball, body_c, Vector3(side * 1.6, 0, 2.3), Vector3(2.1, 0.18, 1.1), Vector3(0, side * -0.4, 0))

func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.4
    mi.material_override = m
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    parent.add_child(mi)
    return mi

func _process(delta: float) -> void:
    _t += delta
    _tail.rotation.x = sin(_t * 1.6) * 0.22
    for i in _fins.size():
        _fins[i].rotation.z = sin(_t * 1.1 + i * PI) * 0.15

## The spout when the blowhole clears the water.
func blow() -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = 30
    p.lifetime = 1.0
    p.explosiveness = 1.0
    p.direction = Vector3(0, 1, 0)
    p.spread = 8.0
    p.initial_velocity_min = 6.0
    p.initial_velocity_max = 9.0
    p.gravity = Vector3(0, -6, 0)
    p.scale_amount_min = 0.3
    p.scale_amount_max = 0.7
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.8)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    p.position = Vector3(0, 1.9, -5.5)
    add_child(p)
    p.emitting = true
    get_tree().create_timer(1.6).timeout.connect(p.queue_free)
