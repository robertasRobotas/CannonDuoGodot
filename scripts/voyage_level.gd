## A voyage at the helm, no cannon: the Captain gives orders and the gunner sails.
##
## mode "sail" (level 2): a sunny morning. Haul the halyard (drag down, with the wind swelling
## as the canvas drops), the camera swings astern, and the ship runs for port: lean her past
## the rocks (tilt the phone, or drag) and the level ends made fast at the pier.
##
## mode "waves" (level 4): storm swell. Crests roll in with a wall of breaking white water in
## them; steer for the green shoulder. Take the white water and the ship rolls over. The last
## wave is a mountain: ride it, fly off its back, done.
class_name VoyageLevel
extends Node3D

signal next_level
signal replay
signal quit

enum Phase { PREP, SAILING, DOCKING, ENDED }

const LANE := 10.0          # how far to port or starboard the helm allows
const CRUISE := {"sail": 8.0, "waves": 7.0}

var data: Dictionary
var settings: Dictionary
var mode := "sail"
var goal := 260.0
var phase := Phase.PREP
var time := 0.0
var hoist := 0.0
var speed := 0.0
var steer := 0.0
var hits := 0
var waves_cleared := 0
var won := false
var autopilot := false
var gyro_on := true

var sea: Sea
var root: Node3D           # the hull's position and attitude; the Ship visual sits inside
var ship: Ship
var camera: Camera3D
var overlay: CanvasLayer
var prompt: Label
var prompt_who: Label
var ui: Control
var spray: CPUParticles3D

var rocks: Array = []       # {x, z, r, hit, grazed}
var crests: Array = []      # {z, bx, bw, h, node, prev, final}
var _steer_touch := 0.0
var _steer_gyro := 0.0
var _drag_id := -1
var _drag_start := Vector2.ZERO
var _hoist_buzz := 0.0
var _next_crest := 0.0
var _final_spawned := false
var _trim := 0.0
var _heel := 0.0
var _wind: AudioStreamPlayer
var _result_up := false

func build(level_data: Dictionary, user_settings: Dictionary) -> void:
    data = level_data
    settings = user_settings
    mode = str(data.get("mode", "sail"))
    goal = float(data.get("dist", 260.0))
    gyro_on = bool(settings.get("gyro", true)) and (Input.get_gyroscope().length() > 0.0 or OS.has_feature("mobile"))
    autopilot = "--autopilot" in OS.get_cmdline_user_args()
    Haptics.muted = false
    _build_sky()
    sea = Sea.new()
    add_child(sea)
    sea.setup(float(data.get("sea", 0.2)), Vector3.ZERO, true, float(data.get("swell", 1.0)))
    root = Node3D.new()
    add_child(root)
    ship = Ship.new()
    ship.setup()
    ship.rotation.y = -PI / 2.0   # bow forward, down the course
    root.add_child(ship)
    ship.set_sail(0.0 if mode == "sail" else 1.0)
    # Bow spray kicks up with speed.
    spray = CPUParticles3D.new()
    spray.amount = 60
    spray.lifetime = 0.7
    spray.local_coords = false
    spray.direction = Vector3(0, 1, -1)
    spray.spread = 35.0
    spray.initial_velocity_min = 2.0
    spray.initial_velocity_max = 4.5
    spray.gravity = Vector3(0, -9, 0)
    spray.scale_amount_min = 0.25
    spray.scale_amount_max = 0.6
    spray.mesh = QuadMesh.new()
    var sm := StandardMaterial3D.new()
    sm.albedo_texture = load("res://assets/particles/whitePuff12.png")
    sm.albedo_color = Color(1, 1, 1, 0.7)
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    spray.material_override = sm
    spray.emitting = false
    root.add_child(spray)
    spray.position = Vector3(0, 0.4, -4.0)
    camera = Camera3D.new()
    camera.fov = 72.0
    camera.near = 0.05
    camera.far = 500.0
    add_child(camera)
    camera.make_current()
    if mode == "sail":
        _build_course_rocks()
        _build_port()
    else:
        phase = Phase.SAILING
        _next_crest = 2.0
    _build_overlay()
    _sounds()
    _say("Hoist the sail, lad!" if mode == "sail" else "Storm swell! Steer where it's green!")

