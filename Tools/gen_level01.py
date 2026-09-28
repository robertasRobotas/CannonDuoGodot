#!/usr/bin/env python3
"""Generates the blocks and targets of level 1, the great wooden fort, into levels/level01.json.

A five storey keep, four storey side towers and three storey watch posts, joined by palisades,
all wood, with red powder barrels at the base of every tower and part way up, so one good hit
sets off a chain that brings the whole fort down. Guards stand at the open front of their
floors so they can be seen from the ship.
"""
import json
import os

PATH = os.path.join(os.path.dirname(__file__), "..", "levels", "level01.json")
Z = -10.2

blocks = []
targets = []
captives = []


def blk(mat, pos, size, **kw):
    b = {"material": mat, "position": [round(v, 3) for v in pos], "size": [round(v, 3) for v in size]}
    b.update(kw)
    blocks.append(b)


def storey(x, z, w, dp, y, h, post=0.3, floor=0.24, walls=False, front_rail=True):
    """Corner posts standing on y and a floor plank on top; returns the top of the floor."""
    ix = w / 2 - post / 2
    iz = dp / 2 - post / 2
    for sx in (-ix, ix):
        for sz in (-iz, iz):
            blk("wood", (x + sx, y + h / 2, z + sz), (post, h, post))
    if walls:
        blk("wood", (x - ix, y + h / 2, z), (0.12, h * 0.9, dp - post * 2))
        blk("wood", (x + ix, y + h / 2, z), (0.12, h * 0.9, dp - post * 2))
        blk("wood", (x, y + h / 2, z - iz), (w - post * 2, h * 0.9, 0.12))
    top = y + h
    blk("wood", (x, top + floor / 2, z), (w + 0.3, floor, dp + 0.3))
    if front_rail:
        blk("wood", (x, top + floor + 0.25, z + dp / 2 + 0.05), (w, 0.5, 0.1))
    return top + floor


def guard(x, y, z):
    targets.append([x, y + 0.3, z])


# Great keep: five storeys. Guards on floors 2 and 4 stand at the open front.
y = 0.0
for k, h in enumerate([2.3, 2.1, 2.0, 1.9, 1.8]):
    has_guard = k in (1, 3)
    y = storey(0, Z, 3.2, 3.0, y, h, post=0.34, walls=(k in (1, 3, 4)), front_rail=not has_guard)
    if has_guard:
        guard(0, y, Z + 1.05)
    if k == 2:
        blk("tnt", (0, y + 0.35, Z - 0.4), (0.6, 0.7, 0.6))
# Peaked roof with a guard on the ridge.
blk("wood", (-0.85, y + 0.75, Z), (2.1, 0.18, 3.4), rotation=[0, 0, 38])
blk("wood", (0.85, y + 0.75, Z), (2.1, 0.18, 3.4), rotation=[0, 0, -38])
blk("wood", (0, y + 1.4, Z), (0.3, 0.3, 3.4))
guard(0, y + 1.45, Z)
# Powder at the base of the keep, in plain sight.
blk("tnt", (-0.5, 0.4, Z + 0.7), (0.62, 0.8, 0.62))
blk("tnt", (0.5, 0.4, Z + 0.7), (0.62, 0.8, 0.62))

# Side towers: four storeys, a guard at the front of the top floor under a little roof.
for sx in (-3.9, 3.9):
    y = 0.0
    for k, h in enumerate([2.2, 2.0, 1.9, 1.8]):
        y = storey(sx, Z + 0.3, 2.2, 2.2, y, h, post=0.28, walls=(k >= 2), front_rail=(k != 3))
        if k == 1:
            blk("tnt", (sx, y + 0.35, Z + 0.3), (0.55, 0.65, 0.55))
    guard(sx, y, Z + 0.3 + 0.7)
    blk("wood", (sx, y + 1.0, Z + 0.3), (1.6, 0.16, 1.6))
    for ox in (-0.65, 0.65):
        blk("wood", (sx + ox, y + 0.45, Z + 0.3 - 0.65), (0.14, 0.9, 0.14))
        blk("wood", (sx + ox, y + 0.45, Z + 0.3 + 0.65), (0.14, 0.9, 0.14))
    blk("tnt", (sx, 0.35, Z + 0.3), (0.55, 0.7, 0.55))

