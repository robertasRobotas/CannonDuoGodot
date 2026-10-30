## The campaign: chapters and their levels. Chapter 1, The Valora Islands, is 24 levels:
## fort battles, two sailing voyages (the helm levels), a window shot, the orca pod, and
## Grimhorn's trap. Later chapters are charted but not yet sailed.
##
## You are the young gunner of the last navy ship afloat; the Captain gives the orders.
##
## Each level row builds a full level dictionary (the same shape as the level JSON) so Level
## does not care whether a castle was designed by hand or generated.
class_name Campaign

const CHAPTERS := [
    {"title": "The Valora Islands", "levels": 38},
    {"title": "The Frozen North", "levels": 0},
    {"title": "The Desert Coast", "levels": 0},
    {"title": "The Pirate King", "levels": 0},
]

## Level rows. Keys:
##   name, sub, tip, biome (tropic, meadow, highlands, badlands, volcano, harbor, opensea),
##   sky (noon, sunset, overcast, night), sea (0..1 weather), swell (wave height multiplier),
##   fort [kind, site, z, opts], ships [[x, z, speed, hp, cannon, length?], ...], ammo, old (the
##   old small cannon), offshore, look (camera aim for sea levels), file (which levelNN.json to
##   read when "json" is set), mode (a voyage at the helm, no cannon: sail, waves, reef, whirl,
##   escape, wrecks, gauntlet, cave), dist (the voyage's length in metres), orcas (the pod),
##   scenario (special battle rules: chase, landing, lighthouse, raid, escort, bridge, sharks,
##   balloons), stern_gun (the gun fires over the stern), shots / par (override the ammo).
const LEVELS := {
    1: {"json": true, "name": "Storm Landing", "sub": "Twin towers", "biome": "tropic", "sea": 1.0, "swell": 2.3, "offshore": 18.0, "intro_hold": 3.5, "fov": 74.0,
        "intro_from": [-30.0, 15.0, 40.0], "sail_in": 11.0, "sail_after": 0.8,
        "tip": "Stone laughs at cannonballs. Their powder is in the tower cellars, behind the boarded doors.", },
    2: {"mode": "sail", "name": "Set Sail", "sub": "Take the helm", "biome": "harbor", "sky": "noon", "sea": 0.15, "dist": 260.0,
        "tip": "Haul the halyard, then lean the ship past the rocks. The pier does the rest."},
    3: {"name": "Fisher's Wharf", "sub": "A pirate-held harbour", "biome": "harbor", "sky": "noon", "sea": 0.15,
        "fort": ["harbor", "sand", -11.0, {"captives": 2, "no_tnt": true}], "offshore": 7.0,
        "tip": "No powder here. Shoot the legs out from under the lookouts."},
    4: {"mode": "waves", "name": "Wave Rider", "sub": "Storm swell", "biome": "opensea", "sky": "overcast", "sea": 0.7, "swell": 2.4, "dist": 300.0,
        "tip": "Meet each wave where it is green. White water rolls a ship over."},
    5: {"name": "Rock Perch", "sub": "Pirates on the hillfort", "biome": "tropic", "sky": "sunset", "sea": 0.2,
        "fort": ["perch", "mound", -19.0, {"captives": 1, "no_tnt": true}], "tip": "A pirate who falls off the hill is done for."},
    6: {"mode": "sail", "name": "Night Run", "sub": "The gorge in fog", "biome": "harbor", "sky": "night", "sea": 0.15, "dist": 260.0, "rock_seed": 6061,
        "light": 3.2, "fog_dist": 45.0,
        "tip": "The same channel, by night and in fog. The rocks have shifted, and they show forty-five metres out. Lean her past them."},
    7: {"name": "The Stockade", "sub": "A log fort in the fields", "biome": "meadow", "sky": "noon", "sea": 0.1,
        "fort": ["stockade", "sand", -10.5, {"captives": 2}], "blast_radius": 0.8, "chain_delay": 0.0, "tnt_spark": false, "tnt_fall": 0.4,
        "tip": "Balls bounce off those logs. Hit a keg up in a lookout, or knock one down: the powder inside goes too, and the sentries with it."},
    8: {"name": "Driftwood Camp", "sub": "A fort among its stores", "biome": "tropic", "sky": "sunset", "sea": 0.25, "file": 10,
        "fort": ["medium", "far", -16.0, {"no_tnt": true, "pirates": 4, "props": true}], "shots": 8, "par": 4, "ammo": [],
        "tip": "No powder here. Knock the towers down onto them; the stores about the fort are just timber."},
    9: {"name": "Sandbag Battery", "sub": "Two guns dug in on the beach", "biome": "tropic", "sky": "noon", "sea": 0.35,
        "fort": ["sandbags", "sand", -11.5, {}], "scenario": "sandbags", "shots": 10, "par": 4,
        "ammo": [], "tip": "Two guns behind sandbags, firing wild. One ball sets a nest alight; the second blows it, gun and gunner."},
    10: {"name": "Broadside", "sub": "A galleon, gun to gun", "biome": "opensea", "sky": "noon", "sea": 0.3, "offshore": 0.0, "scenario": "duel", "file": 8,
        "look": [0.0, 2.5, -24.0], "shots": 14, "par": 8, "hull": 4, "islets": false, "ammo": [],
        "tip": "A galleon, thirty metres off, and nothing but sea. Six balls sink her. Every third or fourth of hers finds us: four and we go down."},
    11: {"name": "Port Alder", "sub": "The harbour", "biome": "harbor", "sky": "noon", "sea": 0.15, "scenario": "sandbags",
        "fort": ["harbor", "sand", -11.0, {"captives": 2, "no_tnt": true, "nest": true}], "blast_radius": 0.65, "blast_power": 0.5, "nest_markers": false,
        "tip": "A gun dug in on the quay, firing wild: one ball sets it alight, the second blows it. Then the lookouts. Mind the people in cages."},
    12: {"mode": "whirl", "name": "Maelstrom Lane", "sub": "Whirlpools in the storm", "biome": "opensea", "sky": "night", "sea": 1.0, "swell": 1.8, "storm": true, "dist": 300.0,
        "tip": "A storm, and the funnels pull. Give every throat a wide berth; the sea runs easiest down the middle."},
    13: {"name": "Eagle's Nest", "sub": "High on the crag", "biome": "highlands", "sky": "overcast", "sea": 0.3,
        "fort": ["large", "crag", -21.0, {"captives": 1, "logs": true, "log_share": 1.0}], "ammo": ["stone", "stone", "iron", "stone", "stone", "iron"], "tip": "The fort is on the crag's top. Aim high and pull hard; the logs only fall to a blast."},
    14: {"name": "The Lighthouse", "sub": "Put out the light", "biome": "tropic", "sky": "night", "sea": 0.25, "scenario": "beacon",
        "fort": ["lighthouse", "knoll", -9.0, {}], "offshore": 6.0, "shots": 9, "par": 3, "blast_radius": 1.0, "torches": false,
        "tip": "The powder is up in the lantern. One ball there and the top of the tower comes down."},
    15: {"name": "Night Watch", "sub": "By firelight", "biome": "tropic", "sky": "night", "sea": 0.2, "torches": false, "scenario": "sandbags", "nest_markers": false,
        "fort": ["keep", "sand", -10.0, {"captives": 2, "no_tnt": true, "log_share": 1.0, "nest": true}], "shots": 9, "par": 5,
        "ammo": ["iron", "tnt", "iron", "iron", "tnt", "iron", "iron", "iron", "iron"],
        "bonfires": [[-7.5, -7.5], [7.5, -7.5]], "blast_radius": 0.65, "blast_power": 0.5,
        "tip": "A gun dug in before the log keep: one ball sets it alight, the second blows it. Then the towers. Two of your balls are powder."},
    16: {"mode": "whirl", "name": "Fog Lane", "sub": "Whirlpools in the fog", "biome": "opensea", "sky": "night", "sea": 1.0, "swell": 1.8, "storm": true, "dist": 300.0,
        "light": 3.2, "fog_dist": 45.0, "rock_seed": 1616,
        "tip": "The storm again, and fog with it: the funnels show forty-five metres out. Keep to the middle."},
    17: {"name": "Brick Tower", "sub": "The old tower on the hill", "biome": "meadow", "sky": "overcast", "sea": 0.4, "scenario": "twin_powder",
        "fort": ["castle", "sand", -13.0, {"captives": 2}], "ammo": [],
        "tip": "The tower will not fall. Powder in the works either side of it: blow both, and the gun on top shoots back."},
    18: {"mode": "escape", "name": "The Eye", "sub": "Caught in the maelstrom", "biome": "opensea", "sky": "night", "sea": 1.0, "swell": 1.8, "storm": true, "dist": 0.0,
        "tip": "Keep the rudder in the white window and she climbs out. The window never stops moving."},
    19: {"name": "Black Galleon", "sub": "Gun to gun in the storm", "biome": "opensea", "sky": "night", "sea": 0.85, "swell": 1.8, "offshore": 0.0, "scenario": "duel", "file": 8,
        "duel": {"size": 2.0, "hits": 7, "interval": 2.67, "hits_every": 2, "hits_every_max": 3, "variant": "black"}, "light": 2.2, "fog": 0.4,
        "look": [0.0, 3.0, -24.0], "shots": 16, "par": 9, "hull": 4, "islets": false, "ammo": [],
        "tip": "A black galleon twice our size, in a storm by night. Seven balls sink her. She fires fast, and every second or third ball of hers finds us."},
    20: {"mode": "kraken", "name": "The Kraken", "sub": "The beast of the deep", "biome": "opensea", "sky": "overcast", "sea": 0.7, "swell": 2.4, "storm": true, "dist": 300.0, "boss": true, "light": 0.5,
        "tip": "Ride the swell. When the sea opens, steer out from under its arms, and when they stand up, tap them and fire. Kill it before the mouth takes us."},
    21: {"name": "Stormbreak", "sub": "Huge waves", "biome": "opensea", "sky": "storm", "sea": 0.9, "swell": 3.2, "offshore": 0.0,
        "ships": [[-8.0, -12.0, 0.0, 3, true], [6.0, -16.0, 0.0, 3, true], [-1.0, -24.0, 0.0, 3, true]], "look": [0.0, 1.5, -16.0],
        "tip": "The sea lifts you high. Fire as you rise."},
    22: {"mode": "gauntlet", "name": "The Gauntlet", "sub": "Guns on both cliffs", "biome": "opensea", "sky": "night", "sea": 0.3, "dist": 320.0,
        "tip": "A white ring shows where each ball will land. Be anywhere else."},
    23: {"name": "Old Faithful", "sub": "With the old cannon", "biome": "tropic", "sky": "noon", "sea": 0.15, "old": true,
        "fort": ["small", "rock", -8.5, {"captives": 1}], "offshore": 2.5, "tip": "My old cannon is weak. Get close and aim higher."},
    24: {"name": "Silent Harbour", "sub": "A night raid", "biome": "harbor", "sky": "night", "sea": 0.15, "old": true, "scenario": "raid",
        "fort": ["harbor", "sand", -11.0, {"guns": 2, "armed": 2, "captives": 1}], "offshore": 6.0,
        "tip": "Every ball must hit something. The first miss rings the alarm bell."},
    25: {"name": "Fire Mountain", "sub": "The volcano island", "biome": "volcano", "sky": "overcast", "sea": 0.3, "old": true,
        "fort": ["medium", "sand", -10.0, {"captives": 2}], "offshore": 3.0, "tip": "The mountain throws lava. Let it help you."},
    26: {"name": "The Convoy", "sub": "Protect the merchant", "biome": "opensea", "sky": "sunset", "sea": 0.25, "old": true, "offshore": 0.0, "scenario": "escort",
        "look": [0.0, 1.5, -18.0], "shots": 14, "par": 8,
        "tip": "The merchant is slow and the boats are fast. Sink them before they reach her side."},
    27: {"name": "Skull Rock", "sub": "Where they keep your cannon", "biome": "badlands", "sky": "sunset", "sea": 0.3, "old": true,
        "fort": ["boss", "cliff", -15.5, {"guns": 1, "armed": 1}], "offshore": 2.5, "tip": "Your own cannon is in that vault. Take it back."},
    28: {"name": "Rope Bridge", "sub": "Pirates on the planks", "biome": "highlands", "sky": "noon", "sea": 0.2, "scenario": "bridge",
        "fort": ["ropebridge", "sand", -11.5, {"armed": 1}], "offshore": 6.0, "shots": 7, "par": 3,
        "tip": "Shoot the posts or the ropes. The planks, the pirates and the powder below do the rest."},
    29: {"name": "Windmill Vale", "sub": "Pirates who want to quit", "biome": "meadow", "sky": "noon", "sea": 0.1,
        "fort": ["large", "far", -17.0, {"captives": 1, "deserters": 2}], "tip": "Some caged pirates wave white rags. Free them too."},
    30: {"name": "Shark Bay", "sub": "A pier over deep water", "biome": "tropic", "sky": "noon", "sea": 0.2, "scenario": "sharks",
        "fort": ["pier", "sand", -2.0, {"armed": 1}], "offshore": 9.0, "shots": 8, "par": 4,
        "tip": "Knock them into the water. Something down there is hungry."},
    31: {"name": "The Treasury", "sub": "By torchlight", "biome": "highlands", "sky": "night", "sea": 0.2,
        "fort": ["large", "rock", -11.5, {"guns": 1, "captives": 2, "armed": 1}], "tip": "Grimhorn's gold is in the keep. So are his letters."},
    32: {"name": "Balloon Raiders", "sub": "Pirates in the air", "biome": "meadow", "sky": "noon", "sea": 0.15, "scenario": "balloons",
        "fort": ["medium", "sand", -12.0, {"captives": 1}], "shots": 10, "par": 5,
        "tip": "Shoot the envelopes while they are over the fort. The baskets carry powder."},
    33: {"name": "Sand Citadel", "sub": "A huge fortress", "biome": "tropic", "sky": "overcast", "sea": 0.7,
        "fort": ["huge", "far", -20.0, {"captives": 3, "armed": 2}], "tip": "Hit low and let it fall. Time the roll of the ship."},
    34: {"mode": "cave", "name": "The Hollow", "sub": "The roof comes down", "biome": "opensea", "sky": "overcast", "sea": 0.15, "dist": 260.0,
        "tip": "Dust from the roof means a rock is coming. Steer clear, or tap it and the bow gun takes it."},
    35: {"name": "The Vault", "sub": "Guns on the red cliffs", "biome": "badlands", "sky": "noon", "sea": 0.35,
        "fort": ["large", "cliff", -16.0, {"guns": 2, "captives": 1, "armed": 1}], "ships": [[9.0, 3.8, 0.0, 2, true]],
        "tip": "Take the guns first. They see you coming."},
    36: {"name": "The Keyhole", "sub": "One small window", "biome": "badlands", "sky": "sunset", "sea": 0.2,
        "fort": ["keyhole", "sand", -12.0, {"guns": 1}], "offshore": 10.0,
        "tip": "The wall laughs at iron. Thread the window."},
    37: {"name": "The Pod", "sub": "Something is circling", "biome": "opensea", "sky": "overcast", "sea": 0.45, "orcas": 3, "offshore": 0.0,
        "look": [0.0, 1.0, -16.0], "tip": "They only show their backs for a breath. Fire then."},
    38: {"name": "Grimhorn's Trap", "sub": "The last island", "biome": "volcano", "sky": "storm", "sea": 0.85, "swell": 1.6,
        "fort": ["mega", "far", -22.5, {"guns": 1, "captives": 3, "armed": 2, "grimhorn": true}],
        "ships": [[-10.0, 3.6, 0.0, 3, true], [10.5, 3.9, 0.0, 3, true], [-5.0, 4.2, 0.4, 1, false], [6.0, 4.4, 0.45, 1, false]],
        "tip": "Every ship he has is here. Grimhorn stands on the highest tower."},
}

