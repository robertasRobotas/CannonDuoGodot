## A voyage at the helm, no cannon: the Captain gives orders and the gunner sails.
##
## mode "sail" (level 2): a sunny morning. Haul the halyard (drag down, with the wind swelling
## as the canvas drops), the camera swings astern, and the ship runs for port down a gorge:
## cliffs wall the channel either side, so there is no sailing out of it. Lean her past the
## rocks (tilt the phone, or drag) and the level ends made fast at the pier.
##
## mode "waves" (level 4): storm swell. Crests roll in with a wall of breaking white water in
## them; steer for the green shoulder. Take the white water and the ship rolls over. The last
## wave is a mountain: it rears up ahead, and the run is won while it is still well off, the
## ship never touching it.
class_name VoyageLevel
extends Node3D

signal next_level
signal replay
signal quit
signal paused(on: bool)

enum Phase { PREP, SAILING, DOCKING, ENDED }

const LANE := 20.0          # how far to port or starboard the helm allows (default)
const ROCK_SPAN := 18.0     # rocks stand out to here either side of the course, inside the gorge
const GORGE_X := 22.5       # the gorge's cliff faces stand here either side, a hull's width past the lane
var lane := LANE            # a mode may open the channel wider
const CRUISE := {"sail": 8.0, "waves": 7.0, "reef": 8.0, "whirl": 7.0, "escape": 3.0, "wrecks": 6.5, "gauntlet": 8.5, "cave": 6.5}

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
var _dip_cool := 0.0           # seconds until the bow may throw its next sheet of water

var rocks: Array = []       # {x, z, r, hit, grazed}
var _rock_count := 0        # seeds each sea stack's own shape
var _port_arrow: Node3D     # floats over the ship, turning to point at the harbour
var _pier_edge := 0.0       # the great pier's starboard edge in x (sail level)
var _pier_z := 0.0          # ...and how far out to sea it reaches
var _pier_left := 0.0       # the pier head's port edge in x
var _has_pier := false
var _dock_z := 0.0          # where the hull comes to rest: midway along the pier
var _quay_z := 0.0          # the quay's face: a ship still under way here hits it
const BERTH_REACH := 5.0    # how far from the berth the helm may still be to bring her in
var _arrow_yaw := 0.0
var crests: Array = []      # {z, bx, bw, h, node, prev, final}
var _steer_touch := 0.0
var _steer_gyro := 0.0
var _drag_id := -1
var _drag_start := Vector2.ZERO
var _hoist_buzz := 0.0
var _next_crest := 0.0
var _final_spawned := false
const FINAL_CLEAR := 22.5    # the run is won with the last wave still this far ahead
var _trim := 0.0
var _heel := 0.0
var _lat_vel := 0.0        # sideways speed: the helm steers momentum, not position
var _yaw := 0.0            # the bow points where the ship is actually going
var _shake := 0.0          # camera kick from impacts
var _env: Environment
var _sun: DirectionalLight3D
var mode_obj: VoyageMode = null    # the special courses (see VoyageMode)
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _wind: AudioStreamPlayer
var _result_up := false
var is_paused := false
var _pause_menu: Control
var _pause_panel: Control
var _pause_settings: Control

func build(level_data: Dictionary, user_settings: Dictionary) -> void:
    data = level_data
    settings = user_settings
    mode = str(data.get("mode", "sail"))
    goal = float(data.get("dist", 260.0))
    set_gyro(bool(settings.get("gyro", true)))
    autopilot = "--autopilot" in OS.get_cmdline_user_args()
    Haptics.muted = false
    _build_sky()
    sea = Sea.new()
    add_child(sea)
    sea.setup(float(data.get("sea", 0.2)), Vector3.ZERO, true, float(data.get("swell", 1.0)))
    if str(data.get("terrain", {}).get("sky", "noon")) == "night":
        sea.set_colors(Color(0.03, 0.07, 0.14), Color(0.06, 0.14, 0.22), Color(0.12, 0.16, 0.28))
    root = Node3D.new()
    add_child(root)
    ship = Ship.new()
    ship.setup()
    ship.rotation.y = -PI / 2.0   # bow forward, down the course
    root.add_child(ship)
    ship.set_sail(0.0 if mode == "sail" else 1.0)
    # Spray particles: never emit on their own now; the splashes borrow this material.
    spray = CPUParticles3D.new()
    spray.amount = 60
    spray.lifetime = 0.7
    spray.local_coords = false
    spray.direction = Vector3(0, 1, -1)
    spray.spread = 35.0
    spray.initial_velocity_min = 3.5
    spray.initial_velocity_max = 7.0
    spray.gravity = Vector3(0, -13, 0)
    spray.scale_amount_min = 0.14
    spray.scale_amount_max = 0.38
    spray.mesh = QuadMesh.new()
    var sm := StandardMaterial3D.new()
    sm.albedo_texture = load("res://assets/particles/whitePuff12.png")
    sm.albedo_color = Color(1, 1, 1, 0.55)
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
    _build_port_arrow()
    if mode == "waves" or bool(data.get("storm", false)):
        _build_rain()
    if mode == "sail":
        _build_gorge()
        _build_course_rocks()
        _build_port()
    elif mode == "waves":
        phase = Phase.SAILING
        _next_crest = 2.0
    else:
        phase = Phase.SAILING
        mode_obj = VoyageMode.make(mode)
        mode_obj.build(self)
    _build_overlay()
    _sounds()
    if mode_obj:
        _say(mode_obj.intro_line)
    else:
        _say("Hoist the sail, lad!" if mode == "sail" else "Storm swell! Steer where it's green!")

## The gyroscope helm, where the phone has one (the settings toggle).
func set_gyro(on: bool) -> void:
    settings["gyro"] = on
    gyro_on = on and (Input.get_gyroscope().length() > 0.0 or OS.has_feature("mobile"))
    _steer_gyro = 0.0

## Sky, sun and haze, matching the battle levels' look.
func _build_sky() -> void:
    var sky_kind := str(data.get("terrain", {}).get("sky", "noon"))
    var stormy := mode == "waves" or bool(data.get("storm", false))   # a level may ask for the storm
    var night := sky_kind == "night"
    var env := WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    if night and stormy:
        # A clouded night: the overcast dome, barely lit, and no stars behind it.
        var cloud := PanoramaSkyMaterial.new()
        cloud.panorama = load("res://assets/sky/overcast.hdr")
        cloud.energy_multiplier = 0.07
        sky.sky_material = cloud
    elif night:
        var ps := ProceduralSkyMaterial.new()
        ps.sky_top_color = Color(0.01, 0.02, 0.06)
        ps.sky_horizon_color = Color(0.06, 0.09, 0.18)
        ps.ground_horizon_color = Color(0.06, 0.09, 0.18)
        ps.ground_bottom_color = Color(0.02, 0.03, 0.05)
        ps.sun_angle_max = 3.0
        ps.sun_curve = 0.02
        sky.sky_material = ps
        Atmosphere.stars(self, 320)
    else:
        var pano := PanoramaSkyMaterial.new()
        pano.panorama = load("res://assets/sky/sky_noon.jpg" if sky_kind == "noon" else ("res://assets/sky/sky_sunset.jpg" if sky_kind == "sunset" else "res://assets/sky/overcast.hdr"))
        pano.energy_multiplier = 1.0 if sky_kind == "noon" else (1.1 if sky_kind == "sunset" else (0.55 if stormy else 0.7))
        sky.sky_material = pano
    e.background_mode = Environment.BG_SKY
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    e.ambient_light_energy = 0.9 if sky_kind == "noon" else (0.55 if stormy else 0.7)
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.fog_enabled = true
    # The storm sits in thick wet air; the sunny run has only a breath of haze.
    e.fog_light_color = Color(0.72, 0.8, 0.88) if sky_kind == "noon" else (Color(0.9, 0.7, 0.6) if sky_kind == "sunset" else Color(0.44, 0.49, 0.55))
    e.fog_density = 0.003 if sky_kind in ["noon", "sunset"] else (0.011 if stormy else 0.006)
    if mode == "sail":
        e.fog_density = 0.0014   # clear enough to see the hills behind the harbour
    e.fog_sky_affect = 0.35 if stormy else 0.2
    if night:
        e.ambient_light_energy = 0.35
        e.fog_light_color = Color(0.05, 0.07, 0.13)
        e.fog_density = 0.006
    # A level may turn the lights up (`light`, a multiplier on the ambient and the
    # sun or moon) and close the world in with fog: `fog_dist` is how far past the ship
    # anything can be seen, the camera's own distance behind her allowed for.
    var light_k := float(data.get("light", 1.0))
    e.ambient_light_energy *= light_k
    if data.has("fog_dist"):
        var from_ship := 11.0
        e.fog_mode = Environment.FOG_MODE_DEPTH
        e.fog_depth_begin = from_ship * 0.8
        e.fog_depth_end = from_ship + float(data.fog_dist)
        e.fog_depth_curve = 1.0
        e.fog_sky_affect = 1.0
        if night:
            # The fog itself glows with the level's light, so a bright night stays bright.
            e.fog_light_color = Color(0.13, 0.17, 0.26) * minf(light_k / 2.2, 1.6)
    env.environment = e
    _env = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.light_energy = 1.1 if sky_kind == "noon" else (0.5 if stormy else 0.7)
    sun.light_color = Color(1.0, 0.95, 0.88) if sky_kind == "noon" else Color(0.78, 0.83, 0.92)
    if sky_kind == "sunset":
        sun.light_color = Color(1.0, 0.72, 0.48)
        sun.light_energy = 1.2
        sun.rotation_degrees = Vector3(-14, 70, 0)
    elif night:
        # The moon high: low, it lit every crest of the cross swell in the harbour channel
        # into a bright bar across the water.
        sun.light_color = Color(0.58, 0.68, 1.0)
        sun.light_energy = 0.3
        sun.rotation_degrees = Vector3(-62, -35, 0)
    else:
        sun.rotation_degrees = Vector3(-50, 40, 0)
    sun.light_energy *= float(data.get("light", 1.0))
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 30.0
    _sun = sun
    add_child(sun)

