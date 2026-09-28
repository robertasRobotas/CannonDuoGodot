## Animated water. The shader displaces vertices; height() is the same function on the CPU so
## the ship and enemy boats ride the water they are drawn on. One uniform `t` keeps both in sync.
class_name Sea
extends MeshInstance3D

var storminess: float = 0.0
var open_sea: bool = false
var amplitude: float = Tuning.CALM_AMPLITUDE
var t: float = 0.0
var wave_len := 1.0
var _mat: ShaderMaterial

## `swell` multiplies the wave height: above 1 for the huge-wave levels.
func setup(storm: float, center: Vector3, is_open_sea: bool, swell: float = 1.0) -> void:
    storminess = clampf(storm, 0.0, 1.0)
    open_sea = is_open_sea
    amplitude = (Tuning.CALM_AMPLITUDE + Tuning.STORM_AMPLITUDE * storminess) * swell
    wave_len = 1.0 + maxf(swell - 1.0, 0.0) * 0.7
    # Advance the water before anything samples it, so ships ride this frame's waves.
    process_priority = -10
    var plane := PlaneMesh.new()
    plane.size = Vector2(160, 160)
    plane.subdivide_width = 110
    plane.subdivide_depth = 110
    mesh = plane
    _mat = ShaderMaterial.new()
    _mat.shader = load("res://shaders/sea.gdshader")
    _mat.set_shader_parameter("amplitude", amplitude)
    _mat.set_shader_parameter("wave_len", wave_len)
    _mat.set_shader_parameter("storm", storminess)
    _mat.set_shader_parameter("shore_z", Tuning.SHORE_Z)
    _mat.set_shader_parameter("open_sea", open_sea)
    _mat.set_shader_parameter("normal_map", load("res://assets/water/waternormals.jpg"))
    if storminess >= 0.6:
        _mat.set_shader_parameter("deep_color", Color(0.10, 0.22, 0.30))
        _mat.set_shader_parameter("shallow_color", Color(0.20, 0.36, 0.42))
        _mat.set_shader_parameter("sky_color", Color(0.45, 0.47, 0.52))
    material_override = _mat
    position = Vector3(center.x, Tuning.SEA_LEVEL, (center.z - 14.0) if open_sea else center.z)
    # A flat far plane to the horizon so the animated patch never shows an edge.
    var far := MeshInstance3D.new()
    var fp := PlaneMesh.new()
    fp.size = Vector2(900, 900)
    far.mesh = fp
    far.material_override = Models.flat_material(Color(0.10, 0.32, 0.54) if storminess < 0.6 else Color(0.10, 0.22, 0.30), 0.25)
    far.position = Vector3(0, -0.6 - amplitude * 3.0, 0)   # below the deepest trough
    add_child(far)

## Dark water under the moon.
func set_night() -> void:
    _mat.set_shader_parameter("deep_color", Color(0.02, 0.05, 0.10))
    _mat.set_shader_parameter("shallow_color", Color(0.05, 0.12, 0.18))
    _mat.set_shader_parameter("sky_color", Color(0.12, 0.16, 0.28))
    for c in get_children():
        if c is MeshInstance3D:
            (c as MeshInstance3D).material_override = Models.flat_material(Color(0.02, 0.05, 0.10), 0.25)

func _process(delta: float) -> void:
    t += delta
    if _mat:
        _mat.set_shader_parameter("sea_time", t)

## Keeps the water below the deck inside the player's hull (see the shader).
func set_hull(center: Vector3, half_length: float, half_width: float, floor_y: float) -> void:
    if _mat:
        _mat.set_shader_parameter("hull", Vector4(center.x, center.z, half_length, half_width))
        _mat.set_shader_parameter("hull_floor", floor_y)

func height(qx: float, qz: float) -> float:
    var x := qx / wave_len
    var z := qz / wave_len
    var w1 := sin(x * 0.35 + t * 1.1)
    var w2 := sin((x + z) * 0.21 - t * 0.8) * 0.6
    var w3 := sin(z * 0.5 + t * 1.6) * 0.35
    var w4 := sin((x * 0.6 - z * 0.4) + t * 1.9) * 0.25
    var chop := (sin(x * 1.3 - t * 3.2) * 0.12 * storminess) if storminess > 0.4 else 0.0
    var fade := 1.0 if open_sea else smoothstep(Tuning.SHORE_Z + 0.5, Tuning.SHORE_Z + 4.0, qz)
    return amplitude * fade * (w1 + w2 + w3 + w4 + chop)

## Height plus slopes, for hull roll and pitch.
func sample(x: float, z: float) -> Vector3:
    var e := 0.5
    var h := height(x, z)
    var sx := (height(x + e, z) - height(x - e, z)) / (2.0 * e)
    var sz := (height(x, z + e) - height(x, z - e)) / (2.0 * e)
    return Vector3(h, sx, sz)
