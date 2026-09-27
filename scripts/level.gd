## One level: builds the world from the level JSON, runs the game loop, owns the camera and
## input. Talks to the HUD through `event` and plain properties.
class_name Level
extends Node3D

signal event(name: String, data: Dictionary)

enum Phase { LOADING, INTRO, AIMING, IN_FLIGHT, SETTLING, SLOWMO, FINISHED }
## Fly-in start points relative to the ship: far out, so the camera sweeps in over the water.
const INTRO_STARTS := [Vector3(-26, 12.0, 26), Vector3(24, 10.0, 24), Vector3(-4, 18.0, 32), Vector3(12, 8.0, 34)]
const Z_OFF := 0.0

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
var _load_touch := -1
var _aim_last := Vector2.ZERO
var _load_start_y := 0.0
var _controls: Node
var open_sea := false
var focus_point: Variant = null
var next_thunder := 0.0
var is_paused := false
var _touches: Dictionary = {}
var _pinch_start := -1.0
var zoom_out := 0.0
var _zoom_target := 0.0

func level_time() -> float:
    return time

## Debug: aim and fire once the level is ready.
var auto_fire: float = -1.0
var auto_fire_yaw: float = 0.0
var auto_fire_pitch: float = 8.0
var _auto_fired := false

func next_ammo() -> String:
    var ammo: Array = data.get("ammo", [])
    if ammo.is_empty():
        return "iron"
    return ammo[mini(shots_used, ammo.size() - 1)]

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
    data = level_data
    settings = user_settings
    gyro_enabled = bool(settings.get("gyro", true))
    projectiles_remaining = int(data.projectiles)
    targets_remaining = data.targets.size()
    ships_remaining = data.get("enemyShips", []).size()
    open_sea = data.get("terrain", {}).get("biome", "coast") == "opensea"
    var storm := is_storm()

    # Sky and light.
    var env := WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    var sm: Material
    style = Decor.style(data, storm)
    var sky_kind: String = style.sky
    if sky_kind == "overcast" or sky_kind == "storm":
        # Real overcast sky (Poly Haven HDR), darker for storms.
        var pano := PanoramaSkyMaterial.new()
        pano.panorama = load("res://assets/sky/overcast.hdr")
        pano.energy_multiplier = 0.45 if sky_kind == "storm" else 0.8
        sm = pano
    else:
        var ps := ProceduralSkyMaterial.new()
        if sky_kind == "sunset":
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
    e.ambient_light_energy = 0.9 if not storm else 0.6
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    e.glow_enabled = false
    # Haze gives depth: the mountains and far trees fade into the air, thickly in a storm.
    e.fog_enabled = true
    e.fog_light_color = Color(0.46, 0.50, 0.56) if storm else (Color(0.92, 0.72, 0.62) if sky_kind == "sunset" else Color(0.72, 0.80, 0.88))
    e.fog_density = 0.008 if storm else (0.005 if is_windy() else 0.003)
    e.fog_sky_affect = 0.25
    env.environment = e
    add_child(env)
    sun = DirectionalLight3D.new()
    sun.light_energy = 1.1 if not storm else 0.55
    sun.light_color = Color(1.0, 0.93, 0.85) if not storm else Color(0.75, 0.8, 0.95)
    if sky_kind == "sunset":
        # Low warm sun from the left, long shadows.
        sun.light_color = Color(1.0, 0.72, 0.48)
        sun.light_energy = 1.25
    elif sky_kind == "overcast":
        sun.light_energy = 0.8
        sun.light_color = Color(0.92, 0.94, 1.0)
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 22.0
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.rotation_degrees = Vector3(-16, 70, 0) if sky_kind == "sunset" else Vector3(-52, 35, 0)
    add_child(sun)
    var glint := DirectionalLight3D.new()
    glint.light_energy = 0.15 if not storm else 0.08
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
    sea.setup(float(data.get("sea", 0.0)), ship_pos, open_sea)
    add_child(ship)
    _build_cannon()
    ship.deck_found.connect(func(): cannon.position = ship.cannon_mount)

    # Island and scenery.
    Decor.build(self, int(data.id), data.get("terrain", {}).get("biome", "coast"), storm, style, cannon_pos.z)

    # Castle, figures, guns, boats.
    for b in data.blocks:
        _spawn_block(b)
    var i := 0
    for t in data.targets:
        _spawn_target(t, i)
        i += 1
    for g in data.get("enemyCannons", []):
        _spawn_gun(g)
    for s in data.get("enemyShips", []):
        _spawn_enemy_ship(s)
    _freeze_all(true)

    # Camera and the fly-in.
    camera = Camera3D.new()
    camera.fov = Tuning.CAMERA_FOV
    camera.cull_mask = 0xFFFFF
    camera.near = 0.05
    camera.far = 400.0
    add_child(camera)
    camera.make_current()
    camera_look_base = _v3(data.camera.lookAt)
    intro_start = INTRO_STARTS[(int(data.id) - 1) % INTRO_STARTS.size()]
    loading_end = Tuning.LOADING_DURATION
    intro_end = loading_end + Tuning.INTRO_DURATION + Tuning.INTRO_HOLD
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

