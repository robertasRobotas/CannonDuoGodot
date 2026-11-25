## The Kraken: the last island. It opens like the storm swell (three crests to ride); then
## the sea begins to turn under the ship, slowly at first, a maelstrom three times the
## Eye's growing to its full width, and out of it the beast's arms come up. The helm is
## no use now: the current carries her round and down toward the mouth in the middle.
## The gun is all we have, laid and loaded as at any castle: turn the phone to aim (or drag,
## with the gyro off), pull down to load, let go to fire. Shoot the arms until the beast dies; reach the mouth first and she
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
var _arms: Array = []        # {node, pivot, alive, up, t, mat, phase, sunk}
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
# Gyro aim, as at a castle: yaw from the phone's turn rate, pitch from gravity, each with a
# reference that slides along past the limit so turning back moves the aim at once.
var _gyro_ready := false
var _yaw_raw := 0.0
var _yaw_offset := 0.0
var _pitch_ref := 0.0
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

const MOUTH_SHADER := preload("res://shaders/kraken_mouth.gdshader")
const TOOTH_SHADER := preload("res://shaders/kraken_tooth.gdshader")
## The mouth's cross-section from the outer skirt (under the water) over the lip and down
## the gullet: (radius in R_MOUTH, height in metres). LIP_INDEX is the crest.
const MOUTH_PROFILE := [Vector2(1.75, -3.0), Vector2(1.45, -1.4), Vector2(1.2, -0.3), Vector2(1.04, 0.75),
    Vector2(0.94, 0.65), Vector2(0.88, 0.0), Vector2(0.82, -1.2), Vector2(0.70, -3.5), Vector2(0.56, -6.0),
    Vector2(0.42, -8.5), Vector2(0.28, -11.5), Vector2(0.15, -14.5), Vector2(0.04, -17.5)]
const LIP_INDEX := 3.5
## Rings of fangs down the gullet: radius (R_MOUTH), height, count, length, how deep it
## is (darkness), and how far it points inward rather than up.
const TOOTH_RINGS := [[0.93, 0.45, 46, 2.2, 0.0, 0.55], [0.80, -1.6, 40, 1.9, 0.3, 0.68], [0.65, -4.4, 32, 1.6, 0.5, 0.8],
    [0.49, -7.2, 26, 1.3, 0.7, 0.88], [0.34, -10.2, 20, 1.0, 0.9, 0.93]]

static var _mouth_mesh_cache: ArrayMesh
static var _mouth_lip_u := 0.34
static var _tooth_mesh_cache: ArrayMesh

## The lathe of MOUTH_PROFILE, smoothed (Catmull-Rom), with folds round the gullet.
static func _mouth_mesh() -> ArrayMesh:
    if _mouth_mesh_cache:
        return _mouth_mesh_cache
    var pts: Array[Vector2] = []
    var sub := 6
    var n := MOUTH_PROFILE.size()
    for i in n - 1:
        var p0: Vector2 = MOUTH_PROFILE[maxi(i - 1, 0)]
        var p1: Vector2 = MOUTH_PROFILE[i]
        var p2: Vector2 = MOUTH_PROFILE[i + 1]
        var p3: Vector2 = MOUTH_PROFILE[mini(i + 2, n - 1)]
        for j in sub:
            var t := float(j) / sub
            var t2 := t * t
            var t3 := t2 * t
            pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
    pts.append(MOUTH_PROFILE[n - 1])
    # Arc length along the profile for UV.x; the crest's share of it for the shader.
    var lens: Array[float] = [0.0]
    for i in range(1, pts.size()):
        var d := Vector2(pts[i].x * R_MOUTH, pts[i].y) - Vector2(pts[i - 1].x * R_MOUTH, pts[i - 1].y)
        lens.append(lens[i - 1] + d.length())
    var total: float = lens[lens.size() - 1]
    _mouth_lip_u = lens[int(LIP_INDEX * sub)] / total
    var sides := 96
    var grid: Array = []   # rows of Vector3
    for i in pts.size():
        var u := lens[i] / total
        var inner := smoothstep(_mouth_lip_u + 0.04, _mouth_lip_u + 0.15, u)
        var row: Array[Vector3] = []
        for j in sides:
            var a := TAU * j / sides
            # Folds down the gullet, twisting a little with depth.
            var fold := 1.0 + inner * 0.06 * sin(a * 18.0 + pts[i].y * 0.12)
            var r := pts[i].x * R_MOUTH * fold
            row.append(Vector3(cos(a) * r, pts[i].y, sin(a) * r))
        grid.append(row)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rows := grid.size()
    for i in rows:
        for j in sides + 1:
            var jj := j % sides
            var p: Vector3 = grid[i][jj]
            var du: Vector3 = grid[mini(i + 1, rows - 1)][jj] - grid[maxi(i - 1, 0)][jj]
            var dv: Vector3 = grid[i][(jj + 1) % sides] - grid[i][(jj - 1 + sides) % sides]
            var nrm := dv.cross(du).normalized()
            if nrm.length() < 0.5:
                nrm = Vector3.UP
            st.set_normal(nrm)
            st.set_uv(Vector2(lens[i] / total, float(j) / sides))
            st.add_vertex(p)
    var w := sides + 1
    for i in rows - 1:
        for j in sides:
            var i0 := i * w + j
            st.add_index(i0)
            st.add_index(i0 + w)
            st.add_index(i0 + 1)
            st.add_index(i0 + 1)
            st.add_index(i0 + w)
            st.add_index(i0 + w + 1)
    st.generate_tangents()
    _mouth_mesh_cache = st.commit()
    return _mouth_mesh_cache