## Driving rain, streaking down-wind past the camera.
func _build_rain() -> void:
    var rain := CPUParticles3D.new()
    rain.amount = 260
    rain.lifetime = 0.8
    rain.local_coords = false
    rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    rain.emission_box_extents = Vector3(16.0, 0.5, 16.0)
    rain.direction = Vector3(0, -1, 0)
    rain.spread = 4.0
    rain.initial_velocity_min = 18.0
    rain.initial_velocity_max = 23.0
    rain.gravity = Vector3(0, -6, -4)
    rain.scale_amount_min = 0.5
    rain.scale_amount_max = 0.9
    var q := QuadMesh.new()
    q.size = Vector2(0.025, 0.55)
    rain.mesh = q
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.8, 0.86, 0.92, 0.32)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    rain.material_override = m
    camera.add_child(rain)
    rain.position = Vector3(0, 9.0, -7.0)

func _sounds() -> void:
    if int(settings.get("sound", 100)) <= 0:
        return
    var waves := AudioStreamPlayer.new()
    waves.stream = load("res://assets/audio/waves_loop.wav")
    waves.bus = &"Sfx"
    waves.volume_db = -8.0
    add_child(waves)
    waves.play(randf_range(0.0, 20.0))
    _wind = AudioStreamPlayer.new()
    _wind.stream = load("res://assets/audio/wind_loop.wav")
    _wind.bus = &"Sfx"
    # The sail level starts with a light air that swells as the canvas drops.
    _wind.volume_db = -26.0 if mode == "sail" else -8.0
    add_child(_wind)
    _wind.play(randf_range(0.0, 6.0))
    if mode == "waves":
        var storm := AudioStreamPlayer.new()
        storm.stream = load("res://assets/audio/rain_loop.wav")
        storm.bus = &"Sfx"
        storm.volume_db = -10.0
        add_child(storm)
        storm.play(randf_range(0.0, 20.0))

# MARK: Course

## Rocks scattered down the lane, always leaving a way through: two flank the gap, and
## with the course this wide a few more stand further out.
func _build_course_rocks() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(data.get("rock_seed", 2024))   # a level may lay the rocks out its own way
    var z := -45.0
    var gap_x := 0.0
    while z > -(goal - 50.0):
        # The safe water this row leaves open: it wanders across the wide course, but never
        # further between rows than the helm can reach.
        gap_x = clampf(gap_x + rng.randf_range(-9.0, 9.0), -12.0, 12.0)
        var n := 3 if rng.randf() < 0.4 else 5
        var row: Array = []
        for i in n:
            var r := rng.randf_range(1.2, 2.4)
            var shape := rock_shape(r)
            r = float(shape.r)
            var x: float
            if i < 2:
                # The gap's two gateposts, close either side: a hull's width and little more.
                x = gap_x + (r + 4.0 + rng.randf_range(0.0, 1.0)) * (1.0 if i == 0 else -1.0)
            else:
                # Drawn over the old, wider span (so the course is laid out as it always
                # was), then held inside the gorge.
                x = clampf(rng.randf_range(-23.0, 23.0), -ROCK_SPAN, ROCK_SPAN)
            if not _row_fits(row, x, r, gap_x, 3.6):
                continue
            var holder := make_rock(shape, false)   # bare stone: no foam ring to give it away
            holder.position = Vector3(x, 0.0, z)
            add_child(holder)
            var rock := {"x": x, "z": z, "r": r, "hit": false, "grazed": false}
            row.append(rock)
            rocks.append(rock)
        z -= rng.randf_range(12.0, 18.0)

## A cliff's five rings: the lower three are stone (grey as the rocks in the water; those
## entries are unused). The stone fades into a mossy grey-green at the shoulder ring, where
## the turf begins in that same tone, and the turf deepens to dark green at the peak.
const CLIFF_RINGS: Array = [Color.WHITE, Color.WHITE, Color.WHITE, Color(0.52, 0.62, 0.4), Color(0.28, 0.48, 0.16)]
## A mountain's rings, all grass: deep green in the valleys, lighter up the slopes and tops.
const MOUNTAIN_RINGS: Array = [Color(0.6, 0.8, 0.5), Color(0.7, 0.9, 0.55), Color(0.8, 0.95, 0.65), Color(0.9, 1.0, 0.75), Color(1.0, 1.0, 0.85)]

static var _turf_mat: StandardMaterial3D

## Grass over the cliff tops and the mountains, shaded through vertex colours.
static func _turf_material() -> StandardMaterial3D:
    if _turf_mat == null:
        _turf_mat = Models.tex_material("leafy_grass", 0.08, Color(0.85, 1.0, 0.75)).duplicate()
        _turf_mat.vertex_color_use_as_albedo = true
    return _turf_mat

## The gorge: a wall of cliffs down either side of the course, from behind the start right
## to the quay. Each side is one mesh of tall stone lumps (the rocks' chunks, grown big) in
## two rows: a front row at the waterline and a taller row behind it, staggered, so the wall
## reads as massive rock rather than a fence. Their inner faces stand at GORGE_X, so the
## helm's limit (`lane`) is the cliff, not an invisible line. The tops are turf, and trees
## grow from the lumps' ledges, shoulders and peaks.
func _build_gorge() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 4077
    var zq := -goal - 12.0    # the quay's face: the cliffs run down to it
    for side: float in [-1.0, 1.0]:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var turf := SurfaceTool.new()
        turf.begin(Mesh.PRIMITIVE_TRIANGLES)
        for row in 2:
            var z := 40.0 + rng.randf_range(0.0, 6.0)
            # The front row ends against the quay's end; the back row a little short of it,
            # clear of the houses behind the quay.
            var end := zq + (6.0 if row == 0 else 10.0)
            while z > end:
                var rr := rng.randf_range(5.0, 8.0) * (1.0 if row == 0 else 1.4)
                var hh := rng.randf_range(9.0, 15.0) * (1.0 if row == 0 else 1.6)
                # The lump's jitter reaches 1.3 of its radius: set it back so its nearest
                # face never comes inside GORGE_X.
                var x := side * (GORGE_X + rr * 1.3 + (0.0 if row == 0 else rr * 0.9))
                var size := Vector3(rr, hh, rr * rng.randf_range(0.8, 1.3))
                var rings := _chunk(st, Vector3(x, 0.0, z), size, rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.0), rng, CLIFF_RINGS, turf, 3)
                _plant_cliff(rings, side, rng)
                z -= size.z * rng.randf_range(0.9, 1.2)
        st.generate_normals()
        var mi := MeshInstance3D.new()
        mi.mesh = st.commit()
        mi.material_override = _stone_material()
        add_child(mi)
        turf.generate_normals()
        var top := MeshInstance3D.new()
        top.mesh = turf.commit()
        top.material_override = _turf_material()
        add_child(top)
    _build_hinterland(zq, rng)
    _flush_trees()

