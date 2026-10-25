## Sandbag nests: guns dug in behind sandbags, a pirate beside each, firing wild every
## three to five seconds: they never hit. A ball into a nest (bags or gun) sets it alight;
## a second ball blows it up, bags, gun and pirate together. Every nest blown lets the
## level end (with whatever else it asks for). Nests are told apart by their guns: a bag
## belongs to the nearest gun's nest.
extends Scenario

const Marker := preload("res://scripts/tnt_marker.gd")

var _nests: Array = []               # each nest's centre (its gun's starting place)
var _hits: Array = []                # hits taken, per nest
var _last_shot: Array = []           # the shot that last counted on each nest: one hit per ball
var _fires: Dictionary = {}          # nest index -> the flames node
var _blown := 0
var _markers: Array = []             # white arrows over the guns, until the first gun goes
var _ready := false

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()

## The nests, from the guns as built; and white arrows bobbing gently over the guns to
## show where to shoot. They all go the moment any one gun is destroyed.
func _find_nests() -> void:
    _ready = true
    for g in level.enemy_guns:
        if not is_instance_valid(g):
            continue
        _nests.append((g as Node3D).global_position)
        _hits.append(0)
        _last_shot.append(-1)
        if not bool(level.data.get("nest_markers", true)):
            continue   # this level shows no arrows
        var m := Marker.new()
        m.offset = Vector3(0.0, 2.9, 0.0)
        m.amp = 0.06
        (g as Node).add_child(m)
        _markers.append(m)

func _clear_markers() -> void:
    for m in _markers:
        if is_instance_valid(m):
            (m as Node).queue_free()
    _markers.clear()

func _nest_of(at: Vector3) -> int:
    var best := -1
    var best_d := 6.0   # further than this from any gun is not a nest at all
    for i in _nests.size():
        var d := Vector2(at.x, at.z).distance_to(Vector2(_nests[i].x, _nests[i].z))
        if d < best_d:
            best_d = d
            best = i
    return best

func tick(_delta: float) -> void:
    if not _ready and not level.enemy_guns.is_empty():
        _find_nests()

func on_gun_destroyed(_gun: EnemyGun) -> void:
    _clear_markers()

func on_ball_hit(body: Node, speed: float) -> void:
    if speed < 2.0:
        return   # a ball rolling up to the bags is no hit
    var at: Vector3
    if body is Block:
        var blk := body as Block
        if blk.is_fragment or not (blk.style == "sandbag" or blk.tint == "nest"):
            return
        at = blk.base_position
    elif body is EnemyGun:
        at = (body as EnemyGun).global_position
    else:
        return
    var k := _nest_of(at)
    if k < 0 or _hits[k] >= 2:
        return
    if _last_shot[k] == level.shots_used:
        return   # the same ball touching bag after bag counts once
    _last_shot[k] = level.shots_used
    _hits[k] += 1
    var centre: Vector3 = _nests[k]
    if level._settle_probe:
        print("SANDBAGS nest %d hit %d" % [k, _hits[k]])
    if _hits[k] == 1:
        # Alight: flames over the nest, and the Captain says so.
        var fire := EnemyShip._flames(1.5)
        fire.position = centre + Vector3(0, 0.6, 0)
        level.add_child(fire)
        _fires[k] = fire
        level.fx.dust(centre + Vector3(0, 0.5, 0), "wood")
        banner("IT'S ALIGHT!", "Once more and it goes up")
    else:
        # Blown: the powder in the nest goes; bags, gun and the pirate beside it with it.
        if _fires.has(k) and is_instance_valid(_fires[k]):
            (_fires[k] as Node).queue_free()
        _clear_markers()
        level.explode(centre + Vector3(0, 0.4, 0))
        _blown += 1
        if _blown >= _nests.size():
            release(centre)
        else:
            banner("ONE DOWN!", "%d to go" % (_nests.size() - _blown))
