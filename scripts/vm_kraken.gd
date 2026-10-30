## The Kraken: the last island. It opens like the storm swell (three crests to ride); then
## the sea begins to turn under the ship, slowly at first, a maelstrom three times the
## Eye's growing to its full width, and out of it the beast's arms come up. The helm is
## no use now: the current carries her round and down toward the mouth in the middle.
## The gun is all we have, laid and loaded as at any castle: drag to aim, pull down to
## load, let go to fire. Shoot the arms until the beast dies; reach the mouth first and she
## breaks up and goes down.
class_name VmKraken
extends VoyageMode

const R := 78.0              # the funnel's full radius (three times the Eye's)
const DEPTH := 14.0
const GROW_TIME := 16.0      # seconds the funnel takes to open fully
const R_START := 58.0        # where the ship is caught
const R_MOUTH := 11.0        # into the mouth
const ROAD_TIME := 90.0      # seconds from the beast's rising to the mouth
const HP := 12               # arms to shoot
const ARM_H := Ship.LENGTH * 2.25
const ARM_COLOR := Color(0.07, 0.26, 0.13)
const INTRO_CRESTS := 3
const ARMS_UP := 2           # arms standing at once

enum Stage { INTRO, OPENING, FIGHT, WON, LOST }

var stage := Stage.INTRO
var hp := HP
var centre := Vector3.ZERO
var radius := R_START
var angle := 0.0
var _t := 0.0                # time in the stage
var _intro_done_at := -1.0
var _arms: Array = []        # {node, pivot, segs, alive, up, t, ring, mat, sunk}
var _balls: Array = []       # {node, pos, vel, t}
var _wrecks: Array = []
var _mouth: Node3D
var _funnel_k := 0.0         # how open the funnel is, 0..1
var _cannon: Node3D
var _dots: Array = []
var _road_t := 0.0           # seconds the road has been closing
# The gun.
var aim_yaw := 0.0
var aim_pitch := 12.0
var power := 0.0
var _reload := 0.0
var _pending := -1
var _aim_touch := -1
var _load_touch := -1
var _touch_start := Vector2.ZERO
var _aim_last := Vector2.ZERO
var _load_start_y := 0.0
var _shots := 0
var _auto_next := 0.0

func build(voyage: VoyageLevel) -> void:
    super.build(voyage)
    win_title = "The Kraken is dead!"
    end_line = "The sea is ours, lad. The whole of it."
    intro_line = "Storm swell! Steer where it's green!"
    has_hearts = false
    v._next_crest = 2.0
    v.goal = 1.0e9          # no last wave: the sea gives way to the beast instead
    v.sea.set_extent(220.0, 200)
    # The storm's thick air would grey out a funnel this wide: thinner haze here.
    if v._env:
        v._env.fog_density = 0.0035
    _build_cannon()
    _build_dots()

func drives() -> bool:
    return stage != Stage.INTRO

func ends_by_distance() -> bool:
    return false

## Three stars for a kill with a third of the road still to run, two for some, one for a
## close thing.
func stars() -> int:
    var left := 1.0 - _road_t / ROAD_TIME
    return 3 if left >= 0.33 else (2 if left >= 0.12 else 1)

## A gun on our deck, by the rail, laid wherever the aim points.
func _build_cannon() -> void:
    _cannon = Models.instance("res://assets/hq/cannon/cannon_01_1k.gltf")
    Models.fit(_cannon, Vector3(0.6, 0.55, 0.95) * 1.2, true)
    _cannon.position = Vector3(v.ship.cannon_mount.x, 1.05, v.ship.cannon_mount.z)
    v.ship.add_child(_cannon)

func _build_dots() -> void:
    var dot_mesh := SphereMesh.new()
    dot_mesh.radius = 0.05
    dot_mesh.height = 0.1
    var dot_mat := StandardMaterial3D.new()
    dot_mat.albedo_color = Color(1, 1, 1, 0.75)
    dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    for k in 40:
        var d := MeshInstance3D.new()
        d.mesh = dot_mesh
        d.material_override = dot_mat
        d.visible = false
        v.add_child(d)
        _dots.append(d)

# MARK: The funnel