# Watch posts at the ends: tall and thin, they topple.
for sx in (-6.3, 6.3):
    y = storey(sx, Z + 1.0, 1.2, 1.2, 0.0, 3.4, post=0.2)
    y = storey(sx, Z + 1.0, 1.2, 1.2, y, 2.6, post=0.18, front_rail=False)
    y = storey(sx, Z + 1.0, 1.1, 1.1, y, 1.6, post=0.16, front_rail=False)
    guard(sx, y, Z + 1.0)

# Rope bridges from the keep's second floor to each side tower, a pirate on each. The tower
# end rests on a short riser so both ends sit level. Bring a tower down and it drags the
# bridge, the pirate and often the keep's corner with it.
KEEP_F2 = 2.3 + 0.24 + 2.1 + 0.24
TOWER_F2 = 2.2 + 0.24 + 2.0 + 0.24
for side in (-1, 1):
    x0 = side * 1.45
    x1 = side * 3.05
    riser_x = side * 3.15
    blk("wood", (riser_x, TOWER_F2 + (KEEP_F2 - TOWER_F2) / 2, Z + 0.3), (0.5, KEEP_F2 - TOWER_F2, 1.0))
    a, b = min(x0, x1) - 0.2, max(x0, x1) + 0.3
    blk("wood", ((a + b) / 2, KEEP_F2 + 0.1, Z + 0.2), (b - a, 0.2, 1.0))
    blk("tnt", ((a + b) / 2 + side * 0.45, KEEP_F2 + 0.2 + 0.35, Z + 0.35), (0.5, 0.7, 0.5))
    guard((a + b) / 2 - side * 0.3, KEEP_F2 + 0.2, Z + 0.2)

# Powder along the foot of the palisades, so the chain runs the whole width of the fort.
for x in (-2.25, 2.25, -5.3, 5.3):
    blk("tnt", (x, 0.35, Z + 2.1), (0.55, 0.7, 0.55))

# Islanders in two cages on the beach side of the fort: break a bar to free them.
for n, x in enumerate((-2.3, 2.3), start=1):
    cz = Z + 3.3
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            blk("wood", (x + dx, 0.62, cz + dz), (0.1, 1.24, 0.1), cage=n)
    blk("wood", (x, 1.3, cz), (1.1, 0.12, 1.1), cage=n)
    captives.append({"position": [x, 0.45, cz], "cage": n, "deserter": False})

# Palisades with a walkway between the towers.
for x0, x1 in ((1.8, 2.7), (-2.7, -1.8), (5.0, 5.6), (-5.6, -5.0)):
    n = max(2, int(round((x1 - x0) / 0.32)) + 1)
    for i in range(n):
        x = x0 + (x1 - x0) * i / (n - 1)
        blk("wood", (x, 1.1, Z + 1.4), (0.3, 2.2, 0.3))
    blk("wood", ((x0 + x1) / 2, 2.3, Z + 1.4), (x1 - x0 + 0.5, 0.18, 0.7))

# A huge fort: built at the size above, then stretched to twice the height and 1.6 times
# the width, and set further back so it still fits the screen from the ship.
SX, SY, SZ = 1.6, 2.1, 1.5
ZB = -13.0
for b in blocks:
    x, y, z = b["position"]
    b["position"] = [round(x * SX, 3), round(y * SY, 3), round(ZB + (z - Z) * SZ, 3)]
    sx, sy, sz = b["size"]
    b["size"] = [round(sx * SX, 3), round(sy * SY, 3), round(sz * SZ, 3)]
targets = [[t[0] * SX, (t[1] - 0.3) * SY + 0.45, ZB + (t[2] - Z) * SZ] for t in targets]
for c in captives:
    x, y, z = c["position"]
    c["position"] = [round(x * SX, 3), 0.55, round(ZB + (z - Z) * SZ, 3)]

d = json.load(open(PATH))
d["blocks"] = blocks
d["targets"] = [{"position": [round(v, 3) for v in t], "radius": 0.45} for t in targets]
d["camera"] = {"lookAt": [0, 11.0, ZB], "pitch": -5.0}
d["blast_radius"] = 2.1   # powder reaches across the stretched fort
d["captives"] = captives
d["projectiles"] = 7
d["par"] = 3
d["stars"] = {"three": 3, "two": 5}
json.dump(d, open(PATH, "w"), indent=1)
print(len(blocks), "blocks", len(targets), "targets")
