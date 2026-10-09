## The Hollow: a sea cave. A pirate ship fires into the mouth behind us and the roof starts to
## come down: dust streams from the ceiling where a rock is about to fall. Steer clear, or tap
## it and the bow gun blows it to gravel before it lands.
class_name VmCave
extends VoyageMode

var falling: Array = []   # {x, z, t, node, dust, state}
var _next := 2.5
var _started := false
var _shot := 0
var _ball: MeshInstance3D
var _ball_t := -1.0
var _ball_from := Vector3.ZERO
var _ball_target: Dictionary = {}

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "Out of the Hollow!"
    end_line = "Daylight! We're out!"
    intro_line = "Keep her steady. Not a sound in here."
    if v._env:
        v._env.ambient_light_energy = 0.25
        v._env.fog_light_color = Color(0.1, 0.11, 0.12)
        v._env.fog_density = 0.012
        v._env.background_mode = Environment.BG_COLOR
        v._env.background_color = Color(0.04, 0.045, 0.05)
    v.sea.set_colors(Color(0.04, 0.10, 0.14), Color(0.08, 0.18, 0.22), Color(0.2, 0.22, 0.25))
    var rng := RandomNumberGenerator.new()
    rng.seed = 3434
    var z := 25.0
    while z > -(v.goal + 30.0):
        for side: float in [-1.0, 1.0]:
            var m := Models.prop("namaqualand_cliff_01")
            var k := rng.randf_range(2.3, 2.9)
            m.scale = Vector3(k, k * rng.randf_range(1.3, 1.7), k)
            m.position = Vector3(side * rng.randf_range(19.0, 23.0), -2.0, z)
            m.rotation.y = rng.randf_range(0.0, TAU)
            v.add_child(m)
        z -= 11.0
    var roof := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(44.0, 3.0, v.goal + 90.0)
    roof.mesh = bm
    roof.material_override = Models.tex_material("coast_sand_rocks_02", 0.25, Color(0.35, 0.33, 0.32))
    roof.position = Vector3(0, 15.5, -(v.goal / 2.0) - 15.0)
    v.add_child(roof)
    # Torches along the walls light the way; daylight at the far end.
    z = -10.0
    var i := 0
    while z > -(v.goal + 10.0):
        var side := -1.0 if i % 2 == 0 else 1.0
        var torch := OmniLight3D.new()
        torch.light_color = Color(1.0, 0.7, 0.4)
        torch.light_energy = 2.4
        torch.omni_range = 16.0
        torch.position = Vector3(side * 12.0, 4.0, z)
        v.add_child(torch)
        var f := EnemyShip._flames(0.6)
        f.position = torch.position
        v.add_child(f)
        z -= 24.0
        i += 1
    var day := OmniLight3D.new()
    day.light_color = Color(0.8, 0.9, 1.0)
    day.light_energy = 6.0
    day.omni_range = 60.0
    day.position = Vector3(0, 6.0, -(v.goal + 20.0))
    v.add_child(day)
    # Daylight at the mouth: a soft glare, not a flat sheet.
    var mouth := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(40.0, 30.0)
    mouth.mesh = qm
    var mm := StandardMaterial3D.new()
    mm.albedo_texture = load("res://assets/particles/whitePuff12.png")
    mm.albedo_color = Color(0.9, 0.95, 1.0, 0.95)
    mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mouth.material_override = mm
    mouth.position = Vector3(0, 6.0, -(v.goal + 40.0))
    v.add_child(mouth)
    # The bow gun's ball.
    _ball = MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.16
    sm.height = 0.32
    _ball.mesh = sm
    _ball.material_override = Models.flat_material(Color(0.12, 0.11, 0.13), 0.4, 0.6)
    _ball.visible = false
    v.add_child(_ball)