func _open_funnel() -> void:
    stage = Stage.OPENING
    _t = 0.0
    if v.autopilot:
        print("KRAKEN funnel opens at t=%.1f" % v.time)
    var p := v.root.position
    var fwd := Vector3(-sin(v._yaw), 0, -cos(v._yaw))
    centre = Vector3(p.x, 0, p.z) + fwd * R_START
    angle = atan2(p.z - centre.z, p.x - centre.x)
    radius = R_START
    v._say("The sea's turning... hold on!")
    Haptics.rumble(1)
    _build_mouth()
    _build_wrecks()

## The mouth at the bottom of the funnel: a lip of dark flesh, three rings of teeth curving
## inward, a black throat ringed inside, and bones of its last meals about the lip.
func _build_mouth() -> void:
    _mouth = Node3D.new()
    _mouth.position = Vector3(centre.x, Tuning.SEA_LEVEL - DEPTH + 1.5, centre.z)
    var flesh := Models.flat_material(Color(0.28, 0.05, 0.07), 0.85)
    var dark := Models.flat_material(Color(0.16, 0.02, 0.04), 0.9)
    var lip := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = R_MOUTH * 0.78
    tm.outer_radius = R_MOUTH * 1.12
    tm.rings = 48
    tm.ring_segments = 12
    lip.mesh = tm
    lip.material_override = flesh
    lip.position.y = 0.2
    _mouth.add_child(lip)
    var gum := MeshInstance3D.new()
    var gm := CylinderMesh.new()
    gm.top_radius = R_MOUTH * 0.8
    gm.bottom_radius = R_MOUTH * 0.5
    gm.height = 4.0
    gm.radial_segments = 32
    gum.mesh = gm
    gum.material_override = dark
    gum.position.y = -1.8
    _mouth.add_child(gum)
    for ring in 3:
        var tr := MeshInstance3D.new()
        var rm := TorusMesh.new()
        rm.inner_radius = R_MOUTH * (0.5 - ring * 0.13)
        rm.outer_radius = R_MOUTH * (0.58 - ring * 0.13)
        rm.rings = 32
        rm.ring_segments = 8
        tr.mesh = rm
        tr.material_override = flesh if ring % 2 == 0 else dark
        tr.position.y = -3.6 - ring * 1.6
        _mouth.add_child(tr)
    var throat := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = R_MOUTH * 0.3
    cm.bottom_radius = 0.3
    cm.height = 10.0
    cm.radial_segments = 20
    throat.mesh = cm
    var thm := StandardMaterial3D.new()
    thm.albedo_color = Color(0.03, 0.0, 0.01)
    thm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    throat.material_override = thm
    throat.position.y = -8.5
    _mouth.add_child(throat)
    var tooth := Models.flat_material(Color(0.9, 0.88, 0.78), 0.55)
    var yellow := Models.flat_material(Color(0.82, 0.76, 0.58), 0.6)
    for i in 40:
        var a := float(i) / 40.0 * TAU
        _tooth(_mouth, Vector3(cos(a) * R_MOUTH * 0.98, 0.8, sin(a) * R_MOUTH * 0.98), randf_range(2.8, 4.0), 0.6, -a, 0.5, tooth)
    for i in 30:
        var a := (float(i) + 0.5) / 30.0 * TAU
        _tooth(_mouth, Vector3(cos(a) * R_MOUTH * 0.72, -0.6, sin(a) * R_MOUTH * 0.72), randf_range(2.0, 3.0), 0.5, -a, 0.7, yellow)
    for i in 24:
        var a := (float(i) + 0.25) / 24.0 * TAU
        _tooth(_mouth, Vector3(cos(a) * R_MOUTH * 0.5, -2.2, sin(a) * R_MOUTH * 0.5), randf_range(1.4, 2.2), 0.4, -a, 0.9, tooth)
    # Bones and a broken keel about the lip.
    var bone := Models.flat_material(Color(0.85, 0.83, 0.74), 0.7)
    for i in 10:
        var a := randf() * TAU
        var b := MeshInstance3D.new()
        var bm := CylinderMesh.new()
        bm.top_radius = 0.14
        bm.bottom_radius = 0.18
        bm.height = randf_range(1.6, 3.2)
        b.mesh = bm
        b.material_override = bone
        b.position = Vector3(cos(a) * R_MOUTH * randf_range(1.05, 1.25), 0.4, sin(a) * R_MOUTH * randf_range(1.05, 1.25))
        b.rotation = Vector3(randf_range(-1.4, 1.4), randf(), randf_range(-1.4, 1.4))
        _mouth.add_child(b)
    v.add_child(_mouth)