## A fang one metre long: a cone swept along a hook that bends over toward +x, flaring
## at the root.
static func _tooth_mesh() -> ArrayMesh:
    if _tooth_mesh_cache:
        return _tooth_mesh_cache
    var rings := 16
    var sides := 10
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var p := Vector3(0, -0.12, 0)
    for i in rings + 1:
        var k := float(i) / rings
        var th := 1.25 * k * k
        var tan := Vector3(sin(th), cos(th), 0)
        var nx := Vector3(cos(th), -sin(th), 0)
        var r := 0.17 * pow(1.0 - k, 0.85) * (1.0 + 0.6 * (1.0 - smoothstep(0.0, 0.18, k))) + 0.004
        for j in sides + 1:
            var a := TAU * j / sides
            var dir := nx * cos(a) * 0.8 + Vector3(0, 0, 1) * sin(a)   # a little flattened
            st.set_normal((nx * cos(a) + Vector3(0, 0, 1) * sin(a)).normalized())
            st.set_uv(Vector2(k, float(j) / sides))
            st.add_vertex(p + dir * r)
        p += tan * (1.12 / rings)
    var w := sides + 1
    for i in rings:
        for j in sides:
            var i0 := i * w + j
            st.add_index(i0)
            st.add_index(i0 + 1)
            st.add_index(i0 + w)
            st.add_index(i0 + 1)
            st.add_index(i0 + w + 1)
            st.add_index(i0 + w)
    _tooth_mesh_cache = st.commit()
    return _tooth_mesh_cache

## The mouth at the bottom of the funnel: a thick lip of hide rolling into a wet, folded
## gullet that goes black down the throat, and five rings of hooked fangs down it. Built
## about its own origin (the water at the lip).
static func make_mouth() -> Node3D:
    var mouth := Node3D.new()
    var flesh := MeshInstance3D.new()
    flesh.mesh = _mouth_mesh()
    var fm := ShaderMaterial.new()
    fm.shader = MOUTH_SHADER
    fm.set_shader_parameter("lip_u", _mouth_lip_u)
    flesh.material_override = fm
    mouth.add_child(flesh)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7717
    for ring: Array in TOOTH_RINGS:
        var count := int(ring[2])
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _tooth_mesh()
        mm.instance_count = count
        var off := rng.randf() * TAU
        for i in count:
            var a := off + TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / count
            var inward := Vector3(-cos(a), 0, -sin(a))
            var ci := float(ring[5]) + rng.randf_range(-0.08, 0.08)
            var yv := (inward * ci + Vector3.UP * sqrt(maxf(1.0 - ci * ci, 0.05))).normalized()
            var xv := (Vector3.DOWN - yv * yv.dot(Vector3.DOWN)).normalized()
            # Each hook leans a little to one side or the other.
            var side := yv.cross(xv).normalized()
            xv = (xv + side * rng.randf_range(-0.3, 0.3)).normalized()
            var zv := xv.cross(yv).normalized()
            xv = yv.cross(zv).normalized()
            var len := float(ring[3]) * rng.randf_range(0.75, 1.15)
            var base := Vector3(cos(a), 0, sin(a)) * (float(ring[0]) * R_MOUTH - 0.1) + Vector3(0, float(ring[1]), 0)
            mm.set_instance_transform(i, Transform3D(Basis(xv, yv, zv).scaled(Vector3(len, len, len)), base))
        var mi := MultiMeshInstance3D.new()
        mi.multimesh = mm
        var tm := ShaderMaterial.new()
        tm.shader = TOOTH_SHADER
        tm.set_shader_parameter("shade", float(ring[4]))
        mi.material_override = tm
        mouth.add_child(mi)
    return mouth

