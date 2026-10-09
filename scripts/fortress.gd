## Builds pirate-held castles from parts, seeded so the same seed always gives the same castle:
## the campaign castles (see Campaign), the daily castle and the boss fortresses.
## Output matches the level JSON (blocks, targets, enemy guns), so Level builds it like any
## designed castle.
##
## A castle stands on a site: open sand (near or far back behind a wide beach), a rock plateau,
## or the top of a sea cliff. Towers share one floor height so rope bridges can join them: bring
## one tower down and the bridge, its guard and often the next tower go with it.
class_name Fortress

const FLOOR_H := 2.1
const PLANK := 0.24
const STEP := FLOOR_H + PLANK
const ROCK_H := 2.4
const CLIFF_H := 6.5

var blocks: Array = []
var targets: Array = []
var guns: Array = []
var base := 0.0
var rng := RandomNumberGenerator.new()
var _tops: Array = []   # [x, z, width] of each tower, for guns and cages
var captives: Array = []
var no_tnt := false
var _cage_n := 0

## kind: small, medium, large, huge, boss, mega, harbor, battery, or daily (random).
## opts: guns (enemy cannons), armed (pirates with blunderbusses), captives (caged islanders),
## deserters (caged pirates who want to quit), grimhorn (the boss on the top).
static func generate(seed_value: int, kind: String, site: String = "sand", z: float = -9.5, opts: Dictionary = {}) -> Dictionary:
    var f := Fortress.new()
    f.rng.seed = seed_value
    f.no_tnt = bool(opts.get("no_tnt", false))
    if kind == "daily":
        kind = ["small", "medium", "large", "large"][f.rng.randi_range(0, 3)]
        site = ["sand", "rock", "cliff", "far"][f.rng.randi_range(0, 3)]
        z = -16.0 if site == "far" else -10.5
    var width := {"small": 5.0, "medium": 10.0, "large": 13.0, "huge": 18.0, "boss": 18.0,
        "mega": 21.0, "harbor": 17.0, "battery": 5.0, "stockade": 14.0, "coastal": 17.0,
        "keyhole": 12.0, "lighthouse": 6.0, "ropebridge": 16.0, "pier": 8.0}.get(kind, 10.0) as float
    f._site(site, width, z)
    match kind:
        "small": f._small(z)
        "medium": f._medium(z)
        "large": f._large(z)
        "huge": f._huge(z)
        "boss": f._boss(z)
        "mega": f._mega(z)
        "harbor": f._harbor(z)
        "battery": f._battery(z)
        "keyhole": f._keyhole(z)
        "lighthouse": f._lighthouse(z)
        "ropebridge": f._ropebridge(z)
        "pier": f._pier(z)
        "stockade": f._stockade(z)
        "coastal": f._coastal_battery(z)
    f._place_guns(int(opts.get("guns", 0)))
    f._place_cages(int(opts.get("captives", 0)), int(opts.get("deserters", 0)))
    f._arm_pirates(int(opts.get("armed", 0)))
    if bool(opts.get("grimhorn", false)):
        f._crown_grimhorn()
    var top := 0.0
    for b in f.blocks:
        top = maxf(top, float(b.position[1]) + float(b.size[1]) / 2.0)
    # Aim point: the middle of the castle above the ground or rock.
    var look_y := f.base + (top - f.base) * 0.45
    return {
        "blocks": f.blocks,
        "targets": f.targets,
        "captives": f.captives,
        "enemyCannons": f.guns,
        "lookAt": [0, look_y, z],
        "pitch": -5.5 if site == "cliff" else (-7.0 if top > 10.0 else -9.0),
        "shore": {"far": "sand", "sand": "sand", "rock": "rocks", "cliff": "cliffs"}.get(site, "sand"),
        "beach": 12.0 if site == "far" else 4.2,
        "offshore": 3.0 if site == "far" else 8.0,
    }

# MARK: Sites

func _site(site: String, width: float, z: float) -> void:
    match site:
        "rock":
            _blk("stone", Vector3(0, ROCK_H / 2.0, z), Vector3(width + 2.5, ROCK_H, 7.0), {"isStatic": true, "style": "plateau"})
            base = ROCK_H
        "cliff":
            _blk("stone", Vector3(0, CLIFF_H / 2.0, z - 0.5), Vector3(width + 4.0, CLIFF_H, 9.0), {"isStatic": true, "style": "cliff"})
            base = CLIFF_H
        _:
            base = 0.0