func _tooth(parent: Node3D, at: Vector3, h: float, r: float, yaw: float, lean: float, mat: Material) -> void:
    var t := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = r
    cm.height = h
    cm.radial_segments = 7
    t.mesh = cm
    t.material_override = mat
    t.position = at
    t.rotation = Vector3(0.0, yaw, 0.0)
    t.rotate_object_local(Vector3(0, 0, 1), lean)
    parent.add_child(t)

## Wreckage going round in the funnel: broken hulls with a stump of mast, and planks.
func _build_wrecks() -> void:
    var hull_mat := Models.tex_material("brown_planks_07", 1.2, Color(0.4, 0.3, 0.22))
    for i in 7:
        var n := Node3D.new()
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(randf_range(2.4, 3.6), 0.9, randf_range(1.0, 1.4))
        body.mesh = bm
        body.material_override = hull_mat
        body.rotation.z = randf_range(-0.5, 0.5)
        n.add_child(body)
        var mast := MeshInstance3D.new()
        var mm := CylinderMesh.new()
        mm.top_radius = 0.06
        mm.bottom_radius = 0.1
        mm.height = randf_range(1.5, 2.8)
        mast.mesh = mm
        mast.material_override = hull_mat
        mast.position = Vector3(randf_range(-0.6, 0.6), mm.height / 2.0, 0)
        mast.rotation.z = randf_range(-0.7, 0.7)
        n.add_child(mast)
        n.set_meta("ang", randf() * TAU)
        n.set_meta("rad", randf_range(16.0, 62.0))
        v.add_child(n)
        _wrecks.append(n)
    for i in 10:
        var d := Debris.new()
        d.setup(v.sea, i % 4 == 0, 1.1)
        v.add_child(d)
        d.set_process(false)
        d.set_meta("ang", randf() * TAU)
        d.set_meta("rad", randf_range(14.0, 66.0))
        _wrecks.append(d)

func _tick_wrecks(delta: float) -> void:
    for n: Node3D in _wrecks:
        var rad := float(n.get_meta("rad")) - delta * 0.15
        if rad < R_MOUTH + 1.0:
            rad = randf_range(40.0, 66.0)
        n.set_meta("rad", rad)
        var ang := float(n.get_meta("ang")) + delta * (9.0 / maxf(rad, 4.0)) * _funnel_k
        n.set_meta("ang", ang)
        var pos := Vector3(centre.x + cos(ang) * rad, 0, centre.z + sin(ang) * rad)
        pos.y = Tuning.SEA_LEVEL + v.sea.height(pos.x, pos.z) + 0.05
        n.position = pos
        n.rotation.y = -ang

# MARK: Arms

## An arm of the beast: twelve tapering green segments curving up out of the water and
## over at the tip, two rows of pale suckers down the inner side, the skin knobbled.
func _make_arm() -> Dictionary:
    var root := Node3D.new()
    var pivot := Node3D.new()
    root.add_child(pivot)
    var mat := Models.flat_material(ARM_COLOR, 0.45)
    var under := Models.flat_material(Color(0.1, 0.3, 0.17), 0.5)
    var sucker := Models.flat_material(Color(0.6, 0.66, 0.5), 0.8)
    var n := 12
    var y := 0.0
    var bend := 0.0
    var x := 0.0
    var segs: Array = []
    for i in n:
        var k := float(i) / float(n - 1)
        var seg := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        var r0 := lerpf(2.25, 0.33, pow(k, 0.85))
        var r1 := lerpf(2.25, 0.33, pow((float(i) + 1.0) / float(n - 1), 0.85))
        cm.bottom_radius = r0
        cm.top_radius = maxf(r1, 0.14)
        var h := ARM_H / float(n) * 1.12
        cm.height = h
        cm.radial_segments = 14
        seg.mesh = cm
        seg.material_override = mat if i % 3 != 2 else under
        seg.position = Vector3(x, y + h / 2.0, 0)
        seg.rotation.z = bend
        pivot.add_child(seg)
        segs.append(seg)
        if i >= 1 and i < n - 1:
            for side in [-0.55, 0.55]:
                var s := MeshInstance3D.new()
                var sm := SphereMesh.new()
                sm.radius = r0 * 0.26
                sm.height = r0 * 0.4
                sm.radial_segments = 8
                sm.rings = 4
                s.mesh = sm
                s.material_override = sucker
                s.position = Vector3(x - r0 * 0.9, y + h / 2.0, r0 * float(side))
                pivot.add_child(s)
        # Straight for the lower half, then curling over, hard at the tip.
        bend -= 0.04 if k < 0.45 else (0.16 + 0.1 * k)
        x += sin(-bend) * h * 0.5
        y += cos(bend) * h
    root.position.y = Tuning.SEA_LEVEL - ARM_H - 1.0
    v.add_child(root)
    return {"node": root, "pivot": pivot, "segs": segs, "alive": true, "up": 0.0, "t": 0.0, "mat": mat, "sunk": false}

