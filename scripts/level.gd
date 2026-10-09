## One level: builds the world from the level JSON, runs the game loop, owns the camera and
## input. Talks to the HUD through `event` and plain properties.
class_name Level
extends Node3D

signal event(name: String, data: Dictionary)

enum Phase { LOADING, INTRO, AIMING, IN_FLIGHT, SETTLING, SLOWMO, FINISHED }
## Fly-in start points relative to the ship: far out, so the camera sweeps in over the water.
const INTRO_STARTS := [Vector3(-26, 12.0, 26), Vector3(24, 10.0, 24), Vector3(-4, 18.0, 32), Vector3(12, 8.0, 34)]
const Z_OFF := 0.0
const SKY_TURN := {"noon": 0.0, "sunset": 0.95, "night": 0.0}

var data: Dictionary
var settings: Dictionary
var phase: int = Phase.LOADING
var time: float = 0.0
var shots_used := 0
var projectiles_remaining := 0
var targets_remaining := 0
var ships_remaining := 0
var blocks_broken := 0
var hull_hits := 0
var won := false
var blast_count := 0
var thunder_count := 0
var sea: Sea
var ship_base_x := 0.0
var intro_hold := Tuning.INTRO_HOLD
var _turn_accum := 0.0
var _bark: StandardMaterial3D
var _prev_yaw := 0.0
var _prev_pitch := 0.0
var _castle_zone := Rect2()
var _castle_top := 0.0
var _intro_look := Vector2.ZERO   # degrees of look-around from the phone during the fly-in
var sail_in := Tuning.SAIL_IN
var sail_after := Tuning.SAIL_IN_AFTER
var _trim := 0.0
var _heel := 0.0
var style: Dictionary
var ship: Ship
var cannon: Node3D
var cannon_pivot: Node3D
var cannon_barrel: Node3D
var cannon_elevation: Node3D
var muzzle_local := Vector3(0, 0.4, -0.7)
var camera: Camera3D
var sun: DirectionalLight3D
var fx: Fx
var weather: Weather
var ambience: Ambience
var aim_yaw := 0.0
var aim_pitch := 0.0
var power := 0.0
var loading_end := 0.0
var intro_end := 0.0
var intro_start: Vector3
var camera_look_base: Vector3
var camera_look := Vector3.ZERO
var camera_pos := Vector3.ZERO
var camera_up := Vector3.UP
var blast_shake := 0.0
var recoil := 0.0
var active_projectile: Projectile
var last_shot_time := 0.0
var settle_start := -1.0
var slowmo_end := -1.0
var win_linger_start := -1.0
var blast_slowmo_end := -1.0
var frozen := true
var enemy_guns: Array[EnemyGun] = []
var enemy_ships: Array[EnemyShip] = []
var enemy_balls: Array[RigidBody3D] = []
var dots: Array[MeshInstance3D] = []
var fragments_alive := 0
var gyro_enabled := true
var gyro_available := false
var _yaw_raw := 0.0
var _pitch_ref := 0.0
var _yaw_offset := 0.0
var _aim_touch := -1
var _pending_touch := -1
var _touch_start := Vector2.ZERO
var _load_touch := -1
var _aim_last := Vector2.ZERO
var _load_start_y := 0.0
var _controls: Node
var open_sea := false
var focus_point: Variant = null
var next_thunder := 0.0
var is_paused := false
var ship_lift := 0.0   # the whale under the keel (The Pod) raises this
var _touches: Dictionary = {}
var _pinch_start := -1.0
var zoom_out := 0.0
var _zoom_target := 0.0

# Feel: combos, loot, cameras, near misses, kick.
var combo := 0
var best_combo := 0
var bonus := 0
var _combo_last := -100.0
var shot_pops := 0
var coins := 0
var _coin_nodes: Array[Node3D] = []
var cine_until := -1.0          # real seconds (Time) until the action camera lets go
var cine_pos := Vector3.ZERO
var cine_look := Vector3.ZERO
var _cine_used := false
var follow := false
var _follow_until := -1.0
var _shot_min_dist := INF
var _shot_start_breaks := 0
var _shot_start_targets := 0
var _shot_blasts := 0
var kick := 0.0
var _kick_vel := 0.0
var specials: Dictionary = {}   # "chain"/"fire" -> balls left this level
var armed_special := ""
var regular_used := 0
var _fire_tick := 0.0
var powder_scale := 1.0
var power_scale := 1.0
var reload_time := Tuning.RELOAD_TIME
var max_hull := Tuning.MAX_HULL_HITS
var old_cannon := false
var upgrades: Dictionary = {}
var captives_freed := 0
var lava_next := 6.0
var ui_blocks: Array[Rect2] = []   # HUD buttons in the play area; touches there are not aim or load

func level_time() -> float:
    return time

## Debug: aim and fire once the level is ready.
var auto_fire: float = -1.0
var auto_fire_yaw: float = 0.0
var auto_fire_pitch: float = 8.0
var _auto_fired := false

func next_ammo() -> String:
    if armed_special != "" and int(specials.get(armed_special, 0)) > 0:
        return armed_special
    var ammo: Array = data.get("ammo", [])
    if ammo.is_empty():
        return "iron"
    return ammo[mini(regular_used, ammo.size() - 1)]

## Arms a special ball for the next shot (tap again to disarm).
func arm_special(kind: String) -> void:
    armed_special = "" if armed_special == kind or int(specials.get(kind, 0)) <= 0 else kind
    event.emit("ammo", {})

func specials_left() -> int:
    var n := 0
    for k in specials:
        n += int(specials[k])
    return n

func ammo_for(i: int) -> String:
    var ammo: Array = data.get("ammo", [])
    if ammo.is_empty():
        return "iron"
    return ammo[mini(i, ammo.size() - 1)]

func is_storm() -> bool:
    return float(data.get("sea", 0.0)) >= 0.6

func is_windy() -> bool:
    return float(data.get("sea", 0.0)) >= 0.4

func sea_description() -> String:
    var s := float(data.get("sea", 0.0))
    if s < 0.15:
        return "Calm sea"
    if s < 0.45:
        return "Rough sea"
    return "Storm"

# MARK: Build