# MARK: Layouts

func _small(z: float) -> void:
    _tower(0.0, z, 2, 2.6)
    if rng.randf() < 0.5:
        _watch_post(rng.randf_range(2.3, 2.8) * (1.0 if rng.randf() < 0.5 else -1.0), z + 0.6)
    else:
        _palisade(1.6, 2.6, z + 1.2)
        _palisade(-2.6, -1.6, z + 1.2)

func _medium(z: float) -> void:
    _tower(0.0, z, 3, 3.0)
    for side: float in [-1.0, 1.0]:
        var x := side * 3.7
        _tower(x, z + 0.3, 2, 2.3)
        _bridge(side * 1.5, x - side * 1.15, 2, z + 0.1)

func _large(z: float) -> void:
    _tower(0.0, z, 4, 3.2)
    for side: float in [-1.0, 1.0]:
        var x := side * 4.3
        _tower(x, z + 0.3, 3, 2.4)
        _bridge(side * 1.6, x - side * 1.2, 3, z + 0.1)
        if rng.randf() < 0.6:
            _watch_post(side * 6.6, z + 0.9)
        else:
            _stone_tower(side * 6.6, z + 0.6, rng.randf_range(4.5, 6.0))

func _huge(z: float) -> void:
    _tower(0.0, z, 6, 3.6)
    for side: float in [-1.0, 1.0]:
        var x1 := side * 4.8
        var x2 := side * 8.7
        _tower(x1, z + 0.3, 4, 2.6)
        _tower(x2, z + 0.6, 3, 2.2)
        _bridge(side * 1.8, x1 - side * 1.3, 4, z + 0.1)
        _bridge(x1 + side * 1.3, x2 - side * 1.1, 3, z + 0.4)
        _stone_tower(side * 2.8, z - 2.2, 9.0)
        _palisade(side * 2.0, side * 3.4, z + 2.0)
    _curtain(z + 3.2, 5.5)

func _boss(z: float) -> void:
    _tower(0.0, z, 5, 3.4)
    for side: float in [-1.0, 1.0]:
        var x := side * 4.6
        _tower(x, z + 0.4, 4, 2.6)
        _bridge(side * 1.7, x - side * 1.3, 4, z + 0.2)
        _stone_tower(side * 7.6, z + 0.8, 8.0)
        _watch_post(side * 9.4, z + 1.4)
        _palisade(side * 2.1, side * 3.2, z + 1.9)
    _curtain(z + 3.2, 4.0)

func _mega(z: float) -> void:
    _tower(0.0, z, 7, 3.8)
    for side: float in [-1.0, 1.0]:
        var x1 := side * 5.0
        var x2 := side * 9.2
        _tower(x1, z + 0.3, 5, 2.8)
        _tower(x2, z + 0.6, 4, 2.4)
        _bridge(side * 1.9, x1 - side * 1.4, 5, z + 0.1)
        _bridge(x1 + side * 1.4, x2 - side * 1.2, 4, z + 0.4)
        _stone_tower(side * 2.9, z - 2.4, 11.0)
        _stone_tower(side * 7.1, z - 2.2, 8.0)
        _watch_post(side * 11.3, z + 1.2)
    _curtain(z + 3.4, 6.5)

## Port Alder's quay taken by pirates: a warehouse, two cranes with crates on their booms,
## stacks of crates and barrels (powder among them), pirates on top of everything.
func _harbor(z: float) -> void:
    _tower(0.0, z, 3, 3.2)
    for side: float in [-1.0, 1.0]:
        _crane(side * 4.4, z + 0.4)
        _crate_stack(side * 7.8, z + 0.6)
        _barrel_stack(side * 2.6, z + 2.6)