func _arm_at(a: Dictionary, pos: Vector3, face: Vector3) -> void:
    (a.node as Node3D).position = Vector3(pos.x, Tuning.SEA_LEVEL - ARM_H - 1.0, pos.z)
    var d := Vector3(face.x - pos.x, 0, face.z - pos.z)
    if d.length() > 0.01:
        # Turned so the curl of the tip shows in profile from the ship, leaning a little
        # toward her.
        (a.node as Node3D).rotation.y = atan2(d.x, d.z) + PI / 2.0 + (PI * 0.4 if randf() < 0.5 else -PI * 0.4)

## An arm comes up in the water ahead, off the road to one side or the other, facing us.
func _raise_arm() -> void:
    var a := _make_arm()
    var dt := randf_range(2.5, 6.0)
    var ang := angle + (5.5 / maxf(radius, 6.0)) * dt
    var side := 1.0 if _arms.size() % 2 == 0 else -1.0
    var rr := clampf(radius + side * randf_range(11.0, 18.0), R_MOUTH + 10.0, R - 6.0)
    var pos := Vector3(centre.x + cos(ang) * rr, 0, centre.z + sin(ang) * rr)
    _arm_at(a, pos, v.root.position)
    _arms.append(a)

func _tick_arms(delta: float) -> void:
    var up_n := 0
    for a: Dictionary in _arms.duplicate():
        var node := a.node as Node3D
        var pivot := a.pivot as Node3D
        a.t = float(a.t) + delta
        var t := float(a.t)
        # The water's own height here: down the funnel's side, not the level sea.
        var water := Tuning.SEA_LEVEL + v.sea.height(node.position.x, node.position.z)
        if a.sunk:
            a.up = maxf(float(a.up) - delta * 0.9, 0.0)
            node.position.y = water - ARM_H - 1.0 + (ARM_H + 1.0) * float(a.up)
            if float(a.up) <= 0.0:
                node.queue_free()
                _arms.erase(a)
            continue
        up_n += 1
        # Up out of the water over two seconds, then a slow sway.
        a.up = minf(t / 2.0, 1.0)
        node.position.y = water - ARM_H - 1.0 + (ARM_H + 1.0) * float(a.up)
        pivot.rotation.z = sin(t * 1.3 + node.position.x) * 0.07
        pivot.rotation.x = sin(t * 0.9 + node.position.z) * 0.05
        # Standing for its while, then back under.
        if t > 9.0:
            _sink_arm(a)
    if stage == Stage.FIGHT and up_n < ARMS_UP and hp > 0:
        _raise_arm()

func _sink_arm(a: Dictionary) -> void:
    a.sunk = true

# MARK: The gun

## Our heading in the world, and the gun's line from it.
func _forward() -> Vector3:
    return Vector3(-sin(v._yaw), 0, -cos(v._yaw))

func _aim_dir() -> Vector3:
    var y := v._yaw + deg_to_rad(aim_yaw)
    var p := deg_to_rad(aim_pitch)
    return Vector3(-sin(y) * cos(p), sin(p), -cos(y) * cos(p))

func _muzzle() -> Vector3:
    return _cannon.global_position + Vector3(0, 0.35, 0) + _aim_dir() * 0.9

func _launch_speed(pw: float) -> float:
    return Tuning.LAUNCH_SPEED_BASE + pw * Tuning.LAUNCH_SPEED_SCALE

