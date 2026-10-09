## A pirate hot-air balloon: a striped envelope, a crate basket with a pirate and a powder
## keg, drifting on the wind. A ball through the envelope and it folds; the basket falls,
## spinning and burning, and the keg goes off where it lands.
class_name Balloon
extends AnimatableBody3D

signal crashed(balloon: Balloon, at: Vector3)
signal bombed(balloon: Balloon, at: Vector3)

const STRIPES := [[Color(0.75, 0.12, 0.1), Color(0.95, 0.9, 0.78)], [Color(0.12, 0.25, 0.55), Color(0.95, 0.9, 0.78)], [Color(0.15, 0.4, 0.2), Color(0.9, 0.78, 0.3)]]

var punctured := false
var dropped := false
var _t := 0.0
var _vel := Vector3.ZERO
var _envelope: MeshInstance3D
var _basket: Node3D
var _floor: Callable
var _spin := Vector3.ZERO
var _drift := Vector3(0, 0, 0.55)
var _shape: CollisionShape3D

func setup(i: int, floor_fn: Callable) -> void:
    _floor = floor_fn
    _t = i * 1.7
    sync_to_physics = false
    _shape = CollisionShape3D.new()
    var sph := SphereShape3D.new()
    sph.radius = 1.75
    _shape.shape = sph
    _shape.position = Vector3(0, 2.7, 0)
    add_child(_shape)
    add_to_group("balloons")
    # Envelope: striped gores.
    _envelope = MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 1.0
    sm.height = 2.0
    sm.radial_segments = 24
    _envelope.mesh = sm
    var mat := ShaderMaterial.new()
    var sh := Shader.new()
    sh.code = """
shader_type spatial;
uniform vec3 c1 : source_color;
uniform vec3 c2 : source_color;
void fragment() {
    float s = step(0.5, fract(UV.x * 7.0));
    ALBEDO = mix(c1, c2, s);
    ROUGHNESS = 0.7;
}
"""
    mat.shader = sh
    var pair: Array = STRIPES[i % STRIPES.size()]
    mat.set_shader_parameter("c1", pair[0])
    mat.set_shader_parameter("c2", pair[1])
    _envelope.material_override = mat
    _envelope.position = Vector3(0, 2.7, 0)
    _envelope.scale = Vector3(1.75, 2.05, 1.75)
    add_child(_envelope)
    # Neck and burner flame.
    var neck := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.5
    cm.bottom_radius = 0.2
    cm.height = 0.5
    neck.mesh = cm
    neck.material_override = Models.flat_material(pair[0] * 0.8, 0.8)
    neck.position = Vector3(0, 0.95, 0)
    add_child(neck)
    var flame := EnemyShip._flames(0.5)
    flame.position = Vector3(0, 0.75, 0)
    add_child(flame)
    # Basket with ropes, the pirate and his keg.
    _basket = Node3D.new()
    add_child(_basket)
    var box := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.95, 0.62, 0.95)
    box.mesh = bm
    box.material_override = Models.tex_material("brown_planks_07", 1.4, Color(0.85, 0.7, 0.5))
    _basket.add_child(box)
    for sx: float in [-0.42, 0.42]:
        for sz: float in [-0.42, 0.42]:
            var rope := MeshInstance3D.new()
            var rm := CylinderMesh.new()
            rm.top_radius = 0.02
            rm.bottom_radius = 0.02
            rm.height = 0.75
            rope.mesh = rm
            rope.material_override = Models.flat_material(Color(0.6, 0.5, 0.35), 0.9)
            rope.position = Vector3(sx, 0.62, sz)
            rope.rotation = Vector3(-sz * 0.35, 0, sx * 0.35)
            _basket.add_child(rope)
    _pirate(_basket, Vector3(-0.18, 0.45, 0.1))
    var keg := MeshInstance3D.new()
    var km := CylinderMesh.new()
    km.top_radius = 0.17
    km.bottom_radius = 0.17
    km.height = 0.4
    keg.mesh = km
    keg.material_override = Models.flat_material(Color(0.75, 0.12, 0.08), 0.6)
    keg.position = Vector3(0.25, 0.45, -0.1)
    _basket.add_child(keg)

