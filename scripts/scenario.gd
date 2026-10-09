## A battle level's special rules, built on top of Level: the chase, the longboat landing,
## the lighthouse, the night raid, the convoy, the rope bridge, shark bay, the balloons.
## Level calls the hooks; a scenario that owns the ending holds `level.targets_remaining`
## up by one until it is done, then calls level._begin_win itself.
class_name Scenario
extends Node

var level: Level
var _lock := false

static func make(kind: String) -> Scenario:
    match kind:
        "chase": return ScnChase.new()
        "landing": return ScnLanding.new()
        "lighthouse": return ScnLighthouse.new()
        "raid": return ScnRaid.new()
        "escort": return ScnEscort.new()
        "bridge": return ScnBridge.new()
        "sharks": return ScnSharks.new()
        "balloons": return ScnBalloons.new()
    return null

func setup(lv: Level) -> void:
    level = lv

## Keep the level from ending until release().
func lock() -> void:
    if not _lock:
        _lock = true
        level.targets_remaining += 1

func release(at: Vector3) -> void:
    if _lock:
        _lock = false
        level.targets_remaining -= 1
    if level.targets_remaining <= 0 and level.ships_remaining <= 0:
        level._begin_win(at)

func playing() -> bool:
    return level.phase != Level.Phase.LOADING and level.phase != Level.Phase.INTRO and level.phase != Level.Phase.FINISHED and not level.is_paused

func banner(text: String, sub: String = "") -> void:
    level.event.emit("banner", {"text": text, "sub": sub})

## Hooks.
func tick(_delta: float) -> void:
    pass

## Return true to take over the pirate's send-off (no fly-off).
func on_enemy_popped(_e: Enemy) -> bool:
    return false

func on_ship_sunk(_s: EnemyShip) -> void:
    pass

## A boat that reached what it was sailing at (the merchant, not the player).
func on_ram(_s: EnemyShip) -> void:
    pass

func on_friendly_hit(_s: EnemyShip, _at: Vector3) -> void:
    pass

func on_block_broke(_blk: Block) -> void:
    pass

## After every shot has come to rest; `nothing` = it broke, popped or blew nothing.
func on_shot_settled(_nothing: bool) -> void:
    pass

## While true the fort's guns and gunmen hold their fire (the night raid before the alarm).
func guns_silent() -> bool:
    return false