func input(ev: InputEvent) -> bool:
    if stage != Stage.OPENING and stage != Stage.FIGHT:
        return false
    if ev is InputEventScreenTouch:
        var t := ev as InputEventScreenTouch
        if t.pressed:
            if t.position.x > 1179.0 * 0.82 and t.position.y < 2556.0 * 0.12:
                return false   # the pause button
            if _aim_touch < 0 and _load_touch < 0:
                _pending = t.index
                _touch_start = t.position
        else:
            if t.index == _pending:
                _pending = -1
            if t.index == _aim_touch:
                _aim_touch = -1
            elif t.index == _load_touch:
                _load_touch = -1
                _release_load()
        return true
    elif ev is InputEventScreenDrag:
        var d := ev as InputEventScreenDrag
        if d.index == _pending:
            var mv := d.position - _touch_start
            if mv.length() > 24.0:
                _pending = -1
                if mv.y > absf(mv.x) * 0.8 and _reload <= 0.0:
                    _load_touch = d.index
                    _load_start_y = _touch_start.y
                else:
                    _aim_touch = d.index
                    _aim_last = _touch_start
        if d.index == _aim_touch:
            var delta := d.position - _aim_last
            _aim_last = d.position
            aim_yaw = clampf(aim_yaw + delta.x * Tuning.AIM_DEG_PER_PX, -Tuning.YAW_RANGE, Tuning.YAW_RANGE)
            aim_pitch = clampf(aim_pitch - delta.y * Tuning.AIM_DEG_PER_PX, Tuning.PITCH_MIN, Tuning.PITCH_MAX)
        elif d.index == _load_touch:
            var pull := maxf(d.position.y - _load_start_y, 0.0)
            var np := minf(pull / Tuning.DRAG_FULL_POWER_PX, 1.0)
            if int(np / 0.05) > int(power / 0.05):
                Haptics.tick(np)
            power = np
        return true
    return false

func _release_load() -> void:
    var released := power
    power = 0.0
    if released >= Tuning.MIN_FIRE_POWER and _reload <= 0.0:
        _fire(released)

func _fire(pw: float) -> void:
    _reload = Tuning.RELOAD_TIME
    _shots += 1
    var from := _muzzle()
    var vel := _aim_dir() * _launch_speed(pw)
    var ball := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.2
    sm.height = 0.4
    ball.mesh = sm
    ball.material_override = Models.flat_material(Color(0.12, 0.11, 0.14), 0.5, 0.6)
    v.add_child(ball)
    ball.global_position = from
    _balls.append({"node": ball, "pos": from, "vel": vel, "t": 0.0})
    Haptics.thump()
    v._shake = maxf(v._shake, 0.4)
    var puff := VoyageMode.puffs(16, 0.3, 0.8, 0.75)
    puff.one_shot = true
    puff.explosiveness = 1.0
    puff.position = from
    v.add_child(puff)
    v.get_tree().create_timer(1.2).timeout.connect(puff.queue_free)

## Balls fly as at any castle: gravity and nothing else. One that comes to an arm's skin
## wounds it; one that comes to the water splashes.
func _tick_balls(delta: float) -> void:
    for b: Dictionary in _balls.duplicate():
        b.t = float(b.t) + delta
        var vel: Vector3 = b.vel
        vel.y -= Tuning.GRAVITY * delta
        b.vel = vel
        var pos: Vector3 = b.pos
        pos += vel * delta
        b.pos = pos
        var node := b.node as Node3D
        node.global_position = pos
        var hit := _arm_struck(pos)
        if not hit.is_empty():
            node.queue_free()
            _balls.erase(b)
            _hit_arm(hit, pos)
            continue
        if pos.y < Tuning.SEA_LEVEL + v.sea.height(pos.x, pos.z) or float(b.t) > 8.0:
            node.queue_free()
            _balls.erase(b)
            v._splash_at(Vector3(pos.x, Tuning.SEA_LEVEL + v.sea.height(pos.x, pos.z), pos.z))

func _arm_struck(pos: Vector3) -> Dictionary:
    for a: Dictionary in _arms:
        if not a.alive or a.sunk or float(a.up) < 0.3:
            continue
        for seg: MeshInstance3D in a.segs:
            var r: float = (seg.mesh as CylinderMesh).bottom_radius
            if pos.distance_to(seg.global_position) < r + 0.35:
                return a
    return {}