## A frontier stockade: a front wall of sharpened logs with a gate, a blockhouse at each corner
## (a log ground floor and a wider upper floor overhanging it, as on real frontier forts),
## firing steps behind the wall, and a raised lookout in the middle.
func _stockade(z: float) -> void:
    var front := z + 2.6
    # Log wall with a gap for the gate.
    for i in 22:
        var x := -6.3 + i * 0.6
        if absf(x) < 0.9:
            continue
        var h := 2.6 + (0.25 if i % 2 == 0 else 0.0)
        _part("wood", Vector3(x, h / 2.0, front), Vector3(0.52, h, 0.5), {"style": "log"})
    # Gate: two leaves and a lintel beam.
    for side: float in [-1.0, 1.0]:
        _part("wood", Vector3(side * 0.42, 1.2, front + 0.1), Vector3(0.78, 2.4, 0.18))
    _part("wood", Vector3(0, 2.75, front), Vector3(2.4, 0.3, 0.6))
    # Firing step behind the wall with pirates on it.
    for side: float in [-1.0, 1.0]:
        _part("wood", Vector3(side * 3.3, 1.55, front - 0.7), Vector3(4.4, 0.18, 0.9))
        _part("wood", Vector3(side * 3.3, 0.72, front - 0.9), Vector3(0.24, 1.45, 0.24))
        _guard(Vector3(side * 3.3, 1.64, front - 0.7))
        _blockhouse(side * 6.3, front - 0.6)
    # Lookout tower in the yard.
    var y := _storey(0.0, z - 0.5, 2.0, 2.0, 0.0, 0.22, false, true)
    y = _storey(0.0, z - 0.5, 2.0, 2.0, y, 0.2, true, false)
    _guard(Vector3(0.0, y, z - 0.5))
    _part("tnt", Vector3(0.0, 0.35, z - 0.5), Vector3(0.6, 0.7, 0.6))
    _tops.append([0.0, z - 0.5, 2.0])

## Two-storey log blockhouse, the upper floor wider than the lower, a pyramid roof.
func _blockhouse(x: float, z: float) -> void:
    var w := 2.2
    for k in 5:
        var y := 0.25 + k * 0.5
        _part("wood", Vector3(x, y, z - w / 2.0), Vector3(w, 0.46, 0.34), {"style": "log"})
        _part("wood", Vector3(x, y, z + w / 2.0), Vector3(w, 0.46, 0.34), {"style": "log"})
        _part("wood", Vector3(x - w / 2.0, y, z), Vector3(0.34, 0.46, w - 0.3), {"style": "log"})
        _part("wood", Vector3(x + w / 2.0, y, z), Vector3(0.34, 0.46, w - 0.3), {"style": "log"})
    var y0 := 2.5
    _part("wood", Vector3(x, y0 + 0.1, z), Vector3(w + 0.9, 0.2, w + 0.9))
    var u := w + 0.8
    for k in 3:
        var y := y0 + 0.45 + k * 0.5
        _part("wood", Vector3(x, y, z - u / 2.0), Vector3(u, 0.46, 0.3), {"style": "log"})
        _part("wood", Vector3(x - u / 2.0, y, z), Vector3(0.3, 0.46, u - 0.3), {"style": "log"})
        _part("wood", Vector3(x + u / 2.0, y, z), Vector3(0.3, 0.46, u - 0.3), {"style": "log"})
    var top := y0 + 1.7
    _part("wood", Vector3(x, top + 0.1, z), Vector3(u + 0.3, 0.2, u + 0.3))
    _part("wood", Vector3(x - u * 0.26, top + 0.7, z), Vector3(u * 0.62, 0.16, u + 0.4), {"rotation": [0, 0, 36]})
    _part("wood", Vector3(x + u * 0.26, top + 0.7, z), Vector3(u * 0.62, 0.16, u + 0.4), {"rotation": [0, 0, -36]})
    _guard(Vector3(x, y0 + 0.2, z + 0.4))
    _part("tnt", Vector3(x, 0.35, z), Vector3(0.6, 0.7, 0.6))
    _tops.append([x, z, w])

