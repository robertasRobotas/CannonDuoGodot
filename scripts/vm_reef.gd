## Reef Run: rocks that are not there until they are. Boils of bubbles and a ring of foam
## give each one away a few seconds before it breaks the surface right in the ship's road.
class_name VmReef
extends VoyageMode

var _reef: Array = []   # {x, z, r, node, state, ring, t}
var _warned := false

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    v.lane = 22.0
    win_title = "Clear of the reef!"
    end_line = "Clear water. Well steered, lad."
    intro_line = "Reef ahead. Watch for the boils."
    var rng := RandomNumberGenerator.new()
    rng.seed = 606
    var z := -50.0
    var gap_x := 0.0
    while z > -(v.goal - 30.0):
        # The gap wanders, but never further between rows than the helm can reach.
        gap_x = clampf(gap_x + rng.randf_range(-9.0, 9.0), -12.0, 12.0)
        var n := 3 if rng.randf() < 0.6 else 5
        var row: Array = []
        for i in n:
            var r := rng.randf_range(1.3, 2.3)
            var x: float
            if i < 2:
                x = gap_x + (r + 4.2 + rng.randf_range(0.0, 3.0)) * (1.0 if i == 0 else -1.0)
            else:
                x = rng.randf_range(-VoyageLevel.ROCK_SPAN, VoyageLevel.ROCK_SPAN)
            var shape := v.rock_shape(r)
            r = float(shape.r)
            if not v._row_fits(row, x, r, gap_x):
                continue
            # Sea stacks as on the sail course; each hides under the water by its own height
            # until it rises.
            var m := v.make_rock(shape)
            var hidden := -1.5 - float(m.get_meta("top"))
            m.position = Vector3(x, hidden, z)
            v.add_child(m)
            var rock := {"x": x, "z": z, "r": r, "node": m, "state": 0, "t": 0.0, "hidden": hidden}
            row.append(rock)
            _reef.append(rock)
        z -= rng.randf_range(16.0, 24.0)

func tick(delta: float) -> void:
    var sz := v.root.position.z
    for rk: Dictionary in _reef:
        var dz: float = sz - float(rk.z)    # metres ahead (positive while ahead)
        if int(rk.state) == 0 and dz < 46.0:
            rk.state = 1
            rk.t = 0.0
            # The boil: bubbles and foam over the rock before it shows.
            var boil := VoyageMode.puffs(50, 0.12, 0.3, 0.7)
            boil.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
            boil.emission_sphere_radius = float(rk.r) * 0.9
            boil.position = Vector3(float(rk.x), Tuning.SEA_LEVEL, float(rk.z))
            v.add_child(boil)
            rk["boil"] = boil
            var ring := VoyageMode.foam_ring(float(rk.r) + 0.8, 0.7)
            ring.position = Vector3(float(rk.x), Tuning.SEA_LEVEL + 0.05, float(rk.z))
            v.add_child(ring)
            rk["ring"] = ring
            if not _warned:
                _warned = true
                v._say("Boils to starboard! A rock's coming up!")
            Haptics.detent()
        elif int(rk.state) == 1:
            rk.t = float(rk.t) + delta
            var k: float = clampf(float(rk.t) / 2.2, 0.0, 1.0)
            var e := 1.0 - pow(1.0 - k, 2.0)
            (rk.node as Node3D).position.y = lerpf(float(rk.hidden), 0.0, e)
            if rk.has("ring"):
                var ring: MeshInstance3D = rk.ring
                ring.scale = Vector3.ONE * (1.0 + 0.5 * sin(float(rk.t) * 5.0))
                ring.material_override.albedo_color.a = 0.75 * (1.0 - k) + 0.1
            if k >= 1.0:
                rk.state = 2
                v.rocks.append({"x": rk.x, "z": rk.z, "r": rk.r, "hit": false, "grazed": false})
                v._splash_at(Vector3(float(rk.x), 0.1, float(rk.z)))
                if rk.has("boil"):
                    (rk.boil as CPUParticles3D).emitting = false
                if rk.has("ring"):
                    (rk.ring as Node3D).queue_free()
    v._check_rocks()

func autopilot_target() -> float:
    # Dodge rocks that are up or coming up, row by row like the sail level does.
    var up: Array = []
    for rk: Dictionary in _reef:
        if int(rk.state) != 0:
            up.append(rk)
    return v.row_target(up)