## A small pirate from spheres and cones: red shirt, horned helmet, waving.
func _pirate(parent: Node3D, at: Vector3) -> void:
    var r := 0.2
    var body := MeshInstance3D.new()
    body.mesh = SphereMesh.new()
    body.scale = Vector3(r * 2, r * 1.6, r * 2)
    body.material_override = Models.flat_material(Color(0.72, 0.12, 0.1), 0.8)
    body.position = at
    parent.add_child(body)
    var head := MeshInstance3D.new()
    head.mesh = SphereMesh.new()
    head.scale = Vector3(r * 1.1, r * 1.0, r * 1.1)
    head.material_override = Models.flat_material(Color(0.93, 0.7, 0.55), 0.7)
    head.position = at + Vector3(0, r * 1.45, 0)
    parent.add_child(head)
    var helm := MeshInstance3D.new()
    helm.mesh = SphereMesh.new()
    helm.scale = Vector3(r * 1.25, r * 0.8, r * 1.25)
    helm.material_override = Models.flat_material(Color(0.62, 0.64, 0.68), 0.3, 0.85)
    helm.position = at + Vector3(0, r * 1.8, 0)
    parent.add_child(helm)
    for side: float in [-1.0, 1.0]:
        var horn := MeshInstance3D.new()
        var hm := CylinderMesh.new()
        hm.top_radius = 0.0
        hm.bottom_radius = r * 0.16
        hm.height = r * 0.5
        horn.mesh = hm
        horn.material_override = Models.flat_material(Color(0.95, 0.9, 0.78), 0.45)
        horn.position = at + Vector3(side * r * 0.7, r * 1.95, 0)
        horn.rotation.z = side * -1.0
        parent.add_child(horn)

func tick(delta: float, ship_pos: Vector3) -> void:
    _t += delta
    if not punctured:
        position += _drift * delta
        position.y += sin(_t * 0.7) * 0.004
        rotation.z = sin(_t * 0.9) * 0.05
        rotation.x = sin(_t * 0.6 + 1.0) * 0.04
        _basket.rotation.z = sin(_t * 1.3) * 0.08
        # Over the ship: the keg goes over the side, then the wind carries the balloon off.
        if not dropped and position.z > ship_pos.z - 3.0 and absf(position.x - ship_pos.x) < 12.0:
            dropped = true
            bombed.emit(self, Vector3(ship_pos.x + randf_range(-1.0, 1.0), ship_pos.y + 1.0, ship_pos.z))
            _drift = Vector3(0.8 * signf(position.x if position.x != 0.0 else 1.0), 0.25, 0.1)
        return
    # Falling: the envelope folds, the basket tumbles, a slow fall under the torn canvas.
    _vel.y -= 5.5 * delta
    _vel.x *= 1.0 - minf(delta * 0.5, 1.0)
    position += _vel * delta
    rotation += _spin * delta
    var k := clampf(_t, 0.0, 1.0)
    _envelope.scale = Vector3(1.75 * (1.0 - 0.75 * k), 2.05 * (1.0 - 0.6 * k), 1.75 * (1.0 - 0.75 * k))
    var floor_y: float = _floor.call(position.x, position.z) if _floor.is_valid() else 0.3
    if position.y <= floor_y + 0.3:
        crashed.emit(self, Vector3(position.x, floor_y + 0.3, position.z))
        queue_free()

## A ball through the envelope.
func puncture(at: Vector3) -> void:
    if punctured:
        return
    punctured = true
    _t = 0.0
    _shape.queue_free()
    _vel = Vector3((at.x - position.x) * -0.3, 1.2, (at.z - position.z) * -0.3)
    _spin = Vector3(randf_range(-1.2, 1.2), randf_range(-2.0, 2.0), randf_range(-1.2, 1.2))
    var smoke := EnemyShip._smoke(0.8)
    smoke.position = Vector3(0, 2.7, 0)
    add_child(smoke)
    var fire := EnemyShip._flames(1.2)
    fire.position = Vector3(0, 1.6, 0)
    add_child(fire)
    Haptics.pop()