## A Spanish-style coastal battery: a low curtain of coral stone with gun embrasures between
## merlons, angled bastions at both ends each with a round sentry box on its point, a stone
## powder magazine with a tiled roof behind the wall, and pirates on the ramparts.
func _coastal_battery(z: float) -> void:
    var front := z + 2.4
    var wall_h := 1.6
    # Curtain wall of stacked blocks.
    for row in 2:
        for i in 12:
            var x := -5.5 + i + (0.5 if row == 1 else 0.0)
            if x > 5.6:
                continue
            _part("stone", Vector3(x, 0.4 + row * 0.8, front), Vector3(0.98, 0.78, 1.1), {"style": ":sand"})
    # Merlons and embrasures along the top.
    for i in 6:
        var x := -5.0 + i * 2.0
        _part("stone", Vector3(x, wall_h + 0.45, front), Vector3(1.1, 0.9, 1.0), {"style": ":sand"})
        _guard(Vector3(x + 1.0, wall_h, front - 0.2))
    # Bastions: angled walls at each end, pointing out toward the sea.
    for side: float in [-1.0, 1.0]:
        var bx := side * 7.4
        for row in 3:
            _part("stone", Vector3(bx - side * 0.6, 0.4 + row * 0.8, front + 0.7), Vector3(2.4, 0.78, 1.0), {"style": ":sand", "rotation": [0, side * 35.0, 0]})
            _part("stone", Vector3(bx + side * 0.6, 0.4 + row * 0.8, front - 0.7), Vector3(2.4, 0.78, 1.0), {"style": ":sand", "rotation": [0, side * -35.0, 0]})
        # Garita: a round sentry box on the point.
        _part("stone", Vector3(bx + side * 0.9, 2.4 + 0.9, front + 0.1), Vector3(1.0, 1.8, 1.0), {"style": "tower:sand"})
        _guard(Vector3(bx - side * 0.2, 2.4, front))
        _tops.append([bx, front - 1.4, 1.2])
    # The powder magazine behind the wall: thick stone walls, a pitched tile roof, powder inside.
    var mz := z - 1.2
    for side: float in [-1.0, 1.0]:
        _part("stone", Vector3(side * 1.45, 1.1, mz), Vector3(0.5, 2.2, 2.6), {"style": ":sand"})
    _part("stone", Vector3(0, 1.1, mz - 1.1), Vector3(2.4, 2.2, 0.4), {"style": ":sand"})
    for i in 3:
        _part("tnt", Vector3(-0.7 + i * 0.7, 0.4, mz), Vector3(0.6, 0.8, 0.6))
    _part("tnt", Vector3(0, 1.2, mz), Vector3(0.55, 0.7, 0.55))
    _part("wood", Vector3(0, 2.3, mz), Vector3(3.6, 0.2, 3.0))
    _part("wood", Vector3(-0.95, 2.85, mz), Vector3(2.1, 0.16, 3.2), {"rotation": [0, 0, 30], "style": "roof"})
    _part("wood", Vector3(0.95, 2.85, mz), Vector3(2.1, 0.16, 3.2), {"rotation": [0, 0, -30], "style": "roof"})
    _guard(Vector3(0, 3.35, mz))
    _tops.append([0.0, mz, 2.4])

## The Keyhole: a sheer curtain wall of dressed stone with one small window dead centre.
## Iron does nothing to the wall; the only way in is a ball through the window, straight into
## the powder shelf behind it. Pirates watch from the rampart and the scaffolds behind.
func _keyhole(z: float) -> void:
    var wall_z := z + 1.6
    var rows := 5
    for row in rows:
        var y := 0.5 + row
        for i in 11:
            var x := (i - 5) * 1.02
            if row == 2 and i == 5:
                continue   # the window
            _part("stone", Vector3(x, y, wall_z), Vector3(0.98, 0.98, 0.9), {"style": ":sand"})
    # Merlons along the top, pirates on the rampart between them.
    for i in 5:
        _part("stone", Vector3(-5.1 + i * 2.55, rows + 0.9, wall_z), Vector3(1.0, 0.8, 0.9), {"style": ":sand"})
    for x: float in [-3.8, 3.8]:
        _guard(Vector3(x, rows + 0.55, wall_z))
    # The powder shelf, level with the window, right behind it: thread the window and it goes.
    _part("wood", Vector3(0, 2.0, wall_z - 1.1), Vector3(2.0, 0.16, 1.4))
    for sx: float in [-0.65, 0.65]:
        _part("wood", Vector3(sx, 1.0, wall_z - 1.5), Vector3(0.22, 2.0, 0.22))
    for sx: float in [-0.5, 0.5]:
        _part("tnt", Vector3(sx, 2.45, wall_z - 1.2), Vector3(0.55, 0.72, 0.55))
    for sx: float in [-0.6, 0.6]:
        _part("tnt", Vector3(sx, 0.4, wall_z - 1.6), Vector3(0.6, 0.8, 0.6))
    # Scaffold lookouts behind the wall, heads showing over the rampart.
    for side: float in [-1.0, 1.0]:
        var sx := side * 2.6
        var y := _storey(sx, wall_z - 2.8, 1.5, 1.5, 0.0, 0.22, false, false)
        y = _storey(sx, wall_z - 2.8, 1.4, 1.4, y, 0.2, false, false)
        y = _storey(sx, wall_z - 2.8, 1.3, 1.3, y, 0.18, false, false)
        _guard(Vector3(sx, y, wall_z - 2.8))
    _tops.append([-5.0, wall_z, 1.0])
    _tops.append([5.0, wall_z, 1.0])