func _build_mouth() -> void:
    _mouth = make_mouth()
    _mouth.position = Vector3(centre.x, Tuning.SEA_LEVEL - DEPTH + 1.5, centre.z)
    v.add_child(_mouth)
    v.sea.set_hole(centre.x, centre.z, R_MOUTH * 0.9)

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

const TENTACLE_SHADER := preload("res://shaders/tentacle.gdshader")
const ARM_RINGS := 72
const ARM_SIDES := 22
const ARM_HITS := 16

static var _arm_mesh: ArrayMesh
static var _arm_spine: Array = []   # [{pos: Vector3, r: float, k: float}] for hit tests

## Radius of the arm at `k` (0 root .. 1 tip): thick and slightly swollen at the root,
## tapering to a whip.
static func _arm_radius(k: float) -> float:
    return 2.1 * pow(1.0 - k, 0.95) * (1.0 + 0.1 * sin(k * PI * 1.4)) + 0.05

## The bend angle along the arm: leaning back a little low down, then curling over harder
## and harder toward the tip, three quarters of a turn and more: a hook to seize a ship.
static func _arm_theta(k: float) -> float:
    return -0.55 * k + 5.4 * pow(k, 3.4)

## One shared mesh: a tube swept along the curling spine, with UVs for the skin shader.
static func _tentacle_mesh() -> ArrayMesh:
    if _arm_mesh:
        return _arm_mesh
    var L := ARM_H * 1.3
    # The trunk runs on 30 m under the root, so the cut end never shows above the water
    # down the funnel's side.
    var spine: Array = [{"pos": Vector3(0, -30.0, 0), "th": 0.0, "r": _arm_radius(0.0), "k": 0.0, "q": -30.0 / _arm_radius(0.0)}]
    var p := Vector3.ZERO
    var qlen := 0.0
    for i in ARM_RINGS + 1:
        var k := float(i) / ARM_RINGS
        var th := _arm_theta(k)
        var r := _arm_radius(k)
        spine.append({"pos": p, "th": th, "r": r, "k": k, "q": qlen})
        var ds := L / ARM_RINGS
        p += Vector3(sin(th), cos(th), 0.0) * ds
        qlen += ds / maxf(r, 0.12)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in spine.size():
        var e: Dictionary = spine[i]
        var th: float = e.th
        var n := Vector3(cos(th), -sin(th), 0.0)   # toward the inside of the curl
        var b := Vector3(0, 0, 1)
        for j in ARM_SIDES + 1:
            var a := TAU * float(j) / ARM_SIDES
            var dir := n * cos(a) + b * sin(a)
            # A little flatter on the sucker side, as a real arm is.
            var rr: float = e.r * (1.0 - 0.18 * maxf(cos(a), 0.0))
            st.set_normal(dir)
            st.set_uv(Vector2(e.k, float(j) / ARM_SIDES))
            st.set_uv2(Vector2(e.q, 0.0))
            st.add_vertex((e.pos as Vector3) + dir * rr)
    var row := ARM_SIDES + 1
    for i in spine.size() - 1:
        for j in ARM_SIDES:
            var i0 := i * row + j
            var i1 := i0 + row
            st.add_index(i0)
            st.add_index(i0 + 1)
            st.add_index(i1)
            st.add_index(i0 + 1)
            st.add_index(i1 + 1)
            st.add_index(i1)
    st.generate_tangents()   # the skin shader's normal map: suckers and wrinkles in relief
    _arm_mesh = st.commit()
    for h in ARM_HITS:
        var e: Dictionary = spine[1 + int(float(h) / (ARM_HITS - 1) * ARM_RINGS)]
        _arm_spine.append({"pos": e.pos, "r": e.r, "k": e.k})
    return _arm_mesh

## The writhing offset of the shader (shaders/tentacle.gdshader), for the same point here.
static func _writhe(k: float, t: float, ph: float) -> Vector3:
    return Vector3(1.6 * k * k * sin(0.8 * t + ph + 1.0 - 2.5 * k), 0.0, 2.2 * pow(k, 1.6) * sin(1.1 * t + ph - 3.0 * k))