## Trees on one lump of the gorge: a pine on most peaks, two to four trees on the upper
## shoulder (the ring below the peak), and shrubs on the ledge at mid height on the side
## that faces the channel. Each is sunk a little into the stone, so it grows out of the rock.
func _plant_cliff(rings: Array, side: float, rng: RandomNumberGenerator) -> void:
    var ledge: Array = rings[rings.size() - 3]
    var shoulder: Array = rings[rings.size() - 2]
    var peak: Vector3 = rings[rings.size() - 1][0]
    if rng.randf() < 0.7:
        _tree("pine", peak, rng.randf_range(4.5, 7.5), rng)
    for i in rng.randi_range(2, 4):
        var p: Vector3 = shoulder[rng.randi_range(0, shoulder.size() - 1)]
        if p.y < 1.5:
            continue   # too near the water
        var kind: String = ["oak_small", "maple", "palm_plant", "pine", "oak_medium"][rng.randi_range(0, 4)]
        var h := rng.randf_range(1.6, 2.6) if kind == "palm_plant" else rng.randf_range(3.0, 5.5)
        _tree(kind, p, h, rng)
    for i in rng.randi_range(1, 2):
        var p: Vector3 = ledge[rng.randi_range(0, ledge.size() - 1)]
        # Only ledges that face the channel show from the water.
        if p.y < 1.2 or p.x * side > absf(peak.x):
            continue
        _tree("palm_plant" if rng.randf() < 0.6 else "oak_small", p, rng.randf_range(1.4, 2.4), rng)

## The land behind the harbour town: green ground out to the sides and far back, a range of
## mountains across the whole width behind it (green slopes, bare peaks), and woods between.
func _build_hinterland(zq: float, rng: RandomNumberGenerator) -> void:
    var grass := Models.tex_material("leafy_grass", 0.05, Color(0.8, 0.9, 0.7))
    # Ground: the main sweep behind the town's sand, and two strips either side of the quay
    # under the cliffs' ends.
    _block(Vector3(0.0, -0.4, zq - 130.0), Vector3(600.0, 1.0, 200.0), grass)
    for side: float in [-1.0, 1.0]:
        _block(Vector3(side * 160.0, -0.4, zq - 12.0), Vector3(280.0, 1.0, 36.0), grass)
    # The mountains: two rows of massifs, the back row higher. Each massif is a tall lump
    # with two or three lower ones leaning on its flanks, so it has shoulders, not one spike.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for row in 2:
        var x := -260.0 + rng.randf_range(0.0, 20.0)
        while x < 260.0:
            var rr := rng.randf_range(16.0, 26.0) * (1.0 if row == 0 else 1.5)
            var hh := rng.randf_range(22.0, 40.0) * (1.0 if row == 0 else 1.7)
            var z := zq - (58.0 if row == 0 else 105.0) - rng.randf_range(0.0, 15.0)
            var rings := _chunk(st, Vector3(x, 0.0, z), Vector3(rr, hh, rr * rng.randf_range(0.7, 1.1)), rng.randf_range(0.0, TAU), rng.randf_range(0.85, 1.0), rng, MOUNTAIN_RINGS)
            _plant_mountain(rings, z, 50, rng)
            for k in rng.randi_range(2, 3):
                var a := rng.randf_range(0.0, TAU)
                var d := rr * rng.randf_range(0.6, 1.1)
                var fr := rr * rng.randf_range(0.5, 0.8)
                var fh := hh * rng.randf_range(0.4, 0.7)
                var fz := z + sin(a) * d * 0.6
                rings = _chunk(st, Vector3(x + cos(a) * d, 0.0, fz), Vector3(fr, fh, fr * rng.randf_range(0.7, 1.2)), rng.randf_range(0.0, TAU), rng.randf_range(0.85, 1.0), rng, MOUNTAIN_RINGS)
                _plant_mountain(rings, fz, 30, rng)
            x += rr * rng.randf_range(1.5, 1.9)
    st.generate_normals()
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _turf_material()
    add_child(mi)
    # Woods on the ground: thickest toward the mountains, thinning to the town's back.
    for i in 220:
        var x := rng.randf_range(-230.0, 230.0)
        var z := zq - rng.randf_range(10.0, 60.0)
        # Keep off the town (its houses stand within 50 either side, to 30 back) and the
        # church on the right.
        if absf(x) < 52.0 and z > zq - 32.0:
            continue
        var kind: String = ["pine", "oak_medium", "oak_large", "maple", "palm_coconut"][rng.randi_range(0, 4)]
        _tree(kind, Vector3(x, 0.1, z), rng.randf_range(4.0, 8.0), rng)

## Woods up a mountain's slopes: `count` trees scattered over the faces between the
## waterline ring and the shoulder, on the side that looks toward the harbour (z greater
## than the lump's centre `cz`), so the slopes the player sees are thick with forest. Each
## tree stands on a point picked inside one face of the lump, sunk a little into it.
func _plant_mountain(rings: Array, cz: float, count: int, rng: RandomNumberGenerator) -> void:
    var n: int = (rings[0] as Array).size()
    for i in count:
        var j := rng.randi_range(1, 2)   # the band between rings j and j + 1
        var k := rng.randi_range(0, n - 1)
        var lo: Array = rings[j]
        var hi: Array = rings[j + 1]
        var u := rng.randf()
        var a: Vector3 = (lo[k] as Vector3).lerp(lo[(k + 1) % n], u)
        var b: Vector3 = (hi[k] as Vector3).lerp(hi[(k + 1) % n], u)
        var p := a.lerp(b, rng.randf())
        if p.y < 0.8 or p.z < cz:
            continue
        # Pines mostly, some oaks; no maples (the heaviest mesh) by the hundred. Big, so
        # they read from the water. Their own MultiMesh group, far off, so it can drop to
        # the meshes' coarse LODs.
        var kind: String = ["pine", "pine", "pine", "oak_medium", "oak_large"][rng.randi_range(0, 4)]
        _tree("far:" + kind, p - Vector3(0.0, 0.6, 0.0), rng.randf_range(7.0, 13.0), rng)

var _trees: Dictionary = {}   # tree kind -> its transforms, drawn as one MultiMesh each

## A tree of `kind` standing at `at`, `height` tall, turned any way: queued for _flush_trees.
## A "group:" prefix on the kind keeps those trees in a MultiMesh of their own.
func _tree(kind: String, at: Vector3, height: float, rng: RandomNumberGenerator) -> void:
    var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * height)
    if not _trees.has(kind):
        _trees[kind] = []
    (_trees[kind] as Array).append(Transform3D(basis, at - Vector3(0.0, 0.35, 0.0)))

## Every queued tree in one MultiMesh per kind: hundreds of trees for a handful of draws.
func _flush_trees() -> void:
    for kind: String in _trees:
        var list: Array = _trees[kind]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = Models.tree(kind.get_slice(":", 1) if kind.contains(":") else kind, 1.0).mesh
        mm.instance_count = list.size()
        for i in list.size():
            mm.set_instance_transform(i, list[i])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        add_child(mmi)
    _trees.clear()

## Whether a rock at `x` keeps out of the row's gap (by `clear` beyond its own radius) and
## off the rocks already in it.
func _row_fits(row: Array, x: float, r: float, gap_x: float, clear: float = 5.0) -> bool:
    if absf(x) > ROCK_SPAN or absf(x - gap_x) < r + clear:
        return false
    for o: Dictionary in row:
        if absf(x - float(o.x)) < r + float(o.r) + 4.5:
            return false
    return true

## What a rock will be, from its own dice: a crag of grey stone, small, medium or, now and
## then, a big one. The wider kinds grow their hull radius `r` too, so the course is laid
## out round the real stone. Returns {seed, h, r, w}: height, hull radius and width over
## the hull.
func rock_shape(r: float) -> Dictionary:
    var dice := RandomNumberGenerator.new()
    dice.seed = 91 + _rock_count * 7
    _rock_count += 1
    var roll := dice.randf()
    var h: float
    var wide: float
    if roll < 0.45:
        h = dice.randf_range(1.2, 2.2)        # small
        wide = 1.0
    elif roll < 0.8:
        h = dice.randf_range(2.2, 3.8)        # medium
        wide = 1.3
    else:
        h = dice.randf_range(4.0, 6.5)        # a big one
        wide = 1.65
    return {"seed": dice.seed, "h": h, "r": r * wide, "w": dice.randf_range(0.85, 1.05)}

## A rock in a holder at sea level (position it): one mesh of grey stone (see rock_shape)
## and, if `foam`, a ring of foam at the waterline. The hull radius `r` is the same either
## way: the ring is only a mark. The holder's meta "top" is the stone's height.
func make_rock(shape: Dictionary, foam: bool = true) -> Node3D:
    var dice := RandomNumberGenerator.new()
    dice.seed = int(shape.seed) + 1
    var holder := Node3D.new()
    var r := float(shape.r)
    var h := float(shape.h)
    holder.add_child(_crag(r * float(shape.w), h, dice))
    if foam:
        var ring := VoyageMode.foam_ring(r * 1.2, 0.4)
        ring.position.y = Tuning.SEA_LEVEL + 0.06
        holder.add_child(ring)
    holder.set_meta("top", h)
    return holder

static var _stone_mat: StandardMaterial3D

## One grey stone material for every rock, shaded through vertex colours.
static func _stone_material() -> StandardMaterial3D:
    if _stone_mat == null:
        _stone_mat = Models.tex_material("coast_sand_rocks_02", 0.5, Color(0.8, 0.8, 0.82)).duplicate()
        _stone_mat.vertex_color_use_as_albedo = true
    return _stone_mat

