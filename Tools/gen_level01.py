#!/usr/bin/env python3
"""Generates level 1, Storm Landing: Grimhorn's stone fort, into levels/level01.json.

Two square stone towers with slate spires stand a cable apart, each with two round turrets
on its outer corners, joined by a battlemented curtain wall with a gate. Stone shrugs off cannonballs; only a blast cracks it. Each tower
keeps all its powder in ONE place: the magazine in the cellar, behind two boarded doors on the
seaward side.

The magazines stand within each other's catch radius, so blowing one tower throws its stones
into its twin and lights the other store too: one well-placed low shot brings it all down.
"""
import json
import os

PATH = os.path.join(os.path.dirname(__file__), "..", "levels", "level01.json")
Z = -13.0      # the fort line
CX = 4.8       # tower centres at +-CX; the two magazines sit 2*CX apart

blocks = []
targets = []
captives = []


def blk(mat, pos, size, **kw):
    if mat == "stone":
        # The whole fort is light grey stone.
        st = kw.get("style", "")
        kw["style"] = st + ":grey" if ":" not in st else st
    b = {"material": mat, "position": [round(v, 3) for v in pos], "size": [round(v, 3) for v in size]}
    b.update(kw)
    blocks.append(b)


def guard(x, y, z, r=0.35):
    targets.append({"position": [round(x, 3), round(y + r, 3), round(z, 3)], "radius": r})


def pillar(x, y0, h, z, w=0.5):
    blk("stone", (x, y0 + h / 2, z), (w, h, w))


def tower(cx):
    """A square stone tower: three storeys of corner pillars and wall slabs, a stone floor
    between each, and a slate spire. The powder sits in the cellar behind two boarded doors on
    the seaward side; the upper storeys have arrow slits (a gap between two front slabs)."""
    R = 1.15     # pillar centres at +-R
    H = 2.2      # one storey
    y = 0.0
    for storey in range(3):
        for sx in (-R, R):
            for sz in (-R, R):
                pillar(cx + sx, y, H, Z + sz)
        blk("stone", (cx, y + H / 2, Z - R), (1.8, H, 0.36))
        for sx in (-R, R):
            blk("stone", (cx + sx, y + H / 2, Z), (0.36, H, 1.8))
        if storey == 0:
            # Boarded doors with a gap between them: the red powder shows through, and a
            # precise ball goes straight in.
            for dx in (-0.55, 0.55):
                blk("wood", (cx + dx, y + H / 2, Z + R), (0.6, H, 0.2))
        else:
            for dx in (-0.55, 0.55):
                blk("stone", (cx + dx, y + H / 2, Z + R), (0.6, H, 0.36))
        y += H
        blk("stone", (cx, y + 0.11, Z), (2.9, 0.22, 2.9))
        y += 0.22
    # The magazine in the cellar: big barrels, two at the doors and one behind.
    for mx, mz in ((-0.47, 0.45), (0.47, 0.45), (0.0, -0.5)):
        blk("tnt", (cx + mx, 0.7, Z + mz), (0.9, 1.4, 0.9))
    # Parapet and the spire; a lookout on the walk.
    for sx in (-R, R):
        for sz in (-R, R):
            blk("stone", (cx + sx, y + 0.3, Z + sz), (0.5, 0.6, 0.5))
    blk("stone", (cx, y + 1.0, Z), (2.6, 2.0, 2.6), style="spire")
    guard(cx + 0.55 * (1 if cx < 0 else -1), y, Z + 0.55)
    # Two round turrets lean on the tower's outer corners, front and back.
    out = 1.0 if cx >= 0 else -1.0
    for dz in (-1.15, 1.15):
        blk("stone", (cx + out * (R + 0.77), 2.1, Z + dz), (1.0, 4.2, 1.0), style="tower")


def curtain_wall():
    """The wall between the towers: two courses of stone, merlons on top, and the gate in the
    middle with a guard either side."""
    xs = (-2.35, 0.0, 2.35)
    for x in xs:
        if x == 0.0:
            blk("wood", (0.0, 1.0, Z), (1.7, 2.0, 0.3), style="gate")
        else:
            blk("stone", (x, 1.0, Z), (2.3, 2.0, 0.4))
    for x in xs:
        blk("stone", (x, 2.55, Z), (2.3, 1.1, 0.4))
    for i in range(7):
        blk("stone", (-2.9 + i * 0.95, 3.35, Z), (0.45, 0.5, 0.4))
    guard(-1.5, 3.1, Z)
    guard(1.5, 3.1, Z)
    # Stores against the wall, inside the fort.
    blk("wood", (-2.0, 0.4, Z - 1.1), (0.8, 0.8, 0.8), style="crate")
    blk("wood", (2.1, 0.375, Z - 1.1), (0.55, 0.75, 0.55), style="barrel")
    blk("wood", (2.65, 0.375, Z - 1.0), (0.55, 0.75, 0.55), style="barrel")


def fort():
    tower(-CX)
    tower(CX)
    curtain_wall()


fort()

# Islanders caged beyond each fort, away from the pirates.
for n, sx in enumerate((-1.0, 1.0), start=1):
    x = sx * (CX + 5.6)
    cz = Z + 2.0
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            blk("wood", (x + dx, 0.62, cz + dz), (0.1, 1.24, 0.1), cage=n)
    blk("wood", (x, 1.3, cz), (1.1, 0.12, 1.1), cage=n)
    captives.append({"position": [round(x, 3), 0.55, cz], "cage": n, "deserter": False})

d = json.load(open(PATH))
d["blocks"] = blocks
d["targets"] = targets
d["captives"] = captives
d["camera"] = {"lookAt": [0, 4.8, Z], "pitch": -6.5}
d["blast_radius"] = 1.9   # one magazine lights the other across the gap
d["big_blast"] = True     # stone flies in slow motion, long and heavy
d["bonfires"] = [[0.0, Z + 3.4, 0.55]]   # a small fire on the beach before the gate, lighting the walls
d.setdefault("terrain", {})["tree_max"] = 6.5     # no palm overtops the towers
d["projectiles"] = 6
d["par"] = 3
d["stars"] = {"three": 3, "two": 5}
json.dump(d, open(PATH, "w"), indent=1)
print(len(blocks), "blocks", len(targets), "targets")