## Sky, sun and haze, matching the battle levels' look.
func _build_sky() -> void:
    var sky_kind := str(data.get("terrain", {}).get("sky", "noon"))
    var env := WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    var pano := PanoramaSkyMaterial.new()
    pano.panorama = load("res://assets/sky/sky_noon.jpg" if sky_kind == "noon" else "res://assets/sky/overcast.hdr")
    pano.energy_multiplier = 1.0 if sky_kind == "noon" else 0.7
    sky.sky_material = pano
    e.background_mode = Environment.BG_SKY
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    e.ambient_light_energy = 0.9 if sky_kind == "noon" else 0.7
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.fog_enabled = true
    e.fog_light_color = Color(0.72, 0.8, 0.88) if sky_kind == "noon" else Color(0.5, 0.55, 0.6)
    e.fog_density = 0.003 if sky_kind == "noon" else 0.006
    e.fog_sky_affect = 0.2
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.light_energy = 1.1 if sky_kind == "noon" else 0.7
    sun.light_color = Color(1.0, 0.95, 0.88) if sky_kind == "noon" else Color(0.85, 0.88, 0.95)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 30.0
    sun.rotation_degrees = Vector3(-50, 40, 0)
    add_child(sun)

func _sounds() -> void:
    if not bool(settings.get("sound", true)):
        return
    var waves := AudioStreamPlayer.new()
    waves.stream = load("res://assets/audio/waves_loop.wav")
    waves.volume_db = -8.0
    add_child(waves)
    waves.play(randf_range(0.0, 20.0))
    _wind = AudioStreamPlayer.new()
    _wind.stream = load("res://assets/audio/wind_loop.wav")
    # The sail level starts with a light air that swells as the canvas drops.
    _wind.volume_db = -26.0 if mode == "sail" else -8.0
    add_child(_wind)
    _wind.play(randf_range(0.0, 6.0))
    if mode == "waves":
        var storm := AudioStreamPlayer.new()
        storm.stream = load("res://assets/audio/rain_loop.wav")
        storm.volume_db = -10.0
        add_child(storm)
        storm.play(randf_range(0.0, 20.0))

# MARK: Course

## Rocks scattered down the lane, always leaving a way through.
func _build_course_rocks() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2024
    var z := -45.0
    while z > -(goal - 50.0):
        var gap_x := rng.randf_range(-6.0, 6.0)   # the safe water this row leaves open
        var n := 1 if rng.randf() < 0.45 else 2
        for i in n:
            var x := gap_x + (rng.randf_range(4.5, 8.5) * (1.0 if i == 0 else -1.0))
            if absf(x) > 11.0:
                continue
            var r := rng.randf_range(1.2, 2.4)
            var pick: String = ["boulder_01", "namaqualand_boulder_02", "namaqualand_cliff_01"][rng.randi_range(0, 2)]
            var m := Models.prop(pick)
            var k := r / (2.5 if pick == "namaqualand_cliff_01" else 0.9)
            m.scale = Vector3(k, k * rng.randf_range(0.9, 1.3), k)
            m.position = Vector3(x, -0.6, z)
            m.rotation.y = rng.randf_range(0.0, TAU)
            add_child(m)
            rocks.append({"x": x, "z": z, "r": r, "hit": false, "grazed": false})
        z -= rng.randf_range(15.0, 24.0)

