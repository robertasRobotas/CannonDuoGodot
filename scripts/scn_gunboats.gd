## Sea Duel: no fort. Our ship is under way, the sea streaming past her side and the swell
## coming across her beam. Pirate gunboats come up one at a time on the same course, close
## abeam, overhauling slowly from astern until they hold station off the bow; a single ball
## sinks one, and a few seconds later the next comes on. Three sunk wins it. Each boat
## fires every four to six seconds, but its gunners find the range only on their fifth
## shot: four fall wide, the fifth strikes home and costs a life. A fresh boat starts its
## count over. Our ship has three lives.
extends Scenario

const BOATS := 3
const NEXT_DELAY := 3.5      # seconds between a sinking and the next sail
const ABEAM := 11.0          # how far off the beam the boats run (about 13 m from the gun)

var _spawned := 0
var _next_in := -1.0         # countdown to the next boat (< 0: none pending)
var _boat: EnemyShip = null
var _boat_age := 0.0         # seconds since the current boat came on (the probe sinks it at 12)

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()
    # Under way, bow to -x: the water streams aft along the hull.
    level.sea.current = Vector2(-7.0, 0.0)
    _wake()
    if level._settle_probe:
        level.event.connect(func(kind: String, _info: Dictionary):
            if kind == "hull":
                print("GUNBOATS hull hit, lives left %d" % (level.max_hull - level.hull_hits)))

## Spray at the bow and a long foam wake astern: the ship is under way (as in the chase).
func _wake() -> void:
    var ship := level.ship
    var spray := CPUParticles3D.new()
    spray.amount = 70
    spray.lifetime = 0.6
    spray.local_coords = false
    spray.direction = Vector3(0, 1, 1)
    spray.spread = 40.0
    spray.initial_velocity_min = 3.0
    spray.initial_velocity_max = 6.5
    spray.gravity = Vector3(0, -13, 0)
    spray.scale_amount_min = 0.12
    spray.scale_amount_max = 0.35
    spray.mesh = QuadMesh.new()
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/particles/whitePuff12.png")
    m.albedo_color = Color(1, 1, 1, 0.55)
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    spray.material_override = m
    spray.position = Vector3(-Ship.LENGTH * 0.5, 0.2, 0)   # the bow, in ship space
    ship.add_child(spray)
    var wake := CPUParticles3D.new()
    wake.amount = 90
    wake.lifetime = 2.6
    wake.local_coords = false
    wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    wake.emission_box_extents = Vector3(0.3, 0.05, 1.1)
    wake.direction = Vector3(0, 0, -1)
    wake.spread = 6.0
    wake.initial_velocity_min = 6.0
    wake.initial_velocity_max = 7.5
    wake.gravity = Vector3.ZERO
    wake.scale_amount_min = 0.6
    wake.scale_amount_max = 1.3
    var ramp := Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0.55))
    ramp.set_color(1, Color(1, 1, 1, 0.0))
    wake.color_ramp = ramp
    wake.mesh = QuadMesh.new()
    var wm := m.duplicate()
    wm.vertex_color_use_as_albedo = true
    wm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    wake.material_override = wm
    wake.rotation.x = -PI / 2.0
    wake.position = Vector3(Ship.LENGTH * 0.5 + 0.3, -0.75, 0)   # the stern
    ship.add_child(wake)

func _spawn_boat() -> void:
    _spawned += 1
    # Abeam to seaward, a little astern, on our course: it draws ahead slowly and holds
    # station once it is off the bow.
    var z := level.ship.global_position.z - ABEAM - randf_range(0.0, 1.5)
    var x := level.ship.global_position.x + 9.0
    _boat = level._spawn_enemy_ship({"position": [x, 0.0, z], "speed": 0.45 + 0.1 * _spawned, "hitPoints": 1,
        "hasCannon": true, "interval": 5.0, "length": 6.5, "waypoint": [x - 15.0, 0.0, z]})
    _boat.heading = 0.0   # bow to -x, as ours
    _boat.interval = 5.0
    _boat.interval_jitter = 1.0
    _boat.next_fire = 3.0
    _boat.hits_every = 5
    _boat.arrived.connect(_turn_about)
    _boat_age = 0.0
    if level._settle_probe:
        _boat.fired.connect(func(_from: Vector3, _v: Vector3):
            print("GUNBOATS boat %d fired shot %d (%s)" % [_spawned, _boat._shot_n, "sure" if _boat._shot_n % 5 == 0 else "wide"]))
    level.ships_remaining += 1

## Off the bow, the boat eases her sheets and holds station, still on our course.
func _turn_about(s: EnemyShip) -> void:
    s.speed = 0.0
    s.heading = 0.0

func on_ship_sunk(_s: EnemyShip) -> void:
    if level._settle_probe:
        print("GUNBOATS boat %d sunk" % _spawned)
    if _spawned < BOATS:
        _next_in = NEXT_DELAY
    else:
        if level._settle_probe:
            print("GUNBOATS all three sunk: won")
        release(level.ship.global_position)

func tick(delta: float) -> void:
    if not playing():
        return
    if _spawned == 0:
        _spawn_boat()
        banner("SAIL HO!", "Sink three. One ball each.")
        return
    _boat_age += delta
    if "--autosink" in OS.get_cmdline_user_args() and _boat and is_instance_valid(_boat) and _boat.sinking_since < 0.0 and _boat_age > 12.0:
        level.damage_ship(_boat, _boat.global_position)   # a debug run that sinks each boat itself
    if _next_in >= 0.0:
        _next_in -= delta
        if _next_in < 0.0:
            _spawn_boat()
            banner("ANOTHER SAIL!", "%d to go" % (BOATS - _spawned + 1))
