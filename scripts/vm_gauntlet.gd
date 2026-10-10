## The Gauntlet: a night passage between two cliffs lined with shore batteries. Each gun
## flashes, and a ring of white shows where its ball will land a moment later: be anywhere
## else. Near misses drench the deck; hits hole the hull.
class_name VmGauntlet
extends VoyageMode

var batteries: Array = []   # {pos, light}
var shots: Array = []       # {from, to, t, ring, ball}
var _next := 4.0
var _said := false

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "Through the gauntlet!"
    end_line = "We're through! Not a man lost."
    intro_line = "Batteries on both cliffs. Watch where they aim."
    v.lane = 12.0
    # A bright moon: the cliffs read as cliffs, the rings read on the water.
    if v._env:
        v._env.ambient_light_energy = 0.7
        v._env.fog_density = 0.004
    if v._sun:
        v._sun.light_energy = 0.75
    var rng := RandomNumberGenerator.new()
    rng.seed = 2222
    # Cliffs down both sides.
    var z := 20.0
    while z > -(v.goal + 40.0):
        for side: float in [-1.0, 1.0]:
            var coastal := rng.randf() < 0.5
            var m := Models.prop("coastal_cliff_01" if coastal else "namaqualand_cliff_01")
            var k := rng.randf_range(0.28, 0.38) if coastal else rng.randf_range(2.0, 2.6)
            m.scale = Vector3(k, k * rng.randf_range(0.9, 1.3), k)
            m.position = Vector3(side * rng.randf_range(30.0, 36.0), -1.5, z)
            m.rotation.y = rng.randf_range(0.0, TAU)
            v.add_child(m)
        z -= rng.randf_range(18.0, 26.0)
    # Batteries: a dark gun on a ledge with a brazier beside it.
    z = -30.0
    var i := 0
    while z > -(v.goal - 20.0):
        var side := -1.0 if i % 2 == 0 else 1.0
        _battery(Vector3(side * 19.0, 6.0 + rng.randf_range(0.0, 2.0), z), side)
        if rng.randf() < 0.4:
            _battery(Vector3(-side * 19.0, 5.5 + rng.randf_range(0.0, 2.0), z - 12.0), -side)
        z -= rng.randf_range(34.0, 46.0)
        i += 1
    # A lantern at our own masthead and stern.
    var lamp := OmniLight3D.new()
    lamp.light_color = Color(1.0, 0.8, 0.5)
    lamp.light_energy = 1.6
    lamp.omni_range = 9.0
    lamp.position = Vector3(0, 3.0, 2.5)
    v.root.add_child(lamp)

func _battery(at: Vector3, side: float) -> void:
    var root := Node3D.new()
    root.position = at
    root.rotation.y = PI / 2.0 * side + PI / 2.0
    v.add_child(root)
    var ledge := MeshInstance3D.new()
    var lm := BoxMesh.new()
    lm.size = Vector3(4.0, 0.6, 3.0)
    ledge.mesh = lm
    ledge.material_override = Models.tex_material("coast_sand_rocks_02", 0.5, Color(0.55, 0.52, 0.5))
    ledge.position.y = -0.3
    root.add_child(ledge)
    var carriage := MeshInstance3D.new()
    var cm := BoxMesh.new()
    cm.size = Vector3(0.7, 0.5, 1.1)
    carriage.mesh = cm
    carriage.material_override = Models.tex_material("brown_planks_07", 1.5, Color(0.6, 0.45, 0.35))
    carriage.position.y = 0.25
    root.add_child(carriage)
    var barrel := MeshInstance3D.new()
    var bm := CylinderMesh.new()
    bm.top_radius = 0.14
    bm.bottom_radius = 0.2
    bm.height = 1.6
    barrel.mesh = bm
    barrel.material_override = Models.flat_material(Color(0.12, 0.12, 0.13), 0.4, 0.7)
    barrel.rotation.x = PI / 2.0 - 0.25
    barrel.position = Vector3(0, 0.65, 0.3)
    root.add_child(barrel)
    var fire := EnemyShip._flames(0.7)
    fire.position = Vector3(1.4, 0.3, -0.6)
    root.add_child(fire)
    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.65, 0.3)
    light.light_energy = 1.4
    light.omni_range = 10.0
    light.position = Vector3(1.4, 0.8, -0.6)
    root.add_child(light)
    var flash := OmniLight3D.new()
    flash.light_color = Color(1.0, 0.85, 0.6)
    flash.light_energy = 0.0
    flash.omni_range = 26.0
    flash.position = Vector3(0, 1.0, 1.2)
    root.add_child(flash)
    batteries.append({"pos": at + Vector3(0, 0.8, 0), "flash": flash, "root": root})