const SHOTS := {"small": 4, "perch": 4, "sandbags": 10, "medium": 5, "large": 6, "keep": 6, "castle": 8, "huge": 8, "boss": 8, "mega": 12, "harbor": 6, "battery": 6, "keyhole": 5, "lighthouse": 7, "ropebridge": 6, "pier": 7}
const PAR := {"small": 2, "perch": 2, "sandbags": 4, "medium": 3, "large": 3, "keep": 3, "castle": 4, "huge": 4, "boss": 5, "mega": 7, "harbor": 3, "battery": 3, "keyhole": 2, "lighthouse": 3, "ropebridge": 3, "pier": 4}

## The game ends at this island: later rows in LEVELS are kept but not played.
const LAST_LEVEL := 20

static func level_count() -> int:
    return mini(LAST_LEVEL, LEVELS.size())

static func row(id: int) -> Dictionary:
    return LEVELS.get(id, {})

## Which levelNN.json file backs this level (some ids share one).
static func file_id(id: int) -> int:
    return int(row(id).get("file", id))

## The full level data for a campaign level. `json` is the designed level file's contents
## (used by the "json" rows, and as the base for ammo lists).
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
    for key in ["fov", "intro_from", "sail_in", "sail_after", "blast_radius", "blast_power", "chain_delay", "rock_seed", "light", "fog", "fog_dist", "tnt_knock", "tnt_spark", "tnt_fall", "nest_markers", "storm", "torches", "bonfires"]:
        if r.has(key):
            d[key] = r[key]
    # A voyage at the helm: no castle, no cannon; VoyageLevel reads mode and dist.
    if r.has("mode"):
        d["mode"] = r.mode
        d["dist"] = float(r.get("dist", 260.0))
        d["boss"] = bool(r.get("boss", false))   # the skull on the chart
        return d
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
        # Powder goes up as on the first island: the long slow blast, and rubble that
        # smoulders and smokes afterwards.
        d["big_blast"] = true
        d["embers"] = 0.18
    else:
        d["camera"] = {"lookAt": r.get("look", [0.0, 1.5, -14.0]), "pitch": -6.0}
        d["boss"] = false
    if r.has("offshore"):
        d["offshore"] = r.offshore
    # The pod: orcas instead of a fort, handled by OrcaDirector inside the level.
    if r.has("orcas"):
        d["orcas"] = int(r.orcas)
    for key in ["scenario", "stern_gun", "hull", "wave_axis", "islets", "duel"]:
        if r.has(key):
            d[key] = r[key]
    # Ships.
    var ships: Array = []
    for s: Array in r.get("ships", []):
        var sd := {"position": [s[0], 0.0, s[1]], "speed": s[2], "hitPoints": s[3], "hasCannon": s[4], "interval": 7.0}
        if s.size() > 5:
            sd["length"] = s[5]
        ships.append(sd)
    d["enemyShips"] = ships
    # Balls and stars.
    var shots: int = SHOTS.get(kind, 6) + ships.size()
    var par: int = PAR.get(kind, 3) + ships.size()
    if r.has("orcas"):
        shots = 12
        par = 6
    if r.has("shots"):
        shots = int(r.shots)
    if r.has("par"):
        par = int(r.par)
    d["projectiles"] = shots
    d["par"] = par
    d["stars"] = {"three": par, "two": par + 2}
    var ammo: Array = r.get("ammo", d.get("ammo", []))
    while not ammo.is_empty() and ammo.size() < shots:
        ammo.append("iron")
    d["ammo"] = ammo
    d["cannon"] = d.get("cannon", [0, 0.9, 7.0])
    return d