func build(level_data: Dictionary, user_settings: Dictionary) -> void:
    Haptics.muted = false
    data = level_data
    settings = user_settings
    gyro_enabled = bool(settings.get("gyro", true))
    upgrades = settings.get("upgrades", {})
    old_cannon = bool(data.get("old_cannon", false))
    var loader := int(upgrades.get("loader", 0))
    reload_time = maxf(Tuning.RELOAD_TIME * (1.0 - 0.15 * loader), 0.25)
    projectiles_remaining = int(data.projectiles) + (1 if loader >= 3 else 0)
    if not old_cannon:
        for kind in ["chain", "fire", "shell"]:
            if int(upgrades.get(kind, 0)) > 0:
                specials[kind] = int(upgrades[kind])
    powder_scale = 1.0 + 0.12 * int(upgrades.get("powder", 0))
    max_hull = Tuning.MAX_HULL_HITS + int(upgrades.get("hull", 0))
    power_scale = 0.8 if old_cannon else 1.0 + 0.07 * int(upgrades.get("barrel", 0))
    targets_remaining = data.targets.size()
    ships_remaining = data.get("enemyShips", []).size()
    open_sea = data.get("terrain", {}).get("biome", "tropic") == "opensea"
    var storm := is_storm()

    # Sky and light.
    var env := WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    var sm: Material
    style = Decor.style(data, storm)
    var sky_kind: String = style.sky
    # The worst storms (level 1): the rain blacks out the sky.
    var tempest := float(data.get("sea", 0.0)) >= 0.95
    if sky_kind == "overcast" or sky_kind == "storm":
        # Real overcast sky (Poly Haven HDR), darker for storms.
        var pano := PanoramaSkyMaterial.new()
        pano.panorama = load("res://assets/sky/overcast.hdr")
        pano.energy_multiplier = 0.45 if sky_kind == "storm" else 0.8
        if tempest:
            pano.energy_multiplier = 0.2
        sm = pano
    elif sky_kind in ["noon", "sunset"]:
        # A real photographed sky (Poly Haven), clouds and all: cheap, and never flat.
        var photo := PanoramaSkyMaterial.new()
        photo.panorama = load("res://assets/sky/sky_%s.jpg" % sky_kind)
        photo.energy_multiplier = {"noon": 1.0, "sunset": 1.1, "night": 0.32}[sky_kind]
        sm = photo
        # Turn the photo so the best of it (the sunset glow) sits behind the fort.
        e.sky_rotation = Vector3(0, SKY_TURN.get(sky_kind, 0.0), 0)
    else:
        var ps := ProceduralSkyMaterial.new()
        if sky_kind == "night":
            ps.sky_top_color = Color(0.01, 0.02, 0.06)
            ps.sky_horizon_color = Color(0.06, 0.09, 0.18)
            ps.ground_horizon_color = Color(0.06, 0.09, 0.18)
            ps.sun_angle_max = 3.0
            ps.sun_curve = 0.02
        elif sky_kind == "sunset":
            ps.sky_top_color = Color(0.22, 0.28, 0.52)
            ps.sky_horizon_color = Color(0.98, 0.62, 0.40)
            ps.ground_horizon_color = Color(0.98, 0.62, 0.40)
            ps.sun_angle_max = 30.0
            ps.sun_curve = 0.08
        else:
            ps.sky_top_color = Color(0.26, 0.46, 0.78)
            ps.sky_horizon_color = Color(0.74, 0.82, 0.90)
            ps.ground_horizon_color = Color(0.74, 0.82, 0.90)
            ps.sun_angle_max = 20.0
        ps.ground_bottom_color = Color(0.30, 0.34, 0.36)
        sm = ps
    sky.sky_material = sm
    e.background_mode = Environment.BG_SKY
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    e.ambient_light_energy = 0.9 if not storm else (0.32 if tempest else 0.6)
    if sky_kind == "night":
        e.ambient_light_energy = 0.4
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.glow_enabled = false
    # Haze gives depth: the mountains and far trees fade into the air, thickly in a storm.
    e.fog_enabled = true
    e.fog_light_color = Color(0.46, 0.50, 0.56) if storm else (Color(0.92, 0.72, 0.62) if sky_kind == "sunset" else Color(0.72, 0.80, 0.88))
    e.fog_density = 0.008 if storm else (0.005 if is_windy() else 0.003)
    if tempest:
        e.fog_light_color = Color(0.2, 0.22, 0.26)
        e.fog_density = 0.0055
    if sky_kind == "night":
        e.fog_light_color = Color(0.05, 0.07, 0.13)
        e.fog_density = 0.006
    e.fog_sky_affect = 0.25
    env.environment = e
    add_child(env)
    sun = DirectionalLight3D.new()
    sun.light_energy = 1.1 if not storm else (0.3 if tempest else 0.55)
    sun.light_color = Color(1.0, 0.93, 0.85) if not storm else Color(0.75, 0.8, 0.95)
    if sky_kind == "sunset":
        # Low warm sun from the left, long shadows.
        sun.light_color = Color(1.0, 0.72, 0.48)
        sun.light_energy = 1.25
    elif sky_kind == "overcast":
        sun.light_energy = 0.8
        sun.light_color = Color(0.92, 0.94, 1.0)
    elif sky_kind == "night":
        # Moonlight: cold, dim, from high on the right.
        sun.light_energy = 0.32
        sun.light_color = Color(0.58, 0.68, 1.0)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 22.0
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.rotation_degrees = Vector3(-16, 70, 0) if sky_kind == "sunset" else (Vector3(-38, -35, 0) if sky_kind == "night" else Vector3(-52, 35, 0))
    add_child(sun)
    var glint := DirectionalLight3D.new()
    glint.light_energy = 0.15 if not storm else 0.08
    if sky_kind == "night":
        glint.light_energy = 0.04
    glint.light_color = Color(1.0, 0.85, 0.7)
    glint.rotation_degrees = Vector3(-8, 190, 0)
    add_child(glint)

    # Sea, ship, cannon.
    # The ship is placed so its foredeck cannon sits at the level's cannon position.
    var cannon_pos := _v3(data.cannon) + Vector3(0, 0, float(data.get("offshore", Tuning.offshore(int(data.id)))))
    ship = Ship.new()
    ship.setup()
    var ship_pos := cannon_pos - Vector3(ship.cannon_mount.x, 0.9, ship.cannon_mount.z)
    ship.position = ship_pos
    ship_base_x = ship_pos.x
    sea = Sea.new()
    add_child(sea)
    sea.setup(float(data.get("sea", 0.0)), ship_pos, open_sea, float(data.get("swell", 1.0)))
    if sky_kind == "night":
        sea.set_night()
    add_child(ship)
    _build_cannon()
    ship.deck_found.connect(func(): cannon.position = ship.cannon_mount)

    # Island and scenery.
    Decor.build(self, int(data.id), data.get("terrain", {}).get("biome", "tropic"), storm, style, cannon_pos.z, _castle_rect())
    if not open_sea:
        sea.set_shore(Decor._seed)

    # Castle, figures, guns, boats.
    for b in data.blocks:
        _spawn_block(b)
    var i := 0
    for t in data.targets:
        _spawn_target(t, i)
        i += 1
    var ci := 0
    for c in data.get("captives", []):
        _spawn_captive(c, ci)
        ci += 1
    for g in data.get("enemyCannons", []):
        _spawn_gun(g)
    for s in data.get("enemyShips", []):
        _spawn_enemy_ship(s)
    if data.has("orcas"):
        var pod := OrcaDirector.new()
        add_child(pod)
        pod.setup(self)
    _freeze_all(true)
    _castle_zone = _castle_rect()
    for b in data.blocks:
        _castle_top = maxf(_castle_top, float(b.position[1]) + float(b.size[1]) / 2.0)

    # Life: flags on the towers; at night torches, stars and a deck lantern; gulls by day.
    Atmosphere.flags(self, 3, 1.0 + float(data.get("sea", 0.0)))
    Atmosphere.ship_flag(ship, Vector3(5.9, 2.3, 0.0))
    if sky_kind == "night":
        Atmosphere.torches(self, 6)
        Atmosphere.stars(self, 320)
        Atmosphere.deck_lantern(ship, ship.cannon_mount)


    # Camera and the fly-in.
    camera = Camera3D.new()
    # A wider view on levels with a big fort far away (level 1).
    camera.fov = float(data.get("fov", Tuning.CAMERA_FOV))
    camera.cull_mask = 0xFFFFF
    camera.near = 0.05
    camera.far = 400.0
    add_child(camera)
    camera.make_current()
    camera_look_base = _v3(data.camera.lookAt)
    intro_start = INTRO_STARTS[(int(data.id) - 1) % INTRO_STARTS.size()]
    if data.has("intro_from"):
        intro_start = _v3(data.intro_from)
    sail_in = float(data.get("sail_in", Tuning.SAIL_IN))
    sail_after = float(data.get("sail_after", Tuning.SAIL_IN_AFTER))
    loading_end = Tuning.LOADING_DURATION
    intro_hold = float(data.get("intro_hold", Tuning.INTRO_HOLD))
    intro_end = loading_end + Tuning.INTRO_DURATION + intro_hold
    camera_pos = ship_pos + intro_start
    camera_look = ship_pos + Vector3(0, 1.5, 0)

    # Trajectory dots.
    var dot_mesh := SphereMesh.new()
    dot_mesh.radius = 0.035
    dot_mesh.height = 0.07
    var dot_mat := StandardMaterial3D.new()
    dot_mat.albedo_color = Color(1, 1, 1, 0.75)
    dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    for k in 64:
        var d := MeshInstance3D.new()
        d.mesh = dot_mesh
        d.material_override = dot_mat
        d.visible = false
        add_child(d)
        dots.append(d)

    fx = Fx.new()
    add_child(fx)
    fx.blast_scale = clampf(cannon_pos.distance_to(camera_look_base) / 13.0, 1.0, 2.2)
    weather = Weather.new()
    add_child(weather)
    weather.setup(self, float(data.get("sea", 0.0)), ship_pos)
    ambience = Ambience.new()
    add_child(ambience)
    ambience.setup(float(data.get("sea", 0.0)), bool(settings.get("sound", true)))
    weather.thunder.connect(ambience.thunder)
    if storm:
        next_thunder = Tuning.THUNDER_MIN
    gyro_available = Input.get_gyroscope().length() > 0.0 or OS.has_feature("mobile")
    fx.prewarm(ship_pos + Vector3(0, 2, 0))

## The castle's footprint in x/z, from its blocks (not counting rock or cliff bases' extra
## width), so scenery keeps clear of it.
func _castle_rect() -> Rect2:
    var r := Rect2()
    var first := true
    for b in data.blocks:
        var p := _v3(b.position)
        var sz := _v3(b.size)
        var box := Rect2(p.x - sz.x / 2.0, p.z - sz.z / 2.0, sz.x, sz.z)
        r = box if first else r.merge(box)
        first = false
    return r

func camera_look_base_guess() -> Vector3:
    return _v3(data.camera.lookAt)

func _v3(a: Array) -> Vector3:
    return Vector3(float(a[0]), float(a[1]), float(a[2]) + Z_OFF)

## Poly Haven cannon: the carriage turns with the aim, the barrel tilts on its trunnions.
const CANNON_LENGTH := 1.25
const CANNON_SRC := "res://assets/hq/cannon/cannon_01_1k.gltf"

func _build_cannon() -> void:
    cannon = Node3D.new()
    cannon.position = ship.cannon_mount
    ship.add_child(cannon)
    cannon_pivot = Node3D.new()
    cannon.add_child(cannon_pivot)
    cannon_elevation = Node3D.new()
    cannon_pivot.add_child(cannon_elevation)
    cannon_barrel = Node3D.new()
    cannon_elevation.add_child(cannon_barrel)
    var src: Node3D = Models.instance(CANNON_SRC)
    var bounds := Models.aabb_of(src)
    # The source faces +z; half a turn points it at the island, scaled to CANNON_LENGTH.
    var sc := CANNON_LENGTH / maxf(bounds.size.z, 0.01)
    var place := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(sc, sc, sc)), Vector3.ZERO)
    var barrel_box := AABB()
    for c in src.find_children("*", "MeshInstance3D", true, false):
        if c.name.contains("barrel"):
            barrel_box = Models._relative_transform(src, c) * (c as MeshInstance3D).mesh.get_aabb()
    # Trunnions: a little behind the middle of the barrel, at its axis.
    var trunnion_src := Vector3(barrel_box.get_center().x, barrel_box.get_center().y, barrel_box.position.z + barrel_box.size.z * 0.3)
    var trunnion := place * trunnion_src
    cannon_elevation.position = trunnion
    muzzle_local = place * Vector3(barrel_box.get_center().x, barrel_box.get_center().y, barrel_box.end.z) - trunnion
    for c in src.find_children("*", "MeshInstance3D", true, false):
        var mi := c as MeshInstance3D
        if mi.name.contains("ball"):
            continue   # the loose balls lying beside the carriage
        var part := MeshInstance3D.new()
        part.mesh = mi.mesh
        var t := place * Models._relative_transform(src, mi)
        if mi.name.contains("barrel"):
            part.transform = Transform3D(Basis.IDENTITY, -trunnion) * t
            cannon_barrel.add_child(part)
        else:
            part.transform = t
            cannon_pivot.add_child(part)
    src.free()
    if old_cannon:
        # Old Tomas's cannon: smaller, rusty.
        cannon.scale = Vector3(0.78, 0.78, 0.78)
        Models.tint(cannon, Color(0.85, 0.62, 0.45))
    else:
        # The barrel takes on the colour of the cannon's rank.
        var rank_color: Color = Tuning.rank(upgrades)[2]
        Models.tint(cannon_barrel, Color.WHITE.lerp(rank_color * 1.4, 0.55))