func tick(delta: float) -> void:
    var sp := v.root.position
    if not _said and v.time > 2.0:
        _said = true
    _next -= delta
    if _next <= 0.0 and v.phase == VoyageLevel.Phase.SAILING:
        _next = randf_range(2.0, 3.2)
        var near: Array = batteries.filter(func(b): return absf((b.pos as Vector3).z - sp.z) < 55.0 and (b.pos as Vector3).z < sp.z + 10.0)
        if not near.is_empty():
            _fire(near[randi() % near.size()])
    for s: Dictionary in shots.duplicate():
        s.t = float(s.t) + delta
        var k: float = float(s.t) / 1.5
        var from: Vector3 = s.from
        var to: Vector3 = s.to
        var ring: MeshInstance3D = s.ring
        var ball: MeshInstance3D = s.ball
        if k < 1.0:
            # The ball on its arc, the ring tightening where it will land.
            var p := from.lerp(to, k)
            p.y += sin(k * PI) * 9.0
            ball.position = p
            ring.scale = Vector3.ONE * (1.6 - 0.6 * k)
            ring.material_override.albedo_color.a = 0.35 + 0.55 * k
            ring.position.y = Tuning.SEA_LEVEL + v.sea.height(to.x, to.z) + 0.08
        else:
            shots.erase(s)
            ring.queue_free()
            ball.queue_free()
            _land(to)

func _fire(b: Dictionary) -> void:
    var sp := v.root.position
    var aim := sp + Vector3(v._lat_vel * 1.5 + randf_range(-3.5, 3.5), 0, -v.speed * 1.5 + randf_range(-4.0, 4.0))
    aim.y = Tuning.SEA_LEVEL
    var flash: OmniLight3D = b.flash
    flash.light_energy = 12.0
    var tw := v.create_tween()
    tw.tween_property(flash, "light_energy", 0.0, 0.3)
    var puff := VoyageMode.puffs(16, 0.3, 0.7, 0.5)
    puff.one_shot = true
    puff.explosiveness = 1.0
    puff.position = b.pos
    v.add_child(puff)
    puff.emitting = true
    v.get_tree().create_timer(1.2).timeout.connect(puff.queue_free)
    var snd := AudioStreamPlayer3D.new()
    snd.stream = load("res://assets/audio/cannon.mp3")
    snd.bus = &"Sfx"
    snd.volume_db = 2.0
    snd.max_distance = 80.0
    snd.position = b.pos
    v.add_child(snd)
    snd.play()
    snd.finished.connect(snd.queue_free)
    var ring := VoyageMode.foam_ring(2.8, 0.4)
    ring.position = Vector3(aim.x, Tuning.SEA_LEVEL + 0.08, aim.z)
    v.add_child(ring)
    var ball := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.18
    sm.height = 0.36
    ball.mesh = sm
    ball.material_override = Models.flat_material(Color(0.1, 0.09, 0.1), 0.4, 0.5)
    v.add_child(ball)
    shots.append({"from": b.pos, "to": aim, "t": 0.0, "ring": ring, "ball": ball})
    Haptics.detent()

func _land(at: Vector3) -> void:
    v._splash_at(at)
    var big := VoyageMode.puffs(60, 0.3, 0.8, 0.7)
    big.one_shot = true
    big.explosiveness = 1.0
    big.initial_velocity_min = 5.0
    big.initial_velocity_max = 10.0
    big.gravity = Vector3(0, -12, 0)
    big.position = at
    v.add_child(big)
    big.emitting = true
    v.get_tree().create_timer(1.5).timeout.connect(big.queue_free)
    if v.phase != VoyageLevel.Phase.SAILING:
        return
    var d := Vector2(v.root.position.x - at.x, v.root.position.z - at.z).length()
    if d < 3.0:
        v.take_hit("Shot through at the waterline.", "Hit! Hold her together!")
    elif d < 6.5:
        v._shake = 0.6
        Haptics.rumble(1)
        if v.prompt.text.find("Close") < 0:
            v._say("Close one! Keep her moving!")

func autopilot_target() -> float:
    var sp := v.root.position
    var target := sp.x
    for s: Dictionary in shots:
        var to: Vector3 = s.to
        if Vector2(sp.x - to.x, sp.z - to.z).length() < 7.0 or absf(to.z - (sp.z - v.speed * (1.5 - float(s.t)))) < 5.0:
            var dir := signf(sp.x - to.x if sp.x != to.x else 1.0)
            var cx := to.x + dir * 7.0
            if absf(cx) > v.lane - 0.5:
                cx = to.x - dir * 7.0
            return cx
    return target