## A square lighthouse in red and white bands on its rock, the lantern at the top, a keeper's
## hut with powder at its foot. The lantern is the point of the level (see ScnLighthouse).
func _lighthouse(z: float) -> void:
    var rows := 9
    for row in rows:
        var w := 1.7 - row * 0.05
        var tint := ":red" if (row / 3) % 2 == 1 else ":white"
        _part("stone", Vector3(0, 0.5 + row, z), Vector3(w, 0.98, w), {"style": tint})
    _part("wood", Vector3(0, rows + 0.1, z), Vector3(2.6, 0.2, 2.6))
    for side: float in [-1.0, 1.0]:
        _part("wood", Vector3(side * 1.2, rows + 0.5, z), Vector3(0.1, 0.6, 2.4))
    _part("wood", Vector3(0, rows + 0.75, z), Vector3(0.9, 1.0, 0.9), {"style": "lamp"})
    _guard(Vector3(0.95, rows + 0.2, z + 0.9))
    # The keeper's hut and his powder, and two pirates on the rock.
    var y := _storey(-2.6, z + 0.4, 1.5, 1.5, 0.0, 0.2, true, false)
    _part("wood", Vector3(-2.6, y + 0.3, z + 0.4), Vector3(1.9, 0.5, 1.9), {"style": "roof"})
    _part("tnt", Vector3(-1.5, 0.4, z + 1.6), Vector3(0.6, 0.8, 0.6))
    _part("tnt", Vector3(1.6, 0.4, z + 1.5), Vector3(0.6, 0.8, 0.6))
    _guard(Vector3(1.6, 0.0, z + 2.3))
    _guard(Vector3(-2.6, y + 0.55, z + 0.4))

## Two rock towers with a plank bridge slung between them on two ropes over four posts.
## Pirates run across; powder waits underneath for whatever falls.
func _ropebridge(z: float) -> void:
    var top := 5.0
    for side: float in [-1.0, 1.0]:
        var x := side * 6.5
        _blk("stone", Vector3(x, top / 2.0, z), Vector3(3.2, top, 4.2), {"isStatic": true, "style": "plateau"})
        var y := _storey(x, z, 1.7, 1.7, top, 0.22, true, true)
        y = _storey(x, z, 1.5, 1.5, y, 0.2, false, true)
        _guard(Vector3(x, y, z))
        for dz: float in [-0.5, 0.5]:
            _part("wood", Vector3(side * 4.95, top + 0.6, z + dz), Vector3(0.24, 1.2, 0.24))
        _part("tnt", Vector3(side * 4.6, top + 0.4, z - 1.4), Vector3(0.55, 0.75, 0.55))
    for dz: float in [-0.5, 0.5]:
        _part("wood", Vector3(0, top + 1.26, z + dz), Vector3(10.2, 0.1, 0.1), {"style": "log"})
    for i in 9:
        var x := -4.0 + i
        _part("wood", Vector3(x, top + 1.37, z), Vector3(0.88, 0.08, 1.3))
    for i in 3:
        targets.append({"position": [-2.5 + i * 2.5, top + 1.72 + base, z], "radius": 0.28, "run": true})
    # The powder under the bridge, and crates to break the fall... or not.
    for i in 4:
        _part("tnt" if i % 2 == 0 else "wood", Vector3(-2.4 + i * 1.6, 0.4, z + 0.3), Vector3(0.6, 0.8, 0.6), {} if i % 2 == 0 else {"style": "barrel"})
    _part("wood", Vector3(0.4, 1.25, z + 0.3), Vector3(0.9, 0.9, 0.9), {"style": "crate"})

