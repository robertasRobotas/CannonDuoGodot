## Longboats: for a minute, boats push off the beach and row at the hull. Hold them off,
## then take the fort.
class_name ScnLanding
extends Scenario

const TOTAL := 9

var _next := 3.0
var _count := 0
var _said := false

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()

func tick(delta: float) -> void:
    if not playing():
        return
    if not _said:
        _said = true
        banner("BOATS FROM THE BEACH!", "Hold them off for a minute")
    _next -= delta
    if _count < TOTAL and _next <= 0.0:
        _next = 6.5
        _count += 1
        var x := randf_range(-14.0, 14.0)
        level._spawn_enemy_ship({"position": [x, 0.0, Tuning.SHORE_Z + 1.5], "speed": 0.55, "hitPoints": 1, "hasCannon": false, "length": 4.5})
        level.ships_remaining += 1
        level.fx.splash(Vector3(x, Tuning.SEA_LEVEL, Tuning.SHORE_Z + 1.5))
        if _count == TOTAL:
            banner("LAST BOATS!", "")
        elif _count == 5:
            banner("HALF WAY", "They keep coming")
    if _count >= TOTAL and level.ships_remaining == 0:
        release(level.ship.global_position)