func _spawn_block(b: Dictionary) -> void:
    var blk := Block.new()
    var size := _v3(b.size) - Vector3(0, 0, Z_OFF)
    var visual := _block_visual(b.material, size, b.get("style", ""))
    blk.setup(b.material, size, b.get("style", ""), bool(b.get("isStatic", false)), b.get("motion", {}), false, visual)
    blk.position = _v3(b.position)
    if b.has("rotation"):
        var r: Array = b.rotation
        blk.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
    blk.base_position = blk.position
    blk.cage_id = int(b.get("cage", -1))
    blk.broke.connect(_on_block_broke)
    add_child(blk)

func _block_visual(mat: String, size: Vector3, style_raw: String) -> Node3D:
    var parts := style_raw.split(":")
    var style: String = parts[0] if parts.size() > 0 else ""
    var tint: String = parts[1] if parts.size() > 1 else ""
    var tint_color := Color.WHITE
    match tint:
        "sand": tint_color = Color(1.0, 0.88, 0.70)
        "white": tint_color = Color(1.1, 1.1, 1.08)
        "dark": tint_color = Color(0.62, 0.60, 0.66)
        "red": tint_color = Color(1.0, 0.70, 0.62)
    var root := Node3D.new()
    match style:
        "tower":
            # Round brick tower with a tiled cone roof (Atmosphere puts cloth flags on top).
            var body := MeshInstance3D.new()
            var cm := CylinderMesh.new()
            cm.top_radius = size.x * 0.5
            cm.bottom_radius = size.x * 0.54
            cm.height = size.y
            cm.radial_segments = 20
            body.mesh = cm
            body.material_override = Models.tex_material("castle_brick_07", 0.8, tint_color)
            root.add_child(body)
            var ring := MeshInstance3D.new()
            var rm := CylinderMesh.new()
            rm.top_radius = size.x * 0.62
            rm.bottom_radius = size.x * 0.58
            rm.height = size.x * 0.22
            rm.radial_segments = 20
            ring.mesh = rm
            ring.material_override = Models.tex_material("castle_brick_07", 0.8, tint_color * Color(0.85, 0.85, 0.85))
            ring.position.y = size.y / 2.0 - size.x * 0.11
            root.add_child(ring)
            var roof := MeshInstance3D.new()
            var rc := CylinderMesh.new()
            rc.top_radius = 0.0
            rc.bottom_radius = size.x * 0.7
            rc.height = size.x * 1.3
            rc.radial_segments = 20
            roof.mesh = rc
            roof.material_override = Models.tex_material("clay_roof_tiles_02", 1.2, Color(0.95, 0.75, 0.7))
            roof.position.y = size.y / 2.0 + size.x * 0.65
            root.add_child(roof)
        "gate":
            var g := Models.instance("res://assets/castle/gate.glb")
            Models.fit(g, size)
            root.add_child(g)
        "log":
            # A round log along its longest side, bark on; upright ones end in a sharpened point.
            var axis := 1
            if size.x >= size.y and size.x >= size.z:
                axis = 0
            elif size.z >= size.y and size.z >= size.x:
                axis = 2
            var length: float = size[axis]
            var r := minf(size[(axis + 1) % 3], size[(axis + 2) % 3]) * 0.5
            var log := MeshInstance3D.new()
            var cm := CylinderMesh.new()
            cm.top_radius = r
            cm.bottom_radius = r
            cm.height = length - (r * 1.4 if axis == 1 else 0.0)
            cm.radial_segments = 10
            log.mesh = cm
            if _bark == null:
                _bark = StandardMaterial3D.new()
                _bark.albedo_texture = load("res://assets/hq/oak_trees/textures/bark1_baseColor.png")
                _bark.uv1_scale = Vector3(1.0, 2.0, 1.0)
                _bark.roughness = 0.95
            log.material_override = _bark
            if axis == 0:
                log.rotation.z = PI / 2.0
            elif axis == 2:
                log.rotation.x = PI / 2.0
            else:
                log.position.y = -r * 0.7
                var tip := MeshInstance3D.new()
                var tm := CylinderMesh.new()
                tm.top_radius = 0.0
                tm.bottom_radius = r
                tm.height = r * 1.4
                tm.radial_segments = 10
                tip.mesh = tm
                tip.material_override = _bark
                tip.position.y = length / 2.0 - r * 0.7
                root.add_child(tip)
            root.add_child(log)
        "roof":
            root.add_child(_box(size, Models.tex_material("clay_roof_tiles_02", 1.2, Color(0.95, 0.75, 0.7))))
        "crate":
            var c := Models.prop("wooden_crate_01")
            var holder := Node3D.new()
            holder.add_child(c)
            Models.fit(holder, size)
            root.add_child(holder)
        "barrel":
            var c := Models.prop("wine_barrel_01")
            var holder := Node3D.new()
            holder.add_child(c)
            Models.fit(holder, size, true)
            root.add_child(holder)
        "boulder", "rock":
            var r := Models.prop("boulder_01")
            var holder := Node3D.new()
            holder.add_child(r)
            Models.fit(holder, size, style == "boulder")
            root.add_child(holder)
        "plateau", "cliff":
            # A rock (or sea cliff) the castle stands on: rock faces fitted to the box, a grass
            # top so the castle stands on turf.
            var rock := Models.prop("namaqualand_cliff_01" if style == "cliff" else "boulder_01")
            var holder := Node3D.new()
            holder.add_child(rock)
            Models.fit(holder, size * Vector3(1.04, 1.0, 1.08))
            root.add_child(holder)
            if style == "plateau":
                # Two more boulders break up the outline.
                for side: float in [-1.0, 1.0]:
                    var r2 := Models.prop("namaqualand_boulder_02")
                    var h2 := Node3D.new()
                    h2.add_child(r2)
                    Models.fit(h2, Vector3(size.x * 0.35, size.y * 0.9, size.z * 0.8))
                    h2.position = Vector3(side * size.x * 0.36, 0, size.z * 0.12)
                    root.add_child(h2)
            var cap := _box(Vector3(size.x * 0.97, 0.14, size.z * 0.95), Models.tex_material("leafy_grass", 0.35, Color(0.9, 0.95, 0.85)))
            cap.position.y = size.y / 2.0 - 0.05
            root.add_child(cap)
        "hill":
            var mi := MeshInstance3D.new()
            var bm := BoxMesh.new()
            bm.size = size
            mi.mesh = bm
            mi.material_override = Models.tex_material("coast_sand_01", 0.5, Color(0.72, 0.62, 0.50))
            root.add_child(mi)
            var cap := MeshInstance3D.new()
            var capm := BoxMesh.new()
            capm.size = Vector3(size.x, 0.12, size.z)
            cap.mesh = capm
            cap.material_override = Models.tex_material("leafy_grass", 0.4)
            cap.position.y = size.y / 2.0
            root.add_child(cap)
        _:
            match mat:
                "stone":
                    # Sand-coloured walls are dressed coral stone blocks; the rest brick.
                    if tint == "sand":
                        root.add_child(_box(size, Models.tex_material("large_sandstone_blocks", 0.45)))
                    else:
                        root.add_child(_box(size, Models.tex_material("castle_brick_07", 0.8, tint_color)))
                "wood":
                    root.add_child(_box(size, Models.wood_material()))
                "tnt":
                    # A powder barrel (Poly Haven), painted red.
                    var c := Models.prop("barrel_03")
                    var holder := Node3D.new()
                    holder.add_child(c)
                    Models.fit(holder, size, true)
                    Models.tint(holder, Color(2.4, 0.42, 0.32))
                    root.add_child(holder)
                "glass":
                    var gm := StandardMaterial3D.new()
                    gm.albedo_color = Color(0.62, 0.88, 0.80, 0.42)
                    gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    gm.roughness = 0.08
                    root.add_child(_box(size, gm))
                "metal":
                    root.add_child(_box(size, Models.flat_material(Color(0.30, 0.32, 0.34), 0.35, 0.9)))
                _:
                    root.add_child(_box(size, Models.flat_material(Color(0.78, 0.74, 0.76), 0.9)))
    return root

