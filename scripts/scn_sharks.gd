## Shark Bay: the pirates hold a pier over deep water. Any who go in the drink meet the
## sharks; a whale blows out in the bay.
class_name ScnSharks
extends Scenario

var sharks: Array[Shark] = []
var swimmers: Array = []   # {node, t}
var whale: Whale
var _whale_t := 10.0
var _first := true

func setup(lv: Level) -> void:
    super.setup(lv)
    for i in 3:
        var s := Shark.new()
        level.add_child(s)
        s.setup(Vector3(0, 0, 6.0), 7.0 + i * 2.5, i * 2.1, 0.45 + i * 0.1)
        s.caught.connect(_caught)
        sharks.append(s)
    whale = Whale.new()
    level.add_child(whale)
    whale.position = Vector3(-30.0, -9.0, -26.0)
    whale.rotation.y = 0.7

func on_enemy_popped(e: Enemy) -> bool:
    var p := e.global_position
    if p.z < Tuning.SHORE_Z - 0.5:
        return false
    # Over the water: he goes in, and starts swimming.
    var ghost := Node3D.new()
    for c in e.get_children():
        if c is MeshInstance3D:
            ghost.add_child((c as MeshInstance3D).duplicate())
    level.add_child(ghost)
    ghost.global_position = Vector3(p.x, Tuning.SEA_LEVEL, p.z)
    ghost.rotation = Vector3(0, randf() * TAU, 0)
    swimmers.append({"node": ghost, "t": 0.0, "phase": randf() * TAU})
    level.fx.splash(Vector3(p.x, Tuning.SEA_LEVEL, p.z))
    var best: Shark = null
    var best_d := 1e9
    for s in sharks:
        if s.state != Shark.State.HUNT and s.global_position.distance_to(p) < best_d:
            best_d = s.global_position.distance_to(p)
            best = s
    if best:
        best.hunt(ghost)
    if _first:
        _first = false
        banner("SHARK BAY!", "The sea finishes the job")
    return true

func _caught(ghost: Node3D) -> void:
    for sw: Dictionary in swimmers.duplicate():
        if sw.node == ghost:
            swimmers.erase(sw)
    if is_instance_valid(ghost):
        level.fx.splash(ghost.global_position)
        level.fx.pop(ghost.global_position, Color(0.85, 0.2, 0.15))
        ghost.queue_free()
    level.bonus += 250
    Haptics.pop()
    banner("CHOMP!", "+250")

func tick(delta: float) -> void:
    if not playing():
        return
    for s in sharks:
        s.tick(delta, level.sea)
    for sw: Dictionary in swimmers:
        var n: Node3D = sw.node
        if not is_instance_valid(n):
            continue
        sw.t = float(sw.t) + delta
        var water := Tuning.SEA_LEVEL + level.sea.height(n.position.x, n.position.z)
        n.position.y = water - 0.05 + sin(float(sw.t) * 6.0) * 0.04
        n.rotation.z = sin(float(sw.t) * 7.0 + float(sw.phase)) * 0.35
        n.rotation.x = 0.4 + sin(float(sw.t) * 5.0) * 0.2
    _whale_t -= delta
    if _whale_t <= 0.0:
        _whale_t = 22.0
        var tw := whale.create_tween()
        tw.tween_property(whale, "position:y", -1.6, 2.6).set_ease(Tween.EASE_OUT)
        tw.tween_callback(whale.blow)
        tw.tween_interval(2.2)
        tw.tween_property(whale, "position:y", -9.0, 3.0).set_ease(Tween.EASE_IN)
