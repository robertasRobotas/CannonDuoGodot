## The Lighthouse: a pirate ship works along the coast past a reef, steering by the light.
## Shoot the lantern out and she holds her course straight onto the rocks.
class_name ScnLighthouse
extends Scenario

const REEF_X := -13.0
const PASS_Z := -3.0

var ship: EnemyShip
var dark := false
var _wrecked := false
var _route: Array = []
var _leg := 0
var _spins: Array[Node3D] = []
var _said := false

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()
    ship = level._spawn_enemy_ship({"position": [36.0, 0.0, PASS_Z], "speed": 2.2, "hitPoints": 6, "hasCannon": false, "length": 8.0})
    level.ships_remaining += 1
    ship.arrived.connect(_arrived)
    _set_route(true)
    # The reef, awash: three boulders in the ship's road.
    for i in 3:
        var m := Models.prop("boulder_01" if i != 1 else "namaqualand_boulder_02")
        var k := randf_range(1.3, 1.8)
        m.scale = Vector3(k, k * 0.8, k)
        m.position = Vector3(REEF_X + (i - 1) * 2.2, -0.9, PASS_Z + (i - 1) * 0.9)
        m.rotation.y = randf() * TAU
        level.add_child(m)
    for n in level.get_tree().get_nodes_in_group("blocks"):
        for c in (n as Node).find_children("*", "Node3D", true, false):
            if (c as Node).has_meta("spin"):
                _spins.append(c as Node3D)

## Westbound: round the reef to seaward. Eastbound: back along the coast to start again.
func _set_route(west: bool) -> void:
    if west:
        _route = [Vector3(REEF_X + 11.0, 0, PASS_Z), Vector3(REEF_X, 0, PASS_Z + 7.5), Vector3(REEF_X - 12.0, 0, PASS_Z), Vector3(-40.0, 0, PASS_Z)]
    else:
        _route = [Vector3(REEF_X, 0, PASS_Z + 7.5), Vector3(36.0, 0, PASS_Z)]
    _leg = 0
    ship.waypoint = _route[0]

func _arrived(_s: EnemyShip) -> void:
    _leg += 1
    if _leg < _route.size():
        ship.waypoint = _route[_leg]
    else:
        _set_route(ship.global_position.x > 0.0)

func on_block_broke(blk: Block) -> void:
    if blk.style == "lamp" and not dark:
        dark = true
        for s in _spins:
            if is_instance_valid(s):
                s.queue_free()
        banner("THE LIGHT IS OUT!", "She can't see the reef")
        Haptics.rumble(1)

func tick(delta: float) -> void:
    if not playing():
        return
    if not _said:
        _said = true
        banner("SHOOT OUT THE LIGHT", "Then watch the reef")
    for s in _spins:
        if is_instance_valid(s):
            s.rotation.y += delta * 0.9
    if _wrecked or ship == null or not is_instance_valid(ship):
        if not _wrecked and level.ships_remaining == 0:
            release(level.ship.global_position)
        return
    if ship.sinking_since >= 0.0:
        return
    var p := ship.global_position
    if dark:
        # Blind, she holds her course straight along the coast, into the rocks.
        if absf(p.x - REEF_X) < 10.0 and ship.waypoint.z > PASS_Z + 1.0:
            ship.waypoint = Vector3(REEF_X, 0, PASS_Z)
        if Vector2(p.x, p.z).distance_to(Vector2(REEF_X, PASS_Z)) < 2.8:
            _wreck(p)

func _wreck(p: Vector3) -> void:
    _wrecked = true
    ship.sinking_since = level.time
    ship.waypoint = Vector3.INF
    level.ships_remaining -= 1
    level.blast_shake = 0.9
    level.fx.blast(p)
    level.fx.splinters(p, 30)
    level.ambience.blast()
    level.ambience.crack()
    ship.break_apart(level.sea, level.fx)
    Haptics.rumble(3)
    banner("ON THE ROCKS!", "The reef takes her")
    level.bonus += 2000
    level._drop_coins(p + Vector3(0, 1, 0))
    level._start_cine(p)
    level.get_tree().create_timer(2.5).timeout.connect(func():
        if is_instance_valid(level):
            release(p))