func _v3(a: Array) -> Vector3:
    return Vector3(float(a[0]), float(a[1]), float(a[2]) + Z_OFF)

## Poly Haven cannon: the carriage turns with the aim, the barrel tilts on its trunnions.
const CANNON_LENGTH := 1.5
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
            # Round brick tower with a tiled cone roof and a pennant.
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
            var flag := Models.instance("res://assets/pirate/flag-pennant.glb")
            Models.fit(flag, Vector3(0.5, 1.0, 0.1), true)
            flag.position = Vector3(0, size.y / 2.0 + size.x * 1.3 + 0.5, 0)
            root.add_child(flag)
        "gate":
            var g := Models.instance("res://assets/castle/gate.glb")
            Models.fit(g, size)
            root.add_child(g)
        "boulder", "rock":
            var r := Models.prop("boulder_01")
            var holder := Node3D.new()
            holder.add_child(r)
            Models.fit(holder, size, style == "boulder")
            root.add_child(holder)
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

func _spawn_target(t: Dictionary, index: int) -> void:
    var e := Enemy.new()
    e.setup(float(t.get("radius", 0.28)), index, level_time)
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
    es.setup(float(s.get("speed", 0.0)), int(s.get("hitPoints", 2)), bool(s.get("hasCannon", true)), float(s.get("interval", 7.0)))
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
    if auto_fire >= 0.0 and not _auto_fired and phase == Phase.AIMING and time >= intro_end + Tuning.SAIL_IN_AFTER:
        _auto_fired = true
        set_aim(auto_fire_yaw, auto_fire_pitch)
        fire(auto_fire)
    _update_gyro(delta)
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
    _update_camera(delta)
    _check_progress()
    if blast_slowmo_end >= 0.0 and time >= blast_slowmo_end:
        blast_slowmo_end = -1.0
        if phase != Phase.SLOWMO and phase != Phase.FINISHED:
            Engine.time_scale = 1.0
    if is_storm():
        _update_weather()

## Trees lean and sway with the wind, harder in a storm, with slow gusts.
func _sway_trees() -> void:
    var wind := Tuning.TREE_SWAY_CALM + Tuning.TREE_SWAY_STORM * float(data.get("sea", 0.0))
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
    var span := intro_end - loading_end + Tuning.SAIL_IN_AFTER
    var k := clampf((time - loading_end) / span, 0.0, 1.0)
    var eased := sin(k * PI / 2.0)
    ship.position.x = ship_base_x + Tuning.SAIL_IN * (1.0 - eased)
    var p := ship.position
    var s := sea.sample(p.x, p.z)
    ship.position.y = Tuning.SEA_LEVEL + s.x + Tuning.SHIP_FREEBOARD
    var roll := atan(s.y) * Tuning.SHIP_ROLL_GAIN
    var pitch := atan(s.z) * Tuning.SHIP_PITCH_GAIN
    ship.rotation = Vector3(pitch, 0, -roll)
    camera_up = Vector3(sin(-roll * 0.5), cos(-roll * 0.5), 0)

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
    return (Tuning.LAUNCH_SPEED_BASE + pw * Tuning.LAUNCH_SPEED_SCALE) * float(Tuning.AMMO[type].speed)

