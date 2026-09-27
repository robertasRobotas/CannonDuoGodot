## A piece of a wrecked ship: flies out of the blast, lands on the water and floats, bobbing
## with the waves, then slowly sinks away. Not a physics body: cheap enough for dozens.
class_name Debris
extends Node3D

const LIFE := 12.0

var velocity := Vector3.ZERO
var spin := Vector3.ZERO
var _sea: Sea
var _floating := false
var _t := 0.0
var _phase := 0.0

static var _plank_mat: Material

func setup(sea: Sea, barrel: bool, k: float) -> void:
    _sea = sea
    _phase = randf() * TAU
    if barrel:
        var b := Models.prop("wine_barrel_01")
        b.scale = Vector3.ONE * 0.8 * k
        add_child(b)
    else:
        if _plank_mat == null:
            _plank_mat = Models.tex_material("brown_planks_07", 1.5, Color(0.8, 0.62, 0.48))
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(randf_range(0.6, 1.6), 0.08, randf_range(0.14, 0.3)) * k
        mi.mesh = bm
        mi.material_override = _plank_mat
        add_child(mi)

func _process(delta: float) -> void:
    _t += delta
    var p := global_position
    var water := Tuning.SEA_LEVEL + (_sea.height(p.x, p.z) if _sea else 0.0)
    if not _floating:
        velocity.y -= 9.8 * delta
        p += velocity * delta
        rotation += spin * delta
        if p.y <= water and velocity.y < 0.0:
            _floating = true
            velocity = Vector3(velocity.x, 0, velocity.z) * 0.25
    if _floating:
        # Drift, bob, settle flat, and in the end slip under.
        velocity *= 1.0 - minf(delta * 0.8, 1.0)
        p += velocity * delta
        var sink := maxf(0.0, _t - LIFE + 3.0) * 0.25
        p.y = water + 0.04 + sin(_t * 2.0 + _phase) * 0.03 - sink
        rotation.x = lerpf(rotation.x, 0.0, minf(delta * 2.0, 1.0))
        rotation.z = lerpf(rotation.z, sin(_t * 1.3 + _phase) * 0.15, minf(delta * 2.0, 1.0))
    global_position = p
    if _t > LIFE:
        queue_free()