func tick(delta: float) -> void:
    var sp := v.root.position
    if not _started and v.time > 3.5:
        _started = true
        _cannon_shot_behind()
    if _started:
        _next -= delta
        if _next <= 0.0 and v.phase == VoyageLevel.Phase.SAILING:
            _next = randf_range(1.9, 3.0)
            _drop(Vector3(randf_range(-8.0, 8.0), 0, sp.z - randf_range(36.0, 50.0)))
    for r: Dictionary in falling.duplicate():
        r.t = float(r.t) + delta
        var node: Node3D = r.node
        if int(r.state) == 0:
            # Warning: dust pours from the roof.
            if float(r.t) > 1.4:
                r.state = 1
                r.t = 0.0
                (r.dust as CPUParticles3D).emitting = false
        elif int(r.state) == 1:
            var y := 14.5 - 4.9 * float(r.t) * float(r.t)
            node.position.y = y
            node.rotation.x += delta * 2.0
            if y <= Tuning.SEA_LEVEL + 0.6:
                r.state = 2
                _landed(r)
    # The bow gun's ball in flight.
    if _ball_t >= 0.0:
        _ball_t += delta * 2.8
        if _ball_target.is_empty() or not is_instance_valid(_ball_target.node) or int(_ball_target.state) == 2:
            _ball_t = -1.0
            _ball.visible = false
        elif _ball_t >= 1.0:
            _ball_t = -1.0
            _ball.visible = false
            _shatter(_ball_target)
        else:
            var to: Vector3 = (_ball_target.node as Node3D).global_position
            var p := _ball_from.lerp(to, _ball_t)
            p.y += sin(_ball_t * PI) * 2.0
            _ball.position = p
    v._check_rocks()

## The pirate ship outside fires into the mouth of the cave: the shot that starts it all.
func _cannon_shot_behind() -> void:
    var flash := OmniLight3D.new()
    flash.light_color = Color(1.0, 0.85, 0.6)
    flash.light_energy = 14.0
    flash.omni_range = 50.0
    flash.position = v.root.position + Vector3(4.0, 5.0, 30.0)
    v.add_child(flash)
    var tw := v.create_tween()
    tw.tween_property(flash, "light_energy", 0.0, 0.5)
    tw.tween_callback(flash.queue_free)
    var snd := AudioStreamPlayer.new()
    snd.stream = load("res://assets/audio/cannon_strong.mp3")
    snd.volume_db = 4.0
    v.add_child(snd)
    snd.play()
    snd.finished.connect(snd.queue_free)
    v._shake = 1.2
    Haptics.rumble(3)
    v._say("They're firing into the cave! The roof!")
    var dust := VoyageMode.puffs(80, 0.2, 0.5, 0.45)
    dust.one_shot = true
    dust.explosiveness = 1.0
    dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    dust.emission_box_extents = Vector3(14.0, 0.5, 30.0)
    dust.direction = Vector3(0, -1, 0)
    dust.gravity = Vector3(0, -3, 0)
    dust.position = v.root.position + Vector3(0, 13.0, -20.0)
    v.add_child(dust)
    dust.emitting = true

func _drop(at: Vector3) -> void:
    var m := Models.prop("boulder_01" if randf() < 0.6 else "namaqualand_boulder_02")
    var k := randf_range(1.6, 2.4)
    m.scale = Vector3(k, k, k)
    m.position = Vector3(at.x, 14.5, at.z)
    m.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
    v.add_child(m)
    var dust := VoyageMode.puffs(40, 0.15, 0.4, 0.5)
    dust.direction = Vector3(0, -1, 0)
    dust.gravity = Vector3(0, -4, 0)
    dust.initial_velocity_min = 2.0
    dust.initial_velocity_max = 4.0
    dust.lifetime = 1.4
    dust.position = Vector3(at.x, 14.0, at.z)
    v.add_child(dust)
    falling.append({"x": at.x, "z": at.z, "t": 0.0, "node": m, "dust": dust, "state": 0, "r": k * 0.9})
    Haptics.detent()

func _landed(r: Dictionary) -> void:
    var at := Vector3(float(r.x), Tuning.SEA_LEVEL, float(r.z))
    v._splash_at(at)
    v._shake = maxf(v._shake, 0.5)
    (r.node as Node3D).position.y = -0.5
    (r.dust as Node).queue_free()
    falling.erase(r)
    v.rocks.append({"x": r.x, "z": r.z, "r": r.r, "hit": false, "grazed": false})
    var d := Vector2(v.root.position.x - float(r.x), v.root.position.z - float(r.z)).length()
    if d < float(r.r) + 1.8 and v.phase == VoyageLevel.Phase.SAILING:
        v.take_hit("The roof came down on her.", "Rock on the deck! Clear it!")