## The pier at the end of the run: a stone quay, two wooden piers, cargo and the flag.
func _build_port() -> void:
    var zq := -goal - 12.0
    var quay := MeshInstance3D.new()
    var qm := BoxMesh.new()
    qm.size = Vector3(26, 2.2, 10)
    quay.mesh = qm
    quay.material_override = Models.tex_material("large_sandstone_blocks", 0.4)
    quay.position = Vector3(0, 0.1, zq - 5.0)
    add_child(quay)
    var sand := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(60, 1.2, 26)
    sand.mesh = bm
    sand.material_override = Models.tex_material("coast_sand_01", 0.4)
    sand.position = Vector3(0, -0.4, zq - 20.0)
    add_child(sand)
    for px: float in [-4.5, 4.5]:
        var pier := Models.prop("modular_wooden_pier")
        pier.position = Vector3(px, -4.6, zq + 8.0)
        add_child(pier)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for i in 6:
        var prop := Models.prop("wooden_crate_01" if i % 2 == 0 else "wine_barrel_01")
        prop.scale = Vector3.ONE * rng.randf_range(1.1, 1.6)
        prop.position = Vector3(rng.randf_range(-9.0, 9.0), 1.25, zq - 4.0 + rng.randf_range(-2.0, 2.0))
        prop.rotation.y = rng.randf_range(0.0, TAU)
        add_child(prop)
    for i in 5:
        var t := Models.tree("palm_coconut", rng.randf_range(5.0, 7.5))
        t.position = Vector3(rng.randf_range(-24.0, 24.0), 0.2, zq - 16.0 - rng.randf_range(0.0, 6.0))
        add_child(t)
    Atmosphere.ship_flag(self, Vector3(-8.0, 1.2, zq - 3.0))

# MARK: Waves

func _spawn_crest(final := false) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(time * 977.0) + crests.size()
    var c := {
        "z": root.position.z - 110.0,
        "bx": rng.randf_range(-7.0, 7.0),
        "bw": rng.randf_range(5.0, 8.0),
        "h": (4.5 if final else rng.randf_range(1.8, 2.6)),
        "final": final,
        "prev": -1.0,
    }
    if final:
        c.bw = 0.0   # the big one has no white wall: it is all ride
    else:
        # Leave at least a helm's width of green inside the lane on one side.
        c.bw = minf(float(c.bw), LANE + absf(float(c.bx)) - 2.6)
    var node := Node3D.new()
    add_child(node)
    node.position = Vector3(0, 0, c.z)
    # The crest line: a row of foam puffs the whole lane wide.
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var q := QuadMesh.new()
    q.size = Vector2(1, 1)
    mm.mesh = q
    mm.instance_count = 26
    for i in 26:
        var x := -16.0 + i * 1.28
        var s := randf_range(1.6, 2.6) * (1.6 if final else 1.0)
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), Vector3(x, float(c.h) * 0.55, 0)))
    var mi := MultiMeshInstance3D.new()
    mi.multimesh = mm
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff05.png")
    m.albedo_color = Color(1, 1, 1, 0.5)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.add_child(mi)
    if not final:
        # The breaking section: a churning white wall. This is the part that rolls you.
        var churn := CPUParticles3D.new()
        churn.amount = 70
        churn.lifetime = 0.8
        churn.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        churn.emission_box_extents = Vector3(float(c.bw), 0.4, 0.8)
        churn.direction = Vector3(0, 1, 1)
        churn.spread = 25.0
        churn.initial_velocity_min = 2.0
        churn.initial_velocity_max = 5.0
        churn.gravity = Vector3(0, -7, 0)
        churn.scale_amount_min = 0.6
        churn.scale_amount_max = 1.4
        churn.mesh = QuadMesh.new()
        churn.material_override = m.duplicate()
        churn.position = Vector3(float(c.bx), float(c.h) * 0.7, 0)
        node.add_child(churn)
    c["node"] = node
    crests.append(c)

# MARK: Loop

func _process(delta: float) -> void:
    time += delta
    var real_delta := delta / maxf(Engine.time_scale, 0.05)
    _read_gyro(real_delta)
    if autopilot:
        _autopilot(delta)
    match phase:
        Phase.PREP:
            _tick_prep(delta)
        Phase.SAILING:
            _tick_sailing(delta)
        Phase.DOCKING:
            _tick_docking(delta)
        Phase.ENDED:
            pass
    _float_ship(delta)
    _update_camera(real_delta)
    if ui:
        ui.queue_redraw()

