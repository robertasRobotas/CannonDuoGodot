## Maelstrom Lane: whirlpools in a storm, real funnels in the water that pull at the hull.
## They open in the ship's own path, 20 to 25 m ahead and a little toward the nearer side
## of the channel, one at a time: the next opens two to four seconds after the last is
## astern. Skirt them. Get drawn into the throat and the ship goes round and down. The sea
## sets gently toward the middle of the channel, so the centre is always the slightly
## easier water. The only wreckage afloat is what goes round in the funnels.
class_name VmWhirl
extends VoyageMode

var pools: Array = []   # {x, z, r, depth, debris: [Node3D]}
var _said := false

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "Through the maelstroms!"
    end_line = "Open water. Breathe, lad."
    intro_line = "Whirlpools ahead! Keep clear of the throats."
    v.lane = 33.0
    has_hearts = false   # no hearts here: the maelstrom takes her whole or not at all
    _rng.seed = int(v.data.get("rock_seed", 1212))   # a level may lay its funnels out its own way
    _next_in = 3.0

var _rng := RandomNumberGenerator.new()
var _next_in := -1.0     # seconds until the next funnel opens (< 0: waiting to pass the last)
var _last: Dictionary = {}
const GROW := 6.0        # seconds a funnel takes to open from a small eddy to its full size

## A funnel opens in the ship's path: 25 to 35 m ahead, and 3 to 5 m from her line toward
## the nearer side of the channel, so the open water is always back toward the middle.
func _spawn_ahead() -> void:
    var sp := v.root.position
    var side := signf(sp.x) if absf(sp.x) > 0.5 else (1.0 if _rng.randf() < 0.5 else -1.0)
    var x := clampf(sp.x + side * _rng.randf_range(3.0, 5.0), -v.lane + 4.0, v.lane - 4.0)
    var z := sp.z - _rng.randf_range(20.0, 25.0)
    _pool(x, z, _rng.randf_range(6.0, 8.0) * 1.25, _rng)
    _last = pools[pools.size() - 1]
    if "--settle" in " ".join(OS.get_cmdline_user_args()) or "--autopilot" in OS.get_cmdline_user_args():
        print("WHIRL funnel at x=%.1f z=%.1f r=%.1f (ship x=%.1f z=%.1f)" % [x, z, _last.r, sp.x, sp.z])

func _pool(x: float, z: float, r: float, rng: RandomNumberGenerator) -> void:
    var p := {"x": x, "z": z, "r": r, "depth": 2.4 + r * 0.12, "age": 0.0, "debris": []}
    # Wreckage going round in it: planks and a couple of barrels.
    for i in 8:
        var d := Debris.new()
        d.setup(v.sea, i % 4 == 0, 0.9)
        v.add_child(d)
        d.set_process(false)
        d.set_meta("ang", rng.randf() * TAU)
        d.set_meta("rad", rng.randf_range(0.3, 0.75) * r)
        p.debris.append(d)
    pools.append(p)

func tick(delta: float) -> void:
    var sp := v.root.position
    var sailing := v.phase == VoyageLevel.Phase.SAILING
    # The set toward the middle: gentle, stronger the further out she is.
    if sailing:
        v._lat_vel += -signf(sp.x) * minf(absf(sp.x) / v.lane, 1.0) * 1.4 * delta
    # The next funnel: a few seconds after the last one is astern (or at the start).
    if sailing and sp.z > -(v.goal - 40.0):
        if _next_in >= 0.0:
            _next_in -= delta
            if _next_in < 0.0:
                _spawn_ahead()
                _next_in = -1.0
        elif _last.is_empty() or float(_last.z) > sp.z + float(_last.r):
            _next_in = _rng.randf_range(2.0, 4.0)
    # Funnels well astern close and their wreckage goes.
    for p: Dictionary in pools.duplicate():
        if float(p.z) > sp.z + 70.0:
            for n: Node3D in p.debris:
                n.queue_free()
            pools.erase(p)
    # The water knows the four nearest funnels, each as open as it has had time to get.
    var near: Array = pools.filter(func(p): return absf(float(p.z) - sp.z) < 85.0)
    near.sort_custom(func(a, b): return absf(float(a.z) - sp.z) < absf(float(b.z) - sp.z))
    var packed: Array[Vector4] = []
    for p: Dictionary in near.slice(0, 4):
        p.age = float(p.age) + delta
        var open := clampf(float(p.age) / GROW, 0.0, 1.0)
        # It starts as a small eddy and widens and deepens as it opens.
        var grow := 0.2 + 0.8 * open
        packed.append(Vector4(float(p.x), float(p.z), float(p.r) * grow, float(p.depth) * (0.25 + 0.75 * open)))
    v.sea.set_sinks(packed)
    for p: Dictionary in near:
        var c := Vector2(float(p.x), float(p.z))
        var d := Vector2(sp.x, sp.z).distance_to(c)
        var r := float(p.r)
        var open := clampf(float(p.age) / GROW, 0.0, 1.0)
        var grow := 0.2 + 0.8 * open
        # The wreckage goes round, faster near the throat.
        for n: Node3D in p.debris:
            var rad := float(n.get_meta("rad"))
            var ang := float(n.get_meta("ang")) + delta * (6.0 / maxf(rad, 1.0)) * open
            n.set_meta("ang", ang)
            var pos := Vector3(c.x + cos(ang) * rad * grow, 0, c.y + sin(ang) * rad * grow)
            pos.y = Tuning.SEA_LEVEL + v.sea.height(pos.x, pos.z) + 0.05
            n.position = pos
            n.rotation.y = -ang
        if d < r * grow * 1.9 and sailing:
            var pull := pow(1.0 - d / (r * grow * 1.9), 2.0) * 9.5 * (0.3 + 0.7 * open)
            var toward := signf(c.x - sp.x)
            v._lat_vel += toward * pull * delta
            v.speed = maxf(v.speed - pull * 0.25 * delta, 2.5)
            if d < r * 1.1 and not _said:
                _said = true
                v._say("She's being drawn in! Hard over!")
                Haptics.rumble(1)
            if d < r * grow * 0.42:
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