func _box(size: Vector3, material: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = material
    return mi

func _spawn_captive(c: Dictionary, index: int) -> void:
    var cap := Captive.new()
    cap.deserter = bool(c.get("deserter", false))
    cap.cage_id = int(c.get("cage", -1))
    cap.setup(index)
    cap.position = _v3(c.position)
    cap.start = cap.position
    cap.freed.connect(_on_captive_freed)
    add_child(cap)

func _on_captive_freed(cap: Captive) -> void:
    if phase == Phase.FINISHED:
        return
    captives_freed += 1
    bonus += 500
    fx.confetti(cap.global_position + Vector3(0, 0.6, 0))
    event.emit("freed", {"deserter": cap.deserter, "count": captives_freed})

func _free_cage(id: int) -> void:
    for n in get_tree().get_nodes_in_group("captives"):
        var cap := n as Captive
        if cap.cage_id == id and not cap.is_free:
            cap.call_deferred("free_now")

func _spawn_target(t: Dictionary, index: int) -> void:
    var e := Enemy.new()
    e.armed = bool(t.get("armed", false))
    e.boss = bool(t.get("boss", false))
    e.setup(float(t.get("radius", 0.28)), index, level_time)
    e.fired.connect(_on_enemy_fired)
    e.position = _v3(t.position)
    e.base_position = e.position
    e.popped.connect(_on_enemy_popped)
    add_child(e)

func _spawn_gun(g: Dictionary) -> void:
    var gun := EnemyGun.new()
    gun.setup(float(g.get("interval", 6.0)), float(g.get("power", 0.5)))
    gun.position = _v3(g.position)
    gun.fired.connect(_on_enemy_fired)
    gun.destroyed.connect(_on_gun_destroyed)
    add_child(gun)
    enemy_guns.append(gun)

func _spawn_enemy_ship(s: Dictionary) -> void:
    var es := EnemyShip.new()
    # Longboats rowing at you are small; gunships at anchor are bigger.
    var length := 4.5 if float(s.get("speed", 0.0)) > 0.0 else 6.5
    es.setup(float(s.get("speed", 0.0)), int(s.get("hitPoints", 2)), bool(s.get("hasCannon", true)), float(s.get("interval", 7.0)), length)
    es.position = _v3(s.position)
    es.fired.connect(_on_enemy_fired)
    es.sunk.connect(_on_ship_sunk)
    es.rammed.connect(_on_ship_rammed)
    add_child(es)
    enemy_ships.append(es)

func _freeze_all(value: bool) -> void:
    frozen = value
    for n in get_tree().get_nodes_in_group("blocks"):
        (n as Block).set_frozen(value)
    for n in get_tree().get_nodes_in_group("enemies"):
        var en := n as Enemy
        en.set_frozen(value)
        if not value:
            en.spawn_time = time
    for g in enemy_guns:
        g.set_frozen(value)
    for n in get_tree().get_nodes_in_group("captives"):
        var cap := n as Captive
        if not cap.is_free:
            cap.freeze = value

# MARK: Loop

func _process(delta: float) -> void:
    if is_paused:
        return
    time += delta
    if phase == Phase.LOADING and time >= loading_end:
        phase = Phase.INTRO
        event.emit("phase", {})
    if phase == Phase.INTRO and time >= intro_end:
        phase = Phase.AIMING
        event.emit("phase", {})
    if auto_fire >= 0.0 and not _auto_fired and phase == Phase.AIMING and time >= intro_end + sail_after:
        _auto_fired = true
        set_aim(auto_fire_yaw, auto_fire_pitch)
        fire(auto_fire)
    # Aim and camera follow the phone in real time, even while slow motion runs.
    var real_delta := delta / maxf(Engine.time_scale, 0.05)
    _update_gyro(real_delta)
    # Turning the cannon clicks under the hand, a notch every degree and a half (aim view only).
    if phase == Phase.AIMING and zoom_out < 0.15:
        _turn_accum += absf(aim_yaw - _prev_yaw) + absf(aim_pitch - _prev_pitch)
        if _turn_accum > 8.0:
            _turn_accum = 0.0
            Haptics.detent()
    _prev_yaw = aim_yaw
    _prev_pitch = aim_pitch
    _rock_ship()
    _sway_trees()
    _apply_aim()
    if can_load():
        _update_trajectory()
    else:
        for d in dots:
            d.visible = false
    _update_enemies(delta)
    _update_projectiles()
    _update_fires(delta)
    _track_near_miss()
    _update_camera(real_delta)
    _check_progress()
    if blast_slowmo_end >= 0.0 and time >= blast_slowmo_end:
        blast_slowmo_end = -1.0
        if phase != Phase.SLOWMO and phase != Phase.FINISHED:
            Engine.time_scale = 1.0
    if is_storm():
        _update_weather()

## Wood that lands in the sea floats: it splashes in, sinks a little, is pushed back up by
## the water it displaces, bobs with the waves and slowly drifts. Stone and iron sink.
func _physics_process(delta: float) -> void:
    if sea == null or frozen:
        return
    for n in get_tree().get_nodes_in_group("blocks"):
        var b := n as Block
        if b.freeze or b.material_name != "wood":
            continue
        var p := b.global_position
        if not open_sea and p.z < Tuning.SHORE_Z + 0.5:
            continue
        var water := Tuning.SEA_LEVEL + sea.height(p.x, p.z)
        var half := minf(b.size.x, minf(b.size.y, b.size.z)) * 0.5
        var depth := water - (p.y - half)
        if depth <= 0.0:
            b.set_meta("wet", false)
            continue
        if not b.get_meta("wet", false):
            b.set_meta("wet", true)
            if b.linear_velocity.y < -2.0:
                fx.splash(Vector3(p.x, water, p.z))
        # Wood is about half as dense as water. It hits the surface, is slowed hard by it,
        # and settles half under with no spring: strong damping on vertical motion so it
        # never bobs out. Rocking comes from the waves it rides.
        var submerged := clampf(depth / (half * 2.0), 0.0, 1.0)
        var target := water + half * 0.1 - p.y              # float line
        var v := b.linear_velocity
        var up := target * 14.0 - v.y * 7.0                 # stiff, critically damped
        b.apply_central_force(Vector3(0, (9.8 + up) * b.mass * minf(submerged * 3.0, 1.0), 0))
        var drift := Vector3(sea.sample(p.x, p.z).y * -1.0, 0.0, 0.0)
        b.linear_velocity = Vector3(lerpf(v.x, drift.x, minf(delta * 2.0, 1.0)), v.y, lerpf(v.z, 0.0, minf(delta * 2.0, 1.0)))
        b.angular_velocity = b.angular_velocity.lerp(Vector3.ZERO, minf(delta * 2.5, 1.0))
        # Floating wood turns to lie flat on the water: its thinnest side ends up facing up.
        var basis := b.global_transform.basis
        var thin := 0
        for k in 3:
            if b.size[k] < b.size[thin]:
                thin = k
        var axis := basis[thin].normalized()
        if axis.dot(Vector3.UP) < 0.0:
            axis = -axis
        var turn := axis.cross(Vector3.UP)
        b.angular_velocity += turn * delta * 6.0 * submerged
        # Anything that drifts in close to our ship slips under, so it never blocks the view.
        if p.z > ship.global_position.z - 7.0:
            b.set_meta("sinking", true)
        if b.get_meta("sinking", false):
            b.apply_central_force(Vector3(0, -9.8 * b.mass * 3.0, 0))
            if p.y < water - 3.0:
                b.queue_free()
        b.angular_velocity = b.angular_velocity.lerp(Vector3.ZERO, minf(delta * 1.5 * submerged, 1.0))

## Trees lean and sway with the wind, harder in a storm, with slow gusts.
func _sway_trees() -> void:
    var wind := Tuning.TREE_SWAY_CALM + Tuning.TREE_SWAY_STORM * float(data.get("sea", 0.0))
    var dt := get_process_delta_time()
    for n in get_tree().get_nodes_in_group("mill_sails"):
        (n as Node3D).rotation.z -= dt * float(n.get_meta("speed")) * (1.0 + float(data.get("sea", 0.0)))
    for n in get_tree().get_nodes_in_group("sway"):
        var t := n as Node3D
        var ph: float = t.get_meta("phase")
        var gust := 0.6 + 0.4 * sin(time * 0.37 + ph * 0.25)
        var sway := sin(time * 1.4 + ph) * wind * gust
        # Lean downwind (+x), sway about it; applied in world axes, then the tree's own yaw.
        var k: float = t.get_meta("scale")
        t.basis = (Basis.from_euler(Vector3(sway * 0.35, 0, -(wind * 0.5 * gust + sway))) * Basis(Vector3.UP, t.get_meta("yaw"))).scaled(Vector3(k, k, k))

func _rock_ship() -> void:
    # Sail in from the right (bow first, to the left) and ease to a stop as aiming starts.
    var span := intro_end - loading_end + sail_after
    var k := clampf((time - loading_end) / span, 0.0, 1.0)
    var eased := sin(k * PI / 2.0)
    ship.position.x = ship_base_x + sail_in * (1.0 - eased)
    var p := ship.position
    var dt := get_process_delta_time()
    # The hull floats on the water under its whole length: bow, stern and both sides. It
    # heaves with their average, pitches with bow against stern and rolls with side against
    # side, and being heavy it follows the sea a little behind, never jerking.
    var half_l := Ship.LENGTH * 0.45
    var half_w := 1.2
    var bow := sea.height(p.x - half_l, p.z)
    var stern := sea.height(p.x + half_l, p.z)
    var port := sea.height(p.x, p.z - half_w)
    var starboard := sea.height(p.x, p.z + half_w)
    var mid := sea.height(p.x, p.z)
    var level_y := Tuning.SEA_LEVEL + (bow + stern + port + starboard + mid * 2.0) / 6.0 + Tuning.SHIP_FREEBOARD + ship_lift
    var trim := clampf(atan2(stern - bow, half_l * 2.0), -0.22, 0.22)      # fore and aft
    var heel := clampf(atan2(starboard - port, half_w * 2.0) * 0.55, -0.2, 0.2)   # side to side
    var follow := minf(dt * 3.5, 1.0)
    ship.position.y = lerpf(ship.position.y, level_y, follow) if time > 0.1 else level_y
    _trim = lerpf(_trim, trim, follow)
    _heel = lerpf(_heel, heel, follow)
    # Recoil heel: a damped spring kicked by each shot.
    _kick_vel += (-kick * 30.0 - _kick_vel * 5.0) * dt
    kick += _kick_vel * dt
    ship.rotation = Vector3(-_heel - kick, 0, _trim)
    camera_up = Vector3(sin(_trim * 0.4), cos(_trim * 0.4), 0)
    sea.set_hull(ship.position, Ship.LENGTH * 0.47, 1.35, ship.position.y - 0.45)

func cannon_world() -> Vector3:
    return ship.to_global(ship.cannon_mount)

func muzzle_world() -> Vector3:
    return cannon_barrel.to_global(muzzle_local)

func _apply_aim() -> void:
    cannon_pivot.rotation = Vector3(0, deg_to_rad(-aim_yaw), 0)
    cannon_elevation.rotation = Vector3(deg_to_rad(aim_pitch), 0, 0)
    cannon_barrel.position = Vector3(0, 0, power * 0.12 + recoil)

func aim_direction() -> Vector3:
    var y := deg_to_rad(aim_yaw)
    var p := deg_to_rad(aim_pitch)
    var local := Vector3(sin(y) * cos(p), sin(p), -cos(y) * cos(p))
    return (ship.global_transform.basis * local).normalized()

func launch_speed(pw: float, type: String) -> float:
    return _base_launch_speed(pw, type) * power_scale

func _base_launch_speed(pw: float, type: String) -> float:
    return (Tuning.LAUNCH_SPEED_BASE + pw * Tuning.LAUNCH_SPEED_SCALE) * float(Tuning.AMMO[type].speed)

## The next ball can be loaded while the last one is still flying or the castle settling.
func can_load() -> bool:
    if projectiles_remaining <= 0:
        return false
    if phase == Phase.AIMING:
        return true
    return (phase == Phase.IN_FLIGHT or phase == Phase.SETTLING) and time - last_shot_time >= reload_time

func _update_trajectory() -> void:
    if not bool(settings.get("trajectory", true)):
        return
    var loading := power > 0.01
    var pw := power if loading else 0.45
    var v := aim_direction() * launch_speed(pw, next_ammo())
    var origin := muzzle_world()
    var count := 0
    for i in dots.size():
        var t := float(i + 1) * 0.045
        var p := origin + v * t + Vector3(0, -0.5 * Tuning.GRAVITY * t * t, 0)
        if p.y < 0.0:
            break
        dots[i].global_position = p
        dots[i].visible = true
        var k := float(i) / float(dots.size() - 1)
        var sc := (1.15 - 0.6 * k) * (1.0 if loading else 0.8)
        dots[i].scale = Vector3(sc, sc, sc)
        count = i + 1
    for i in range(count, dots.size()):
        dots[i].visible = false

# MARK: Input

## Handled in _input so HUD panels never swallow a drag. Buttons live in the top right column.
func _input(ev: InputEvent) -> void:
    if phase == Phase.LOADING or phase == Phase.INTRO or phase == Phase.FINISHED or is_paused:
        return
    var vp := get_viewport().get_visible_rect().size
    var drag_aim := not (gyro_enabled and gyro_available)
    if ev is InputEventScreenTouch:
        var t := ev as InputEventScreenTouch
        if t.pressed:
            if t.position.x > vp.x * 0.82 and t.position.y < vp.y * 0.22:
                return   # HUD buttons
            for r in ui_blocks:
                if r.has_point(t.position):
                    return
            _touches[t.index] = t.position
            if _touches.size() == 2:
                # Second finger: pinch to zoom out and see the ship. Cancels any load in progress.
                var pts := _touches.values()
                _pinch_start = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
                if _load_touch >= 0:
                    _load_touch = -1
                    power = 0.0
                    event.emit("power", {"power": 0.0})
                _aim_touch = -1
                return
            # Undecided until the finger moves: sideways or up aims (touch mode), down loads.
            if _aim_touch < 0 and _load_touch < 0:
                _pending_touch = t.index
                _touch_start = t.position
        else:
            _touches.erase(t.index)
            if _touches.size() < 2:
                _pinch_start = -1.0
                _zoom_target = 0.0
            if t.index == _pending_touch:
                _pending_touch = -1
            if t.index == _aim_touch:
                _aim_touch = -1
            elif t.index == _load_touch:
                _load_touch = -1
                _release_load()
    elif ev is InputEventScreenDrag:
        var d := ev as InputEventScreenDrag
        if _touches.has(d.index):
            _touches[d.index] = d.position
        if _pinch_start > 0.0 and _touches.size() == 2:
            var pts := _touches.values()
            var dist := (pts[0] as Vector2).distance_to(pts[1] as Vector2)
            _zoom_target = clampf((_pinch_start - dist) / (vp.x * 0.45), 0.0, 1.0)
            return
        if d.index == _pending_touch:
            var mv := d.position - _touch_start
            if mv.length() > 24.0:
                _pending_touch = -1
                if mv.y > absf(mv.x) * 0.8:
                    if can_load():
                        _load_touch = d.index
                        _load_start_y = _touch_start.y
                elif drag_aim:
                    _aim_touch = d.index
                    _aim_last = _touch_start
                else:
                    # Gyro mode but the finger tries to aim: show how to aim with the phone.
                    event.emit("touch_aim_tried", {})
        if d.index == _aim_touch:
            var delta := d.position - _aim_last
            _aim_last = d.position
            set_aim(aim_yaw + delta.x * Tuning.AIM_DEG_PER_PX, aim_pitch - delta.y * Tuning.AIM_DEG_PER_PX)
        elif d.index == _load_touch:
            var pull := maxf(d.position.y - _load_start_y, 0.0)
            set_power(minf(pull / Tuning.DRAG_FULL_POWER_PX, 1.0))

func set_aim(yaw: float, pitch: float) -> void:
    aim_yaw = clampf(yaw, -Tuning.YAW_RANGE, Tuning.YAW_RANGE)
    aim_pitch = clampf(pitch, Tuning.PITCH_MIN, Tuning.PITCH_MAX)

func set_power(v: float) -> void:
    var tick_before := int(power / 0.05)
    power = v
    if int(power / 0.05) > tick_before and power > 0.0:
        Haptics.tick(power)
    event.emit("power", {"power": power})

func _release_load() -> void:
    var released := power
    power = 0.0
    event.emit("power", {"power": 0.0})
    if released >= Tuning.MIN_FIRE_POWER and can_load():
        fire(released)

func _update_gyro(delta: float) -> void:
    if not (gyro_enabled and gyro_available):
        return
    var g := Input.get_gyroscope()
    if phase == Phase.LOADING or phase == Phase.INTRO:
        # During the fly-in the phone looks around a little, then the view settles back.
        var rate := Vector2(-g.y, g.x)
        if rate.length() < Tuning.GYRO_DEADZONE:
            rate = Vector2.ZERO
        _intro_look += rate * rad_to_deg(1.0) * delta * 0.8
        _intro_look = _intro_look.clamp(Vector2(-18, -10), Vector2(18, 10))
        return
    _intro_look = _intro_look.lerp(Vector2.ZERO, minf(delta * 3.0, 1.0))
    if phase == Phase.FINISHED:
        return
    # Yaw from the gyro about the phone's vertical axis, with the reference sliding along past
    # the limit so turning back moves the aim at once. Gain and deadzone keep it calm.
    var rate := -g.y
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
    # Pitch from gravity: absolute, no drift.
    var grav := Input.get_gravity()
    var pitch_abs := rad_to_deg(atan2(grav.z, -grav.y)) * Tuning.GYRO_GAIN if grav.length() > 0.5 else 0.0
    var pitch := pitch_abs - _pitch_ref
    if pitch > Tuning.PITCH_MAX:
        _pitch_ref = pitch_abs - Tuning.PITCH_MAX
        pitch = Tuning.PITCH_MAX
    elif pitch < Tuning.PITCH_MIN:
        _pitch_ref = pitch_abs - Tuning.PITCH_MIN
        pitch = Tuning.PITCH_MIN
    aim_yaw = lerpf(aim_yaw, yaw, minf(delta * Tuning.GYRO_SMOOTH, 1.0))
    aim_pitch = lerpf(aim_pitch, pitch, minf(delta * Tuning.GYRO_SMOOTH, 1.0))

func recenter() -> void:
    _yaw_offset = _yaw_raw
    var grav := Input.get_gravity()
    _pitch_ref = rad_to_deg(atan2(grav.z, -grav.y)) * Tuning.GYRO_GAIN if grav.length() > 0.5 else 0.0
    aim_yaw = 0.0
    aim_pitch = 0.0

func set_gyro(enabled: bool) -> void:
    gyro_enabled = enabled
    settings["gyro"] = enabled
    if enabled:
        recenter()

func fire(pw: float) -> void:
    if not can_load():
        return
    var type := next_ammo()
    var special := type == armed_special and armed_special != ""
    var v := aim_direction() * launch_speed(pw, type)
    var origin := muzzle_world()
    var p := Projectile.new()
    add_child(p)
    p.global_position = origin
    p.setup(type, v)
    p.spawn_time = time
    p.exploded.connect(func(at): explode(at))
    p.splashed.connect(func(at): fx.splash(at); ambience.splash(); event.emit("splash", {}))
    active_projectile = p
    if special:
        specials[type] = int(specials[type]) - 1
        armed_special = ""
    else:
        projectiles_remaining -= 1
        regular_used += 1
    shots_used += 1
    last_shot_time = time
    # A fresh shot: new combo chances, one action cam, near miss tracking.
    shot_pops = 0
    _cine_used = false
    _shot_min_dist = INF
    _shot_start_breaks = blocks_broken
    _shot_start_targets = targets_remaining
    _shot_blasts = 0
    p.smashed.connect(_smash_around)
    p.hit.connect(func(_b):
        _end_follow()
        _spark_near(p))
    # The shot that may win it: a touch of slow motion while it flies.
    if targets_remaining + ships_remaining <= 1 or (projectiles_remaining == 0 and specials_left() == 0):
        follow = true
        _follow_until = _now() + 3.0
        Engine.time_scale = Tuning.FOLLOW_SLOWMO
    # Kick: the ship heels away from the shot and the carriage rolls back.
    _kick_vel = Tuning.KICK_ROLL * 9.0
    var roll_back := create_tween()
    roll_back.tween_property(cannon_pivot, "position:z", 0.32, 0.08).set_ease(Tween.EASE_OUT)
    roll_back.tween_property(cannon_pivot, "position:z", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
    settle_start = -1.0
    phase = Phase.IN_FLIGHT
    recoil = 0.18
    fx.muzzle(origin)
    ambience.cannon(pw)
    Haptics.thump()
    event.emit("fired", {})

# MARK: Breaking and blasts

func _on_block_broke(blk: Block) -> void:
    var pos := blk.global_position
    var mat := blk.material_name
    if blk.cage_id >= 0:
        _free_cage(blk.cage_id)
    blocks_broken += 1
    if mat == "tnt":
        blk.queue_free()
        explode(pos)
        return
    if fragments_alive + Tuning.FRAGMENT_COUNT > Tuning.MAX_FRAGMENTS:
        # Too much rubble already: this piece falls whole instead of splitting.
        blk.break_threshold = -1.0
        fx.dust(pos, mat)
        return
    _fragment(blk)
    blk.queue_free()
    fx.dust(pos, mat)
    if mat == "wood":
        ambience.crack()
        fx.splinters(pos, 10 if blk.is_fragment else 16)
        Haptics.crack()
    event.emit("broke", {"material": mat})

func _fragment(blk: Block) -> void:
    if fragments_alive >= Tuning.MAX_FRAGMENTS:
        return
    var size := blk.size
    var blasted := blk.has_meta("blast_v")
    var n := Tuning.FRAGMENT_COUNT + (2 if blasted else 0)
    var axis := 0
    if size.y > size.x and size.y > size.z:
        axis = 1
    elif size.z > size.x and size.z > size.y:
        axis = 2
    var piece := size
    piece[axis] = size[axis] / float(n)
    var color: Color
    match blk.material_name:
        "wood": color = Color(0.93, 0.55, 0.40)
        "glass": color = Color(0.62, 0.88, 0.80, 0.6)
        "stone": color = Color(0.78, 0.74, 0.76)
        _: color = Color(0.5, 0.5, 0.5)
    for i in n:
        var f := Block.new()
        var mi := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = piece * 0.92
        mi.mesh = bm
        match blk.material_name:
            "wood": mi.material_override = Models.tex_material("brown_planks_07", 0.9, Color(0.35, 0.28, 0.24)) if blk.burning or blk.burn_time > 0.0 else Models.wood_material()
            "stone": mi.material_override = Models.tex_material("castle_brick_07", 0.8)
            _: mi.material_override = Models.flat_material(color, 0.9)
        f.setup(blk.material_name, piece * 0.92, "", false, {}, true, mi)
        var local := Vector3.ZERO
        local[axis] = (float(i) + 0.5) * piece[axis] - size[axis] / 2.0
        f.position = blk.to_global(local)
        f.rotation = blk.global_rotation
        var push: Vector3 = blk.get_meta("blast_v", Vector3.ZERO)
        var spread := 3.0 if blasted else 1.2
        f.linear_velocity = blk.linear_velocity + push + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * spread
        f.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
        f.spawn_time = time
        add_child(f)
        fragments_alive += 1
        f.tree_exited.connect(func(): fragments_alive -= 1)

func explode(center: Vector3) -> void:
    blast_count += 1
    _shot_blasts += 1
    _register_combo()
    blast_shake = minf(1.0 + 0.25 * (combo - 1), 1.8)
    fx.blast(center)
    fx.blast_light(center, 9.0 if style.get("sky", "") == "night" else 3.5)
    fx.smoke_column(center + Vector3(0, 0.5, 0))
    ambience.blast()
    _start_cine(center)
    event.emit("blast", {})
    Haptics.rumble(combo)
    if phase != Phase.SLOWMO and phase != Phase.FINISHED and cine_until < 0.0:
        Engine.time_scale = 0.35
        blast_slowmo_end = time + 0.45
    for n in get_tree().get_nodes_in_group("dynamic"):
        if not (n is RigidBody3D):
            continue
        var body := n as RigidBody3D
        var off := body.global_position - center
        var dist := off.length()
        var radius := Tuning.TNT_RADIUS * powder_scale * float(data.get("blast_radius", 1.0))
        # Powder catches from further away than a blast can break wood: chains carry on.
        var catches := body is Block and (body as Block).material_name == "tnt" and not (body as Block).is_fragment
        if dist >= radius * (1.5 if catches else 1.0):
            continue
        var falloff := 1.0 - dist / radius
        # Thrown out in every direction and up, with a random twist so pieces scatter wide.
        var dir := Vector3.UP if dist < 0.05 else (off.normalized() + Vector3(randf_range(-0.35, 0.35), 0.55, randf_range(-0.35, 0.35))).normalized()
        var dv := Tuning.TNT_BLAST_SPEED * (0.35 + 0.65 * falloff)
        if body is Block and (body as Block).frozen:
            (body as Block).set_frozen(false)
        if body is Enemy and (body as Enemy).frozen:
            (body as Enemy).set_frozen(false)
        body.apply_central_impulse(dir * dv * body.mass)
        body.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * dv * body.mass * 0.3)
        if body is Block:
            var b := body as Block
            b.set_meta("blast_v", dir * dv)
            if b.material_name == "tnt" and not b.is_fragment:
                # Chain reaction: the next crate goes a beat later, so the fort goes up in a
                # rolling cascade instead of one flash.
                var id := b.get_instance_id()
                get_tree().create_timer(Tuning.TNT_CHAIN_DELAY).timeout.connect(func():
                    var crate := instance_from_id(id) as Block
                    if crate and not crate.is_queued_for_deletion():
                        crate.break_now())
            elif b.break_threshold >= 0.0 and dv > b.break_threshold and not b.is_fragment:
                b.call_deferred("break_now")
        elif body is Enemy:
            if dv > Tuning.TARGET_BREAK_IMPULSE:
                (body as Enemy).call_deferred("pop")
        elif body is EnemyGun:
            if dv > Tuning.ENEMY_CANNON_BREAK:
                _on_gun_destroyed(body as EnemyGun)

func _on_enemy_popped(e: Enemy) -> void:
    var pos := e.global_position
    # Burst at once and fly off tumbling; drop loot.
    fx.pop(pos, e.body_color)
    _fly_off(e)
    e.queue_free()
    targets_remaining -= 1
    shot_pops += 1
    _register_combo()
    _drop_coins(pos)
    ambience.pop()
    Haptics.pop()
    if shot_pops >= 2:
        event.emit("multi", {"count": shot_pops})
    event.emit("target", {"remaining": targets_remaining})
    if targets_remaining == 0 and ships_remaining == 0:
        _begin_win(pos)

func _on_gun_destroyed(gun: EnemyGun) -> void:
    if not is_instance_valid(gun) or gun.is_queued_for_deletion():
        return
    fx.dust(gun.global_position, "metal")
    fx.pop(gun.global_position, Color(0.98, 0.78, 0.32))
    enemy_guns.erase(gun)
    gun.queue_free()
    blocks_broken += 1
    event.emit("broke", {"material": "metal"})

func _on_enemy_fired(from: Vector3, velocity: Vector3) -> void:
    var ball := RigidBody3D.new()
    ball.mass = 12.0
    var shape := CollisionShape3D.new()
    var s := SphereShape3D.new()
    s.radius = 0.15
    shape.shape = s
    ball.add_child(shape)
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.15
    sm.height = 0.3
    mi.mesh = sm
    mi.material_override = Models.flat_material(Color(0.45, 0.08, 0.08), 0.4, 0.5)
    ball.add_child(mi)
    ball.continuous_cd = true
    ball.contact_monitor = true
    ball.max_contacts_reported = 2
    ball.add_to_group("enemy_ball")
    add_child(ball)
    ball.global_position = from
    ball.linear_velocity = velocity
    ball.set_meta("spawn", time)
    ball.body_entered.connect(func(body): _enemy_ball_hit(ball, body))
    enemy_balls.append(ball)
    fx.muzzle(from)
    event.emit("enemy_fired", {})

func _enemy_ball_hit(ball: RigidBody3D, body: Node) -> void:
    if not is_instance_valid(ball) or ball.is_queued_for_deletion():
        return
    if body.is_in_group("projectile"):
        # Intercepted in the air.
        fx.intercept(ball.global_position)
        body.queue_free()
        enemy_balls.erase(ball)
        ball.queue_free()
        event.emit("intercept", {})

func _on_ship_sunk(s: EnemyShip) -> void:
    enemy_ships.erase(s)
    s.queue_free()

func _on_ship_rammed(s: EnemyShip) -> void:
    var p := s.global_position
    enemy_ships.erase(s)
    s.queue_free()
    ships_remaining -= 1
    fx.blast(p)
    _hull_hit()
    if hull_hits < max_hull and ships_remaining == 0 and targets_remaining == 0:
        _begin_win(p)

func damage_ship(s: EnemyShip, at: Vector3) -> void:
    fx.dust(at, "wood")
    fx.splinters(at, 14)
    ambience.crack()
    if s.damage():
        s.sinking_since = time
        ships_remaining -= 1
        blast_shake = 0.8
        fx.blast(at)
        fx.blast_light(at, 5.0)
        ambience.blast()
        s.break_apart(sea, fx)
        _register_combo()
        _start_cine(at)
        _drop_coins(at + Vector3(0, 0.5, 0))
        Haptics.rumble(2)
        event.emit("blast", {})
        if ships_remaining == 0 and targets_remaining == 0:
            _begin_win(at)
    else:
        s.hit(at)
        Haptics.crack()
        event.emit("broke", {"material": "wood"})

func _hull_hit(at: Vector3 = Vector3.INF) -> void:
    hull_hits += 1
    _ship_damage(at)
    blast_shake = 0.8
    Haptics.hull()
    event.emit("hull", {"remaining": max_hull - hull_hits})
    if hull_hits >= max_hull:
        _finish(false)

func _update_enemies(delta: float) -> void:
    if phase == Phase.LOADING or phase == Phase.INTRO or phase == Phase.FINISHED:
        return
    var target := cannon_world()
    for g in enemy_guns:
        if is_instance_valid(g):
            g.tick(delta, target)
    for s in enemy_ships.duplicate():
        if is_instance_valid(s):
            s.tick(delta, time, sea, ship.global_position)
    if phase != Phase.SLOWMO:
        for n in get_tree().get_nodes_in_group("enemies"):
            (n as Enemy).tick_gun(delta, target)
    if bool(data.get("volcano", false)) and phase != Phase.SLOWMO:
        lava_next -= delta
        if lava_next <= 0.0:
            lava_next = randf_range(4.0, 7.0)
            _lava_bomb()
    # Enemy balls: hull hits near the cannon, splashes, cleanup.
    for b in enemy_balls.duplicate():
        if not is_instance_valid(b):
            enemy_balls.erase(b)
            continue
        var p: Vector3 = b.global_position
        if p.distance_to(target) < Tuning.ENEMY_HIT_RADIUS:
            enemy_balls.erase(b)
            b.queue_free()
            fx.dust(p, "wood")
            fx.pop(p, Color(1, 0.6, 0.2))
            _hull_hit(p)
        elif p.y < Tuning.SEA_LEVEL + 0.1 or time - float(b.get_meta("spawn")) > 9.0:
            if open_sea or p.z > Tuning.SHORE_Z:
                fx.splash(Vector3(p.x, Tuning.SEA_LEVEL, p.z))
            enemy_balls.erase(b)
            b.queue_free()

func _update_projectiles() -> void:
    var cp := cannon_world()
    # The castle stays locked until a ball actually comes to it: a shot into the sea or the
    # beach leaves it standing.
    if frozen:
        for n in get_tree().get_nodes_in_group("projectile"):
            var bp := (n as Node3D).global_position
            if _castle_zone.grow(6.0).has_point(Vector2(bp.x, bp.z)) and bp.y < _castle_top + 4.0:
                _freeze_all(false)
                break
    for n in get_tree().get_nodes_in_group("projectile"):
        var p := n as Projectile
        if p:
            p.check_lifetime(time, Tuning.SEA_LEVEL, open_sea, cp)
            # Enemy ship hits.
            for s in enemy_ships:
                if is_instance_valid(s) and p.global_position.distance_to(s.global_position + Vector3(0, 0.4, 0)) < 2.2 and not p.is_queued_for_deletion():
                    damage_ship(s, p.global_position)
                    p.queue_free()
                    if active_projectile == p:
                        active_projectile = null
                    break

## A ball tearing through wood splinters the pieces right around the impact too.
func _smash_around(at: Vector3) -> void:
    var n := 0
    for node in get_tree().get_nodes_in_group("blocks"):
        var b := node as Block
        if b.material_name != "wood" or b.is_fragment or b.frozen or b.is_queued_for_deletion():
            continue
        if b.global_position.distance_to(at) < 1.3 + b.size.length() * 0.25:
            b.call_deferred("break_now")
            n += 1
            if n >= 4:
                return

## A ball striking right next to powder sets it off (sparks, splinters), even if it does not
## touch the barrel itself; hits further away leave the powder alone.
func _spark_near(ball: Projectile) -> void:
    if not is_instance_valid(ball):
        return
    var at := ball.global_position
    var reach := 2.2 * (1.3 if float(data.get("blast_radius", 1.0)) > 1.0 else 1.0)
    for n in get_tree().get_nodes_in_group("blocks"):
        var b := n as Block
        if b.material_name == "tnt" and not b.is_fragment and b.global_position.distance_to(at) < reach:
            b.call_deferred("break_now")
            return

## The volcano spits a burning rock onto the castle: it smashes what it lands on.
func _lava_bomb() -> void:
    var r := _castle_rect()
    var land := Vector3(randf_range(r.position.x, r.end.x), 0.5, randf_range(r.position.y, r.end.y))
    var from := Vector3(clampf(land.x * 1.5, -30, 30) + randf_range(-10, 10), 32.0, -48.0)
    var rock := LavaBomb.new()
    add_child(rock)
    rock.global_position = from
    rock.launch(from, land)
    rock.landed.connect(func(at: Vector3): _lava_hit(at))

func _lava_hit(at: Vector3) -> void:
    fx.blast(at)
    fx.blast_light(at, 6.0)
    ambience.blast()
    blast_shake = maxf(blast_shake, 0.4)
    if frozen:
        _freeze_all(false)
    for n in get_tree().get_nodes_in_group("dynamic"):
        if not (n is RigidBody3D):
            continue
        var body := n as RigidBody3D
        var off := body.global_position - at
        var dist := off.length()
        if dist > 2.2:
            continue
        var dv := 6.0 * (1.0 - dist / 2.2)
        body.apply_central_impulse((off + Vector3(0, 0.5, 0)).normalized() * dv * body.mass)
        if body is Block and (body as Block).material_name == "wood":
            (body as Block).call_deferred("ignite")

## A hit on our ship leaves its mark: splinters and a blast where it struck, a charred hole in
## the deck or rail that stays, and a fire that keeps burning there. Each hit adds one, so a
## battered ship smokes from several places.
func _ship_damage(at: Vector3) -> void:
    if at == Vector3.INF:
        at = cannon_world() + Vector3(randf_range(-2.0, 2.0), 0.3, randf_range(-0.6, 0.6))
    fx.blast(at)
    fx.splinters(at, 26)
    fx.blast_light(at, 5.0)
    ambience.blast()
    ambience.crack()
    # The mark, kept in ship space so it rides with the hull.
    var local := ship.to_local(at)
    local.y = ship.cannon_mount.y - 0.45
    var hole := MeshInstance3D.new()
    var hm := CylinderMesh.new()
    hm.top_radius = 0.55
    hm.bottom_radius = 0.55
    hm.height = 0.04
    hm.radial_segments = 14
    hole.mesh = hm
    hole.material_override = Models.flat_material(Color(0.07, 0.05, 0.04), 1.0)
    hole.position = local + Vector3(0, 0.02, 0)
    ship.add_child(hole)
    for k in 5:
        var plank := MeshInstance3D.new()
        var pm := BoxMesh.new()
        pm.size = Vector3(randf_range(0.4, 0.8), 0.05, 0.12)
        plank.mesh = pm
        plank.material_override = Models.tex_material("brown_planks_07", 1.5, Color(0.3, 0.22, 0.18))
        plank.position = local + Vector3(randf_range(-0.5, 0.5), 0.08, randf_range(-0.5, 0.5))
        plank.rotation = Vector3(randf_range(-0.5, 0.5), randf_range(0, TAU), randf_range(-0.4, 0.4))
        ship.add_child(plank)
    var fire := EnemyShip._flames(0.8 + 0.3 * hull_hits)
    fire.position = local + Vector3(0, 0.3, 0)
    ship.add_child(fire)
    var smoke := CPUParticles3D.new()
    smoke.amount = 16
    smoke.lifetime = 3.0
    smoke.local_coords = false
    smoke.direction = Vector3(0.2, 1, 0)
    smoke.spread = 12.0
    smoke.initial_velocity_min = 1.0
    smoke.initial_velocity_max = 1.8
    smoke.scale_amount_min = 1.0
    smoke.scale_amount_max = 1.8
    var ramp := Gradient.new()
    ramp.set_color(0, Color(0.15, 0.13, 0.12, 0.6))
    ramp.set_color(1, Color(0.4, 0.4, 0.42, 0.0))
    smoke.color_ramp = ramp
    smoke.mesh = QuadMesh.new()
    var sm := StandardMaterial3D.new()
    sm.albedo_texture = load("res://assets/particles/blackSmoke16.png")
    sm.vertex_color_use_as_albedo = true
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    smoke.material_override = sm
    smoke.position = local + Vector3(0, 0.6, 0)
    ship.add_child(smoke)
    # The ship lurches from the blow.
    _kick_vel += Tuning.KICK_ROLL * 14.0

# MARK: Feel

func _now() -> float:
    return Time.get_ticks_msec() / 1000.0

## Blasts and pops close together chain into a combo: bigger bonus, bigger shake and buzz.
func _register_combo() -> void:
    if time - _combo_last <= Tuning.COMBO_WINDOW:
        combo += 1
    else:
        combo = 1
    _combo_last = time
    best_combo = maxi(best_combo, combo)
    if combo >= 2:
        # Each link is worth more, up to x5, so a huge chain stays a bonus, not the whole score.
        var pts := Tuning.COMBO_POINTS * mini(combo, 5)
        bonus += pts
        event.emit("combo", {"count": combo, "points": pts})

## Big moments slow time for a beat; the camera stays behind the cannon throughout.
func _start_cine(_at: Vector3) -> void:
    if phase == Phase.FINISHED or phase == Phase.LOADING or phase == Phase.INTRO or phase == Phase.SLOWMO:
        return
    var now := _now()
    if _cine_used:
        # Later blasts in the chain stretch the slow motion a little.
        cine_until = minf(cine_until + 0.4, now + Tuning.CINE_DURATION + 0.8)
        return
    _cine_used = true
    follow = false
    cine_until = now + Tuning.CINE_DURATION
    Engine.time_scale = Tuning.CINE_SLOWMO

func _end_follow() -> void:
    if follow:
        follow = false
        if cine_until < 0.0 and phase != Phase.SLOWMO and phase != Phase.FINISHED:
            Engine.time_scale = 1.0

## Ends the slow motion when its time is up. The camera itself is never taken over.
func _camera_override(_delta: float) -> bool:
    var now := _now()
    if cine_until > 0.0 and (now >= cine_until or phase == Phase.FINISHED):
        cine_until = -1.0
        if phase != Phase.SLOWMO and phase != Phase.FINISHED:
            Engine.time_scale = 1.0
    if follow and (not is_instance_valid(active_projectile) or now > _follow_until):
        _end_follow()
    return false

## The popped guard's body tumbles off the castle instead of just vanishing.
func _fly_off(e: Enemy) -> void:
    var ghost := Node3D.new()
    for c in e.get_children():
        if c is MeshInstance3D:
            ghost.add_child((c as MeshInstance3D).duplicate())
    add_child(ghost)
    ghost.global_transform = e.global_transform
    var away := Vector3(randf_range(-2.5, 2.5), 3.2, randf_range(-1.5, -3.0))
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.set_parallel(true)
    tw.tween_property(ghost, "position", ghost.position + away, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(ghost, "rotation", ghost.rotation + Vector3(randf_range(4, 8), randf_range(-6, 6), randf_range(4, 8)), 0.55)
    tw.tween_property(ghost, "scale", Vector3(0.05, 0.05, 0.05), 0.55).set_ease(Tween.EASE_IN)
    tw.chain().tween_callback(ghost.queue_free)

static var _coin_mesh: CylinderMesh
static var _coin_mat: StandardMaterial3D

## Gold coins burst out of a popped guard, bounce and stay where they land: the loot.
func _drop_coins(at: Vector3) -> void:
    if _coin_mesh == null:
        _coin_mesh = CylinderMesh.new()
        _coin_mesh.top_radius = 0.07
        _coin_mesh.bottom_radius = 0.07
        _coin_mesh.height = 0.018
        _coin_mesh.radial_segments = 12
        _coin_mat = Models.flat_material(Color(1.0, 0.78, 0.25), 0.25, 1.0)
    var n := Tuning.COINS_PER_POP
    coins += n
    event.emit("coins", {"count": coins})
    ambience.coins()
    for i in n:
        if _coin_nodes.size() >= Tuning.MAX_COINS:
            break
        var body := RigidBody3D.new()
        body.mass = 0.05
        var shape := CollisionShape3D.new()
        var cs := CylinderShape3D.new()
        cs.radius = 0.07
        cs.height = 0.02
        shape.shape = cs
        body.add_child(shape)
        var mi := MeshInstance3D.new()
        mi.mesh = _coin_mesh
        mi.material_override = _coin_mat
        body.add_child(mi)
        body.collision_layer = 1 << 3   # coins land on the world but do not knock the castle
        body.collision_mask = 1
        add_child(body)
        body.global_position = at + Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.2, 0.2))
        body.linear_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(3.0, 5.5), randf_range(-1.0, 2.0))
        body.angular_velocity = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))
        _coin_nodes.append(body)