## A long wooden pier out over the bay on stilts, platforms either side with cargo and powder,
## pirates all along it. What falls off goes in the water (see ScnSharks).
func _pier(z: float) -> void:
    var deck := 1.3
    var zz := z
    while zz < z + 10.0:
        for sx: float in [-1.0, 1.0]:
            _part("wood", Vector3(sx, deck * 0.5, zz), Vector3(0.24, deck, 0.24), {"isStatic": true})
        zz += 1.7
    var n := 6
    for i in n:
        _part("wood", Vector3(0, deck + 0.07, z + 0.85 + i * 1.7), Vector3(2.6, 0.14, 1.65))
    for side: float in [-1.0, 1.0]:
        var px := side * 3.3
        var pz := z + 5.0
        for dx: float in [-1.0, 1.0]:
            for dz: float in [-1.0, 1.0]:
                _part("wood", Vector3(px + dx, deck * 0.5, pz + dz), Vector3(0.24, deck, 0.24), {"isStatic": true})
        _part("wood", Vector3(px, deck + 0.07, pz), Vector3(2.8, 0.14, 2.8))
        _part("wood", Vector3(px - side * 1.2, deck * 0.5 + 0.07, pz), Vector3(0.6, 0.14, 2.6))   # plank to the pier
        _part("tnt", Vector3(px + side * 0.6, deck + 0.54, pz - 0.7), Vector3(0.6, 0.8, 0.6))
        _part("wood", Vector3(px - side * 0.4, deck + 0.54, pz + 0.7), Vector3(0.7, 0.7, 0.7), {"style": "crate"})
        _part("wood", Vector3(px + side * 0.6, deck + 1.34, pz - 0.7), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
        _guard(Vector3(px, deck + 0.14, pz + 0.1))
    _guard(Vector3(0, deck + 0.14, z + 2.0))
    _guard(Vector3(0.4, deck + 0.14, z + 6.2))
    _guard(Vector3(-0.3, deck + 0.14, z + 9.4))
    # The pier head: a lantern post and a crate stack.
    _part("wood", Vector3(0.9, deck + 1.1, z + 9.8), Vector3(0.14, 2.0, 0.14))
    _part("wood", Vector3(-0.7, deck + 0.5, z + 9.3), Vector3(0.75, 0.75, 0.75), {"style": "crate"})
    _tops.append([0.0, z + 0.5, 2.0])
func _battery(z: float) -> void:
    _tower(0.0, z, 2, 2.6)
    _palisade(-2.4, -1.5, z + 1.0)
    _palisade(1.5, 2.4, z + 1.0)
    _tops.append([-2.0, z, 1.0])
    _tops.append([2.0, z, 1.0])

## A dockside crane: two uprights, a cross beam, and a long boom with a crate at each end.
func _crane(x: float, z: float) -> void:
    var h := 5.2
    for dz: float in [-0.45, 0.45]:
        _part("wood", Vector3(x, h / 2.0, z + dz), Vector3(0.34, h, 0.34))
    _part("wood", Vector3(x, h + 0.12, z), Vector3(0.5, 0.24, 1.3))
    _part("wood", Vector3(x, h + 0.36, z), Vector3(5.2, 0.24, 0.36))
    for side: float in [-1.0, 1.0]:
        _part("wood", Vector3(x + side * 2.2, h + 0.88, z), Vector3(0.8, 0.8, 0.8), {"style": "crate"})
    _guard(Vector3(x, h + 0.48, z))
    _tops.append([x, z, 1.3])

func _crate_stack(x: float, z: float) -> void:
    var s := 0.9
    for row in 3:
        for i in 3 - row:
            var cx := x + (i - (2 - row) / 2.0) * s
            var tnt := row == 0 and i == 1
            _part("tnt" if tnt else "wood", Vector3(cx, s / 2.0 + row * s, z), Vector3(s * 0.96, s * 0.96, s * 0.96), {} if tnt else {"style": "crate"})
    _guard(Vector3(x, s * 3.0, z))

func _barrel_stack(x: float, z: float) -> void:
    for i in 3:
        _part("tnt" if i == 1 else "wood", Vector3(x + (i - 1) * 0.62, 0.4, z), Vector3(0.58, 0.8, 0.58), {} if i == 1 else {"style": "barrel"})
    _part("wood", Vector3(x - 0.31, 1.2, z), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(x + 0.31, 1.2, z), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})

# MARK: Parts

func _blk(mat: String, pos: Vector3, size: Vector3, extra: Dictionary = {}) -> void:
    if no_tnt and mat == "tnt":
        # A castle without powder: the barrel spots hold plain cargo crates.
        mat = "wood"
        extra = {"style": "crate"}
    var b := {"material": mat, "position": [pos.x, pos.y, pos.z], "size": [size.x, size.y, size.z]}
    b.merge(extra)
    blocks.append(b)

