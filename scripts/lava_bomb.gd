## A burning rock thrown by the volcano: arcs from the crater, trailing fire and smoke, and
## bursts where it lands.
class_name LavaBomb
extends Node3D

signal landed(at: Vector3)

const FLIGHT := 3.2   # seconds from crater to castle

var _from: Vector3
var _to: Vector3
var _t := 0.0
var _v := Vector3.ZERO

static var _mat: StandardMaterial3D

func launch(from: Vector3, to: Vector3) -> void:
    _from = from
    _to = to
    # Ballistic: solve the start velocity for the flight time.
    _v = (to - from) / FLIGHT - Vector3(0, -9.8, 0) * FLIGHT / 2.0
    if _mat == null:
        _mat = StandardMaterial3D.new()
        _mat.albedo_color = Color(0.25, 0.08, 0.04)
        _mat.emission_enabled = true
        _mat.emission = Color(1.0, 0.35, 0.05)
        _mat.emission_energy_multiplier = 3.0
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.38
    sm.height = 0.7
    sm.radial_segments = 8
    sm.rings = 5
    mi.mesh = sm
    mi.material_override = _mat
    add_child(mi)
    var trail := CPUParticles3D.new()
    trail.amount = 36
    trail.lifetime = 0.9
    trail.local_coords = false
    trail.gravity = Vector3(0, 1.0, 0)
    trail.initial_velocity_min = 0.1
    trail.initial_velocity_max = 0.5
    trail.scale_amount_min = 0.6
    trail.scale_amount_max = 1.1
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1.0, 0.6, 0.2, 1.0))
    ramp.add_point(0.35, Color(0.4, 0.2, 0.15, 0.7))
    ramp.set_color(ramp.get_point_count() - 1, Color(0.2, 0.2, 0.2, 0.0))
    trail.color_ramp = ramp
    trail.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/smoke_04.png")
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    trail.material_override = m
    add_child(trail)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.45, 0.15)
    light.light_energy = 2.0
    light.omni_range = 6.0
    add_child(light)

func _physics_process(delta: float) -> void:
    _t += delta
    var p := _from + _v * _t + Vector3(0, -9.8, 0) * _t * _t / 2.0
    global_position = p
    rotation += Vector3(3.0, 2.0, 1.0) * delta
    if _t >= FLIGHT:
        landed.emit(p)
        queue_free()