func _tick_prep(delta: float) -> void:
    # The halyard slips back if the pull is let go half way.
    if _drag_id < 0:
        hoist = maxf(hoist - delta * 0.25, 0.0)
    ship.set_sail(hoist)
    if _wind:
        _wind.volume_db = lerpf(-26.0, -6.0, hoist)
    if hoist >= 0.98:
        hoist = 1.0
        ship.set_sail(1.0)
        phase = Phase.SAILING
        Haptics.thump()
        _say("Now take the helm. Lean her past the rocks!")

func _tick_sailing(delta: float) -> void:
    var cruise: float = CRUISE[mode]
    speed = move_toward(speed, cruise, delta * (2.6 if mode == "sail" else 4.0))
    steer = clampf(_steer_touch + _steer_gyro, -1.0, 1.0)
    root.position.z -= speed * delta
    root.position.x = clampf(root.position.x + steer * 6.5 * delta * minf(speed / 4.0, 1.0), -LANE, LANE)
    spray.emitting = speed > 2.5
    spray.amount = int(20 + speed * 6.0)
    if mode == "sail":
        _check_rocks()
        if root.position.z < -(goal - 55.0) and prompt.text.find("pier") < 0:
            _say("There's the pier. Bring her in!")
        if root.position.z < -goal:
            phase = Phase.DOCKING
            _say("Easy now...")
    else:
        _tick_crests(delta)

func _check_rocks() -> void:
    for r: Dictionary in rocks:
        var dz: float = absf(float(r.z) - root.position.z)
        if dz > float(r.r) + 2.4:
            continue
        var dx: float = absf(float(r.x) - root.position.x)
        if not bool(r.hit) and dx < float(r.r) + 1.5:
            r.hit = true
            hits += 1
            speed *= 0.45
            _steer_touch = 0.0
            root.position.x += signf(root.position.x - float(r.x)) * 1.2
            Haptics.rumble(2)
            _flash(Color(0.8, 0.1, 0.05, 0.4))
            _splash_at(Vector3(float(r.x), 0.2, float(r.z)))
            if hits >= 3:
                _fail("The hull gave way on the rocks.")
            else:
                _say(["Mind the rocks, lad!", "You'll have us swimming!"][hits - 1])
        elif not bool(r.grazed) and dx < float(r.r) + 3.4:
            r.grazed = true
            Haptics.detent()

func _tick_crests(delta: float) -> void:
    _next_crest -= delta
    if _next_crest <= 0.0 and not _final_spawned:
        if -root.position.z >= goal:
            _spawn_crest(true)
            _final_spawned = true
            _say("Big one! Ride it, lad!")
        else:
            _spawn_crest(false)
        _next_crest = 6.5
    for c: Dictionary in crests.duplicate():
        c.z = float(c.z) + 9.0 * delta
        (c.node as Node3D).position.z = float(c.z)
        var dz := float(c.z) - root.position.z
        if float(c.prev) < 0.0 and dz >= 0.0:
            _cross_crest(c)
        c.prev = dz
        if dz > 25.0:
            (c.node as Node3D).queue_free()
            crests.erase(c)

func _cross_crest(c: Dictionary) -> void:
    if phase != Phase.SAILING:
        return
    if not bool(c.final) and absf(root.position.x - float(c.bx)) < float(c.bw):
        _capsize()
        return
    waves_cleared += 1
    Haptics.thump()
    _splash_at(root.position + Vector3(0, 0, -3))
    if bool(c.final):
        # Over the mountain: a beat of slow motion on the crest, then down its back and done.
        Engine.time_scale = 0.45
        var tw := create_tween()
        tw.set_ignore_time_scale(true)
        tw.tween_interval(1.1)
        tw.tween_callback(func():
            Engine.time_scale = 1.0
            _splash_at(root.position + Vector3(0, 0, -4))
            Haptics.rumble(2)
            _win())