## How close the ball in flight comes to a powder barrel or a guard, for "So close!".
func _track_near_miss() -> void:
    if phase != Phase.IN_FLIGHT or not is_instance_valid(active_projectile):
        return
    var p := active_projectile.global_position
    for n in get_tree().get_nodes_in_group("enemies"):
        _shot_min_dist = minf(_shot_min_dist, p.distance_to((n as Node3D).global_position))
    for n in get_tree().get_nodes_in_group("blocks"):
        var b := n as Block
        if b.material_name == "tnt":
            _shot_min_dist = minf(_shot_min_dist, p.distance_to(b.global_position))

## Fire spreads from burning wood to wood close by.
func _update_fires(delta: float) -> void:
    _fire_tick += delta
    if _fire_tick < 0.45:
        return
    _fire_tick = 0.0
    var burning := get_tree().get_nodes_in_group("burning")
    if burning.is_empty():
        return
    for n in burning:
        var src := n as Block
        if not is_instance_valid(src) or src.burn_time < 0.9:
            continue
        for m in get_tree().get_nodes_in_group("blocks"):
            var b := m as Block
            if b.burning or b.material_name != "wood" or b.is_fragment:
                continue
            if b.global_position.distance_to(src.global_position) < Tuning.BURN_SPREAD + (b.size.length() + src.size.length()) * 0.25:
                b.ignite()
                break

