## Animated water. The shader displaces vertices; height() is the same function on the CPU so
## the ship and enemy boats ride the water they are drawn on. One uniform `t` keeps both in sync.
class_name Sea
extends MeshInstance3D

var storminess: float = 0.0
var open_sea: bool = false
var amplitude: float = Tuning.CALM_AMPLITUDE
var t: float = 0.0
var wave_len := 1.0
var _curved := false

## Waves calm along the island's real (curved) shoreline.
func set_shore(seed_value: float) -> void:
    _curved = true
    _mat.set_shader_parameter("shore_seed", seed_value)
    _mat.set_shader_parameter("curved_shore", true)
var _mat: ShaderMaterial
var _far_mat: ShaderMaterial

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
    # Open water gets a denser grid: the voyage crest walls need vertices to stand up in,
    # and the peaked chop keeps its sharp tops.
    plane.subdivide_width = 190 if is_open_sea else 110
    plane.subdivide_depth = 190 if is_open_sea else 110
    mesh = plane
    _mat = ShaderMaterial.new()
    _mat.shader = load("res://shaders/sea.gdshader")
    _mat.set_shader_parameter("amplitude", amplitude)
    _mat.set_shader_parameter("wave_len", wave_len)
    _mat.set_shader_parameter("storm", storminess)
    _mat.set_shader_parameter("shore_z", Tuning.SHORE_Z)
    _mat.set_shader_parameter("open_sea", open_sea)
    _mat.set_shader_parameter("normal_map", load("res://assets/water/waternormals.jpg"))
    # One dark blue for all water, shallow or deep, calm or storm; only the sky it
    # reflects changes. The crests glow a touch lighter in the same blue.
    _mat.set_shader_parameter("deep_color", Tuning.WATER_COLOR)
    _mat.set_shader_parameter("shallow_color", Tuning.WATER_COLOR)
    _mat.set_shader_parameter("crest_color", Tuning.WATER_COLOR.lightened(0.12))
    if storminess >= 0.6:
        _mat.set_shader_parameter("sky_color", Color(0.45, 0.47, 0.52))
    material_override = _mat
    position = Vector3(center.x, Tuning.SEA_LEVEL, (center.z - 14.0) if open_sea else center.z)
    # A flat far plane to the horizon so the animated patch never shows an edge.
    var far := MeshInstance3D.new()
    var fp := PlaneMesh.new()
    fp.size = Vector2(900, 900)
    far.mesh = fp
    _far_mat = ShaderMaterial.new()
    _far_mat.shader = load("res://shaders/far_sea.gdshader")
    _far_mat.set_shader_parameter("color", Tuning.WATER_COLOR)
    far.material_override = _far_mat
    # Just below the deepest trough: any lower and the patch edge reads as a shelf at the horizon.
    far.position = Vector3(0, -0.35 - amplitude * 1.3, 0)
    add_child(far)

## Recolour the sky the water reflects (the cave's dark pool, dusk). The water itself
## keeps its one blue everywhere; `deep` and `shallow` are kept for the callers' sake.
func set_colors(_deep: Color, _shallow: Color, sky: Color) -> void:
    _mat.set_shader_parameter("sky_color", sky)

## Dark water under the moon.
func set_night() -> void:
    _mat.set_shader_parameter("sky_color", Color(0.12, 0.16, 0.28))
    if _far_mat:
        _far_mat.set_shader_parameter("color", Color(0.02, 0.05, 0.10))

func _process(delta: float) -> void:
    t += delta
    if _mat:
        _mat.set_shader_parameter("sea_time", t)

## Open-sea waves run along x (across the view) instead of z.
func set_wave_axis(along_x: bool) -> void:
    wave_x = along_x
    if _mat:
        _mat.set_shader_parameter("wave_axis", 1.0 if along_x else 0.0)

## The wake astern, by how hard the ship is driving (0 = lying still, 1 = full speed),
## for a hull centred at `center`, `half_w` across and `half_l` long, running toward -z.
func set_wake(strength: float, center: Vector3, half_w: float, half_l: float) -> void:
    if _mat:
        _mat.set_shader_parameter("wake", clampf(strength, 0.0, 1.0))
        _mat.set_shader_parameter("wake_hull", Vector4(center.x, center.z, half_w, half_l))