## Castle parts stand on the site: `y` is height above the ground or rock top.
func _part(mat: String, pos: Vector3, size: Vector3, extra: Dictionary = {}) -> void:
    _blk(mat, pos + Vector3(0, base, 0), size, extra)

func _guard(pos: Vector3) -> void:
    targets.append({"position": [pos.x, pos.y + base + 0.3, pos.z], "radius": 0.3})

## Corner posts on `y`, walls on three sides if asked, a floor plank on top; returns its top.
func _storey(x: float, z: float, w: float, d: float, y: float, post: float, walls: bool, rail: bool, mat: String = "wood") -> float:
    var h := FLOOR_H
    var ix := w / 2.0 - post / 2.0
    var iz := d / 2.0 - post / 2.0
    for sx: float in [-ix, ix]:
        for sz: float in [-iz, iz]:
            _part(mat, Vector3(x + sx, y + h / 2.0, z + sz), Vector3(post, h, post))
    if walls:
        _part(mat, Vector3(x - ix, y + h / 2.0, z), Vector3(0.14, h * 0.9, d - post * 2.0))
        _part(mat, Vector3(x + ix, y + h / 2.0, z), Vector3(0.14, h * 0.9, d - post * 2.0))
        _part(mat, Vector3(x, y + h / 2.0, z - iz), Vector3(w - post * 2.0, h * 0.9, 0.14))
    var top := y + h
    _part("wood", Vector3(x, top + PLANK / 2.0, z), Vector3(w + 0.3, PLANK, d + 0.3))
    if rail:
        _part("wood", Vector3(x, top + PLANK + 0.25, z + d / 2.0 + 0.05), Vector3(w, 0.5, 0.1))
    return top + PLANK

## A tower of `floors` storeys with a peaked roof. Pirates stand at the open front of every
## other floor and on the ridge; powder at the foot and part way up.
func _tower(x: float, z: float, floors: int, w: float) -> void:
    var y := 0.0
    for k in floors:
        var guard_here := k > 0 and (k % 2 == 1 or k == floors - 1)
        var mat := "stone" if (w > 3.3 and k == 0) else "wood"
        y = _storey(x, z, w, w * 0.92, y, 0.34 if w > 3.0 else 0.26, k % 2 == 1, not guard_here, mat)
        if guard_here:
            _guard(Vector3(x, y, z + w * 0.46 - 0.3))
        if k == 1 or (k == 3 and floors > 4) or (k == 5 and floors > 6):
            _part("tnt", Vector3(x, y + 0.35, z - 0.3), Vector3(0.55, 0.7, 0.55))
    _tops.append([x, z, w])
    _part("wood", Vector3(x - w * 0.27, y + 0.7, z), Vector3(w * 0.66, 0.18, w + 0.2), {"rotation": [0, 0, 38]})
    _part("wood", Vector3(x + w * 0.27, y + 0.7, z), Vector3(w * 0.66, 0.18, w + 0.2), {"rotation": [0, 0, -38]})
    _part("wood", Vector3(x, y + 1.3, z), Vector3(0.3, 0.3, w + 0.2))
    _guard(Vector3(x, y + 1.4, z))
    for side: float in [-1.0, 1.0]:
        _part("tnt", Vector3(x + side * w * 0.17, 0.4, z + w * 0.24), Vector3(0.6, 0.8, 0.6))

## A plank bridge between two towers resting on their floor `floor_n` (1 = first floor),
## with a pirate halfway across.
func _bridge(x0: float, x1: float, floor_n: int, z: float) -> void:
    var y := floor_n * STEP
    var a := minf(x0, x1) - 0.35
    var b := maxf(x0, x1) + 0.35
    _part("wood", Vector3((a + b) / 2.0, y + 0.1, z), Vector3(b - a, 0.2, 1.0))
    _part("wood", Vector3((a + b) / 2.0, y + 0.45, z + 0.45), Vector3(b - a - 0.7, 0.12, 0.08))
    _guard(Vector3((a + b) / 2.0, y + 0.2, z))

## A round stone tower with a pirate on top and powder at its foot.
func _stone_tower(x: float, z: float, h: float) -> void:
    var tints := ["", ":sand", ":dark", ":white"]
    _part("stone", Vector3(x, h / 2.0, z), Vector3(1.4, h, 1.4), {"style": "tower" + tints[rng.randi_range(0, 3)]})
    _part("wood", Vector3(x, h + 0.1, z), Vector3(1.7, 0.2, 1.7))
    _guard(Vector3(x, h + 0.2, z))
    _part("tnt", Vector3(x + 0.95 * (1.0 if x >= 0 else -1.0), 0.35, z + 0.5), Vector3(0.55, 0.7, 0.55))

