## Maelstrom Lane: whirlpools in the channel, real funnels in the water that pull at the hull.
## Skirt them. Get drawn into the throat and the ship goes round and down.
class_name VmWhirl
extends VoyageMode

var pools: Array = []   # {x, z, r, depth, debris: [Node3D]}
var _said := false

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "Through the maelstroms!"
    end_line = "Open water. Breathe, lad."
    intro_line = "Whirlpools ahead! Keep clear of the throats."
    v.lane = 22.0
    var rng := RandomNumberGenerator.new()
    rng.seed = 1212
    var z := -55.0
    while z > -(v.goal - 25.0):
        var r := rng.randf_range(6.0, 8.0)
        var x := rng.randf_range(-7.0, 7.0)
        _pool(x, z, r, rng)
        if rng.randf() < 0.4:
            # A second pool across the lane, leaving a gap between them.
            var x2 := x + (r + rng.randf_range(10.0, 13.0)) * (1.0 if x < 0.0 else -1.0)
            if absf(x2) < 17.0:
                _pool(x2, z + rng.randf_range(-6.0, 6.0), rng.randf_range(5.5, 7.0), rng)
        z -= rng.randf_range(32.0, 44.0)

func _pool(x: float, z: float, r: float, rng: RandomNumberGenerator) -> void:
    var p := {"x": x, "z": z, "r": r, "depth": 2.4 + r * 0.12, "debris": []}
    # Wreckage going round in it.
    for i in 4:
        var d := Debris.new()
        d.setup(v.sea, i == 0, 0.9)
        v.add_child(d)
        d.set_process(false)
        d.set_meta("ang", rng.randf() * TAU)
        d.set_meta("rad", rng.randf_range(0.3, 0.75) * r)
        p.debris.append(d)
    pools.append(p)

func tick(delta: float) -> void:
    var sp := v.root.position
    # The water knows the four nearest funnels.
    var near: Array = pools.filter(func(p): return absf(float(p.z) - sp.z) < 85.0)
    near.sort_custom(func(a, b): return absf(float(a.z) - sp.z) < absf(float(b.z) - sp.z))
    var packed: Array[Vector4] = []
    for p: Dictionary in near.slice(0, 4):
        packed.append(Vector4(float(p.x), float(p.z), float(p.r), float(p.depth)))
    v.sea.set_sinks(packed)
    for p: Dictionary in near:
        var c := Vector2(float(p.x), float(p.z))
        var d := Vector2(sp.x, sp.z).distance_to(c)
        var r := float(p.r)
        # The wreckage goes round, faster near the throat.
        for n: Node3D in p.debris:
            var rad := float(n.get_meta("rad"))
            var ang := float(n.get_meta("ang")) + delta * (6.0 / maxf(rad, 1.0))
            n.set_meta("ang", ang)
            var pos := Vector3(c.x + cos(ang) * rad, 0, c.y + sin(ang) * rad)
            pos.y = Tuning.SEA_LEVEL + v.sea.height(pos.x, pos.z) + 0.05
            n.position = pos
            n.rotation.y = -ang
        if d < r * 1.9 and v.phase == VoyageLevel.Phase.SAILING:
            var pull := pow(1.0 - d / (r * 1.9), 2.0) * 9.5
            var toward := signf(c.x - sp.x)
            v._lat_vel += toward * pull * delta
            v.speed = maxf(v.speed - pull * 0.25 * delta, 2.5)
            if d < r * 1.1 and not _said:
                _said = true
                v._say("She's being drawn in! Hard over!")
                Haptics.rumble(1)
            if d < r * 0.42:
                _sink_in(p)

## Round and down.
func _sink_in(p: Dictionary) -> void:
    v.phase = VoyageLevel.Phase.ENDED
    Engine.time_scale = 0.6
    Haptics.rumble(3)
    v._say("The maelstrom has her!")
    var c := Vector3(float(p.x), 0, float(p.z))
    var start := v.root.position
    var a0 := atan2(start.z - c.z, start.x - c.x)
    var r0 := Vector2(start.x - c.x, start.z - c.z).length()
    var tw := v.create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_method(func(k: float):
        var ang := a0 + k * TAU * 2.6
        var rad := lerpf(r0, 0.6, k)
        v.root.position = Vector3(c.x + cos(ang) * rad, Tuning.SEA_LEVEL - k * k * 6.0, c.z + sin(ang) * rad)
        v.root.rotation = Vector3(k * 0.7, -ang, k * 1.2), 0.0, 1.0, 3.2).set_ease(Tween.EASE_IN)
    tw.tween_callback(func():
        Engine.time_scale = 1.0
        v._fail("The maelstrom took her down."))

func draw(ui: Control) -> void:
    # Chevrons away from the nearest pool that is pulling.
    var sp := v.root.position
    for p: Dictionary in pools:
        var dz := float(p.z) - sp.z
        if dz > 6.0 or dz < -60.0:
            continue
        var dx := sp.x - float(p.x)
        if absf(dx) < float(p.r) + 2.5:
            var dir := signf(dx if dx != 0.0 else 1.0)
            if absf(float(p.x) + dir * (float(p.r) + 3.0)) > v.lane:
                dir = -dir
            chevrons(ui, dir)
            return

func autopilot_target() -> float:
    var sp := v.root.position
    var target := sp.x
    for p: Dictionary in pools:
        var dz := float(p.z) - sp.z
        if dz > 4.0 or dz < -70.0:
            continue
        var dx := sp.x - float(p.x)
        if absf(dx) < float(p.r) + 4.5:
            var dir := signf(dx if dx != 0.0 else 1.0)
            var cx := float(p.x) + dir * (float(p.r) + 5.0)
            if absf(cx) > v.lane - 0.5:
                cx = float(p.x) - dir * (float(p.r) + 5.0)
            target = cx
            break
    return target