## A crag: a low heap of four to seven angular chunks of grey stone, sharp-edged, each a
## jittered few-sided lump, built into one mesh. Dark and wet at the waterline, paler up top.
static func _crag(radius: float, height: float, dice: RandomNumberGenerator) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := dice.randi_range(4, 7)
    for i in n:
        var a := dice.randf_range(0.0, TAU)
        var d := 0.0 if i == 0 else dice.randf_range(radius * 0.3, radius * 0.8)
        var rr := radius * (dice.randf_range(0.6, 0.8) if i == 0 else dice.randf_range(0.35, 0.6))
        var hh := height * (dice.randf_range(0.8, 1.0) if i == 0 else dice.randf_range(0.35, 0.85))
        var size := Vector3(rr, hh, rr * dice.randf_range(0.7, 1.3))
        _chunk(st, Vector3(cos(a) * d, 0.0, sin(a) * d), size, dice.randf_range(0.0, TAU), dice.randf_range(0.85, 1.05), dice)
    st.generate_normals()
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _stone_material()
    return mi

## One lump of a crag: a sphere of four rings and seven sides, every vertex pushed in or out,
## stretched to `size`, standing with its lower third under the water. Flat faces, so the
## light catches each facet. With `st_upper`, the bands from ring `upper_from` up go into
## that surface instead (turf over the rock). Returns its rings of vertices, bottom to top
## (the top ring is the one peak point), for anything that wants to stand on the stone.
static func _chunk(st: SurfaceTool, at: Vector3, size: Vector3, yaw: float, shade: float, dice: RandomNumberGenerator, ring_colors: Array = [], st_upper: SurfaceTool = null, upper_from: int = 2) -> Array:
    const RINGS := 4
    const SEG := 7
    var rows: Array = []
    var basis := Basis(Vector3.UP, yaw)
    for j in RINGS + 1:
        var lat := -PI / 2.0 + PI * float(j) / RINGS
        var row: Array = []
        var pole_jitter := dice.randf_range(0.8, 1.2)
        for i in SEG:
            var lon := float(i) / SEG * TAU + (0.3 * j)
            var jitter := pole_jitter if (j == 0 or j == RINGS) else dice.randf_range(0.65, 1.3)
            var p := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)) * jitter
            p = basis * (p * size) + at + Vector3(0, size.y * 0.3 - 0.6, 0)
            row.append(p)
        rows.append(row)
    for j in RINGS:
        var lo: Array = rows[j]
        var hi: Array = rows[j + 1]
        # Grey stone, wet at the waterline, exactly as the rocks in the water; or the
        # caller's colour for each ring. With a second surface, the stone bands keep their
        # grey and the upper bands take the caller's colours (the turf), except that the
        # stone band right under the turf fades up into the turf's first colour: a soft
        # change of colour across the seam instead of a hard line.
        var upper := st_upper != null and j >= upper_from
        var has := ring_colors.size() > j + 1
        var tint0 := has and (st_upper == null or upper)
        var tint1 := has and (st_upper == null or j + 1 >= upper_from)
        var c0 := (ring_colors[j] as Color) * shade if tint0 else _wet(lo[0].y, shade)
        var c1 := (ring_colors[j + 1] as Color) * shade if tint1 else _wet(hi[0].y, shade)
        _band(st_upper if upper else st, lo, hi, c0, c1)
    return rows

## Grey, darker and wetter toward the waterline.
static func _wet(y: float, shade: float) -> Color:
    return Color(1, 1, 1) * shade * (0.6 + 0.4 * clampf((y + 0.2) / 1.4, 0.0, 1.0))

## A band of quads between two rings of the same count, as two triangles each.
static func _band(st: SurfaceTool, lo: Array, hi: Array, c0: Color, c1: Color) -> void:
    var n := lo.size()
    for i in n:
        var k := (i + 1) % n
        for v: Array in [[lo[i], c0], [lo[k], c0], [hi[k], c1], [lo[i], c0], [hi[k], c1], [hi[i], c1]]:
            st.set_color(v[1])
            st.add_vertex(v[0])

## A small white arrow floating over the mast, turning to point the way to the harbour.
func _build_port_arrow() -> void:
    _port_arrow = Node3D.new()
    var shape := PackedVector2Array([Vector2(0, -0.75), Vector2(0.5, -0.15), Vector2(0.2, -0.15), Vector2(0.2, 0.65), Vector2(-0.2, 0.65), Vector2(-0.2, -0.15), Vector2(-0.5, -0.15)])
    for layer: Array in [[Color(0.1, 0.1, 0.12), 1.18, -0.02], [Color(1.0, 1.0, 1.0), 1.0, 0.0]]:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        var idx := Geometry2D.triangulate_polygon(shape)
        for i in idx:
            var p2 := shape[i] * float(layer[1])
            st.add_vertex(Vector3(p2.x, float(layer[2]), p2.y))
        var mi := MeshInstance3D.new()
        mi.mesh = st.commit()
        var m := StandardMaterial3D.new()
        m.albedo_color = layer[0]
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
        m.disable_fog = true
        mi.material_override = m
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _port_arrow.add_child(mi)
    _port_arrow.visible = false
    add_child(_port_arrow)

## The arrow rides above the ship and swings to point at the harbour (the end of the run).
func _update_port_arrow(delta: float) -> void:
    # Only the first voyage, to the harbour, carries it; at the quay the harbour speaks for
    # itself.
    var show := mode == "sail" and (phase == Phase.SAILING or phase == Phase.DOCKING)
    _port_arrow.visible = show
    if not show:
        return
    if _has_pier and root.position.z < _pier_z + 30.0:
        # The pier in sight: the arrow leaves the mast for the berth itself, hanging over
        # the water beside the deck, tip down, bobbing gently until she is made fast.
        var berth := Vector3(_pier_edge + 2.0, 6.5 + sin(time * 3.0) * 0.35, _dock_z)
        _port_arrow.position = _port_arrow.position.lerp(berth, minf(delta * 4.0, 1.0))
        _port_arrow.basis = (Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, -PI / 2.0)).scaled(Vector3.ONE * 2.2)
        return
    var target := Vector3(0.0, 0.0, -goal - 12.0)
    var dir := target - root.position
    var want := atan2(-dir.x, -dir.z)
    _arrow_yaw = lerp_angle(_arrow_yaw, want, minf(delta * 3.0, 1.0))
    # Over the mainmast, tipped up toward the camera astern so its face reads from behind.
    _port_arrow.position = root.position + Vector3(0, 8.6 + sin(time * 2.0) * 0.15, 0)
    _port_arrow.basis = Basis(Vector3.UP, _arrow_yaw) * Basis(Vector3.RIGHT, deg_to_rad(38.0))   # unit scale again

## The pier at the end of the run: a stone quay, two wooden piers, cargo and the flag.
func _build_port() -> void:
    var zq := -goal - 12.0
    _quay_z = zq
    var quay := MeshInstance3D.new()
    var qm := BoxMesh.new()
    qm.size = Vector3(52, 2.2, 10)
    quay.mesh = qm
    quay.material_override = Models.tex_material("large_sandstone_blocks", 0.4)
    quay.position = Vector3(0, 0.1, zq - 5.0)
    add_child(quay)
    var sand := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(120, 1.2, 26)
    sand.mesh = bm
    sand.material_override = Models.tex_material("coast_sand_01", 0.4)
    sand.position = Vector3(0, -0.4, zq - 20.0)
    add_child(sand)
    var pier := Models.prop("modular_wooden_pier")
    pier.position = Vector3(4.5, -4.6, zq + 8.0)
    add_child(pier)
    _build_bridge(zq)
    _build_town(zq)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    for i in 6:
        var prop := Models.prop("wooden_crate_01" if i % 2 == 0 else "wine_barrel_01")
        prop.scale = Vector3.ONE * rng.randf_range(1.1, 1.6)
        prop.position = Vector3(rng.randf_range(-9.0, 9.0), 1.25, zq - 4.0 + rng.randf_range(-2.0, 2.0))
        prop.rotation.y = rng.randf_range(0.0, TAU)
        add_child(prop)
    for i in 7:
        var t := Models.tree("palm_coconut", rng.randf_range(5.0, 7.5))
        t.position = Vector3(rng.randf_range(-52.0, 52.0), 0.2, zq - 10.0 - rng.randf_range(0.0, 3.0))
        add_child(t)
    Atmosphere.ship_flag(self, Vector3(-8.0, 1.2, zq - 3.0))

