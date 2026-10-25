## Builds pirate-held castles from parts, seeded so the same seed always gives the same castle:
## the campaign castles (see Campaign), the daily castle and the boss fortresses.
## Output matches the level JSON (blocks, targets, enemy guns), so Level builds it like any
## designed castle.
##
## A castle stands on a site: open sand (near or far back behind a wide beach), a rock plateau, a hillfort mound,
## or the top of a sea cliff. Towers share one floor height so rope bridges can join them: bring
## one tower down and the bridge, its guard and often the next tower go with it.
class_name Fortress

const FLOOR_H := 2.1
const PLANK := 0.24
const STEP := FLOOR_H + PLANK
const ROCK_H := 2.4
const MOUND_H := 4.2
const CLIFF_H := 6.5
const CRAG_H := 6.5   # a stone crag: the mound's shape at the cliff's height

var blocks: Array = []
var targets: Array = []
var guns: Array = []
var base := 0.0
var rng := RandomNumberGenerator.new()
var _tops: Array = []   # [x, z, width] of each tower, for guns and cages
var captives: Array = []
var no_tnt := false
var nest := false   # the wharf: a sandbag gun nest in the middle, before the lookouts
var log_share := 0.0   # this share of the plain planks and posts are built of logs instead (looks only)
var _cage_n := 0

## kind: small, medium, large, huge, boss, mega, harbor, battery, or daily (random).
## opts: guns (enemy cannons), armed (pirates with blunderbusses), captives (caged islanders),
## deserters (caged pirates who want to quit), grimhorn (the boss on the top), no_tnt (plain
## crates where the powder would be), pirates (keep only this many, spread over the fort),
## props (odds and ends of timber scattered about the fort, touching nothing).
static func generate(seed_value: int, kind: String, site: String = "sand", z: float = -9.5, opts: Dictionary = {}) -> Dictionary:
    var f := Fortress.new()
    f.rng.seed = seed_value
    f.no_tnt = bool(opts.get("no_tnt", false))
    f.nest = bool(opts.get("nest", false))
    f.log_share = float(opts.get("log_share", 0.0))
    if kind == "daily":
        kind = ["small", "medium", "large", "large"][f.rng.randi_range(0, 3)]
        site = ["sand", "rock", "cliff", "far"][f.rng.randi_range(0, 3)]
        z = -16.0 if site == "far" else -10.5
    var width := {"small": 5.0, "medium": 10.0, "large": 13.0, "keep": 6.0, "castle": 14.0, "huge": 18.0, "boss": 18.0,
        "mega": 21.0, "harbor": 17.0, "battery": 5.0, "stockade": 14.0, "coastal": 17.0, "perch": 7.0, "sandbags": 16.0,
        "keyhole": 12.0, "lighthouse": 6.0, "ropebridge": 16.0, "pier": 8.0}.get(kind, 10.0) as float
    f._site(site, width, z)
    match kind:
        "small": f._small(z)
        "medium": f._medium(z)
        "large": f._large(z)
        "keep": f._keep(z)
        "castle": f._castle(z)
        "huge": f._huge(z)
        "boss": f._boss(z)
        "mega": f._mega(z)
        "harbor": f._harbor(z)
        "perch": f._perch(z)
        "sandbags": f._sandbags(z)
        "battery": f._battery(z)
        "keyhole": f._keyhole(z)
        "lighthouse": f._lighthouse(z)
        "ropebridge": f._ropebridge(z)
        "pier": f._pier(z)
        "stockade": f._stockade(z)
        "coastal": f._coastal_battery(z)
    if bool(opts.get("props", false)):
        f._props(z, width)
    if bool(opts.get("logs", false)):
        f._log_works(z)
    if opts.has("pirates"):
        f._thin_pirates(int(opts.pirates))
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
        "pitch": -5.5 if site in ["cliff", "crag"] else (-7.0 if top > 10.0 else -9.0),
        "shore": {"far": "sand", "sand": "sand", "rock": "rocks", "cliff": "cliffs", "mound": "sand", "knoll": "sand", "crag": "cliffs"}.get(site, "sand"),
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
        "mound":
            # A hillfort mound: the block is the whole hill, foot to foot; the fort stands
            # on its level top, SKIRT in from the edge.
            _blk("stone", Vector3(0, MOUND_H / 2.0, z), Vector3(width + 2.5 + 2.0 * Mound.SKIRT, MOUND_H, 7.0 + 2.0 * Mound.SKIRT), {"isStatic": true, "style": "mound"})
            base = MOUND_H
        "knoll":
            # The hillfort mound at half its size: half the height, half the skirt, the
            # same level top for the fort.
            var sk := Mound.SKIRT * 0.5
            _blk("stone", Vector3(0, MOUND_H / 4.0, z), Vector3(width + 2.5 + 2.0 * sk, MOUND_H / 2.0, 7.0 + 2.0 * sk), {"isStatic": true, "style": "mound:small"})
            base = MOUND_H / 2.0
        "crag":
            # A crag: the hillfort mound's shape in bare rock, cliff-high, with a top wide
            # and deep enough for the whole fort and the cages beyond its ends.
            _blk("stone", Vector3(0, CRAG_H / 2.0, z), Vector3(width + 6.5 + 2.0 * Mound.SKIRT, CRAG_H, 9.0 + 2.0 * Mound.SKIRT), {"isStatic": true, "style": "mound:stone"})
            base = CRAG_H
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
        _tower(x, z + 0.3, 2, 2.3, -side)
        _bridge(side * 1.5, x - side * 1.15, 2, z + 0.1)