## The bow gun: tap a falling rock and the ball goes to it.
func tap(pos: Vector2) -> void:
    if _ball_t >= 0.0 or v.phase != VoyageLevel.Phase.SAILING:
        return
    var best: Dictionary = {}
    var best_d := 260.0
    for r: Dictionary in falling:
        var node: Node3D = r.node
        if v.camera.is_position_behind(node.global_position):
            continue
        var sp := v.camera.unproject_position(node.global_position)
        var d := sp.distance_to(pos)
        if d < best_d:
            best_d = d
            best = r
    if best.is_empty():
        return
    _ball_target = best
    _ball_from = v.root.global_position + Vector3(0, 1.4, -3.5)
    _ball_t = 0.0
    _ball.visible = true
    var flash := VoyageMode.puffs(14, 0.2, 0.5, 0.6)
    flash.one_shot = true
    flash.explosiveness = 1.0
    flash.position = _ball_from
    v.add_child(flash)
    flash.emitting = true
    v.get_tree().create_timer(1.0).timeout.connect(flash.queue_free)
    var snd := AudioStreamPlayer.new()
    snd.stream = load("res://assets/audio/cannon.mp3")
    snd.volume_db = -2.0
    v.add_child(snd)
    snd.play()
    snd.finished.connect(snd.queue_free)
    v._shake = maxf(v._shake, 0.35)
    Haptics.thump()

func _shatter(r: Dictionary) -> void:
    var node: Node3D = r.node
    var at := node.global_position
    falling.erase(r)
    if r.has("dust") and is_instance_valid(r.dust):
        (r.dust as Node).queue_free()
    node.queue_free()
    for i in 7:
        var frag := Models.prop("boulder_01")
        var k := randf_range(0.25, 0.5)
        frag.scale = Vector3(k, k, k)
        frag.position = at
        v.add_child(frag)
        var vel := Vector3(randf_range(-6, 6), randf_range(2, 7), randf_range(-6, 6))
        var tw := v.create_tween()
        tw.set_parallel(true)
        tw.tween_property(frag, "position", at + vel * 1.1 + Vector3(0, -12.0, 0), 1.3).set_ease(Tween.EASE_IN)
        tw.tween_property(frag, "rotation", Vector3(randf_range(-6, 6), randf_range(-6, 6), 0), 1.3)
        tw.chain().tween_callback(frag.queue_free)
    var dust := VoyageMode.puffs(40, 0.25, 0.6, 0.6)
    dust.one_shot = true
    dust.explosiveness = 1.0
    dust.position = at
    v.add_child(dust)
    dust.emitting = true
    v.get_tree().create_timer(1.2).timeout.connect(dust.queue_free)
    _shot += 1
    Haptics.pop()
    v._say(["Good shot!", "Blew it to gravel!", "That's the way, gunner!"][_shot % 3])

func autopilot_target() -> float:
    var sp := v.root.position
    # Shoot the rock most nearly over the lane ahead; steer from the rest.
    if _ball_t < 0.0:
        for r: Dictionary in falling:
            if int(r.state) <= 1 and absf(float(r.x) - sp.x) < 5.0 and sp.z - float(r.z) < 34.0:
                tap(v.camera.unproject_position((r.node as Node3D).global_position))
                break
    var target := sp.x
    for r: Dictionary in falling + v.rocks:
        var dz := float(r.z) - sp.z
        if dz > 2.0 or dz < -45.0:
            continue
        var dx := sp.x - float(r.x)
        var rr := float(r.get("r", 2.0))
        if absf(dx) < rr + 3.0:
            var dir := signf(dx if dx != 0.0 else 1.0)
            var cx := float(r.x) + dir * (rr + 4.0)
            if absf(cx) > v.lane - 0.5:
                cx = float(r.x) - dir * (rr + 4.0)
            target = cx
            break
    return target