func _tick_docking(delta: float) -> void:
    speed = move_toward(speed, 0.0, delta * 2.2)
    root.position.z -= speed * delta
    root.position.x = move_toward(root.position.x, 2.6, delta * 1.4)
    ship.set_sail(maxf(1.0 - (time - _dock_t()) * 0.6, 0.0))
    if _wind:
        _wind.volume_db = move_toward(_wind.volume_db, -22.0, delta * 8.0)
    if speed <= 0.05 and not _result_up:
        _say("Made fast. Well done, lad.")
        _win()

var _dock_time := -1.0
func _dock_t() -> float:
    if _dock_time < 0.0:
        _dock_time = time
    return _dock_time

## The hull rides the water under bow, stern and both rails, like the battle levels, plus the
## lift of any crest passing beneath.
func _float_ship(delta: float) -> void:
    var p := root.position
    var half_l := Ship.LENGTH * 0.45
    var bow := sea.height(p.x, p.z - half_l)
    var stern := sea.height(p.x, p.z + half_l)
    var port_h := sea.height(p.x - 1.1, p.z)
    var star_h := sea.height(p.x + 1.1, p.z)
    var level_y := Tuning.SEA_LEVEL + (bow + stern + port_h + star_h) / 4.0 + Tuning.SHIP_FREEBOARD
    var trim := clampf(atan2(bow - stern, half_l * 2.0), -0.3, 0.3)
    var heel := clampf(atan2(star_h - port_h, 2.2) * 0.5, -0.2, 0.2)
    for c: Dictionary in crests:
        var dz := float(c.z) - p.z
        var bump: float = float(c.h) * exp(-(dz * dz) / 18.0)
        level_y += bump
        trim += clampf(float(c.h) * dz * exp(-(dz * dz) / 18.0) * 0.08, -0.45, 0.45)
    var follow := minf(delta * 3.5, 1.0)
    root.position.y = lerpf(root.position.y, level_y, follow) if time > 0.1 else level_y
    _trim = lerpf(_trim, trim, follow)
    _heel = lerpf(_heel, heel - steer * 0.3, follow)
    if phase != Phase.ENDED:
        root.rotation = Vector3(_trim, -steer * 0.22, _heel)

func _update_camera(delta: float) -> void:
    var p := root.position
    var want: Vector3
    var look: Vector3
    if phase == Phase.PREP:
        # Standing on deck looking up at the sail, from the quarter.
        want = p + Vector3(5.0, 3.4, 7.0)
        look = p + Vector3(0, 4.5, 0)
    else:
        want = p + Vector3(steer * 1.6, 4.4, 10.5)
        look = p + Vector3(0, 1.2, -10.0)
    camera.global_position = camera.global_position.lerp(want, minf(delta * 3.0, 1.0)) if time > 0.1 else want
    camera.look_at(look, Vector3.UP)

# MARK: Input

func _read_gyro(delta: float) -> void:
    if not gyro_on or phase != Phase.SAILING:
        return
    var rate := -Input.get_gyroscope().y
    if absf(rate) < Tuning.GYRO_DEADZONE:
        rate = 0.0
    _steer_gyro = clampf(_steer_gyro + rate * delta * 1.7, -1.0, 1.0)
    _steer_gyro = move_toward(_steer_gyro, 0.0, delta * 0.55)

func _input(ev: InputEvent) -> void:
    if phase == Phase.ENDED:
        return
    if ev is InputEventScreenTouch:
        var t := ev as InputEventScreenTouch
        if t.pressed and _drag_id < 0:
            _drag_id = t.index
            _drag_start = t.position
        elif not t.pressed and t.index == _drag_id:
            _drag_id = -1
            _steer_touch = 0.0
    elif ev is InputEventScreenDrag and ev.index == _drag_id:
        var d := ev as InputEventScreenDrag
        if phase == Phase.PREP:
            # Hauling the halyard: every pull drops more canvas, with a tick per armful.
            var pulled := (d.position.y - _drag_start.y) / 850.0
            if pulled > 0.0:
                hoist = clampf(hoist + pulled, 0.0, 1.0)
                _drag_start = d.position
                _hoist_buzz += pulled
                if _hoist_buzz > 0.1:
                    _hoist_buzz = 0.0
                    Haptics.tick(hoist)
        elif phase == Phase.SAILING:
            _steer_touch = clampf((d.position.x - _drag_start.x) / 280.0, -1.0, 1.0)

