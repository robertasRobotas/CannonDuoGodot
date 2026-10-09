## Balloon Raiders: pirates in hot-air balloons drift over their own fort toward the ship,
## powder kegs in the baskets. Shoot the envelopes and the baskets fall on the fort.
class_name ScnBalloons
extends Scenario

var balloons: Array[Balloon] = []
var _said := false
var _first_down := true

func setup(lv: Level) -> void:
    super.setup(lv)
    for i in 3:
        var b := Balloon.new()
        level.add_child(b)
        b.setup(i, Callable(self, "_floor_at"))
        b.position = Vector3(-11.0 + i * 11.0, 11.5 + i * 1.3, -36.0 - i * 7.0)
        b.crashed.connect(_crashed)
        b.bombed.connect(_bombed)
        balloons.append(b)
        level.targets_remaining += 1

## The highest castle piece under a point (where a falling basket lands), else the ground.
func _floor_at(x: float, z: float) -> float:
    var top := 0.3
    for n in level.get_tree().get_nodes_in_group("blocks"):
        var b := n as Block
        var p := b.global_position
        if absf(p.x - x) < b.size.x * 0.5 + 0.5 and absf(p.z - z) < b.size.z * 0.5 + 0.5:
            top = maxf(top, p.y + b.size.y * 0.5)
    if z > Tuning.SHORE_Z:
        top = maxf(top, Tuning.SEA_LEVEL)
    return top

func tick(delta: float) -> void:
    if not playing():
        return
    if not _said:
        _said = true
        banner("BALLOONS!", "Shoot the envelopes over the fort")
    for b in balloons:
        if is_instance_valid(b):
            b.tick(delta, level.ship.global_position)

func _crashed(b: Balloon, pos: Vector3) -> void:
    balloons.erase(b)
    level.explode(pos)
    level.bonus += 500
    if _first_down:
        _first_down = false
        banner("DOWN SHE COMES!", "+500")
    level.target_down(pos)

func _bombed(_b: Balloon, pos: Vector3) -> void:
    level.fx.blast(pos)
    level._hull_hit(pos)
    banner("THEY'RE BOMBING US!", "")
