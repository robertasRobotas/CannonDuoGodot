## The Convoy: a slow merchant crosses the bay under our guns while pirate boats race out to
## board her. Sink every boat before it reaches her side.
class_name ScnEscort
extends Scenario

const TOTAL := 7

var merchant: EnemyShip
var _next := 4.0
var _count := 0
var _done := false
var _hp := 3
var _said := false

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()
    merchant = level._spawn_enemy_ship({"position": [16.0, 0.0, -20.0], "speed": 0.8, "hitPoints": 3, "hasCannon": false,
        "length": 7.5, "friendly": true, "waypoint": [-34.0, 0.0, -20.0]})
    merchant.arrived.connect(_arrived)
    Atmosphere.ship_flag(merchant, Vector3(0, 2.6, 0))

func _arrived(_s: EnemyShip) -> void:
    if _done:
        return
    _done = true
    merchant.speed = 0.0
    banner("SAFE IN PORT!", "The convoy got through")
    level.bonus += 1500
    for s in level.enemy_ships.duplicate():
        if s != merchant and is_instance_valid(s):
            # The rest give up and row away.
            s.target_node = null
            s.waypoint = Vector3(s.global_position.x, 0, -70.0)
    level.ships_remaining = 0
    release(merchant.global_position)

func tick(delta: float) -> void:
    if not playing() or _done:
        return
    if not _said:
        _said = true
        banner("PROTECT THE MERCHANT", "Sink the boats before they board her")
    _next -= delta
    if _count < TOTAL and _next <= 0.0:
        _next = 7.0
        _count += 1
        var x := merchant.global_position.x + randf_range(-10.0, 6.0)
        var es := level._spawn_enemy_ship({"position": [x, 0.0, -50.0], "speed": 1.7, "hitPoints": 1, "hasCannon": false, "length": 4.5})
        es.target_node = merchant
        level.ships_remaining += 1

func on_ram(s: EnemyShip) -> void:
    if _done:
        return
    _hp -= 1
    merchant.hit(s.global_position + Vector3(0, 0.5, 0))
    level.fx.splinters(s.global_position, 20)
    Haptics.hull()
    if _hp <= 0:
        _done = true
        banner("THE MERCHANT IS LOST", "")
        merchant.sinking_since = level.time
        merchant.break_apart(level.sea, level.fx)
        level.get_tree().create_timer(2.5).timeout.connect(func():
            if is_instance_valid(level):
                level._finish(false))
    else:
        banner("SHE'S BOARDED!", "%d more and she's lost" % _hp)

func on_friendly_hit(_s: EnemyShip, _at: Vector3) -> void:
    banner("THAT'S THE MERCHANT!", "Hold your fire")
