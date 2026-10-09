## Runs The Pod: three orcas circle the ship, take breaths (the only moment they can be hit)
## and charge the hull. Put down the asked number and the whole pod answers: a dozen fins
## converge — then the great whale rises under the keel, lifts the ship out of their reach,
## the pod scatters, and the whale sets her down. Then the level is won.
class_name OrcaDirector
extends Node3D

var level: Level
var kills_needed := 3
var kills := 0
var orcas: Array[Orca] = []
var _next_surface := 3.0
var _next_ram := 9.0
var _finale := false
var whale: Whale

func setup(lv: Level) -> void:
    level = lv
    kills_needed = int(lv.data.get("orcas", 3))
    level.targets_remaining = 1   # the level ends only when the whale says so
    for i in 3:
        _spawn(-PI / 2.0 + (i - 1) * 0.7)
    if "--podfast" in OS.get_cmdline_user_args():
        get_tree().create_timer(4.0).timeout.connect(_start_finale)

func _spawn(a: float) -> Orca:
    var o := Orca.new()
    o.setup(a, randf_range(15.0, 21.0), randf_range(0.28, 0.42) * (1.0 if randf() < 0.5 else -1.0))
    add_child(o)
    o.global_position = level.ship.global_position + Vector3(cos(a), 0, sin(a)) * o.radius + Vector3(0, -2, 0)
    o.died.connect(_on_died)
    o.rammed.connect(_on_rammed)
    orcas.append(o)
    return o

func _on_died(o: Orca) -> void:
    orcas.erase(o)
    kills += 1
    level.bonus += 1000
    level.event.emit("target", {"remaining": maxi(kills_needed - kills, 0)})
    level._drop_coins(o.global_position + Vector3(0, 1.0, 0))
    if kills >= kills_needed and not _finale:
        _start_finale()
    elif not _finale:
        get_tree().create_timer(3.0).timeout.connect(func():
            if not _finale and is_instance_valid(self):
                _spawn(-PI / 2.0 + randf_range(-0.9, 0.9)))

func _on_rammed(_o: Orca, at: Vector3) -> void:
    if _finale:
        return
    level._hull_hit(at)

func _process(delta: float) -> void:
    if level == null or level.is_paused or level.phase == Level.Phase.LOADING or level.phase == Level.Phase.INTRO:
        return
    var ship_pos := level.ship.global_position
    for o in orcas:
        if is_instance_valid(o):
            o.tick(delta, level.sea, ship_pos)
    if _finale:
        return
    _next_surface -= delta
    _next_ram -= delta
    if _next_surface <= 0.0 and not orcas.is_empty():
        _next_surface = randf_range(4.0, 7.0)
        orcas[randi() % orcas.size()].begin_surface()
    if _next_ram <= 0.0 and not orcas.is_empty():
        _next_ram = randf_range(10.0, 14.0)
        orcas[randi() % orcas.size()].begin_ram(ship_pos)

## The pod answers, and the sea answers the pod.
func _start_finale() -> void:
    _finale = true
    level.event.emit("banner", {"text": "THE WHOLE POD!", "sub": ""})
    Haptics.rumble(2)
    for i in 12:
        var o := _spawn(-PI / 2.0 + (i / 11.0 - 0.5) * 2.6)
        o.radius = randf_range(9.0, 13.0)
        o.ang_speed = randf_range(0.5, 0.8) * (1.0 if i % 2 == 0 else -1.0)
    var ship_pos := level.ship.global_position
    var seq := create_tween()
    seq.tween_interval(4.0)
    seq.tween_callback(func():
        whale = Whale.new()
        add_child(whale)
        # Across the keel, head jutting out to seaward so the gunner looks straight down at it.
        whale.rotation.y = 0.3
        whale.global_position = ship_pos + Vector3(1.5, -9.0, -0.5)
        level.event.emit("banner", {"text": "", "sub": ""})
        for o in orcas:
            o.begin_flee()
        Haptics.rumble(3)
        var up := create_tween()
        # Her back ends up under the keel of the LIFTED ship: clear of the sea, ship on top.
        up.tween_property(whale, "position:y", ship_pos.y + 3.5, 2.6).set_ease(Tween.EASE_OUT)
        up.parallel().tween_property(level, "ship_lift", 4.6, 2.6).set_ease(Tween.EASE_OUT)
        up.tween_callback(func():
            whale.blow()
            level.event.emit("banner", {"text": "THE OLD SEA ANSWERS", "sub": ""})))
    seq.tween_interval(7.2)
    seq.tween_callback(func():
        var down := create_tween()
        down.tween_property(whale, "position:y", ship_pos.y - 10.0, 3.0).set_ease(Tween.EASE_IN)
        down.parallel().tween_property(level, "ship_lift", 0.0, 3.0).set_ease(Tween.EASE_IN_OUT)
        down.tween_callback(func():
            whale.queue_free()
            level.targets_remaining = 0
            level._begin_win(level.ship.global_position + Vector3(0, 2, 0))))