## The next ball can be loaded while the last one is still flying or the castle settling.
func can_load() -> bool:
    if projectiles_remaining <= 0:
        return false
    if phase == Phase.AIMING:
        return true
    return (phase == Phase.IN_FLIGHT or phase == Phase.SETTLING) and time - last_shot_time >= Tuning.RELOAD_TIME

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
            if drag_aim and t.position.x < vp.x * 0.45 and _aim_touch < 0:
                _aim_touch = t.index
                _aim_last = t.position
            elif _load_touch < 0 and can_load():
                _load_touch = t.index
                _load_start_y = t.position.y
        else:
            _touches.erase(t.index)
            if _touches.size() < 2:
                _pinch_start = -1.0
                _zoom_target = 0.0
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
        Input.vibrate_handheld(int(8 + 26 * power))
    event.emit("power", {"power": power})

func _release_load() -> void:
    var released := power
    power = 0.0
    event.emit("power", {"power": 0.0})
    if released >= Tuning.MIN_FIRE_POWER:
        fire(released)

func _update_gyro(delta: float) -> void:
    if not (gyro_enabled and gyro_available):
        return
    if phase != Phase.AIMING and phase != Phase.IN_FLIGHT and phase != Phase.SETTLING:
        return
    var g := Input.get_gyroscope()
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
    if frozen:
        _freeze_all(false)
    var type := next_ammo()
    var v := aim_direction() * launch_speed(pw, type)
    var origin := muzzle_world()
    var p := Projectile.new()
    add_child(p)
    p.global_position = origin
    p.setup(type, v)
    p.spawn_time = time
    p.exploded.connect(func(at): explode(at))
    p.splashed.connect(func(at): fx.splash(at); event.emit("splash", {}))
    active_projectile = p
    projectiles_remaining -= 1
    shots_used += 1
    last_shot_time = time
    settle_start = -1.0
    phase = Phase.IN_FLIGHT
    recoil = 0.18
    fx.muzzle(origin)
    ambience.cannon(pw)
    Input.vibrate_handheld(60)
    event.emit("fired", {})

# MARK: Breaking and blasts

func _on_block_broke(blk: Block) -> void:
    var pos := blk.global_position
    var mat := blk.material_name
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
    event.emit("broke", {"material": mat})

func _fragment(blk: Block) -> void:
    if fragments_alive >= Tuning.MAX_FRAGMENTS:
        return
    var size := blk.size
    var n := Tuning.FRAGMENT_COUNT
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
            "wood": mi.material_override = Models.wood_material()
            "stone": mi.material_override = Models.tex_material("castle_brick_07", 0.8)
            _: mi.material_override = Models.flat_material(color, 0.9)
        f.setup(blk.material_name, piece * 0.92, "", false, {}, true, mi)
        var local := Vector3.ZERO
        local[axis] = (float(i) + 0.5) * piece[axis] - size[axis] / 2.0
        f.position = blk.to_global(local)
        f.rotation = blk.global_rotation
        f.linear_velocity = blk.linear_velocity + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 1.2
        f.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
        f.spawn_time = time
        add_child(f)
        fragments_alive += 1
        f.tree_exited.connect(func(): fragments_alive -= 1)