func _hit_arm(a: Dictionary, at: Vector3) -> void:
    a.alive = false
    a.sunk = true
    hp -= 1
    Haptics.crack()
    v._shake = maxf(v._shake, 0.6)
    (a.mat as StandardMaterial3D).albedo_color = Color(0.2, 0.38, 0.24)   # bruised pale
    v._splinters(at)
    var base := (a.node as Node3D).global_position
    v._splash_at(Vector3(base.x, Tuning.SEA_LEVEL, base.z))
    if v.autopilot:
        print("KRAKEN arm hit, hp %d at t=%.1f" % [hp, v.time])
    if hp <= 0:
        _kill()
    elif hp % 4 == 0:
        v._say(["It's hurt! Keep at it!", "Again! It's weakening!"][(hp / 4) % 2])

# MARK: Stages

func _kill() -> void:
    stage = Stage.WON
    _t = 0.0
    for a: Dictionary in _arms:
        a.sunk = true
    v._say("It's dead! The Kraken's dead!")
    Haptics.rumble(3)
    v._shake = 1.5
    if v.autopilot:
        print("KRAKEN dead at t=%.1f" % v.time)

## Into the mouth: the hull breaks on the teeth and she goes down the throat.
func _lose() -> void:
    if v.autopilot:
        print("KRAKEN lost at t=%.1f" % v.time)
    stage = Stage.LOST
    v.phase = VoyageLevel.Phase.ENDED
    Engine.time_scale = 0.6
    Haptics.rumble(3)
    v._shake = 1.5
    v._splinters(v.root.position + Vector3(0, 1.0, 0))
    v._splash_at(v.root.position)
    v._say("The teeth! She's breaking up!")
    var p0 := v.root.position
    var rot0 := v.root.rotation
    var tw := v.create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_method(func(k: float):
        v.root.position = Vector3(centre.x, 0, centre.z).lerp(p0, 1.0 - k * 0.6) + Vector3(0, p0.y - k * (DEPTH + 8.0), 0)
        v.root.rotation = rot0 + Vector3(k * 1.2, 0.0, k * 0.8), 0.0, 1.0, 1.1).set_ease(Tween.EASE_IN)
    tw.tween_callback(func():
        Engine.time_scale = 1.0
        v._fail("The Kraken took her down."))

func _place() -> void:
    var p := centre + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
    var prev := v.root.position
    v.root.position.x = p.x
    v.root.position.z = p.z
    var d := Vector3(p.x - prev.x, 0, p.z - prev.z)
    if d.length() > 0.001:
        v._yaw = atan2(-d.x, -d.z)

