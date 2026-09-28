## The campaign: chapters and their levels. Chapter 1, The Valora Islands, is 20 levels of
## forts, sea battles, a harbour, a beach landing, a volcano and Grimhorn's trap. Later
## chapters are charted but not yet sailed.
##
## Each level row builds a full level dictionary (the same shape as the level JSON) so Level
## does not care whether a castle was designed by hand or generated.
class_name Campaign

const CHAPTERS := [
    {"title": "The Valora Islands", "levels": 20},
    {"title": "The Frozen North", "levels": 0},
    {"title": "The Desert Coast", "levels": 0},
    {"title": "The Pirate King", "levels": 0},
]

## Level rows. Keys:
##   name, sub, tip (Old Tomas's advice), biome (tropic, meadow, highlands, badlands, volcano,
##   harbor, opensea), sky (noon, sunset, overcast, night), sea (0..1 weather), swell (wave
##   height multiplier), fort [kind, site, z, opts], ships [[x, z, speed, hp, cannon], ...],
##   ammo, old (the old small cannon), offshore, look (camera aim for sea levels).
const LEVELS := {
    1: {"json": true, "name": "Storm Landing", "sub": "The first fort", "biome": "tropic", "sea": 1.0, "swell": 2.3, "offshore": 24.0, "intro_hold": 3.5, "fov": 74.0,
        "intro_from": [-30.0, 15.0, 40.0], "sail_in": 11.0, "sail_after": 0.8,
        "tip": "Hit the red powder barrels. The whole fort comes down.", },
    2: {"name": "Gull Rock", "sub": "A pirate lookout", "biome": "tropic", "sky": "noon", "sea": 0.1,
        "fort": ["small", "sand", -8.5, {"captives": 1}], "tip": "Break the cage bars and the prisoner runs free."},
    3: {"name": "Rock Perch", "sub": "Pirates on a rock", "biome": "tropic", "sky": "sunset", "sea": 0.2,
        "fort": ["small", "rock", -9.0, {"captives": 1}], "tip": "A pirate who falls off the rock is done for."},
    4: {"name": "Rope Bridge", "sub": "Two towers, one bridge", "biome": "meadow", "sky": "noon", "sea": 0.1,
        "fort": ["medium", "sand", -10.0, {"captives": 2}], "tip": "Bring one tower down and the bridge drags the next."},
    5: {"name": "Bay of Gulls", "sub": "Pirate ships in the bay", "biome": "tropic", "sky": "noon", "sea": 0.35, "shore": "cliffs",
        "fort": ["battery", "rock", -10.0, {"guns": 2}], "ships": [[-9.0, 3.6, 0.0, 2, true], [8.5, 3.9, 0.0, 2, true]],
        "ammo": [], "tip": "Two hits sink a pinnace. Shoot their cannonballs down if you must."},
    6: {"name": "Port Alder", "sub": "The harbour", "biome": "harbor", "sky": "noon", "sea": 0.15,
        "fort": ["harbor", "sand", -11.0, {"captives": 2, "armed": 1}], "tip": "Cranes and crates fall hard. Mind the people in cages."},
    7: {"name": "Eagle's Nest", "sub": "High on the cliff", "biome": "highlands", "sky": "overcast", "sea": 0.3,
        "fort": ["large", "cliff", -15.5, {"captives": 1}], "ammo": ["stone", "stone", "iron", "stone", "stone", "iron"], "tip": "The fort is on the cliff top. Aim high and pull hard."},
    8: {"name": "Night Watch", "sub": "By torchlight", "biome": "tropic", "sky": "night", "sea": 0.2,
        "fort": ["medium", "sand", -10.0, {"captives": 2, "armed": 1}], "tip": "Torches show the towers. The one with a gun shoots back."},
    9: {"name": "Beach Landing", "sub": "Boats row out to you", "biome": "tropic", "sky": "sunset", "sea": 0.25,
        "fort": ["medium", "far", -16.0, {"armed": 1}],
        "ships": [[-6.0, 3.8, 0.45, 1, false], [5.0, 3.6, 0.4, 1, false], [-12.0, 4.4, 0.5, 1, false]],
        "tip": "Sink the boats before they reach you, then the fort."},
    10: {"name": "Twin Keeps", "sub": "Red Bjorn's stronghold", "biome": "meadow", "sky": "overcast", "sea": 0.4,
        "fort": ["boss", "rock", -13.0, {"guns": 1, "captives": 2, "armed": 2}], "ships": [[-9.5, 3.6, 0.0, 2, true]],
        "tip": "Red Bjorn, Grimhorn's right hand. Powder under every keep."},
    11: {"json": true, "name": "Open Water", "sub": "Boats across the sea", "biome": "opensea", "tip": "Sink every boat before it reaches the hull."},
    12: {"name": "Stormbreak", "sub": "Huge waves", "biome": "opensea", "sky": "storm", "sea": 0.9, "swell": 3.2, "offshore": 0.0,
        "ships": [[-8.0, -12.0, 0.0, 3, true], [6.0, -16.0, 0.0, 3, true], [-1.0, -24.0, 0.0, 3, true]], "look": [0.0, 1.5, -16.0],
        "tip": "The sea lifts you high. Fire as you rise."},
    13: {"name": "Old Faithful", "sub": "With the old cannon", "biome": "tropic", "sky": "noon", "sea": 0.15, "old": true,
        "fort": ["small", "rock", -8.5, {"captives": 1}], "offshore": 2.5, "tip": "My old cannon is weak. Get close and aim higher."},
    14: {"name": "Fire Mountain", "sub": "The volcano island", "biome": "volcano", "sky": "overcast", "sea": 0.3, "old": true,
        "fort": ["medium", "sand", -10.0, {"captives": 2}], "offshore": 3.0, "tip": "The mountain throws lava. Let it help you."},
    15: {"name": "Skull Rock", "sub": "Where they keep your cannon", "biome": "badlands", "sky": "sunset", "sea": 0.3, "old": true,
        "fort": ["boss", "cliff", -15.5, {"guns": 1, "armed": 1}], "offshore": 2.5, "tip": "Your own cannon is in that vault. Take it back."},
    16: {"name": "Windmill Vale", "sub": "Pirates who want to quit", "biome": "meadow", "sky": "noon", "sea": 0.1,
        "fort": ["large", "far", -17.0, {"captives": 1, "deserters": 2}], "tip": "Some caged pirates wave white rags. Free them too."},
    17: {"name": "The Treasury", "sub": "By torchlight", "biome": "highlands", "sky": "night", "sea": 0.2,
        "fort": ["large", "rock", -11.5, {"guns": 1, "captives": 2, "armed": 1}], "tip": "Grimhorn's gold is in the keep. So are his letters."},
    18: {"name": "Sand Citadel", "sub": "A huge fortress", "biome": "tropic", "sky": "overcast", "sea": 0.7,
        "fort": ["huge", "far", -20.0, {"captives": 3, "armed": 2}], "tip": "Hit low and let it fall. Time the roll of the ship."},
    19: {"name": "The Vault", "sub": "Guns on the red cliffs", "biome": "badlands", "sky": "noon", "sea": 0.35,
        "fort": ["large", "cliff", -16.0, {"guns": 2, "captives": 1, "armed": 1}], "ships": [[9.0, 3.8, 0.0, 2, true]],
        "tip": "Take the guns first. They see you coming."},
    20: {"name": "Grimhorn's Trap", "sub": "The last island", "biome": "volcano", "sky": "storm", "sea": 0.85, "swell": 1.6,
        "fort": ["mega", "far", -22.5, {"guns": 1, "captives": 3, "armed": 2, "grimhorn": true}],
        "ships": [[-10.0, 3.6, 0.0, 3, true], [10.5, 3.9, 0.0, 3, true], [-5.0, 4.2, 0.4, 1, false], [6.0, 4.4, 0.45, 1, false]],
        "tip": "Every ship he has is here. Grimhorn stands on the highest tower."},
}