## A wall of upright logs with a walkway on top.
func _palisade(x0: float, x1: float, z: float) -> void:
    var a := minf(x0, x1)
    var b := maxf(x0, x1)
    var n := maxi(2, int(round((b - a) / 0.32)) + 1)
    for i in n:
        var x := a + (b - a) * float(i) / float(n - 1)
        _part("wood", Vector3(x, 1.1, z), Vector3(0.3, 2.2, 0.3))
    _part("wood", Vector3((a + b) / 2.0, 2.3, z), Vector3(b - a + 0.5, 0.18, 0.7))

## A tall thin lookout that topples.
func _watch_post(x: float, z: float) -> void:
    var y := _storey(x, z, 1.2, 1.2, 0.0, 0.2, false, true)
    y = _storey(x, z, 1.1, 1.1, y, 0.18, false, false)
    _guard(Vector3(x, y, z))

## A low stone curtain wall across the front with wooden hoardings and powder behind.
func _curtain(z: float, half: float) -> void:
    for side: float in [-1.0, 1.0]:
        var n := int(half / 0.95)
        for i in n:
            _part("stone", Vector3(side * (1.2 + i * 0.95), 0.6, z), Vector3(0.9, 1.2, 0.6))
        _part("wood", Vector3(side * (1.2 + half / 2.0), 1.3, z), Vector3(half, 0.16, 0.8))
    _part("tnt", Vector3(0, 0.35, z - 0.6), Vector3(0.6, 0.7, 0.6))

## Islanders locked in wooden cages in front of the towers (inner towers first; guns take the
## outer ones). Each cage is four bars and a lid; breaking any of them frees the prisoner.
func _place_cages(count: int, deserters: int) -> void:
    var n := count + deserters
    if n <= 0 or blocks.is_empty():
        return
    # Beyond both ends of the fort, a little in front: prisoners kept apart from the pirates.
    var reach := 0.0
    var front := -100.0
    for b in blocks:
        reach = maxf(reach, absf(float(b.position[0])) + float(b.size[0]) / 2.0)
        front = maxf(front, float(b.position[2]))
    for i in n:
        var side := -1.0 if i % 2 == 0 else 1.0
        var row: int = i / 2
        var x := side * (reach + 2.0 + row * 1.6)
        var cz := front - 0.5 - row * 0.4
        _cage_n += 1
        for dx: float in [-0.45, 0.45]:
            for dz: float in [-0.45, 0.45]:
                _part("wood", Vector3(x + dx, 0.62, cz + dz), Vector3(0.1, 1.24, 0.1), {"cage": _cage_n})
        _part("wood", Vector3(x, 1.3, cz), Vector3(1.1, 0.12, 1.1), {"cage": _cage_n})
        captives.append({"position": [x, base + 0.45, cz], "cage": _cage_n, "deserter": i >= count})

## Hand blunderbusses to some pirates, preferring the high ones who can see the ship.
func _arm_pirates(count: int) -> void:
    if count <= 0:
        return
    var order: Array = range(targets.size())
    order.sort_custom(func(a, b): return float(targets[a].position[1]) > float(targets[b].position[1]))
    for i in mini(count, order.size()):
        targets[order[(i * 2 + 1) % order.size()]]["armed"] = true

## Grimhorn stands on the highest point, bigger than his men.
func _crown_grimhorn() -> void:
    var best := 0
    for i in targets.size():
        if float(targets[i].position[1]) > float(targets[best].position[1]):
            best = i
    targets[best]["boss"] = true
    targets[best]["radius"] = 0.48
    targets[best].position[1] = float(targets[best].position[1]) + 0.2

## Enemy guns in front of the outermost towers, facing the sea.
func _place_guns(count: int) -> void:
    if count <= 0 or _tops.is_empty():
        return
    var picks := _tops.duplicate()
    picks.sort_custom(func(p, q): return absf(p[0]) > absf(q[0]))
    for i in mini(count, picks.size()):
        var t: Array = picks[i]
        guns.append({"position": [t[0], base + 0.02, t[1] + t[2] * 0.5 + 1.0], "interval": rng.randf_range(6.0, 8.0), "power": 0.5})
