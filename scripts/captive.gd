## An islander of Valora locked in a pirate cage. Freed when a bar of the cage breaks or the
## cage falls apart around them: they jump, cheer and wave, then run off home.
class_name Captive
extends RigidBody3D

signal freed(captive: Captive)

const CLOTHES := [Color(0.32, 0.52, 0.78), Color(0.86, 0.72, 0.36), Color(0.52, 0.72, 0.42), Color(0.82, 0.48, 0.52)]

var cage_id := -1
var start: Vector3
var is_free := false
var deserter := false   # a pirate who wants to quit: a helmet, no weapon, a white rag
var _arm: Node3D
var _t := 0.0

func setup(i: int) -> void:
    mass = 3.0
    var shape := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.2
    cap.height = 0.75
    shape.shape = cap
    shape.position.y = 0.05
    add_child(shape)
    lock_rotation = true
    add_to_group("captives")
    add_to_group("dynamic")
    var skin := Models.flat_material(Color(0.93, 0.72, 0.58), 0.7)
    var clothes := Models.flat_material(Color(0.45, 0.4, 0.36) if deserter else CLOTHES[i % CLOTHES.size()], 0.85)
    var dark := Models.flat_material(Color(0.12, 0.1, 0.1), 0.8)
    _part(CapsuleMesh.new(), clothes, Vector3(0, -0.05, 0), Vector3(0.36, 0.32, 0.36))
    _part(SphereMesh.new(), skin, Vector3(0, 0.33, 0), Vector3(0.3, 0.3, 0.3))
    for side: float in [-1.0, 1.0]:
        _part(SphereMesh.new(), dark, Vector3(side * 0.06, 0.36, 0.13), Vector3(0.04, 0.05, 0.03))
    _part(BoxMesh.new(), dark, Vector3(0, 0.27, 0.14), Vector3(0.08, 0.02, 0.02))   # sad mouth
    if deserter:
        _part(SphereMesh.new(), Models.flat_material(Color(0.62, 0.64, 0.68), 0.3, 0.85), Vector3(0, 0.45, 0), Vector3(0.32, 0.2, 0.32))
    else:
        _part(SphereMesh.new(), Models.flat_material(Color(0.35, 0.22, 0.12), 0.95), Vector3(0, 0.44, -0.03), Vector3(0.32, 0.18, 0.32))
    # One arm to wave once free; a deserter's holds up a white rag.
    _arm = Node3D.new()
    _arm.position = Vector3(0.17, 0.12, 0)
    add_child(_arm)
    var a := MeshInstance3D.new()
    a.mesh = CapsuleMesh.new()
    a.material_override = clothes
    a.scale = Vector3(0.09, 0.16, 0.09)
    a.position = Vector3(0.02, -0.1, 0)
    _arm.add_child(a)
    if deserter:
        var rag := MeshInstance3D.new()
        var q := QuadMesh.new()
        q.size = Vector2(0.22, 0.16)
        rag.mesh = q
        rag.material_override = Models.flat_material(Color(0.96, 0.95, 0.92), 0.9)
        rag.position = Vector3(0.1, -0.28, 0)
        _arm.add_child(rag)

func _part(mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    add_child(mi)

func free_now() -> void:
    if is_free:
        return
    is_free = true
    freed.emit(self)
    # Celebrate: three hops, then off home.
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    for k in 3:
        tw.tween_property(self, "position:y", position.y + 0.5, 0.18).set_ease(Tween.EASE_OUT)
        tw.tween_property(self, "position:y", position.y, 0.18).set_ease(Tween.EASE_IN)
    tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
    tw.tween_callback(queue_free)
    freeze = true

func _process(delta: float) -> void:
    _t += delta
    if _arm:
        _arm.rotation.z = (2.4 + sin(_t * 14.0) * 0.5) if is_free else (0.3 + sin(_t * 2.0) * 0.1)

func _physics_process(_delta: float) -> void:
    # Knocked or dropped out of the cage: free.
    if not is_free and not freeze and global_position.distance_to(start) > 0.8:
        free_now()