func _autopilot(delta: float) -> void:
    if phase == Phase.PREP:
        hoist = clampf(hoist + delta * 0.5, 0.0, 1.0)
        return
    var target := 0.0
    if mode == "sail":
        var best := 1e9
        for r: Dictionary in rocks:
            var dz := float(r.z) - root.position.z
            if dz < -40.0 or dz > -2.0:
                continue
            if absf(dz) < best:
                best = absf(dz)
                var dx := root.position.x - float(r.x)
                if absf(dx) < float(r.r) + 3.0:
                    target = float(r.x) + signf(dx if dx != 0.0 else 1.0) * (float(r.r) + 3.5)
                else:
                    target = root.position.x
    else:
        target = root.position.x
        for c: Dictionary in crests:
            var dz := float(c.z) - root.position.z
            if dz < -60.0 or dz > -2.0 or bool(c.final):
                continue
            if absf(root.position.x - float(c.bx)) < float(c.bw) + 1.5:
                target = float(c.bx) + _green_side(c) * (float(c.bw) + 2.5)
    _steer_touch = clampf((target - root.position.x) * 0.4, -1.0, 1.0)

# MARK: Ends

func _capsize() -> void:
    phase = Phase.ENDED
    Engine.time_scale = 0.4
    Haptics.rumble(3)
    _splash_at(root.position)
    _say("She's going over!")
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.set_parallel(true)
    tw.tween_property(root, "rotation:z", PI, 1.1).set_ease(Tween.EASE_IN)
    tw.tween_property(root, "position:y", root.position.y - 1.4, 1.4)
    tw.chain().tween_callback(func():
        Engine.time_scale = 1.0
        _fail("The white water rolled her over."))

func _fail(reason: String) -> void:
    phase = Phase.ENDED
    won = false
    _show_result(reason)

func _win() -> void:
    if _result_up:
        return
    phase = Phase.ENDED
    won = true
    var stars := 3
    if mode == "sail":
        stars = 3 if hits == 0 else (2 if hits == 1 else 1)
    _show_result("")
    var score := int(goal) * 10 + (3 - hits) * 500
    var gold := 25 + stars * 15
    get_parent().call_deferred("record_result", int(data.id), true, stars, score, gold, hits)

func _splash_at(at: Vector3) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = 50
    p.lifetime = 0.9
    p.explosiveness = 1.0
    p.direction = Vector3(0, 1, 0)
    p.spread = 60.0
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 7.0
    p.gravity = Vector3(0, -9, 0)
    p.scale_amount_min = 0.3
    p.scale_amount_max = 0.8
    p.mesh = QuadMesh.new()
    p.material_override = spray.material_override
    p.position = at
    add_child(p)
    p.emitting = true
    get_tree().create_timer(1.4).timeout.connect(p.queue_free)

# MARK: Overlay

func _build_overlay() -> void:
    overlay = CanvasLayer.new()
    overlay.layer = 10
    add_child(overlay)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.draw.connect(_draw_ui)
    overlay.add_child(ui)
    prompt_who = Label.new()
    prompt_who.text = "THE CAPTAIN"
    prompt_who.add_theme_font_size_override("font_size", 26)
    prompt_who.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
    prompt_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_who.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    prompt_who.position.y = 150
    overlay.add_child(prompt_who)
    prompt = Label.new()
    prompt.add_theme_font_size_override("font_size", 44)
    prompt.add_theme_color_override("font_color", Color.WHITE)
    prompt.add_theme_constant_override("outline_size", 8)
    prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    prompt.position.y = 185
    overlay.add_child(prompt)