## A great round tower of red brick, as on the hill above the old town: three storeys,
## near-straight sides, a flat top with a low parapet, a gun up there laid on the ship,
## and wooden works either side of its foot with a store of powder in each. The tower
## itself is solid: no ball and no blast moves it.
func _castle(z: float) -> void:
    var H := 2.6
    var y := 0.0
    for storey in 3:
        var w := lerpf(4.2, 3.8, float(storey) / 2.0)
        _part("stone", Vector3(0, y + H / 2.0, z), Vector3(w, H, w), {"style": "drum", "isStatic": true})
        y += H
    _part("stone", Vector3(0, y + 0.15, z), Vector3(4.0, 0.3, 4.0), {"style": "drum", "isStatic": true})
    y += 0.3
    # The parapet: merlons round the rim.
    for i in 10:
        var a := float(i) / 10.0 * TAU
        _part("stone", Vector3(cos(a) * 1.75, y + 0.3, z + sin(a) * 1.75), Vector3(0.5, 0.6, 0.4), {"rotation": [0, -rad_to_deg(a), 0]})
    # The gun on a plinth in the middle, its crew either side.
    _part("stone", Vector3(0, y + 0.3, z + 0.2), Vector3(1.6, 0.6, 1.8), {"style": ":grey"})
    # A big piece with its own powder beside it: hit, it blows with two kegs' force.
    guns.append({"position": [0.0, base + y + 0.62, z + 0.2], "interval": 5.5, "jitter": 1.0, "power": 0.5, "scale": 2.1, "blast": 2.0})
    for sx: float in [-1.0, 1.0]:
        _guard(Vector3(sx * 1.4, y, z + 1.2))
    _tops.append([0.0, z, 4.0])
    # Wooden works either side, each with its store of powder.
    var left := -(2.1 + 2.4)
    for dx: float in [-1.0, 1.0]:
        for dz: float in [-0.9, 0.9]:
            _part("wood", Vector3(left + dx, 1.0, z + dz), Vector3(0.2, 2.0, 0.2))
    _part("wood", Vector3(left, 2.07, z), Vector3(2.6, 0.14, 2.3))
    _part("tnt", Vector3(left - 0.3, 0.4, z + 0.1), Vector3(0.6, 0.8, 0.6))
    _part("wood", Vector3(left + 0.5, 0.4, z - 0.3), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _guard(Vector3(left - 2.0, 0.0, z + 0.6))
    var right := 2.1 + 1.8
    _watch_post(right, z + 0.4)
    _crate_stack(right + 2.6, z + 0.6, true)   # its middle crate is a keg
    # In front: a bit of fence, a barrel and a crate.
    for i in 4:
        _part("wood", Vector3(-1.5 + i * 1.0, 0.5, z + 3.8), Vector3(0.14, 1.0, 0.14))
    _part("wood", Vector3(0.0, 1.05, z + 3.8), Vector3(3.3, 0.1, 0.1))
    _part("wood", Vector3(-3.4, 0.4, z + 3.5), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(3.0, 0.4, z + 3.5), Vector3(0.7, 0.7, 0.7), {"style": "crate"})

## The keep: the large fort's great tower with a wooden tower either side (no bridges),
## and, with `nest`, a gun dug in before it behind walls of logs.
func _keep(z: float) -> void:
    _tower(0.0, z, 4, 3.2)
    for side: float in [-1.0, 1.0]:
        _tower(side * 4.3, z + 0.3, 3, 2.4)
    if nest:
        _nest(0.0, z + 5.6, 1.0, "logs")

func _large(z: float) -> void:
    _tower(0.0, z, 4, 3.2)
    for side: float in [-1.0, 1.0]:
        var x := side * 4.3
        _tower(x, z + 0.3, 3, 2.4, -side)
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
        _tower(x1, z + 0.3, 4, 2.6, -side)
        _tower(x2, z + 0.6, 3, 2.2, -side)
        _bridge(side * 1.8, x1 - side * 1.3, 4, z + 0.1)
        _bridge(x1 + side * 1.3, x2 - side * 1.1, 3, z + 0.4)
        _stone_tower(side * 2.8, z - 2.2, 9.0)
        _palisade(side * 2.0, side * 3.4, z + 2.0)
    _curtain(z + 3.2, 5.5)

func _boss(z: float) -> void:
    _tower(0.0, z, 5, 3.4)
    for side: float in [-1.0, 1.0]:
        var x := side * 4.6
        _tower(x, z + 0.4, 4, 2.6, -side)
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
        _tower(x1, z + 0.3, 5, 2.8, -side)
        _tower(x2, z + 0.6, 4, 2.4, -side)
        _bridge(side * 1.9, x1 - side * 1.4, 5, z + 0.1)
        _bridge(x1 + side * 1.4, x2 - side * 1.2, 4, z + 0.4)
        _stone_tower(side * 2.9, z - 2.4, 11.0)
        _stone_tower(side * 7.1, z - 2.2, 8.0)
        _watch_post(side * 11.3, z + 1.2)
    _curtain(z + 3.4, 6.5)

## Port Alder's quay taken by pirates: a warehouse, two cranes with crates on their booms,
## stacks of crates and barrels (powder among them), pirates on top of everything.
## The wharf: two raised lookouts (hunters' stands on splayed legs) in the middle, stacked
## cargo either side with nobody on it, and barrels out front; or, with `nest`, a sandbag
## gun nest out front in the barrels' place.
func _harbor(z: float) -> void:
    for side: float in [-1.0, 1.0]:
        _lookout(side * 3.6, z)
        _crate_stack(side * 7.8, z + 0.6, false)
        if not nest:
            _barrel_stack(side * 2.6, z + 2.6)
    if nest:
        _nest(0.0, z + 6.6, 1.0)

## Two guns dug in on the beach, each in a nest of sandbags open to the land: three courses
## of bags across the front and down both sides, the gun inside with a crate and a barrel
## of shot, and a pirate standing by outside. The guns fire wild (see the scenario).
func _sandbags(z: float) -> void:
    for side: float in [-1.0, 1.0]:
        _nest(side * 5.5, z, side)
    _beach_props(z)

## Odds and ends about the battery: a stack of crates and barrels between the nests, a
## bench before them, planks, crates and a coil of rope on the sand in front, and barrels
## out past the gunners. None of it touches a nest.
func _beach_props(z: float) -> void:
    var s := 0.9
    for row in 3:
        for i in 3 - row:
            _part("wood", Vector3((i - (2 - row) / 2.0) * s, s / 2.0 + row * s, z + 0.2), Vector3(s * 0.96, s * 0.96, s * 0.96), {"style": "crate"})
    _part("wood", Vector3(-2.3, 0.4, z - 0.8), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(2.2, 0.4, z - 1.2), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(2.6, 0.4, z - 0.3), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    for dx: float in [-0.55, 0.55]:
        _part("wood", Vector3(dx, 0.2, z + 2.4), Vector3(0.1, 0.4, 0.1))
    _part("wood", Vector3(0.0, 0.44, z + 2.4), Vector3(1.4, 0.08, 0.4))
    for i in 3:
        _part("wood", Vector3(-3.6 + (i % 2) * 0.1, 0.05 + i * 0.1, z + 3.6), Vector3(1.7, 0.1, 0.32))
    _part("wood", Vector3(3.6, 0.4, z + 3.4), Vector3(0.8, 0.8, 0.8), {"style": "crate"})
    _part("wood", Vector3(4.5, 0.35, z + 3.5), Vector3(0.7, 0.7, 0.7), {"style": "crate"})
    _part("wood", Vector3(-6.0, 0.08, z + 3.2), Vector3(0.5, 0.16, 0.5), {"style": "barrel"})   # a coil of rope
    for side: float in [-1.0, 1.0]:
        _part("wood", Vector3(side * 10.2, 0.4, z - 1.6), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
        _part("wood", Vector3(side * 10.7, 0.4, z - 0.9), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
        _part("wood", Vector3(side * 9.6, 0.35, z + 1.4), Vector3(0.7, 0.7, 0.7), {"style": "crate"})

## `wall`: "sandbag" (courses of bags) or "logs" (three walls of stacked logs, the fort's
## own timber). Either way the walls are timber: balls bounce, only a blast throws them.
func _nest(x: float, z: float, side: float, wall: String = "sandbag") -> void:
    var bag := Vector3(1.0, 0.36, 0.6)
    var front := z + 1.3
    if wall == "logs":
        # Log walls in the bags' place: a low one across the front, taller ones down the
        # sides. Tagged "nest" so the scenario knows them for the nest's.
        _part("timber", Vector3(x, 0.36, front), Vector3(3.6, 0.72, 0.6), {"style": "logs:nest"})
        for sx: float in [-1.0, 1.0]:
            _part("timber", Vector3(x + sx * 2.1, 0.54, front - 2.0), Vector3(0.6, 1.08, 3.0), {"style": "logs:nest"})
    for course in (0 if wall == "logs" else 3):
        var y := bag.y / 2.0 + course * bag.y
        var stagger := 0.5 * (course % 2)
        # Across the front, four bags, staggered course to course; two courses only, so
        # the gun's barrel shows over them.
        if course < 2:
            for i in 4:
                var bx := x - 1.5 + i * 1.0 + stagger
                if bx > x + 1.75:
                    continue
                _part("timber", Vector3(bx, y, front), bag, {"style": "sandbag"})
        # Down both sides, three bags each, lying along z.
        for sx: float in [-1.0, 1.0]:
            for i in 3:
                var bz := front - 0.9 - i * 1.0 - stagger
                _part("timber", Vector3(x + sx * 2.1, y, bz), Vector3(0.6, bag.y, 1.0), {"style": "sandbag"})
    # A big beach gun inside on a low plank platform, its barrel over the front bags,
    # facing the sea; its stores stand behind the nest's open back.
    _part("wood", Vector3(x, 0.15, z - 1.0), Vector3(2.2, 0.3, 3.2))
    guns.append({"position": [x, base + 0.32, z - 1.0], "interval": 4.0, "jitter": 1.0, "miss": true, "power": 0.5, "scale": 3.2})
    _part("wood", Vector3(x - 0.8, 0.35, z - 3.3), Vector3(0.7, 0.7, 0.7), {"style": "crate"})
    _part("wood", Vector3(x + 0.8, 0.4, z - 3.4), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    # The pirate, just outside the nest's side wall: close enough that the nest's blast
    # takes him with it.
    _guard(Vector3(x + side * 2.7, 0.0, z - 0.4))
    _tops.append([x, z, 4.0])

## One lookout on the hilltop, the wharf's size, with its odds and ends about its feet: a
## water butt under the floor, crates and barrels, a coil of rope, a bench, and a vane on
## the roof. Two pirates: one in the cabin, one up on the roof.
func _perch(z: float) -> void:
    _lookout(0.0, z, 1.0, true)
    _part("wood", Vector3(0.0, 0.4, z), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(2.5, 0.45, z + 0.6), Vector3(0.9, 0.9, 0.9), {"style": "crate"})
    _part("wood", Vector3(2.5, 1.3, z + 0.6), Vector3(0.8, 0.8, 0.8), {"style": "crate"})
    _part("wood", Vector3(-2.6, 0.4, z - 0.4), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(-2.6, 0.4, z + 0.35), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(1.0, 0.08, z + 0.5), Vector3(0.5, 0.16, 0.5), {"style": "barrel"})   # a coil of rope
    for sx: float in [-0.55, 0.55]:
        _part("wood", Vector3(sx, 0.2, z + 2.6), Vector3(0.1, 0.4, 0.1))
    _part("wood", Vector3(0.0, 0.44, z + 2.6), Vector3(1.4, 0.08, 0.4))

## A raised lookout as hunters build them: four legs splayed out at the foot and leaning
## in to carry a plank floor, an X of braces across the front and back faces, a boarded
## cabin on top open at the front above a low parapet, and a flat roof on four short posts
## with a gap of air under it. No ladder. One pirate keeps watch inside; with `roof_guard`
## a second stands on the roof by a little weather vane. `s` scales the whole thing.
func _lookout(x: float, z: float, s: float = 1.0, roof_guard: bool = false) -> void:
    var H := 4.2 * s          # the floor's underside
    var POST := 0.28 * s
    var foot := Vector2(1.35, 1.2) * s    # half-spread of the legs at the ground
    var head := Vector2(1.0, 0.9) * s     # ...and under the floor
    var legs := {}
    for sx: float in [-1.0, 1.0]:
        for sz: float in [-1.0, 1.0]:
            # Feet a hair off the ground: a leaning block's low corner dips below its centre.
            legs[[sx, sz]] = _strut(Vector3(x + sx * foot.x, 0.03, z + sz * foot.y), Vector3(x + sx * head.x, H, z + sz * head.y), POST, POST)
    # The braces: each runs from the foot of one front leg up the face of the other, lying
    # flat against the legs' outer face. The two of the X sit one outside the other, so they
    # cross without touching. They are nailed to the leg they start from (drawn as part of
    # it, with no body of their own): bracing that leans on nothing cannot kick the legs out.
    for sz: float in [-1.0, 1.0]:
        for k in 2:
            var sx := -1.0 if k == 0 else 1.0
            var y1 := H * 0.62
            var zf0 := z + sz * (foot.y + POST / 2.0 + (0.08 + k * 0.14) * s)
            var zf1 := z + sz * (lerpf(foot.y, head.y, y1 / H) + POST / 2.0 + (0.08 + k * 0.14) * s)
            _strut(Vector3(x + sx * (foot.x + 0.1 * s), 0.03, zf0), Vector3(x - sx * lerpf(foot.x, head.x, y1 / H), y1, zf1), 0.16 * s, 0.1 * s, {"attach": legs[[sx, sz]]})
    # The floor on the legs' heads, and the cabin: boards on three sides, a parapet in front.
    var fw := 2.6 * s
    var fd := 2.4 * s
    var plank := PLANK * s
    _part("wood", Vector3(x, H + 0.03 + plank / 2.0, z), Vector3(fw, plank, fd))
    var y0 := H + 0.03 + plank
    var wall := 1.5 * s
    var t := 0.12 * s
    for sx: float in [-1.0, 1.0]:
        _part("wood", Vector3(x + sx * (fw / 2.0 - t / 2.0), y0 + wall / 2.0, z), Vector3(t, wall, fd))
    _part("wood", Vector3(x, y0 + wall / 2.0, z - fd / 2.0 + t / 2.0), Vector3(fw - 2.0 * t, wall, t))
    _part("wood", Vector3(x, y0 + 0.2 * s, z + fd / 2.0 - t / 2.0), Vector3(fw - 2.0 * t, 0.4 * s, t))
    _guard(Vector3(x, y0, z + 0.25 * s))
    # Four short posts on the side walls' ends carry the roof, with daylight under it.
    var gap := 0.5 * s
    for sx: float in [-1.0, 1.0]:
        for sz: float in [-1.0, 1.0]:
            _part("wood", Vector3(x + sx * (fw / 2.0 - 0.08 * s), y0 + wall + gap / 2.0, z + sz * (fd / 2.0 - 0.08 * s)), Vector3(0.16 * s, gap, 0.16 * s))
    var roof_y := y0 + wall + gap + 0.12 * s
    _part("wood", Vector3(x, roof_y - 0.06 * s, z), Vector3(fw + 0.5 * s, 0.12 * s, fd + 0.5 * s))
    if roof_guard:
        # A weather vane at the back corner, and the second pirate up here beside it.
        _part("wood", Vector3(x + fw / 2.0 - 0.3, roof_y + 0.35, z - fd / 2.0 + 0.3), Vector3(0.08, 0.7, 0.08))
        _part("wood", Vector3(x + fw / 2.0 - 0.3, roof_y + 0.73, z - fd / 2.0 + 0.3), Vector3(0.45, 0.06, 0.1))
        _guard(Vector3(x - 0.5, roof_y, z + 0.2))
    _tops.append([x, z, fw])

## A straight timber from `a` to `b`, `w` by `d` thick: a block leaned over to lie along
## the line between them. Returns its index in `blocks`.
func _strut(a: Vector3, b: Vector3, w: float, d: float, extra: Dictionary = {}) -> int:
    var v := b - a
    var l := v.length()
    # Godot's YXZ Euler: the block's up axis lands on (-sin rz, cos rz cos rx, cos rz sin rx).
    var rx := atan2(v.z, v.y)
    var rz := -asin(clampf(v.x / l, -1.0, 1.0))
    var e := {"rotation": [rad_to_deg(rx), 0.0, rad_to_deg(rz)]}
    e.merge(extra)
    _part("wood", (a + b) / 2.0, Vector3(w, l, d), e)
    return blocks.size() - 1

## A frontier stockade: a front wall of sharpened logs with a gate, a blockhouse at each corner
## (a log ground floor and a wider upper floor overhanging it, as on real frontier forts),
## firing steps behind the wall, and a raised lookout in the middle.
func _stockade(z: float) -> void:
    # Two square log towers of a height, joined by a log wall with the gate in it. No ball
    # breaks a log wall: each tower keeps two small kegs just inside its door, and their
    # blast takes the seaward half of the tower, no more.
    _log_tower(-4.6, z)
    _log_tower(4.6, z)
    var front := z + 0.5
    var lw := 0.5
    var leaf := 1.0     # half the gate opening
    # The wall either side of the gate, four courses, and two courses of lintel over it.
    for side: float in [-1.0, 1.0]:
        var x0 := side * leaf
        var x1 := side * 3.1
        _logs(Vector3((x0 + x1) / 2.0, 1.0, front), Vector3(absf(x1 - x0), 2.0, lw))
    _logs(Vector3(0.0, 2.5, front), Vector3(6.2, 1.0, lw))
    # Gate: two leaves under the lintel.
    for side: float in [-1.0, 1.0]:
        _part("wood", Vector3(side * 0.5, 1.0, front + 0.1), Vector3(0.96, 2.0, 0.16))
    # The wall walk behind the top course, on two posts under its back edge (the lintel
    # alone carries only a sliver of it).
    for sx: float in [-2.4, 2.4]:
        _part("wood", Vector3(sx, 1.5, front - 0.95), Vector3(0.24, 3.0, 0.24))
    _part("wood", Vector3(0.0, 3.1, front - 0.65), Vector3(6.2, 0.2, 0.9))
    # Two sentries on the ground before the gate.
    for side: float in [-1.0, 1.0]:
        _guard(Vector3(side * 1.9, 0.0, front + 1.2))

## A square tower: walls of upright logs (the side walls in a seaward and a landward half),
## a heavy floor, a lookout of four posts with a railing between them, and a stepped slab
## roof. A pirate stands in the lookout beside two small powder kegs.
func _log_tower(x: float, z: float) -> void:
    var w := 3.0
    var lw := 0.6
    var h := 3.5
    var half := (w - 2.0 * lw) / 2.0
    _part("timber", Vector3(x, h / 2.0, z - w / 2.0 + lw / 2.0), Vector3(w, h, lw), {"style": "palisade"})
    _part("timber", Vector3(x, h / 2.0, z + w / 2.0 - lw / 2.0), Vector3(w, h, lw), {"style": "palisade"})
    for sx: float in [-1.0, 1.0]:
        for sz: float in [-1.0, 1.0]:
            _part("timber", Vector3(x + sx * (w / 2.0 - lw / 2.0), h / 2.0, z + sz * half / 2.0), Vector3(lw, h, half), {"style": "palisade"})
    # A stack of small kegs inside, against the seaward wall, from the ground up to just
    # under the floor: the lookout's kegs set it off, and its blast takes the seaward half
    # of the tower (the front wall and the front halves of the sides).
    for ky: float in [0.4, 1.2, 2.0, 2.8]:
        _part("tnt", Vector3(x, ky, z + 0.65), Vector3(0.45, 0.8, 0.45))
    _part("wood", Vector3(x, h + 0.15, z), Vector3(w + 0.6, 0.3, w + 0.6))
    var floor_y := h + 0.3
    # Two small kegs up in the lookout, at its front corners beside the pirate.
    for kx: float in [-0.9, 0.9]:
        _part("tnt", Vector3(x + kx, floor_y + 0.3, z + 0.9), Vector3(0.45, 0.6, 0.45))
    var post_h := 1.4
    var px := w / 2.0 + 0.15
    for sx: float in [-1.0, 1.0]:
        for sz: float in [-1.0, 1.0]:
            _part("wood", Vector3(x + sx * px, floor_y + post_h / 2.0, z + sz * px), Vector3(0.36, post_h, 0.36))
    # The railing between the posts, one piece per side. The seaward rail is a low one, so
    # the kegs stand clear above it: a ball from the sea can reach them.
    var gw := w + 0.3 - 0.36
    var rh := 0.55
    var rf := 0.28
    _part("timber", Vector3(x, floor_y + rh / 2.0, z - px), Vector3(gw, rh, 0.12), {"style": "fence"})
    _part("timber", Vector3(x, floor_y + rf / 2.0, z + px), Vector3(gw, rf, 0.12), {"style": "fence"})
    _part("timber", Vector3(x - px, floor_y + rh / 2.0, z), Vector3(0.12, rh, gw), {"style": "fence"})
    _part("timber", Vector3(x + px, floor_y + rh / 2.0, z), Vector3(0.12, rh, gw), {"style": "fence"})
    # The roof: a stepped pyramid of three heavy slabs, each square on the one below.
    var roof := floor_y + post_h
    var u := w + 1.0
    for k in 3:
        var side: float = u * [1.0, 0.72, 0.44][k]
        _part("wood", Vector3(x, roof + 0.15 + k * 0.3, z), Vector3(side, 0.3, side))
    _guard(Vector3(x, floor_y, z))
    _tops.append([x, z, w])

## A wall of logs laid close, as one piece (see the "logs" look in Level).
func _logs(pos: Vector3, size: Vector3) -> void:
    _part("timber", pos, size, {"style": "logs"})

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
    # The tower: white stone, flared wide at the foot and tapering to the gallery. The
    # lower half is one solid piece, part of the rock: no ball rocks it, and it stands when
    # the top goes. The upper half is loose courses, for the blast in the lantern to throw.
    var rows := 9
    var half := 5
    _part("stone", Vector3(0, half / 2.0, z), Vector3(2.6, half, 1.9), {"style": "shaft:white", "isStatic": true})
    for row in range(half, rows):
        var k := float(row) / float(rows - 1)
        var w := lerpf(2.6, 1.5, pow(k, 0.55))
        _part("stone", Vector3(0, 0.5 + row, z), Vector3(w, 0.98, w), {"style": "drum:white"})
    # The gallery: a stone slab with a railing of posts round it.
    _part("stone", Vector3(0, rows + 0.1, z), Vector3(2.9, 0.2, 2.9), {"style": "drum:white"})
    for i in 8:
        var a := float(i) / 8.0 * TAU
        _part("metal", Vector3(cos(a) * 1.3, rows + 0.55, z + sin(a) * 1.3), Vector3(0.08, 0.7, 0.08))
    # The lantern room: the light, and the keg of powder that feeds it. One ball up here
    # and the top of the tower goes.
    _part("tnt", Vector3(0, rows + 0.85, z), Vector3(1.1, 1.3, 1.1), {"style": "lamp"})
    _guard(Vector3(1.0, rows + 0.2, z + 1.0))
    # The keeper's hut, with two crates by it, and two pirates on the rock. The only
    # powder is up in the lantern.
    var y := _storey(-2.6, z + 0.4, 1.5, 1.5, 0.0, 0.2, true, false)
    _part("wood", Vector3(-2.6, y + 0.3, z + 0.4), Vector3(1.9, 0.5, 1.9), {"style": "roof"})
    _part("wood", Vector3(-1.5, 0.4, z + 1.6), Vector3(0.7, 0.7, 0.7), {"style": "crate"})
    _part("wood", Vector3(1.6, 0.4, z + 1.5), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
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

func _crate_stack(x: float, z: float, manned: bool = true) -> void:
    var s := 0.9
    for row in 3:
        for i in 3 - row:
            var cx := x + (i - (2 - row) / 2.0) * s
            var tnt := row == 0 and i == 1
            _part("tnt" if tnt else "wood", Vector3(cx, s / 2.0 + row * s, z), Vector3(s * 0.96, s * 0.96, s * 0.96), {} if tnt else {"style": "crate"})
    if manned:
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
    if mat == "wood" and log_share > 0.0 and not (extra.has("style") or extra.has("cage") or extra.has("attach")) and rng.randf() < log_share:
        # Built of logs: the same breakable wood, drawn as stacked rounds.
        extra = extra.duplicate()
        extra["style"] = "logs"
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
## other floor and on the ridge; powder at the foot and part way up. `bridge_dir` (-1, 0
## or 1) says from which side a bridge lands on the top floor: the roof makes room for it.
func _tower(x: float, z: float, floors: int, w: float, bridge_dir: float = 0.0) -> void:
    var y := 0.0
    for k in floors:
        var guard_here := k > 0 and (k % 2 == 1 or k == floors - 1)
        var mat := "stone" if (w > 3.3 and k == 0) else "wood"
        y = _storey(x, z, w, w * 0.92, y, 0.34 if w > 3.0 else 0.26, k % 2 == 1, not guard_here, mat)
        if guard_here:
            _guard(Vector3(x, y, z + w * 0.46 - 0.3))
        if k == 1 or (k == 3 and floors > 4) or (k == 5 and floors > 6):
            _part("tnt", Vector3(x, y + 0.35, z - 0.62), Vector3(0.55, 0.7, 0.55))
    _tops.append([x, z, w])
    var ridge := _roof(x, y, z, w, bridge_dir)
    _guard(Vector3(x, ridge, z))
    for side: float in [-1.0, 1.0]:
        _part("tnt", Vector3(x + side * w * 0.17, 0.4, z + w * 0.24), Vector3(0.6, 0.8, 0.6))

## A gabled roof that stands up to physics: a king post in the middle carries the ridge
## beam; each slope is one board whose foot sits on the floor just inside a low eave
## stop (so it cannot slide out) and whose head rests on the beam's top edge (so it
## cannot slide in). Nothing overlaps, so nothing jumps when the castle wakes. On the
## side a bridge lands from (`bridge_dir`), there is no stop: the board starts further in
## and the bridge's end, lying on the floor there, is what stops it. Returns the ridge's
## height, for the lookout on top.
func _roof(x: float, y: float, z: float, w: float, bridge_dir: float = 0.0) -> float:
    const T := 0.18          # a board's thickness
    var depth := w + 0.2
    var run := w / 2.0 - 0.36                      # from the foot of a board to the beam's edge
    # The king post and the ridge beam on it: never so low that a keg under it would not fit.
    var post_h := maxf(run - 0.3, 0.75)
    _part("wood", Vector3(x, y + post_h / 2.0, z), Vector3(0.3, post_h, 0.3))
    _part("wood", Vector3(x, y + post_h + 0.15, z), Vector3(0.4, 0.3, depth))
    var top := y + post_h + 0.3
    for side: float in [-1.0, 1.0]:
        var bridged := side == bridge_dir
        if not bridged:
            # The eave stop, on the floor's edge.
            _part("wood", Vector3(x + side * (w / 2.0 + 0.125), y + 0.15, z), Vector3(0.25, 0.3, depth))
        # The board: its underside runs from its foot on the floor (a hand inside the stop,
        # or inside the bridge's end) up to the beam's top edge and a little past it. The
        # block is that line lifted by half the thickness along the board's normal.
        var foot := Vector2(side * (w / 2.0 - (0.55 if bridged else 0.16)), 0.0)
        var head := Vector2(side * 0.2, post_h + 0.3)
        var d := (head - foot).normalized()
        head += d * 0.08
        var n := Vector2(-d.y, d.x) * (-side)   # up and outward, above the underside
        var a := foot + n * (T / 2.0)
        var b := head + n * (T / 2.0)
        _strut(Vector3(x + a.x, y + a.y, z), Vector3(x + b.x, y + b.y, z), T, depth)
    return top

## A plank bridge between two towers resting on their floor `floor_n` (1 = first floor),
## with a pirate halfway across.
func _bridge(x0: float, x1: float, floor_n: int, z: float) -> void:
    var y := floor_n * STEP
    var a := minf(x0, x1) - 0.35
    var b := maxf(x0, x1) + 0.35
    _part("wood", Vector3((a + b) / 2.0, y + 0.1, z), Vector3(b - a, 0.2, 1.0))
    _part("wood", Vector3((a + b) / 2.0, y + 0.26, z + 0.45), Vector3(b - a - 0.7, 0.12, 0.08))   # on the plank, not above it
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
    var top_hw := 0.0     # a mound's level top: the cages stay up on it, inside its edge
    var mound_z := 0.0
    for b in blocks:
        if str(b.get("style", "")).begins_with("mound"):
            top_hw = float(b.size[0]) / 2.0 - Mound.skirt_of(str(b.style).get_slice(":", 1))
            mound_z = float(b.position[2])
            continue
        reach = maxf(reach, absf(float(b.position[0])) + float(b.size[0]) / 2.0)
        front = maxf(front, float(b.position[2]))
    for i in n:
        var side := -1.0 if i % 2 == 0 else 1.0
        var row: int = i / 2
        var x := side * (reach + 2.0 + row * 1.6)
        if top_hw > 0.0:
            x = side * (top_hw - 0.8 - row * 1.4)
        var cz := front - 0.5 - row * 0.4
        if top_hw > 0.0:
            # The top's corners are rounded: keep the cage near the hill's middle line,
            # where the level ground runs out to its full width.
            x = side * (top_hw - 1.0 - row * 1.4)
            cz = mound_z + 0.6
        _cage_n += 1
        for dx: float in [-0.45, 0.45]:
            for dz: float in [-0.45, 0.45]:
                _part("wood", Vector3(x + dx, 0.62, cz + dz), Vector3(0.1, 1.24, 0.1), {"cage": _cage_n})
        _part("wood", Vector3(x, 1.3, cz), Vector3(1.1, 0.12, 1.1), {"cage": _cage_n})
        captives.append({"position": [x, base + 0.45, cz], "cage": _cage_n, "deserter": i >= count})

## Timber for a fort: a low wall of logs across the front either side of the way in, and a
## stack of logs behind. Logs shrug off balls; a blast throws them.
func _log_works(z: float) -> void:
    for side: float in [-1.0, 1.0]:
        _logs(Vector3(side * 3.4, 0.5, z + 2.8), Vector3(5.0, 1.0, 0.6))
    _logs(Vector3(0.0, 0.5, z - 2.6), Vector3(3.0, 1.0, 0.7))

## Keep only `keep` pirates, taken evenly from the fort's full crew so every part of it
## still has someone.
func _thin_pirates(keep: int) -> void:
    if keep < 0 or targets.size() <= keep:
        return
    var kept: Array = []
    var step := float(targets.size()) / float(maxi(keep, 1))
    for i in keep:
        kept.append(targets[int(floor(i * step + step / 2.0))])
    targets = kept

## Timber odds and ends about the fort, clear of it on both sides: a stack of crates, a
## pair of barrels, a lean-to on four posts with stores under it, a bit of fence, a bench
## and a signpost. None of it touches the fort, so it falls only when hit.
func _props(z: float, width: float) -> void:
    var r := width / 2.0 + 1.4     # the nearest a prop stands to the fort's middle line
    # Left: crates and barrels.
    var s := 0.9
    for row in 3:
        for i in 3 - row:
            var cx := -r - 1.0 + (i - (2 - row) / 2.0) * s
            _part("wood", Vector3(cx, s / 2.0 + row * s, z + 0.6), Vector3(s * 0.96, s * 0.96, s * 0.96), {"style": "crate"})
    _part("wood", Vector3(-r - 3.4, 0.4, z - 0.8), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(-r - 2.7, 0.4, z - 1.1), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    _part("wood", Vector3(-r - 3.05, 1.2, z - 0.95), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    # Right: a lean-to, stores under its roof.
    var sx := r + 1.6
    for dx: float in [-1.0, 1.0]:
        for dz: float in [-0.9, 0.9]:
            _part("wood", Vector3(sx + dx, 1.0, z + dz), Vector3(0.2, 2.0, 0.2))
    _part("wood", Vector3(sx, 2.07, z), Vector3(2.6, 0.14, 2.3))
    _part("wood", Vector3(sx - 0.35, 0.4, z + 0.1), Vector3(0.8, 0.8, 0.8), {"style": "crate"})
    _part("wood", Vector3(sx + 0.5, 0.4, z - 0.3), Vector3(0.58, 0.8, 0.58), {"style": "barrel"})
    # A bit of fence beyond the lean-to.
    for i in 5:
        _part("wood", Vector3(sx + 2.2 + i * 0.55, 0.5, z + 1.6), Vector3(0.14, 1.0, 0.14))
    _part("wood", Vector3(sx + 3.3, 1.05, z + 1.6), Vector3(2.5, 0.1, 0.1))
    # In front: a bench on the left, a signpost on the right.
    for dx: float in [-0.55, 0.55]:
        _part("wood", Vector3(-r - 0.5 + dx, 0.2, z + 3.2), Vector3(0.1, 0.4, 0.1))
    _part("wood", Vector3(-r - 0.5, 0.44, z + 3.2), Vector3(1.4, 0.08, 0.4))
    _part("wood", Vector3(r + 0.6, 0.9, z + 3.2), Vector3(0.12, 1.8, 0.12))
    _part("wood", Vector3(r + 0.6, 1.88, z + 3.2), Vector3(0.7, 0.16, 0.06))
    # Before the fort, on the sand: two crates side by side and a stack of planks.
    _part("wood", Vector3(1.6, 0.4, z + 3.6), Vector3(0.8, 0.8, 0.8), {"style": "crate"})
    _part("wood", Vector3(2.5, 0.35, z + 3.5), Vector3(0.7, 0.7, 0.7), {"style": "crate"})
    for i in 3:
        _part("wood", Vector3(-2.6 + (i % 2) * 0.1, 0.05 + i * 0.1, z + 3.7), Vector3(1.7, 0.1, 0.32))

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