## A box of `size` in `mat`, centred at `at`.
func _block(at: Vector3, size: Vector3, mat: Material, yaw: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = at
    mi.rotation.y = yaw
    add_child(mi)
    return mi

## The great pier: a long timber bridge on tall pilings running out from the quay beside
## the berth, railed both sides, with a round beacon tower at its seaward head. The ship
## makes fast alongside it at the end of the run.
func _build_bridge(zq: float) -> void:
    var planks := Models.tex_material("brown_planks_07", 0.6, Color(0.92, 0.8, 0.62))
    var timber := Models.tex_material("brown_planks_07", 0.9, Color(0.6, 0.46, 0.33))
    var x0 := -6.0        # the deck's centre line, to port of the berth
    var w := 7.0
    var length := 40.0
    var z_quay := zq - 1.0    # the deck lands on the quay itself
    _dock_z = z_quay + length / 2.0   # the berth: midway along, alongside the deck
    var z_head := z_quay + length
    var deck_y := 1.6
    _block(Vector3(x0, deck_y, z_quay + length / 2.0), Vector3(w, 0.4, length), planks)
    # Pilings and cross beams every six metres, down into the water.
    var z := z_quay + 3.0
    while z < z_head:
        for sx: float in [-1.0, 1.0]:
            var pile := MeshInstance3D.new()
            var cm := CylinderMesh.new()
            cm.top_radius = 0.3
            cm.bottom_radius = 0.34
            cm.height = 7.0
            cm.radial_segments = 8
            pile.mesh = cm
            pile.material_override = timber
            pile.position = Vector3(x0 + sx * (w / 2.0 - 0.5), deck_y - 3.6, z)
            add_child(pile)
        _block(Vector3(x0, deck_y - 0.4, z), Vector3(w + 0.8, 0.3, 0.3), timber)
        z += 6.0
    # Railings: posts every three metres and two rails, both edges.
    for sx: float in [-1.0, 1.0]:
        var rx := x0 + sx * (w / 2.0 - 0.12)
        _block(Vector3(rx, deck_y + 1.1, z_quay + length / 2.0), Vector3(0.1, 0.1, length), timber)
        _block(Vector3(rx, deck_y + 0.7, z_quay + length / 2.0), Vector3(0.08, 0.08, length), timber)
        z = z_quay + 1.5
        while z < z_head:
            _block(Vector3(rx, deck_y + 0.65, z), Vector3(0.16, 1.1, 0.16), timber)
            z += 3.0
    # The head: a wide platform to port, clear of the berth, with a white beacon tower.
    var head_w := 16.0
    var head_d := 9.0
    var hx := x0 - 5.0
    _block(Vector3(hx, deck_y, z_head + head_d / 2.0 - 1.0), Vector3(head_w, 0.4, head_d), planks)
    _has_pier = true
    _pier_edge = x0 + w / 2.0
    _pier_left = hx - head_w / 2.0
    _pier_z = z_head + head_d
    for cx: float in [-1.0, 1.0]:
        for cz: float in [-1.0, 1.0]:
            var pile := MeshInstance3D.new()
            var cm := CylinderMesh.new()
            cm.top_radius = 0.34
            cm.bottom_radius = 0.38
            cm.height = 7.0
            cm.radial_segments = 8
            pile.mesh = cm
            pile.material_override = timber
            pile.position = Vector3(hx + cx * (head_w / 2.0 - 0.6), deck_y - 3.6, z_head + head_d / 2.0 - 1.0 + cz * (head_d / 2.0 - 0.6))
            add_child(pile)
    var tower := MeshInstance3D.new()
    var tm := CylinderMesh.new()
    tm.top_radius = 1.3
    tm.bottom_radius = 1.7
    tm.height = 9.0
    tm.radial_segments = 14
    tower.mesh = tm
    tower.material_override = Models.flat_material(Color(0.95, 0.94, 0.9), 0.8)
    tower.position = Vector3(hx - 4.0, deck_y + 4.7, z_head + 3.0)
    add_child(tower)
    var lamp := MeshInstance3D.new()
    var lm := CylinderMesh.new()
    lm.top_radius = 1.0
    lm.bottom_radius = 1.0
    lm.height = 1.6
    lm.radial_segments = 10
    lamp.mesh = lm
    lamp.material_override = Models.flat_material(Color(1.0, 0.85, 0.5), 0.3)
    lamp.position = Vector3(hx - 4.0, deck_y + 10.0, z_head + 3.0)
    add_child(lamp)
    var cap := MeshInstance3D.new()
    var capm := CylinderMesh.new()
    capm.top_radius = 0.0
    capm.bottom_radius = 1.6
    capm.height = 1.4
    capm.radial_segments = 14
    cap.mesh = capm
    cap.material_override = Models.flat_material(Color(0.6, 0.2, 0.15), 0.7)
    cap.position = Vector3(hx - 4.0, deck_y + 11.5, z_head + 3.0)
    add_child(cap)
    # Cargo along the deck.
    var rng := RandomNumberGenerator.new()
    rng.seed = 23
    for i in 10:
        var prop := Models.prop("wooden_crate_01" if i % 3 != 1 else "wine_barrel_01")
        prop.scale = Vector3.ONE * rng.randf_range(1.0, 1.5)
        prop.position = Vector3(x0 + rng.randf_range(-2.4, 2.4), deck_y + 0.2, z_quay + rng.randf_range(4.0, length - 4.0))
        prop.rotation.y = rng.randf_range(0.0, TAU)
        add_child(prop)

## The town behind the quay: a row of whitewashed and stone houses with tiled roofs, a long
## warehouse, and a round church tower over them all.
func _build_town(zq: float) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    var walls: Array = [Models.flat_material(Color(0.93, 0.9, 0.82), 0.9), Models.flat_material(Color(0.88, 0.8, 0.66), 0.9), Models.tex_material("large_sandstone_blocks", 0.6, Color(0.9, 0.86, 0.78))]
    var ground := 0.2
    var x := -50.0
    while x < 50.0:
        var w := rng.randf_range(4.0, 7.0)
        var d := rng.randf_range(4.0, 6.0)
        var h := rng.randf_range(2.8, 4.6)
        var z := zq - 13.0 - rng.randf_range(0.0, 9.0)
        if absf(x) > 9.0 or z < zq - 17.0:
            _house(Vector3(x, ground, z), Vector3(w, h, d), walls[rng.randi_range(0, walls.size() - 1)], rng)
        x += w + rng.randf_range(2.0, 5.0)
    # The warehouse by the quay's end, long and low.
    _house(Vector3(-32.0, ground, zq - 12.0), Vector3(16.0, 4.2, 8.0), walls[2], rng, 0.4)
    # The church: a hall and a round tower with a red cone.
    _house(Vector3(22.0, ground, zq - 26.0), Vector3(10.0, 5.5, 7.0), walls[0], rng, 0.7)
    var tower := MeshInstance3D.new()
    var tm := CylinderMesh.new()
    tm.top_radius = 2.0
    tm.bottom_radius = 2.2
    tm.height = 14.0
    tm.radial_segments = 14
    tower.mesh = tm
    tower.material_override = walls[0]
    tower.position = Vector3(29.0, ground + 7.0, zq - 26.0)
    add_child(tower)
    var cone := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.0
    cm.bottom_radius = 2.6
    cm.height = 4.5
    cm.radial_segments = 14
    cone.mesh = cm
    cone.material_override = Models.flat_material(Color(0.62, 0.22, 0.16), 0.7)
    cone.position = Vector3(29.0, ground + 16.2, zq - 26.0)
    add_child(cone)

## One house: walls, a tiled gable roof, a door and windows on the seaward side.
func _house(at: Vector3, size: Vector3, wall: Material, rng: RandomNumberGenerator, roof_k: float = 0.55) -> void:
    _block(at + Vector3(0, size.y / 2.0, 0), size, wall)
    var roof := MeshInstance3D.new()
    var pm := PrismMesh.new()
    var roof_h := size.y * roof_k
    pm.size = Vector3(size.z + 0.8, roof_h, size.x + 0.8)
    pm.left_to_right = 0.5
    roof.mesh = pm
    roof.material_override = Models.tex_material("clay_roof_tiles_02", 1.2, Color(0.95, 0.75, 0.7))
    roof.position = at + Vector3(0, size.y + roof_h / 2.0, 0)
    roof.rotation.y = PI / 2.0
    add_child(roof)
    var dark := Models.flat_material(Color(0.2, 0.14, 0.1), 0.8)
    var front := at.z + size.z / 2.0 + 0.03
    _block(Vector3(at.x + rng.randf_range(-size.x * 0.25, size.x * 0.25), at.y + 0.95, front), Vector3(0.9, 1.9, 0.06), dark)
    for sx: float in [-1.0, 1.0]:
        _block(Vector3(at.x + sx * size.x * 0.33, at.y + size.y * 0.6, front), Vector3(0.7, 0.8, 0.06), dark)

# MARK: Waves

func _spawn_crest(final := false) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(time * 977.0) + crests.size()
    var c := {
        # Born inside the animated patch (which trails the ship), behind the haze.
        "z": root.position.z - 100.0,
        "bx": rng.randf_range(-7.0, 7.0),
        "bw": rng.randf_range(5.0, 8.0),
        "h": (11.0 if final else rng.randf_range(2.4, 3.4)),
        "final": final,
        "prev": -1.0,
    }
    if final:
        c.bw = 0.0   # the big one has no white wall: it is all ride
    else:
        # Leave at least a helm's width of green inside the lane on one side.
        c.bw = minf(float(c.bw), LANE + absf(float(c.bx)) - 2.6)
    # The wave itself is real displaced water in the sea shader (see Sea.set_wave_crests);
    # only the breaking lip gets a line of fine wind-torn spray on top.
    var node := Node3D.new()
    add_child(node)
    node.position = Vector3(0, 0, c.z)
    if not final:
        var spume := CPUParticles3D.new()
        spume.amount = 28
        spume.lifetime = 0.45
        spume.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
        spume.emission_box_extents = Vector3(float(c.bw), 0.2, 0.4)
        spume.direction = Vector3(0, 1, 0.5)
        spume.spread = 16.0
        spume.initial_velocity_min = 4.0
        spume.initial_velocity_max = 8.0
        spume.gravity = Vector3(0, -12, 0)
        spume.scale_amount_min = 0.07
        spume.scale_amount_max = 0.18
        spume.mesh = QuadMesh.new()
        var m := StandardMaterial3D.new()
        m.albedo_texture = load("res://assets/particles/whitePuff12.png")
        m.albedo_color = Color(1, 1, 1, 0.45)
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        spume.material_override = m
        spume.position = Vector3(float(c.bx), float(c.h) * 1.1, 0)
        node.add_child(spume)
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
    # The clouds never stand still: the panorama drifts, fast in the storm scud.
    if _env:
        _env.sky_rotation.y += delta * (0.022 if mode == "waves" else 0.008)
    _float_ship(delta)
    _update_port_arrow(delta)
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
    if mode_obj and mode_obj.drives():
        mode_obj.tick(delta)
        return
    var cruise: float = CRUISE[mode]
    speed = move_toward(speed, cruise, delta * (2.6 if mode == "sail" else 4.0))
    # The rudder answers, the hull carries its way: steering drives sideways momentum,
    # and the bow swings to point where the ship is actually going.
    steer = move_toward(steer, clampf(_steer_touch + _steer_gyro, -1.0, 1.0), delta * 5.0)
    var want_lat := steer * 7.5 * minf(speed / 4.0, 1.0)
    _lat_vel = lerpf(_lat_vel, want_lat, minf(delta * 3.6, 1.0))
    root.position.z -= speed * delta
    var nx := root.position.x + _lat_vel * delta
    if absf(nx) >= lane:
        nx = clampf(nx, -lane, lane)
        _lat_vel = 0.0
        if mode == "sail":
            _strike_cliff(signf(nx))
    elif absf(nx) < lane - 2.5:
        _cliff_hit = false
    root.position.x = nx
    _yaw = lerpf(_yaw, atan2(-_lat_vel, maxf(speed, 1.0)), minf(delta * 4.0, 1.0))
    if mode == "sail":
        _check_rocks()
        if _has_pier and root.position.z < _pier_z + 4.2 and root.position.x < _pier_edge + 1.9:
            if root.position.z > _pier_z + 3.0 and root.position.x < _pier_edge + 1.4:
                # Bow on into the pier head: she stoves in just as against the quay.
                _strike_quay("She ran into the pier head and stove her bow in.")
                return
            # Already past the head: the hull fends off the pier's edge and runs alongside.
            root.position.x = move_toward(root.position.x, _pier_edge + 1.9, delta * 8.0)
            _lat_vel = maxf(_lat_vel, 0.0)
        if root.position.z < -(goal - 55.0) and prompt.text.find("pier") < 0:
            _say("There's the pier. Bring her in!")
        # Way off in time to stop alongside the berth (or at the course's end without a pier).
        # With a pier, only a ship brought near the berth is taken in; one that is still out
        # in the harbour runs on and strikes the quay.
        var stop_at := _dock_z if _has_pier else -goal
        var near_berth := (not _has_pier) or absf(root.position.x - (_pier_edge + 2.0)) < BERTH_REACH
        if near_berth and root.position.z < stop_at + speed * speed / (2.0 * 2.2) + 0.5:
            phase = Phase.DOCKING
            _say("Easy now...")
        elif _has_pier and root.position.z < _quay_z + 4.6:
            _strike_quay()
    elif mode == "waves":
        _tick_crests(delta)
    else:
        mode_obj.tick(delta)
        if mode_obj.ends_by_distance() and root.position.z < -goal:
            _say(mode_obj.end_line)
            Haptics.thump()
            _win()

const HULL_R := 2.0   # the hull's reach round the ship's centre against a rock's radius
var _cliff_hit := false   # she is against the gorge's wall: one hit until she comes clear
var _hit_time := -10.0    # when the last heart went

## Into the gorge's wall: a heart gone, and she is thrown back off the stone. One hit per
## touch: she has to come clear of the cliff before it can hurt her again. A rock that
## shoves her into the wall does not count twice: a second blow within a second is let go.
func _strike_cliff(side: float) -> void:
    if _cliff_hit or phase != Phase.SAILING:
        return
    _cliff_hit = true
    if time - _hit_time < 1.0:
        return
    _splash_at(Vector3(side * GORGE_X, 0.2, root.position.z - 2.0))
    take_hit("The hull broke up against the cliffs.", ["Off the cliffs, lad!", "You'll have us swimming!"][mini(hits, 1)])
    _lat_vel = -side * 4.0

func _check_rocks() -> void:
    for r: Dictionary in rocks:
        var off := Vector2(root.position.x - float(r.x), root.position.z - float(r.z))
        var reach := float(r.r) + HULL_R
        var dist := off.length()
        if dist > reach + 2.0:
            continue
        if dist < reach:
            # Into the stone: the hull is pushed back out and glances off sideways, so she
            # never sails through. Dead ahead, the push leans to one side so she slides round.
            var n := off / maxf(dist, 0.01)
            if absf(n.x) < 0.3:
                n.x = 0.3 if n.x >= 0.0 else -0.3
                n = n.normalized()
            root.position.x = clampf(root.position.x + n.x * (reach - dist), -lane, lane)
            root.position.z += n.y * (reach - dist)
            _lat_vel = n.x * 3.5
            if not bool(r.hit):
                r.hit = true
                _splash_at(Vector3(float(r.x), 0.2, float(r.z)))
                take_hit("The hull gave way on the rocks.", ["Mind the rocks, lad!", "You'll have us swimming!"][mini(hits, 1)])
                speed = -1.5   # a weak bounce back off the stone
            else:
                speed = minf(speed, 1.2)   # scraping along it: she crawls until she is round
        elif not bool(r.grazed) and dist < reach + 1.9:
            r.grazed = true
            Haptics.detent()
            # A whisker past: a breath of slow motion to savour it.
            if dist < reach + 0.8 and phase == Phase.SAILING:
                Engine.time_scale = 0.55
                var tw := create_tween()
                tw.set_ignore_time_scale(true)
                tw.tween_interval(0.35)
                tw.tween_callback(func(): if phase == Phase.SAILING: Engine.time_scale = 1.0)

## Autopilot helm: the nearest row of the given rocks ahead, and the closest clear water
## through it that is inside the lane and not in another rock's way.
func row_target(candidates: Array) -> float:
    var row_z := -1e9
    for r: Dictionary in candidates:
        var dz := float(r.z) - root.position.z
        if dz < -55.0 or dz > -2.0:
            continue
        if dz > row_z:
            row_z = dz
    var target := root.position.x
    if row_z < -1e8:
        return target
    var row: Array = []
    for r: Dictionary in candidates:
        if absf((float(r.z) - root.position.z) - row_z) < 6.0:
            row.append(r)
    var blocked := false
    for r: Dictionary in row:
        if absf(root.position.x - float(r.x)) < float(r.r) + 3.5:
            blocked = true
    if not blocked:
        return target
    var best_d := 1e9
    for r: Dictionary in row:
        for side: float in [-1.0, 1.0]:
            var cx: float = float(r.x) + side * (float(r.r) + 4.0)
            if absf(cx) > lane - 0.5:
                continue
            var clear := true
            for o: Dictionary in row:
                if o != r and absf(cx - float(o.x)) < float(o.r) + 3.0:
                    clear = false
            if clear and absf(cx - root.position.x) < best_d:
                best_d = absf(cx - root.position.x)
                target = cx
    return target

## Damage to the ship: a heart gone, a lurch, the red flash. Three and she is lost.
func take_hit(fail_reason: String, line: String) -> void:
    if phase != Phase.SAILING:
        return
    hits += 1
    _hit_time = time
    speed *= 0.5
    _steer_touch = 0.0
    _shake = maxf(_shake, 0.9)
    Haptics.rumble(2)
    _flash(Color(0.8, 0.1, 0.05, 0.4))
    if hits >= 3:
        _fail(fail_reason)
    else:
        _say(line)

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
        if bool(c.final) and dz > -FINAL_CLEAR:
            # The mountain is still a good way off when the run is called: the ship is
            # clear of it and stays clear, since nothing moves once the level has ended.
            Haptics.rumble(2)
            _say("There's the big one. We're clear of it, lad!")
            _win()
            return
        if float(c.prev) < 0.0 and dz >= 0.0:
            _cross_crest(c)
        c.prev = dz
        if dz > 25.0:
            (c.node as Node3D).queue_free()
            crests.erase(c)
    # Hand the crest lines to the water: the shader stands them up as real waves and the
    # same maths lifts the hull in _float_ship.
    var packed: Array[Vector4] = []
    for c: Dictionary in crests:
        packed.append(Vector4(float(c.z), float(c.bx), float(c.bw), float(c.h)))
    sea.set_wave_crests(packed)

func _cross_crest(c: Dictionary) -> void:
    if phase != Phase.SAILING:
        return
    if not bool(c.final) and absf(root.position.x - float(c.bx)) < float(c.bw):
        _capsize()
        return
    waves_cleared += 1
    Haptics.thump()
    _shake = 0.9 if bool(c.final) else 0.5
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
    # She loses way so as to stop right at the berth, and eases over to the pier's side,
    # clear of its edge by more than the hull's half beam.
    var left := (root.position.z - _dock_z) if _has_pier else 1e9
    speed = move_toward(speed, 0.0, delta * 2.2)
    speed = minf(speed, sqrt(2.0 * 2.2 * maxf(left, 0.0)))
    _lat_vel = move_toward(_lat_vel, 0.0, delta * 5.0)
    _yaw = lerpf(_yaw, 0.0, minf(delta * 2.0, 1.0))
    root.position.z -= speed * delta
    root.position.x = move_toward(root.position.x, (_pier_edge + 2.0) if _has_pier else 2.6, delta * 1.4)
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

## The hull rides the water under bow, stern and both rails. The crest ridges are part of
## sea.height itself now, so the bow lifts first, the ship pitches over the face and slides
## down the back — real wave riding, not a scripted bump.
func _float_ship(delta: float) -> void:
    var p := root.position
    # Keep the animated water patch under and ahead of the ship for the whole run.
    sea.position.z = p.z - 35.0
    var half_l := Ship.LENGTH * 0.45
    var bow := sea.height(p.x, p.z - half_l)
    var stern := sea.height(p.x, p.z + half_l)
    var port_h := sea.height(p.x - 1.1, p.z)
    var star_h := sea.height(p.x + 1.1, p.z)
    var level_y := Tuning.SEA_LEVEL + (bow + stern + port_h + star_h) / 4.0 + Tuning.SHIP_FREEBOARD
    var trim := clampf(atan2(bow - stern, half_l * 2.0), -0.38, 0.38)
    # The water foams astern as she drives.
    sea.set_wake(clampf(speed / 6.0, 0.0, 1.0), p, 1.2, half_l + 0.3)
    # The bow buries itself in a wave: a sheet of water comes over it.
    _dip_cool = maxf(_dip_cool - delta, 0.0)
    var bow_y := p.y + sin(_trim) * half_l    # the hull's bow (trim up = bow up)
    var dip := (Tuning.SEA_LEVEL + bow) - (bow_y - Tuning.SHIP_FREEBOARD)
    if dip > 0.55 and speed > 3.0 and _dip_cool <= 0.0 and phase == Phase.SAILING:
        _dip_cool = 0.9
        _bow_sheet(Vector3(p.x, p.y + 0.3, p.z - half_l), minf(dip / 1.5, 1.0))
        Haptics.detent()
    var heel := clampf(atan2(star_h - port_h, 2.2) * 0.5, -0.2, 0.2)
    var follow := minf(delta * (4.5 if mode == "waves" else 3.5), 1.0)
    root.position.y = lerpf(root.position.y, level_y, follow) if time > 0.1 else level_y
    _trim = lerpf(_trim, trim, follow)
    # She banks into the turn with the sideways momentum, on top of the wave heel.
    _heel = lerpf(_heel, heel - _lat_vel * 0.028, follow)
    if phase != Phase.ENDED:
        root.rotation = Vector3(_trim, _yaw, _heel)

func _update_camera(delta: float) -> void:
    if mode_obj and mode_obj.camera(delta):
        return
    var p := root.position
    var want: Vector3
    var look: Vector3
    var fov := 72.0
    if phase == Phase.PREP:
        # Standing on deck looking up at the sail, from the quarter.
        want = p + Vector3(5.0, 3.4, 7.0)
        look = p + Vector3(0, 4.5, 0)
    else:
        # Astern and above, trailing the ship: it slides across the frame when she turns,
        # the lens looks a touch into the turn, and speed widens the view.
        want = p + Vector3(_lat_vel * 0.4, 4.2 + speed * 0.06, 10.8)
        look = p + Vector3(_lat_vel * 0.9, 1.1, -12.0)
        fov = 66.0 + speed * 1.1
    if _shake > 0.005:
        want += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0) * _shake * 0.3
        _shake = maxf(_shake - delta * 1.8, 0.0)
    camera.global_position = camera.global_position.lerp(want, minf(delta * 2.6, 1.0)) if time > 0.1 else want
    camera.fov = lerpf(camera.fov, fov, minf(delta * 2.0, 1.0))
    camera.look_at(look, Vector3.UP)
    # The horizon tips with the hull, a fraction: the sea feels alive, the stomach stays calm.
    camera.rotation.z += _heel * 0.22

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
            _press_pos = t.position
            _press_time = time
        elif not t.pressed and t.index == _drag_id:
            _drag_id = -1
            _steer_touch = 0.0
            if mode_obj and t.position.distance_to(_press_pos) < 24.0 and time - _press_time < 0.4:
                mode_obj.tap(t.position)
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
        target = row_target(rocks)
        if _has_pier and root.position.z < -(goal - 45.0):
            target = _pier_edge + 2.0   # past the rocks: make for the berth, as the arrow shows
        if "--miss-berth" in OS.get_cmdline_user_args() and root.position.z < -(goal - 45.0):
            target = 12.0   # debug: hold off to starboard and run into the quay
        if "--hit-pier" in OS.get_cmdline_user_args() and root.position.z < -(goal - 45.0):
            target = _pier_left + 8.0   # debug: run bow on into the pier head
    elif mode_obj:
        target = mode_obj.autopilot_target()
        if mode_obj.drives():
            return   # the mode set the helm itself
    else:
        target = root.position.x
        for c: Dictionary in crests:
            var dz := float(c.z) - root.position.z
            if dz < -60.0 or dz > -2.0 or bool(c.final):
                continue
            if absf(root.position.x - float(c.bx)) < float(c.bw) + 1.5:
                target = float(c.bx) + _green_side(c) * (float(c.bw) + 2.5)
    # Proportional on the gap, damped on the sideways speed, since the hull now carries way.
    _steer_touch = clampf((target - root.position.x) * 0.45 - _lat_vel * 0.08, -1.0, 1.0)

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