const SHOTS := {"small": 4, "medium": 5, "large": 6, "huge": 8, "boss": 8, "mega": 12, "harbor": 6, "battery": 6}
const PAR := {"small": 2, "medium": 3, "large": 3, "huge": 4, "boss": 5, "mega": 7, "harbor": 3, "battery": 3}

static func level_count() -> int:
    return LEVELS.size()

static func row(id: int) -> Dictionary:
    return LEVELS.get(id, {})

## The full level data for a campaign level. `json` is the designed level file's contents (for
## levels 1 and 11, and as the base for ammo lists).
static func level(id: int, json: Dictionary) -> Dictionary:
    var r := row(id)
    var d := json.duplicate(true)
    d["id"] = id
    d["name"] = r.get("name", d.get("name", "Island"))
    d["subtitle"] = r.get("sub", d.get("subtitle", ""))
    d["hint"] = r.get("tip", d.get("hint", ""))
    d["old_cannon"] = bool(r.get("old", false))
    d["swell"] = float(r.get("swell", 1.0))
    d["volcano"] = r.get("biome", "") == "volcano"
    var terrain: Dictionary = d.get("terrain", {})
    terrain["biome"] = r.get("biome", terrain.get("biome", "tropic"))
    if r.has("sky"):
        terrain["sky"] = r.sky
    if r.has("shore"):
        terrain["shore"] = r.shore
    d["terrain"] = terrain
    if r.has("sea"):
        d["sea"] = r.sea
    if r.has("offshore"):
        d["offshore"] = r.offshore
    if r.has("intro_hold"):
        d["intro_hold"] = r.intro_hold
    for key in ["fov", "intro_from", "sail_in", "sail_after"]:
        if r.has(key):
            d[key] = r[key]
    if bool(r.get("json", false)):
        return d
    # Castle.
    d["blocks"] = []
    d["targets"] = []
    d["captives"] = []
    d["enemyCannons"] = []
    var kind := "none"
    if r.has("fort"):
        var f: Array = r.fort
        kind = f[0]
        var fort := Fortress.generate(id * 101 + 7, f[0], f[1], f[2], f[3])
        for key in ["blocks", "targets", "captives", "enemyCannons"]:
            d[key] = fort[key]
        d["camera"] = {"lookAt": fort.lookAt, "pitch": fort.pitch}
        d["offshore"] = fort.offshore
        terrain["shore"] = r.get("shore", fort.shore)
        terrain["beach"] = fort.beach
        d["boss"] = f[0] in ["boss", "mega"]
    else:
        d["camera"] = {"lookAt": r.get("look", [0.0, 1.5, -14.0]), "pitch": -6.0}
        d["boss"] = false
    if r.has("offshore"):
        d["offshore"] = r.offshore
    # Ships.
    var ships: Array = []
    for s: Array in r.get("ships", []):
        ships.append({"position": [s[0], 0.0, s[1]], "speed": s[2], "hitPoints": s[3], "hasCannon": s[4], "interval": 7.0})
    d["enemyShips"] = ships
    # Balls and stars.
    var shots: int = SHOTS.get(kind, 6) + ships.size()
    var par: int = PAR.get(kind, 3) + ships.size()
    d["projectiles"] = shots
    d["par"] = par
    d["stars"] = {"three": par, "two": par + 2}
    var ammo: Array = r.get("ammo", d.get("ammo", []))
    while not ammo.is_empty() and ammo.size() < shots:
        ammo.append("iron")
    d["ammo"] = ammo
    d["cannon"] = d.get("cannon", [0, 0.9, 7.0])
    return d