func _say(text: String) -> void:
    prompt.text = text
    prompt.modulate.a = 0.0
    create_tween().tween_property(prompt, "modulate:a", 1.0, 0.25)
    Haptics.pop()

func _flash(color: Color) -> void:
    var f := ColorRect.new()
    f.color = color
    f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    f.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(f)
    var tw := create_tween()
    tw.tween_property(f, "color:a", 0.0, 0.5)
    tw.tween_callback(f.queue_free)

## Progress along the course, hearts, the halyard pictogram, and the steer-away arrows.
func _draw_ui() -> void:
    var w := ui.size.x
    # Course bar across the top: a white track, the ship a little triangle on it.
    var frac := clampf(-root.position.z / goal, 0.0, 1.0)
    ui.draw_rect(Rect2(w * 0.1, 80, w * 0.8, 6), Color(1, 1, 1, 0.25))
    ui.draw_rect(Rect2(w * 0.1, 80, w * 0.8 * frac, 6), Color(1, 1, 1, 0.8))
    var sx := w * 0.1 + w * 0.8 * frac
    ui.draw_colored_polygon(PackedVector2Array([Vector2(sx, 62), Vector2(sx + 12, 86), Vector2(sx - 12, 86)]), Color.WHITE)
    # Hearts (the rocks level).
    if mode == "sail":
        var font := ThemeDB.fallback_font
        ui.draw_string(font, Vector2(w - 220, 100), "♥".repeat(maxi(3 - hits, 0)) + "♡".repeat(mini(hits, 3)), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(1, 1, 1, 0.9))
    if phase == Phase.PREP:
        _draw_haul(Vector2(w * 0.72, ui.size.y * 0.42))
    if mode == "waves" and phase == Phase.SAILING:
        _draw_wave_arrows()

## The halyard: a rope from the yard with a ring handle, a white hand pulling it down,
## and a fill ring showing how much canvas is set.
func _draw_haul(at: Vector2) -> void:
    var k := fmod(time, 1.6) / 1.6
    var pull := sin(k * PI)
    ui.draw_line(at + Vector2(0, -260), at + Vector2(0, pull * 140), Color(1, 1, 1, 0.8), 7.0)
    for i in 5:
        ui.draw_line(at + Vector2(-8, -240 + i * 70), at + Vector2(8, -252 + i * 70), Color(1, 1, 1, 0.5), 4.0)
    var hp := at + Vector2(0, pull * 140)
    ui.draw_arc(hp, 34, 0, TAU, 32, Color.WHITE, 8.0)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1, 1, 1, 0.95)
    sb.set_corner_radius_all(20)
    ui.draw_style_box(sb, Rect2(hp.x - 20, hp.y + 20, 40, 110))
    ui.draw_style_box(sb, Rect2(hp.x - 20, hp.y + 85, 95, 130))
    # Hoist ring.
    ui.draw_arc(at + Vector2(0, -330), 44, -PI / 2.0, -PI / 2.0 + TAU * hoist, 40, Color.WHITE, 9.0)
    ui.draw_arc(at + Vector2(0, -330), 44, 0, TAU, 40, Color(1, 1, 1, 0.25), 9.0)
    # Big down arrow beside the rope.
    var ax := at.x - 90
    ui.draw_line(Vector2(ax, at.y - 180), Vector2(ax, at.y + 60), Color(1, 1, 1, 0.85), 10.0)
    ui.draw_colored_polygon(PackedVector2Array([Vector2(ax, at.y + 100), Vector2(ax - 26, at.y + 52), Vector2(ax + 26, at.y + 52)]), Color(1, 1, 1, 0.85))

## The side of the white water the helm can actually reach: the near shoulder when it lies
## inside the lane, otherwise the far one.
func _green_side(c: Dictionary) -> float:
    var dir := signf(root.position.x - float(c.bx))
    if dir == 0.0:
        dir = 1.0
    if absf(float(c.bx) + dir * (float(c.bw) + 2.5)) > LANE:
        dir = -dir
    return dir