## Full tilt into the quay or the pier head: the bow stoves in with a burst of splinters, she stops dead
## and settles by the head, and the run is lost.
func _strike_quay(reason: String = "She ran into the quay and stove her bow in.") -> void:
    phase = Phase.ENDED
    speed = 0.0
    _lat_vel = 0.0
    Engine.time_scale = 0.45
    _shake = 1.4
    Haptics.rumble(3)
    var bow := root.position + Vector3(0, 0.6, -4.2)
    _splash_at(bow)
    _splinters(bow)
    _flash(Color(0.8, 0.1, 0.05, 0.4))
    _say("The bow! You've stove her in!")
    # The bow crumples: broken planks tumble off it into the water, the hull pitches
    # forward and sinks by the head.
    var planks := Models.tex_material("brown_planks_07", 0.9, Color(0.9, 0.7, 0.5))
    for i in 9:
        var plank := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.25, randf_range(1.2, 2.6), 0.12)
        plank.mesh = bm
        plank.material_override = planks
        plank.position = bow + Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 1.2), randf_range(-0.6, 0.6))
        plank.rotation = Vector3(randf_range(-0.4, 0.4), randf_range(0, TAU), randf_range(-0.5, 0.5))
        add_child(plank)
        var pt := plank.create_tween()
        pt.set_ignore_time_scale(true)
        pt.set_parallel(true)
        pt.tween_property(plank, "position", plank.position + Vector3(randf_range(-2.5, 2.5), -2.2, randf_range(-3.0, -0.5)), 1.3).set_ease(Tween.EASE_IN)
        pt.tween_property(plank, "rotation", plank.rotation + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), 1.3)
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.set_parallel(true)
    tw.tween_property(root, "rotation:x", -0.42, 1.3).set_ease(Tween.EASE_OUT)
    tw.tween_property(root, "position:y", root.position.y - 1.1, 1.6)
    tw.tween_property(root, "position:z", root.position.z + 0.9, 0.5).set_ease(Tween.EASE_OUT)
    tw.chain().tween_callback(func():
        Engine.time_scale = 1.0
        _fail(reason))