# MARK: Camera

## Turns the camera by the phone's small look-around during the fly-in.
func _apply_intro_look() -> void:
    if _intro_look.length() > 0.01:
        camera.rotate_object_local(Vector3.UP, deg_to_rad(_intro_look.x))
        camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(_intro_look.y))

func _update_camera(delta: float) -> void:
    var ship_pos := ship.global_position
    if phase == Phase.LOADING:
        # Alternate the wide shot and the cannon view behind the cover so shaders compile now.
        var flip := int(time * 8.0) % 2 == 0
        var start := ship_pos + intro_start
        if flip:
            camera.global_position = start
            camera.look_at(ship_pos + Vector3(0, 1.5, 0), Vector3.UP)
        else:
            var d := _desired_camera()
            camera.global_position = d[0]
            camera.look_at(d[1], Vector3.UP)
        return
    camera.cull_mask = 0xFFFFF
    if phase == Phase.INTRO:
        var duration := Tuning.INTRO_DURATION
        var t: float = clampf((time - loading_end - intro_hold) / duration, 0.0, 1.0)
        # Level 1 drifts slowly at first, then swoops down fast; others ease in and out.
        var eased := pow(t, 2.6) if data.has("intro_from") else t * t * (3.0 - 2.0 * t)
        var start := ship_pos + intro_start
        var start_look := ship_pos + Vector3(0, 1.5, 0)
        var d := _desired_camera()
        camera_pos = start.lerp(d[0], eased)
        camera_look = start_look.lerp(d[1], eased)
        camera.global_position = camera_pos
        camera.look_at(camera_look, Vector3.UP)
        _apply_intro_look()
        return
    if _camera_override(delta):
        return
    if recoil > 0.0:
        recoil = maxf(0.0, recoil - delta * 0.9)
    if blast_shake > 0.0:
        blast_shake = maxf(0.0, blast_shake - delta / 0.5)
    var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.35 * blast_shake * blast_shake
    var d := _desired_camera()
    var desired_look: Vector3 = d[1]
    if focus_point != null:
        desired_look = focus_point
    elif time - last_shot_time < 1.0 and is_instance_valid(active_projectile):
        desired_look = active_projectile.global_position
    var rate := 3.0 if focus_point != null else 8.0
    zoom_out = lerpf(zoom_out, _zoom_target, minf(6.0 * delta, 1.0))
    var back := (camera_pos - camera_look).normalized()
    var zoomed: Vector3 = d[0] + Vector3(0, Tuning.ZOOM_OUT_UP, 0) * zoom_out + back * Tuning.ZOOM_OUT_BACK * zoom_out
    if zoom_out > 0.01:
        desired_look = desired_look.lerp(ship.global_position + Vector3(0, 1.0, 0), zoom_out * 0.6)
    camera_look = camera_look.lerp(desired_look, minf(rate * delta, 1.0))
    camera_pos = camera_pos.lerp(zoomed, minf(4.0 * delta, 1.0))
    camera.global_position = camera_pos + jitter * 0.5
    camera.look_at(camera_look + jitter, camera_up)
    _apply_intro_look()

