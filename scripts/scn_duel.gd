## Broadside: open sea, nothing else in sight. A pirate galleon, half as big again as our
## ship, lies hove to thirty metres dead ahead; so do we. Six balls into her and she goes
## down, each one marking her worse; a bar on the screen fills as she takes them. She
## fires every three to five seconds and finds us only with every third or fourth ball.
## Four of those and we are the ones sinking.
extends Scenario

const RANGE := 30.0
const HITS := 6

var progress := 0.0      # 0..1, how far gone she is (the HUD's bar)
var _galleon: EnemyShip = null

func setup(lv: Level) -> void:
    super.setup(lv)
    var at := level.ship.global_position
    _galleon = level._spawn_enemy_ship({"position": [at.x, 0.0, at.z - RANGE], "speed": 0.0, "hitPoints": HITS,
        "hasCannon": true, "interval": 4.0, "length": Ship.LENGTH * 1.5})
    _galleon.interval = 4.0
    _galleon.interval_jitter = 1.0
    _galleon.hits_every = 3
    _galleon.hits_every_max = 4
    _galleon.next_fire = 4.0
    _galleon.dress_galleon()
    _galleon.sails_burn = true
    _galleon.debris_scale = 1.0 / 3.0
    level.ships_remaining = 1
    if level._settle_probe:
        _galleon.fired.connect(func(f: Vector3, _v: Vector3):
            print("DUEL galleon fired shot %d from x=%.1f" % [_galleon._shot_n, f.x]))

func tick(_delta: float) -> void:
    if _galleon and is_instance_valid(_galleon):
        progress = clampf(float(_galleon.max_hp - _galleon.hit_points) / float(_galleon.max_hp), 0.0, 1.0)
        if level._settle_probe and _galleon.hit_points < _galleon.max_hp and not has_meta("p%d" % _galleon.hit_points):
            set_meta("p%d" % _galleon.hit_points, true)
            print("DUEL galleon hit, %d of %d, progress %d%%" % [_galleon.max_hp - _galleon.hit_points, _galleon.max_hp, int(progress * 100)])

func on_ship_sunk(_s: EnemyShip) -> void:
    progress = 1.0
    if level._settle_probe:
        print("DUEL galleon sunk")