## A burst of plank splinters at `at`.
func _splinters(at: Vector3) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = 40
    p.lifetime = 1.6
    p.explosiveness = 0.95
    p.direction = Vector3(0, 1, -0.6)
    p.spread = 70.0
    p.initial_velocity_min = 3.0
    p.initial_velocity_max = 8.0
    p.gravity = Vector3(0, -9.8, 0)
    p.particle_flag_align_y = true
    p.scale_amount_min = 0.8
    p.scale_amount_max = 1.6
    var bm := BoxMesh.new()
    bm.size = Vector3(0.03, 0.3, 0.04)
    p.mesh = bm
    p.material_override = Models.tex_material("brown_planks_07", 3.0, Color(1.1, 0.85, 0.62))
    p.position = at
    add_child(p)
    p.emitting = true
    get_tree().create_timer(2.4).timeout.connect(p.queue_free)

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
    if mode == "sail" or (mode_obj and mode_obj.has_hearts):
        stars = 3 if hits == 0 else (2 if hits == 1 else 1)
    _show_result("")
    var score := int(goal) * 10 + (3 - hits) * 500
    var gold := 25 + stars * 15
    get_parent().call_deferred("record_result", int(data.id), true, stars, score, gold, hits)

## A sheet of water over the bow, thrown back along the deck: bigger for a deeper dip.
func _bow_sheet(at: Vector3, k: float) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = int(60 + 80 * k)
    p.lifetime = 1.0
    p.explosiveness = 0.9
    p.local_coords = false
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    p.emission_box_extents = Vector3(1.3, 0.2, 0.5)
    p.direction = Vector3(0, 1.0, 0.9)
    p.spread = 40.0
    p.initial_velocity_min = 3.0 + 3.0 * k
    p.initial_velocity_max = 6.0 + 5.0 * k
    p.gravity = Vector3(0, -12, 0)
    p.scale_amount_min = 0.25
    p.scale_amount_max = 0.6 + 0.3 * k
    p.mesh = QuadMesh.new()
    p.material_override = spray.material_override
    p.position = at
    add_child(p)
    p.emitting = true
    get_tree().create_timer(1.6).timeout.connect(p.queue_free)