## Orbit around the cannon: the cannon stays on screen whatever the aim.
func _desired_camera() -> Array:
    var cw := cannon_world()
    var forward := camera_look_base - cw
    var distance := forward.length()
    var base_yaw := atan2(forward.x, -forward.z)
    # Fixed downward tilt so the cannon sits in the same place on every level, whatever the
    # castle height; raising the aim pans the view up.
    var base_pitch := deg_to_rad(float(data.camera.get("pitch", Tuning.CAMERA_PITCH)))
    var yaw := base_yaw + deg_to_rad(aim_yaw) * Tuning.AIM_PAN_YAW
    var pitch := base_pitch + deg_to_rad(aim_pitch) * Tuning.AIM_PAN_PITCH
    var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
    var flat_back := Vector3(-sin(yaw), 0, cos(yaw))
    var pos := cw + flat_back * Tuning.CAMERA_OFFSET.z + Vector3(0, Tuning.CAMERA_OFFSET.y, 0)
    return [pos, pos + dir * distance]

# MARK: Progress

func _check_progress() -> void:
    match phase:
        Phase.SLOWMO:
            # Slow motion for the last pop, then let the fort finish coming down before the
            # result panel covers it.
            if slowmo_end >= 0.0 and time >= slowmo_end:
                Engine.time_scale = 1.0
                slowmo_end = -1.0
                win_linger_start = time
            if win_linger_start >= 0.0:
                var waited := time - win_linger_start
                # The pause lasts while something is still falling; once the scene is still,
                # a short beat and the panel comes up. No staring at a frozen screen.
                var min_wait := 1.1 if _debris_resting() else Tuning.WIN_LINGER
                if waited >= min_wait or waited >= Tuning.WIN_LINGER_MAX:
                    win_linger_start = -1.0
                    _finish(true)
        Phase.IN_FLIGHT, Phase.SETTLING:
            var flight_over := true
            if is_instance_valid(active_projectile):
                flight_over = active_projectile.is_resting() and time - last_shot_time > 1.0
            if flight_over and phase == Phase.IN_FLIGHT:
                phase = Phase.SETTLING
                settle_start = time
                _end_follow()
                var nothing := blocks_broken == _shot_start_breaks and targets_remaining == _shot_start_targets and _shot_blasts == 0
                if nothing and _shot_min_dist < Tuning.NEAR_MISS:
                    event.emit("near_miss", {})
            if phase == Phase.SETTLING:
                var out_of_ammo := projectiles_remaining == 0 and (targets_remaining > 0 or ships_remaining > 0)
                var timeout := Tuning.OUT_OF_AMMO_SETTLE if out_of_ammo else Tuning.SETTLE_TIMEOUT
                if _settled() or time - settle_start > timeout:
                    if out_of_ammo:
                        _finish(false)
                    else:
                        phase = Phase.AIMING
                        event.emit("phase", {})

