## Rope Bridge: pirates run back and forth across a plank bridge slung between two rock
## towers. Shoot the posts or ropes and bridge, planks and pirates go down together, onto
## the powder stacked below.
class_name ScnBridge
extends Scenario

const SPAN := 4.0

var _runners: Array = []   # {e, phase, dir, y}

func setup(lv: Level) -> void:
    super.setup(lv)
    var i := 0
    for n in level.get_tree().get_nodes_in_group("enemies"):
        var e := n as Enemy
        if e.has_meta("run"):
            _runners.append({"e": e, "phase": i * 2.7, "dir": 1.0 if i % 2 == 0 else -1.0, "y": e.position.y})
            i += 1

func tick(delta: float) -> void:
    if not playing():
        return
    for r: Dictionary in _runners:
        var ref = r.e
        if not is_instance_valid(ref) or (ref as Node).is_queued_for_deletion():
            continue
        var e := ref as Enemy
        if e.frozen:
            # Running back and forth, with a little bounce in the step.
            var u := fmod(level.time * 1.6 + float(r.phase), 2.0 * SPAN)
            var x := -SPAN + (u if u <= SPAN else 2.0 * SPAN - u)
            r.dir = 1.0 if u <= SPAN else -1.0
            e.position.x = x
            e.position.y = float(r.y) + absf(sin(level.time * 9.0 + float(r.phase))) * 0.07
            e.base_position = e.position
        elif absf(e.global_position.y - float(r.y)) < 0.6:
            # The bridge is live under him: keep running, turn at the ends.
            if absf(e.position.x) > SPAN:
                r.dir = -signf(e.position.x)
            e.linear_velocity.x = float(r.dir) * 1.8