func explode(center: Vector3) -> void:
    blast_count += 1
    blast_shake = 1.0
    fx.blast(center)
    ambience.blast()
    event.emit("blast", {})
    Input.vibrate_handheld(300)
    if phase != Phase.SLOWMO and phase != Phase.FINISHED:
        Engine.time_scale = 0.35
        blast_slowmo_end = time + 0.45
    for n in get_tree().get_nodes_in_group("dynamic"):
        if not (n is RigidBody3D):
            continue
        var body := n as RigidBody3D
        var off := body.global_position - center
        var dist := off.length()
        if dist >= Tuning.TNT_RADIUS:
            continue
        var falloff := 1.0 - dist / Tuning.TNT_RADIUS
        var dir := Vector3.UP if dist < 0.05 else (off + Vector3(0, 0.35, 0)).normalized()
        var dv := Tuning.TNT_BLAST_SPEED * falloff
        if body is Block and (body as Block).frozen:
            (body as Block).set_frozen(false)
        if body is Enemy and (body as Enemy).frozen:
            (body as Enemy).set_frozen(false)
        body.apply_central_impulse(dir * dv * body.mass)
        if body is Block:
            var b := body as Block
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
    # Burst at once: no swell (a tween would crawl through the slow motion).
    fx.pop(pos, e.body_color)
    e.queue_free()
    targets_remaining -= 1
    Input.vibrate_handheld(120)
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
    if hull_hits < Tuning.MAX_HULL_HITS and ships_remaining == 0 and targets_remaining == 0:
        _begin_win(p)

func damage_ship(s: EnemyShip, at: Vector3) -> void:
    fx.dust(at, "wood")
    fx.pop(at, Color(1, 0.6, 0.2))
    if s.damage():
        s.sinking_since = time
        ships_remaining -= 1
        blast_shake = 0.5
        fx.blast(at)
        event.emit("blast", {})
        if ships_remaining == 0 and targets_remaining == 0:
            _begin_win(at)
    else:
        event.emit("broke", {"material": "wood"})

func _hull_hit() -> void:
    hull_hits += 1
    blast_shake = 0.8
    Input.vibrate_handheld(400)
    event.emit("hull", {"remaining": Tuning.MAX_HULL_HITS - hull_hits})
    if hull_hits >= Tuning.MAX_HULL_HITS:
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
            _hull_hit()
        elif p.y < Tuning.SEA_LEVEL + 0.1 or time - float(b.get_meta("spawn")) > 9.0:
            if open_sea or p.z > Tuning.SHORE_Z:
                fx.splash(Vector3(p.x, Tuning.SEA_LEVEL, p.z))
            enemy_balls.erase(b)
            b.queue_free()

func _update_projectiles() -> void:
    var cp := cannon_world()
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

# MARK: Camera

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
        var t: float = clampf((time - loading_end - Tuning.INTRO_HOLD) / duration, 0.0, 1.0)
        var eased := t * t * (3.0 - 2.0 * t)
        var start := ship_pos + intro_start
        var start_look := ship_pos + Vector3(0, 1.5, 0)
        var d := _desired_camera()
        camera_pos = start.lerp(d[0], eased)
        camera_look = start_look.lerp(d[1], eased)
        camera.global_position = camera_pos
        camera.look_at(camera_look, Vector3.UP)
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
                # Back to the whole fort so the collapse stays in view.
                focus_point = Vector3(camera_look_base.x, camera_look_base.y * 0.6, camera_look_base.z)
            if win_linger_start >= 0.0:
                var waited := time - win_linger_start
                if (waited >= Tuning.WIN_LINGER and _debris_resting()) or waited >= Tuning.WIN_LINGER_MAX:
                    win_linger_start = -1.0
                    _finish(true)
        Phase.IN_FLIGHT, Phase.SETTLING:
            var flight_over := true
            if is_instance_valid(active_projectile):
                flight_over = active_projectile.is_resting() and time - last_shot_time > 1.0
            if flight_over and phase == Phase.IN_FLIGHT:
                phase = Phase.SETTLING
                settle_start = time
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
    focus_point = at
    Engine.time_scale = 0.3
    slowmo_end = time + 0.5   # game time at 0.3 scale: about 1.5 real seconds
    fx.confetti(at + Vector3(0, 1.5, 0))
    Input.vibrate_handheld(200)
    event.emit("win_start", {})

func _finish(did_win: bool) -> void:
    if phase == Phase.FINISHED:
        return
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
        next_thunder = time + randf_range(Tuning.THUNDER_MIN, Tuning.THUNDER_MAX)
        thunder_count += 1
        weather.lightning()
        Input.vibrate_handheld(150)
        event.emit("thunder", {})

func _exit_tree() -> void:
    Engine.time_scale = 1.0
    get_tree().paused = false
