## A voyage level's special course, plugged into VoyageLevel: the reef, the whirlpools, the
## maelstrom escape, the burning wrecks, the night gauntlet and the collapsing cave.
## VoyageLevel sails the ship and draws the common UI; the mode builds the course, runs its
## hazards and draws its own pictograms.
class_name VoyageMode
extends RefCounted

var v: VoyageLevel
var win_title := "Clear water!"
var end_line := "Clear water, lad!"
var intro_line := ""
var has_hearts := true

static func make(kind: String) -> VoyageMode:
    match kind:
        "reef": return VmReef.new()
        "whirl": return VmWhirl.new()
        "escape": return VmEscape.new()
        "wrecks": return VmWrecks.new()
        "gauntlet": return VmGauntlet.new()
        "cave": return VmCave.new()
        "kraken": return VmKraken.new()
    return null

func build(voyage: VoyageLevel) -> void:
    v = voyage

## True when the mode moves the ship itself (the escape orbits a whirlpool).
func drives() -> bool:
    return false

## True when sailing `goal` metres ends the level.
func ends_by_distance() -> bool:
    return true

func tick(_delta: float) -> void:
    pass

func draw(_ui: Control) -> void:
    pass

## Return true after placing the camera itself.
func camera(_delta: float) -> bool:
    return false

func autopilot_target() -> float:
    return v.root.position.x

## The stars for a run that is won (modes without hearts give three).
func stars() -> int:
    return 3

func tap(_pos: Vector2) -> void:
    pass

## A mode that works the touch itself (a gun to lay): return true to keep the helm out of it.
func input(_ev: InputEvent) -> bool:
    return false

## Small white chevrons pointing `dir` (−1 left, +1 right) from the middle of the screen.
func chevrons(ui: Control, dir: float, strength: float = 1.0) -> void:
    var w := ui.size.x
    var mid := ui.size.y * 0.42
    var pulse := (0.55 + 0.4 * sin(v.time * 7.0)) * strength
    for i in 3:
        var x := w / 2.0 + dir * (120.0 + i * 70.0)
        ui.draw_polyline(PackedVector2Array([Vector2(x - dir * 34, mid - 44), Vector2(x, mid), Vector2(x - dir * 34, mid + 44)]), Color(1, 1, 1, pulse - i * 0.12), 12.0)

## A ring of foam on the water (a rising rock, a shot about to land).
static func foam_ring(radius: float, alpha: float = 0.8) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = radius * 0.86
    tm.outer_radius = radius
    tm.rings = 32
    tm.ring_segments = 6
    mi.mesh = tm
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(1, 1, 1, alpha)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi

static func puffs(amount: int, size_min: float, size_max: float, alpha: float = 0.6) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = 0.9
    p.direction = Vector3(0, 1, 0)
    p.spread = 45.0
    p.initial_velocity_min = 1.0
    p.initial_velocity_max = 3.0
    p.gravity = Vector3(0, -5, 0)
    p.scale_amount_min = size_min
    p.scale_amount_max = size_max
    p.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, alpha)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    p.material_override = m
    return p