## Keeps the water below the deck inside the player's hull (see the shader).
func set_hull(center: Vector3, half_length: float, half_width: float, floor_y: float) -> void:
    if _mat:
        _mat.set_shader_parameter("hull", Vector4(center.x, center.z, half_length, half_width))
        _mat.set_shader_parameter("hull_floor", floor_y)

## Travelling swell crests (the voyage levels). Each is Vector4(crest z, break centre x,
## break half width, height). Mirrors the shader exactly so the hull rides the drawn wave.
var _crests: Array[Vector4] = []

func set_wave_crests(list: Array[Vector4]) -> void:
    _crests = list.slice(0, 6)
    if _mat:
        _mat.set_shader_parameter("wave_crest_count", _crests.size())
        if not _crests.is_empty():
            _mat.set_shader_parameter("wave_crests", _crests)

## Water streaming past (m/s): the wave pattern slides, so a ship at anchor reads as under way.
var wave_x := false   # open-sea trains run along x instead of z (see set_wave_axis)
var current := Vector2.ZERO:
    set(v):
        current = v
        if _mat:
            _mat.set_shader_parameter("current", v)

## Whirlpools: Vector4(x, z, radius, depth). Mirrors the shader's funnel.
var _sinks: Array[Vector4] = []

func set_sinks(list: Array[Vector4]) -> void:
    _sinks = list.slice(0, 4)
    if _mat:
        _mat.set_shader_parameter("sink_count", _sinks.size())
        if not _sinks.is_empty():
            _mat.set_shader_parameter("sinks", _sinks)
    if _far_mat:
        # The flat far plane is cut away inside each throat.
        _far_mat.set_shader_parameter("hole_count", _sinks.size())
        if not _sinks.is_empty():
            _far_mat.set_shader_parameter("holes", _sinks)

func sink_dip(qx: float, qz: float) -> float:
    var dip := 0.0
    for s in _sinks:
        var d := Vector2(qx, qz).distance_to(Vector2(s.x, s.y))
        var k := clampf(1.0 - d / s.z, 0.0, 1.0)
        dip += s.w * pow(k, 1.7)
    return dip

## Peaked wave profile: sharp crests, wide troughs (same as `pw` in the shader).
static func _pw(ph: float) -> float:
    var s := 0.5 + 0.5 * sin(ph)
    return pow(s, 2.4) * 2.0 - 1.0

func height(qx: float, qz: float) -> float:
    var x := (qx + current.x * t) / wave_len
    var z := (qz + current.y * t) / wave_len
    var h: float
    if open_sea:
        # Lifted by 0.73 as in the shader: the peaked trains average below zero.
        var a := x if wave_x else z
        var b := z if wave_x else x
        h = amplitude * (_pw(a * 0.32 - t * 1.25) * 0.95
            + _pw((a * 0.21 + b * 0.07) - t * 0.9) * 0.55
            + _pw((a * 0.55 - b * 0.13) - t * 2.0) * 0.28
            + sin(b * 0.4 + t * 0.8) * 0.22
            + 0.73)
    else:
        var w1 := sin(x * 0.35 + t * 1.1)
        var w2 := sin((x + z) * 0.21 - t * 0.8) * 0.6
        var w3 := sin(z * 0.5 + t * 1.6) * 0.35
        var w4 := sin((x * 0.6 - z * 0.4) + t * 1.9) * 0.25
        var chop := (sin(x * 1.3 - t * 3.2) * 0.12 * storminess) if storminess > 0.4 else 0.0
        var s := Decor.shore_z(qx) if _curved else Tuning.SHORE_Z
        var fade := smoothstep(s + 0.5, s + 5.0 + amplitude * 6.0, qz)
        h = amplitude * fade * (w1 + w2 + w3 + w4 + chop)
    h -= sink_dip(qx, qz)
    for c in _crests:
        var d := qz - c.x
        var sigma := 2.3 if d > 0.0 else 3.6
        var r := c.w * exp(-d * d / (sigma * sigma))
        if c.z > 0.001:
            r *= 1.0 + 0.22 * (1.0 - smoothstep(0.75, 1.1, absf(qx - c.y) / c.z))
        h += r
    return h

## Height plus slopes, for hull roll and pitch.
func sample(x: float, z: float) -> Vector3:
    var e := 0.5
    var h := height(x, z)
    var sx := (height(x + e, z) - height(x - e, z)) / (2.0 * e)
    var sz := (height(x, z + e) - height(x, z - e)) / (2.0 * e)
    return Vector3(h, sx, sz)