func tick(delta: float) -> void:
    if v.phase != VoyageLevel.Phase.SAILING:
        return
    if stage == Stage.INTRO:
        # The storm swell, as on the fourth island; three crests ridden and a breath
        # later, the sea begins to turn.
        # Three crests and no more: once three have been born (ridden or still ahead),
        # none follows.
        var ahead := 0
        for c: Dictionary in v.crests:
            if float(c.prev) < 0.0:
                ahead += 1
        if ahead + v.waves_cleared >= INTRO_CRESTS:
            v._next_crest = 1.0e9
        v._tick_crests(delta)
        if v.waves_cleared >= INTRO_CRESTS and _intro_done_at < 0.0:
            _intro_done_at = v.time
        if _intro_done_at >= 0.0 and v.time - _intro_done_at >= 4.0:
            var packed: Array[Vector4] = []
            v.sea.set_wave_crests(packed)
            for c: Dictionary in v.crests:
                (c.node as Node3D).queue_free()
            v.crests.clear()
            _open_funnel()
        return
    _t += delta
    _reload = maxf(_reload - delta, 0.0)
    # The funnel opens slowly to its full width, and stays; it closes when the beast dies.
    if stage == Stage.WON:
        _funnel_k = maxf(_funnel_k - delta / 2.0, 0.0)
    elif stage == Stage.OPENING:
        _funnel_k = minf(_t / GROW_TIME, 1.0)
        if _funnel_k >= 1.0:
            stage = Stage.FIGHT
            _t = 0.0
            v._say("Kraken! Load and fire, lad, it's the gun or nothing!")
            Haptics.rumble(2)
            if v.autopilot:
                print("KRAKEN rises at t=%.1f" % v.time)
    var packed: Array[Vector4] = [Vector4(centre.x, centre.z, R * (0.35 + 0.65 * _funnel_k), DEPTH * _funnel_k)]
    v.sea.set_sinks(packed)
    if _mouth:
        # The lip sits at the water's height round the mouth's rim (the funnel's side is
        # still high there), so the teeth stand out of the water and the throat goes down.
        var r_now := R * (0.35 + 0.65 * _funnel_k)
        var dip := DEPTH * _funnel_k * pow(clampf(1.0 - R_MOUTH / r_now, 0.0, 1.0), 1.7)
        _mouth.position.y = Tuning.SEA_LEVEL - dip + 0.3
    # The current carries her round; from the beast's rising the road closes on the mouth.
    if stage == Stage.OPENING or stage == Stage.FIGHT:
        if stage == Stage.FIGHT:
            _road_t += delta
            radius = lerpf(R_START, R_MOUTH, minf(_road_t / ROAD_TIME, 1.0))
        angle += (5.5 / maxf(radius, 6.0)) * delta * (0.3 + 0.7 * _funnel_k)
        v.speed = 5.5 * _funnel_k
        v._lat_vel = 0.0
        v.spray.emitting = _funnel_k > 0.5
        _place()
        if radius <= R_MOUTH + 0.01:
            _lose()
            return
    elif stage == Stage.WON:
        # Out of the dying funnel, straight on, and done.
        v.root.position += _forward() * 6.0 * delta
        v.speed = 6.0
        if _t > 2.5:
            if v.autopilot:
                print("KRAKEN won at t=%.1f, stars %d" % [v.time, stars()])
            v._win()
            return
    _tick_wrecks(delta)
    _tick_arms(delta)
    _tick_balls(delta)
    _lay_gun()
    _update_dots()
    if v.autopilot:
        _autopilot(delta)

## The gun turns and lifts with the aim.
func _lay_gun() -> void:
    if _cannon:
        var dir := _aim_dir()
        _cannon.look_at(_cannon.global_position - dir, Vector3.UP)

## The line of the shot, while loading (or faintly at a middling charge).
func _update_dots() -> void:
    var loading := power > 0.01
    var show := stage == Stage.FIGHT or stage == Stage.OPENING
    var pw := power if loading else 0.45
    var vel := _aim_dir() * _launch_speed(pw)
    var origin := _muzzle()
    for i in _dots.size():
        var tt := float(i + 1) * 0.07
        var p := origin + vel * tt + Vector3(0, -0.5 * Tuning.GRAVITY * tt * tt, 0)
        var d := _dots[i] as MeshInstance3D
        if not show or p.y < Tuning.SEA_LEVEL - 2.0:
            d.visible = false
            continue
        d.global_position = p
        d.visible = true
        var sc := (1.2 - 0.6 * float(i) / float(_dots.size() - 1)) * (1.0 if loading else 0.7)
        d.scale = Vector3(sc, sc, sc)

# MARK: Camera and screen

func camera(delta: float) -> bool:
    if stage == Stage.INTRO:
        return false
    # The water patch stays over the funnel.
    v.sea.position.x = centre.x
    v.sea.position.z = centre.z
    var p := v.root.position
    var fwd := _forward()
    # Behind and above her, looking ahead and a little toward the mouth, the lens turning
    # some with the gun.
    # The lens sits behind the gun's line, as at a castle: the ship stays low in the
    # frame and the shot flies up the middle of it wherever the gun is laid.
    var aim := Vector3(-sin(v._yaw + deg_to_rad(aim_yaw)), 0, -cos(v._yaw + deg_to_rad(aim_yaw)))
    var want := p - aim * 10.0 + Vector3(0, 6.5, 0)
    var look := p + aim * 14.0 + Vector3(0, 2.0 + aim_pitch * 0.06, 0)
    if v._shake > 0.005:
        want += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0) * v._shake * 0.3
        v._shake = maxf(v._shake - delta * 1.8, 0.0)
    v.camera.global_position = v.camera.global_position.lerp(want, minf(delta * 2.4, 1.0))
    v.camera.look_at(look, Vector3.UP)
    v.camera.fov = lerpf(v.camera.fov, 74.0, minf(delta * 2.0, 1.0))
    return true

