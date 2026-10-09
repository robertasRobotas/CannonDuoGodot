## Graveyard of Ships: the sea after a battle. Hulls on their sides, half under, some still
## burning; oil alight on the water; ash coming down. Thread between the fires and the
## wreckage: fire takes the rigging, a hull takes the planking.
class_name VmWrecks
extends VoyageMode

var hazards: Array = []   # {x, z, r, kind: "hull"|"fire", done}
var _deck_fire: CPUParticles3D
var _fire_until := -1.0

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "Through the graveyard!"
    end_line = "Clear of the wrecks. Poor souls."
    intro_line = "Dead ships ahead. Mind the fires."
    v.lane = 13.0
    if v._env:
        v._env.fog_light_color = Color(0.5, 0.42, 0.36)
        v._env.fog_density = 0.009
        v._env.ambient_light_energy = 0.7
    EnemyShip._split_mesh()
    var rng := RandomNumberGenerator.new()
    rng.seed = 2020
    var z := -45.0
    while z > -(v.goal - 25.0):
        var x := rng.randf_range(-8.0, 8.0)
        _wreck(x, z, rng)
        if rng.randf() < 0.7:
            var fx := x + rng.randf_range(11.0, 14.0) * (1.0 if x < 0.0 else -1.0)
            _fire_patch(fx, z + rng.randf_range(-10.0, 10.0), rng.randf_range(2.0, 2.6))
        z -= rng.randf_range(22.0, 30.0)
    _ash()
    _deck_fire = EnemyShip._flames(1.3)
    _deck_fire.emitting = false
    _deck_fire.position = Vector3(0, 1.4, 1.0)
    v.root.add_child(_deck_fire)

func _wreck(x: float, z: float, rng: RandomNumberGenerator) -> void:
    var len := rng.randf_range(6.0, 9.0)
    var s := len / EnemyShip.HULL_LEN
    var root := Node3D.new()
    root.position = Vector3(x, Tuning.SEA_LEVEL - rng.randf_range(0.6, 1.4), z)
    root.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0))
    v.add_child(root)
    var body := MeshInstance3D.new()
    body.mesh = EnemyShip._parts.body
    body.scale = Vector3(s, s, s)
    root.add_child(body)
    if rng.randf() < 0.5:
        var rig := MeshInstance3D.new()
        rig.mesh = EnemyShip._parts.rig
        rig.scale = Vector3(s, s, s)
        rig.rotation.x = rng.randf_range(0.6, 1.2)
        root.add_child(rig)
    if rng.randf() < 0.75:
        for i in 2:
            var f := EnemyShip._flames(1.8)
            f.position = Vector3(x + (i - 0.5) * len * 0.3, 0.6, z + rng.randf_range(-0.6, 0.6))
            v.add_child(f)
        var sm := EnemyShip._smoke(2.2)
        sm.amount = 24
        sm.lifetime = 4.0
        sm.position = Vector3(x, 1.2, z)
        v.add_child(sm)
        var glow := OmniLight3D.new()
        glow.light_color = Color(1.0, 0.55, 0.2)
        glow.light_energy = 2.5
        glow.omni_range = 9.0
        glow.position = Vector3(x, 1.5, z)
        v.add_child(glow)
    hazards.append({"x": x, "z": z, "r": len * 0.42, "kind": "hull", "done": false})

## Burning oil: low flames across a patch of water, a glow under the smoke.
func _fire_patch(x: float, z: float, r: float) -> void:
    var f := EnemyShip._flames(1.4)
    f.amount = 46
    f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    f.emission_sphere_radius = r
    f.position = Vector3(x, Tuning.SEA_LEVEL + 0.2, z)
    v.add_child(f)
    var sm := EnemyShip._smoke(1.6)
    sm.position = Vector3(x, 0.8, z)
    v.add_child(sm)
    var glow := OmniLight3D.new()
    glow.light_color = Color(1.0, 0.5, 0.15)
    glow.light_energy = 2.0
    glow.omni_range = r * 3.0
    glow.position = Vector3(x, 1.0, z)
    v.add_child(glow)
    hazards.append({"x": x, "z": z, "r": r, "kind": "fire", "done": false})

func _ash() -> void:
    var ash := CPUParticles3D.new()
    ash.amount = 70
    ash.lifetime = 4.0
    ash.local_coords = false
    ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    ash.emission_box_extents = Vector3(16.0, 1.0, 10.0)
    ash.direction = Vector3(0.3, -1, 0)
    ash.spread = 30.0
    ash.initial_velocity_min = 0.6
    ash.initial_velocity_max = 1.4
    ash.gravity = Vector3(0, -0.6, 0)
    ash.scale_amount_min = 0.04
    ash.scale_amount_max = 0.09
    var qm := QuadMesh.new()
    qm.size = Vector2(0.5, 0.5)
    ash.mesh = qm
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(0.3, 0.28, 0.27, 0.8)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    ash.material_override = m
    ash.position = Vector3(0, 8.0, -16.0)
    v.camera.add_child(ash)

func tick(delta: float) -> void:
    var sp := v.root.position
    if _fire_until > 0.0 and v.time > _fire_until:
        _fire_until = -1.0
        _deck_fire.emitting = false
    for h: Dictionary in hazards:
        if bool(h.done):
            continue
        var d := Vector2(sp.x - float(h.x), sp.z - float(h.z)).length()
        if d < float(h.r) + 1.4:
            h.done = true
            if str(h.kind) == "fire":
                _deck_fire.emitting = true
                _fire_until = v.time + 5.0
                v.take_hit("The fire took the rigging.", "Fire on deck! Buckets, now!")
            else:
                v.take_hit("The wreckage opened the hull.", "We've struck a wreck!")
        elif d < float(h.r) + 3.4 and not h.has("grazed"):
            h["grazed"] = true
            Haptics.detent()

func autopilot_target() -> float:
    var sp := v.root.position
    var target := sp.x
    var best := 1e9
    for h: Dictionary in hazards:
        var dz := float(h.z) - sp.z
        if dz > 2.0 or dz < -55.0:
            continue
        if absf(dz) < best:
            var dx := sp.x - float(h.x)
            if absf(dx) < float(h.r) + 4.0:
                best = absf(dz)
                var dir := signf(dx if dx != 0.0 else 1.0)
                var cx := float(h.x) + dir * (float(h.r) + 4.5)
                if absf(cx) > v.lane - 0.5:
                    cx = float(h.x) - dir * (float(h.r) + 4.5)
                target = cx
    return target