## An arm of the beast: one smooth tapering tentacle curling up out of the water and over
## at the tip, wet mottled skin on its back and two rows of suckers along the inner side.
func _make_arm() -> Dictionary:
    var root := Node3D.new()
    var pivot := Node3D.new()
    root.add_child(pivot)
    var mat := ShaderMaterial.new()
    mat.shader = TENTACLE_SHADER
    var ph := randf() * TAU
    mat.set_shader_parameter("phase", ph)
    var body := MeshInstance3D.new()
    body.mesh = _tentacle_mesh()
    body.material_override = mat
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pivot.add_child(body)
    root.position.y = Tuning.SEA_LEVEL - ARM_H - 1.0
    v.add_child(root)
    return {"node": root, "pivot": pivot, "alive": true, "up": 0.0, "t": 0.0, "mat": mat, "phase": ph, "sunk": false}

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
        (a.mat as ShaderMaterial).set_shader_parameter("t_arm", t)
        # The water's own height here: down the funnel's side, not the level sea.
        var water := Tuning.SEA_LEVEL + v.sea.height(node.position.x, node.position.z)
        (a.mat as ShaderMaterial).set_shader_parameter("water_y", water)
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
                elif not v.gyro_on:   # with the gyro on, the phone aims and the finger only loads
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
        var xf := (a.pivot as Node3D).global_transform
        for e: Dictionary in _arm_spine:
            var at: Vector3 = xf * ((e.pos as Vector3) + _writhe(e.k, float(a.t), float(a.phase)))
            if pos.distance_to(at) < float(e.r) + 0.35:
                return a
    return {}

func _hit_arm(a: Dictionary, at: Vector3) -> void:
    a.alive = false
    a.sunk = true
    hp -= 1
    Haptics.crack()
    v._shake = maxf(v._shake, 0.6)
    (a.mat as ShaderMaterial).set_shader_parameter("bruise", 1.0)
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
    if stage == Stage.OPENING or stage == Stage.FIGHT:
        _gyro_aim(delta)
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

## Aim from the phone's motion while the gyro setting is on. The first reading sets the
## references, so the gun starts where it points now.
func _gyro_aim(delta: float) -> void:
    if not v.gyro_on or v.autopilot:
        _gyro_ready = false
        return
    var grav := Input.get_gravity()
    var pitch_abs := rad_to_deg(atan2(grav.z, -grav.y)) * Tuning.GYRO_GAIN if grav.length() > 0.5 else 0.0
    if not _gyro_ready:
        _gyro_ready = true
        _yaw_raw = 0.0
        _yaw_offset = -aim_yaw
        _pitch_ref = pitch_abs - aim_pitch
        return
    var rate := -Input.get_gyroscope().y
    if absf(rate) < Tuning.GYRO_DEADZONE:
        rate = 0.0
    rate = clampf(rate, -4.0, 4.0)
    _yaw_raw += rad_to_deg(rate) * delta * Tuning.GYRO_GAIN
    var yaw := _yaw_raw - _yaw_offset
    if yaw > Tuning.YAW_RANGE:
        _yaw_offset = _yaw_raw - Tuning.YAW_RANGE
        yaw = Tuning.YAW_RANGE
    elif yaw < -Tuning.YAW_RANGE:
        _yaw_offset = _yaw_raw + Tuning.YAW_RANGE
        yaw = -Tuning.YAW_RANGE
    var pitch := pitch_abs - _pitch_ref
    if pitch > Tuning.PITCH_MAX:
        _pitch_ref = pitch_abs - Tuning.PITCH_MAX
        pitch = Tuning.PITCH_MAX
    elif pitch < Tuning.PITCH_MIN:
        _pitch_ref = pitch_abs - Tuning.PITCH_MIN
        pitch = Tuning.PITCH_MIN
    aim_yaw = lerpf(aim_yaw, yaw, minf(delta * Tuning.GYRO_SMOOTH, 1.0))
    aim_pitch = lerpf(aim_pitch, pitch, minf(delta * Tuning.GYRO_SMOOTH, 1.0))

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
    if "--look-mouth" in OS.get_cmdline_user_args() and _mouth:
        # Debug: from beside the ship, looking down into the mouth.
        var to := (centre - Vector3(p.x, 0, p.z)).normalized()
        want = p - to * 6.0 + Vector3(0, 9.0, 0)
        look = _mouth.global_position + Vector3(0, -2.0, 0)
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