func draw(ui: Control) -> void:
    var w := ui.size.x
    var font := ThemeDB.fallback_font
    if stage == Stage.INTRO:
        v._draw_wave_arrows()
        return
    # The Kraken's life, across the top under the Captain's line.
    var by := 270.0
    ui.draw_string(font, Vector2(w * 0.1, by - 14), "THE KRAKEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.85))
    ui.draw_rect(Rect2(w * 0.1, by, w * 0.8, 22), Color(1, 1, 1, 0.22))
    ui.draw_rect(Rect2(w * 0.1, by, w * 0.8 * float(hp) / float(HP), 22), Color(0.85, 0.15, 0.12, 0.95))
    # The road to the mouth, down the right edge: the ship sinks along it.
    var gx := w - 70.0
    var gy := ui.size.y * 0.3
    var gh := ui.size.y * 0.35
    ui.draw_rect(Rect2(gx, gy, 16, gh), Color(1, 1, 1, 0.22))
    var k := clampf(_road_t / ROAD_TIME, 0.0, 1.0)
    ui.draw_rect(Rect2(gx, gy, 16, gh * k), Color(0.95, 0.4, 0.3, 0.9))
    ui.draw_string(font, Vector2(gx - 110, gy + gh + 44), "THE MOUTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))
    # The charge, as at a castle: a bar on the right while the finger pulls.
    if power > 0.01:
        var px := w - 150.0
        var py := ui.size.y - 120.0 - 420.0
        ui.draw_rect(Rect2(px, py, 40, 420), Color(1, 1, 1, 0.15))
        ui.draw_rect(Rect2(px, py + 420.0 * (1.0 - power), 40, 420.0 * power), Color(1.0, 0.58, 0.18))
        ui.draw_string(font, Vector2(px - 30, py - 16), "%d%%" % int(power * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)

# MARK: Autopilot (debug runs)

func autopilot_target() -> float:
    if stage == Stage.INTRO:
        var target := v.root.position.x
        for c: Dictionary in v.crests:
            var dz := float(c.z) - v.root.position.z
            if dz < -60.0 or dz > -2.0 or bool(c.final):
                continue
            if absf(v.root.position.x - float(c.bx)) < float(c.bw) + 1.5:
                target = float(c.bx) + v._green_side(c) * (float(c.bw) + 2.5)
        return target
    return v.root.position.x

## Lays the gun on the nearest standing arm by trying charges and elevations, then fires.
func _autopilot(delta: float) -> void:
    if "--nofire" in OS.get_cmdline_user_args() or stage != Stage.FIGHT:
        return
    _auto_next -= delta
    if _auto_next > 0.0 or _reload > 0.0:
        return
    var best: Dictionary = {}
    var best_d := INF
    for a: Dictionary in _arms:
        if a.alive and not a.sunk and float(a.up) >= 0.6:
            var d := (a.node as Node3D).global_position.distance_to(v.root.position)
            if d < best_d:
                best_d = d
                best = a
    if best.is_empty():
        return
    var target := (best.node as Node3D).global_position + Vector3(0, ARM_H + 1.0 + ARM_H * 0.4, 0)
    # The arm's root node sits ARM_H + 1 under the water when down and rises with `up`:
    # at full height its base is at the surface, so aim ARM_H * 0.4 above the surface.
    target = Vector3(target.x, Tuning.SEA_LEVEL + ARM_H * 0.4, target.z)
    var origin := v.root.position + Vector3(0, 1.4, 0)
    var to := target - origin
    var flat := Vector2(to.x, to.z)
    aim_yaw = clampf(rad_to_deg(atan2(-flat.x, -flat.y) - v._yaw), -Tuning.YAW_RANGE, Tuning.YAW_RANGE)
    var dx := flat.length()
    var dy := to.y
    var g := Tuning.GRAVITY
    for pw in [0.4, 0.55, 0.7, 0.85, 1.0]:
        var s := _launch_speed(pw)
        var disc := s * s * s * s - g * (g * dx * dx + 2.0 * dy * s * s)
        if disc > 0.0:
            aim_pitch = clampf(rad_to_deg(atan((s * s - sqrt(disc)) / (g * dx))), Tuning.PITCH_MIN, Tuning.PITCH_MAX)
            _auto_next = 1.4
            _fire(pw)
            return