func _debris_resting() -> bool:
    for n in get_tree().get_nodes_in_group("dynamic"):
        if n is RigidBody3D and not (n as RigidBody3D).freeze and (n as RigidBody3D).linear_velocity.length() > 1.0:
            return false
    return true

func _settled() -> bool:
    if time - settle_start < 1.2:
        return false
    for n in get_tree().get_nodes_in_group("dynamic"):
        if n is RigidBody3D and not (n as RigidBody3D).freeze and (n as RigidBody3D).linear_velocity.length() > 0.35:
            return false
    return true

func _begin_win(at: Vector3) -> void:
    if phase == Phase.SLOWMO or phase == Phase.FINISHED:
        return
    phase = Phase.SLOWMO
    Engine.time_scale = 0.3
    slowmo_end = time + 0.5   # game time at 0.3 scale: about 1.5 real seconds
    fx.confetti(at + Vector3(0, 1.5, 0))
    Haptics.rumble(2)
    event.emit("win_start", {})

func _finish(did_win: bool) -> void:
    if phase == Phase.FINISHED:
        return
    Haptics.muted = true
    if did_win:
        # The pirates are gone: everyone still in a cage walks free.
        for n in get_tree().get_nodes_in_group("captives"):
            var cap := n as Captive
            if not cap.is_free:
                captives_freed += 1
                cap.free_now()
    Engine.time_scale = 1.0
    phase = Phase.FINISHED
    won = did_win
    focus_point = null
    for d in dots:
        d.visible = false
    event.emit("finished", {"won": did_win, "shots": shots_used, "remaining": projectiles_remaining})

func set_paused(p: bool) -> void:
    is_paused = p
    get_tree().paused = p

func _update_weather() -> void:
    if time >= next_thunder:
        var fury := clampf((float(data.get("sea", 0.0)) - 0.8) * 5.0, 0.0, 1.0)
        next_thunder = time + randf_range(Tuning.THUNDER_MIN, Tuning.THUNDER_MAX) * (1.0 - 0.72 * fury)
        thunder_count += 1
        weather.lightning()
        event.emit("thunder", {})

func _exit_tree() -> void:
    Engine.time_scale = 1.0
    get_tree().paused = false