func _splash_at(at: Vector3) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.amount = 50
    p.lifetime = 0.9
    p.explosiveness = 1.0
    p.direction = Vector3(0, 1, 0)
    p.spread = 60.0
    p.initial_velocity_min = 4.0
    p.initial_velocity_max = 9.0
    p.gravity = Vector3(0, -13, 0)
    p.scale_amount_min = 0.2
    p.scale_amount_max = 0.5
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
    # Pause, top right, where the hearts used to be.
    var pb := Button.new()
    pb.text = "II"
    pb.add_theme_font_size_override("font_size", 34)
    pb.position = Vector2(1179 - 40 - 110, 56)
    pb.custom_minimum_size = Vector2(110, 110)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.10, 0.14, 0.5)
    sb.set_corner_radius_all(55)
    pb.add_theme_stylebox_override("normal", sb)
    pb.add_theme_stylebox_override("hover", sb)
    pb.add_theme_stylebox_override("pressed", sb)
    pb.add_theme_color_override("font_color", Color.WHITE)
    pb.pressed.connect(toggle_pause)
    overlay.add_child(pb)
    # The pause menu, hidden until needed; it runs while the tree is paused.
    _pause_menu = Control.new()
    _pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    _pause_menu.visible = false
    _pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pause_menu.add_child(dim)
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
    head.text = "Paused"
    head.add_theme_font_size_override("font_size", 60)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    v.add_child(_menu_button("Resume", toggle_pause, true))
    v.add_child(_menu_button("Restart", func(): toggle_pause(); replay.emit()))
    v.add_child(_menu_button("Settings", func(): _pause_panel.visible = false; _pause_settings.visible = true))
    v.add_child(_menu_button("Chart", func(): toggle_pause(); quit.emit()))
    pm.add_child(v)
    center.add_child(pm)
    _pause_menu.add_child(center)
    _pause_panel = pm
    # Settings behind the pause menu: the same rows as the settings screen, built by Main.
    var scenter := CenterContainer.new()
    scenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var sm := PanelContainer.new()
    sm.add_theme_stylebox_override("panel", psb)
    sm.custom_minimum_size = Vector2(979, 0)
    var sv := VBoxContainer.new()
    sv.add_theme_constant_override("separation", 20)
    var st := Label.new()
    st.text = "Settings"
    st.add_theme_font_size_override("font_size", 60)
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sv.add_child(st)
    var main := get_parent()
    if main and main.has_method("add_settings_rows"):
        main.add_settings_rows(sv)
    sv.add_child(_menu_button("Back", func(): _pause_settings.visible = false; _pause_panel.visible = true, true))
    sm.add_child(sv)
    scenter.add_child(sm)
    scenter.visible = false
    _pause_menu.add_child(scenter)
    _pause_settings = scenter
    overlay.add_child(_pause_menu)

## A wide rounded menu button, orange when it is the main choice.
func _menu_button(text: String, cb: Callable, accent: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", 38)
    b.custom_minimum_size = Vector2(0, 110)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1.0, 0.58, 0.18) if accent else Color(1, 1, 1, 0.14)
    sb.set_corner_radius_all(55)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

## Pause stops the whole tree (the sea, the helm, the tweens) behind the menu.
func toggle_pause() -> void:
    if phase == Phase.ENDED:
        return
    is_paused = not is_paused
    get_tree().paused = is_paused
    _pause_menu.visible = is_paused
    # The menu always opens on its first page, so settings never stay up across a resume.
    _pause_panel.visible = true
    _pause_settings.visible = false
    # Any touch under way is let go, so the helm does not stick on resume.
    _drag_id = -1
    _steer_touch = 0.0
    paused.emit(is_paused)

## The app went to the background: pause behind the menu so Resume is one tap away.
func pause_for_background() -> void:
    if phase == Phase.ENDED or is_paused:
        return
    toggle_pause()

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
    if mode_obj and not mode_obj.ends_by_distance():
        frac = -1.0
    if frac >= 0.0:
        # Under the Captain's line, clear of a phone's notch or island at the very top.
        var by := 270.0
        ui.draw_rect(Rect2(w * 0.1, by, w * 0.8, 6), Color(1, 1, 1, 0.25))
        ui.draw_rect(Rect2(w * 0.1, by, w * 0.8 * frac, 6), Color(1, 1, 1, 0.8))
        var sx := w * 0.1 + w * 0.8 * frac
        ui.draw_colored_polygon(PackedVector2Array([Vector2(sx, by - 18), Vector2(sx + 12, by + 6), Vector2(sx - 12, by + 6)]), Color.WHITE)
    # Hearts (the levels where the hull takes damage), along the bottom of the screen,
    # above a phone's home bar.
    if mode == "sail" or (mode_obj and mode_obj.has_hearts):
        var font := ThemeDB.fallback_font
        ui.draw_string(font, Vector2(0, ui.size.y - 150), "♥".repeat(maxi(3 - hits, 0)) + "♡".repeat(mini(hits, 3)), HORIZONTAL_ALIGNMENT_CENTER, w, 56, Color(1, 1, 1, 0.9))
    if phase == Phase.PREP:
        _draw_haul(Vector2(w * 0.72, ui.size.y * 0.42))
    if mode == "waves" and phase == Phase.SAILING:
        _draw_wave_arrows()
    if mode_obj and phase == Phase.SAILING:
        mode_obj.draw(ui)

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
    head.text = ((mode_obj.win_title if mode_obj else ("Made fast!" if mode == "sail" else "Through the storm!")) if won else "Lost her!")
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
        var stars := 3 if mode == "waves" or (mode_obj and not mode_obj.has_hearts) else (3 if hits == 0 else (2 if hits == 1 else 1))
        var row := Label.new()
        row.text = "★".repeat(stars) + "☆".repeat(3 - stars)
        row.add_theme_font_size_override("font_size", 110)
        row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
        row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(row)
    for entry: Array in ([["Next island", func(): next_level.emit(), true]] if won else []) + [["Try again", func(): replay.emit(), not won], ["Chart", func(): quit.emit(), false]]:
        v.add_child(_menu_button(entry[0], entry[1], entry[2]))
    pm.add_child(v)
    center.add_child(pm)
    overlay.add_child(center)

func _exit_tree() -> void:
    Engine.time_scale = 1.0