## When white water is ahead, white chevrons point at the green shoulder.
func _draw_wave_arrows() -> void:
    var nearest: Dictionary = {}
    var best := -1e9
    for c: Dictionary in crests:
        var dz := float(c.z) - root.position.z
        if dz > -4.0 or dz < -70.0 or bool(c.final):
            continue
        if dz > best:
            best = dz
            nearest = c
    var w := ui.size.x
    var mid := ui.size.y * 0.42
    if nearest.is_empty():
        if _final_spawned and phase == Phase.SAILING:
            # Ride the big one: chevrons ahead.
            for i in 3:
                var y := mid - i * 54.0 - fmod(time * 90.0, 54.0)
                ui.draw_polyline(PackedVector2Array([Vector2(w / 2 - 50, y + 30), Vector2(w / 2, y), Vector2(w / 2 + 50, y + 30)]), Color(1, 1, 1, 0.8 - i * 0.2), 10.0)
        return
    if absf(root.position.x - float(nearest.bx)) >= float(nearest.bw) + 1.2:
        return   # already in the green
    var dir := _green_side(nearest)
    var pulse := 0.55 + 0.4 * sin(time * 7.0)
    for i in 3:
        var x := w / 2.0 + dir * (120.0 + i * 70.0)
        ui.draw_polyline(PackedVector2Array([Vector2(x - dir * 34, mid - 44), Vector2(x, mid), Vector2(x - dir * 34, mid + 44)]), Color(1, 1, 1, pulse - i * 0.12), 12.0)

## The result panel, in the style of the battle levels.
func _show_result(fail_reason: String) -> void:
    if _result_up:
        return
    _result_up = true
    prompt_who.visible = false
    if not won:
        prompt.text = ""
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var pm := PanelContainer.new()
    var psb := StyleBoxFlat.new()
    psb.bg_color = Color(0.1, 0.09, 0.14, 0.93)
    psb.set_corner_radius_all(36)
    psb.content_margin_left = 50
    psb.content_margin_right = 50
    psb.content_margin_top = 40
    psb.content_margin_bottom = 40
    pm.add_theme_stylebox_override("panel", psb)
    pm.custom_minimum_size = Vector2(880, 0)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 22)
    var head := Label.new()
    head.text = ("Made fast!" if mode == "sail" else "Through the storm!") if won else "Lost her!"
    head.add_theme_font_size_override("font_size", 60)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    var sub := Label.new()
    sub.text = str(data.get("name", "")) if won else fail_reason
    sub.add_theme_font_size_override("font_size", 30)
    sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sub)
    if won:
        var stars := 3 if mode == "waves" else (3 if hits == 0 else (2 if hits == 1 else 1))
        var row := Label.new()
        row.text = "★".repeat(stars) + "☆".repeat(3 - stars)
        row.add_theme_font_size_override("font_size", 110)
        row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
        row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(row)
    for entry: Array in ([["Next island", func(): next_level.emit(), true]] if won else []) + [["Try again", func(): replay.emit(), not won], ["Chart", func(): quit.emit(), false]]:
        var b := Button.new()
        b.text = entry[0]
        b.add_theme_font_size_override("font_size", 38)
        b.custom_minimum_size = Vector2(0, 110)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1.0, 0.58, 0.18) if entry[2] else Color(1, 1, 1, 0.14)
        sb.set_corner_radius_all(55)
        b.add_theme_stylebox_override("normal", sb)
        b.add_theme_stylebox_override("hover", sb)
        b.add_theme_stylebox_override("pressed", sb)
        b.add_theme_color_override("font_color", Color.WHITE)
        b.pressed.connect(entry[1])
        v.add_child(b)
    pm.add_child(v)
    center.add_child(pm)
    overlay.add_child(center)

func _exit_tree() -> void:
    Engine.time_scale = 1.0
