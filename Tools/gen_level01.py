#!/usr/bin/env python3
"""Generates level 1, Storm Landing: Grimhorn's stone fort, into levels/level01.json.

Four square stone towers with slate spires stand in a line, a cable apart, each with a round
turret on all four corners, joined by battlemented curtain walls: a gate in the middle wall, and a
plain wall out to an end tower on either flank. The two inner towers stand a storey taller.
Stone shrugs off cannonballs; only a blast cracks it. Each tower keeps all its powder in ONE
place: the magazine in the cellar. The inner towers show it behind two boarded doors on the
seaward side; the end towers hide theirs behind solid stone. A powder store also stands behind
each flank wall.

Every magazine stands within the catch radius of the next, so blowing one tower throws its
stones into its neighbour and lights the next store too: one well-placed low shot brings the
whole line down.
"""
import json
import os

PATH = os.path.join(os.path.dirname(__file__), "..", "levels", "level01.json")
Z = -13.0      # the fort line
CX = 4.8       # inner tower centres at +-CX; neighbouring magazines sit 2*CX apart
OX = 3 * CX    # end tower centres at +-OX, one more wall's length out
S = 15.0 / 9   # the whole fort is built this much bigger, about the gate on the fort line

blocks = []
targets = []
captives = []


def blk(mat, pos, size, **kw):
    if mat == "stone":
        # The whole fort is light grey stone.
        st = kw.get("style", "")
        kw["style"] = st + ":grey" if ":" not in st else st
    scale = kw.pop("scale", S)
    pos = (pos[0] * scale, pos[1] * scale, (pos[2] - Z) * scale + Z)
    size = tuple(v * scale for v in size)
    b = {"material": mat, "position": [round(v, 3) for v in pos], "size": [round(v, 3) for v in size]}
    b.update(kw)
    blocks.append(b)


def guard(x, y, z, r=0.35):
    # Guards stay man-sized; only where they stand scales with the fort.
    targets.append({"position": [round(x * S, 3), round(y * S + r, 3), round((z - Z) * S + Z, 3)], "radius": r})


def pillar(x, y0, h, z, w=0.5):
    blk("stone", (x, y0 + h / 2, z), (w, h, w))


def tower(cx, storeys=3, doors=True, turret=4.2):
    """A square stone tower: storeys of corner pillars and wall slabs, a stone floor between
    each, and a slate spire. The powder sits in the cellar: behind two boarded doors on the
    seaward side when `doors`, else walled in with solid stone so nothing shows. The upper
    storeys have arrow slits (a gap between two front slabs). The top storey's pillars run on
    up through the walk and stand proud of it as the parapet corners: one block each, so a
    passing ball cannot knock them off. `turret` is the height of the four corner turrets."""
    R = 1.15     # pillar centres at +-R
    H = 2.2      # one storey
    F = 0.22     # a floor slab
    P = 0.6      # the parapet corners stand this much above the walk
    y = 0.0
    for storey in range(storeys):
        last = storey == storeys - 1
        for sx in (-R, R):
            for sz in (-R, R):
                pillar(cx + sx, y, H + F + P if last else H, Z + sz)
        blk("stone", (cx, y + H / 2, Z - R), (1.8, H, 0.36))
        for sx in (-R, R):
            blk("stone", (cx + sx, y + H / 2, Z), (0.36, H, 1.8))
        if storey == 0 and not doors:
            # Solid stone: the magazine behind it is out of sight.
            blk("stone", (cx, y + H / 2, Z + R), (1.8, H, 0.36))
        elif storey == 0:
            # Boarded doors with a gap between them: the red powder shows through, and a
            # precise ball goes straight in.
            for dx in (-0.55, 0.55):
                blk("wood", (cx + dx, y + H / 2, Z + R), (0.6, H, 0.2))
            # A small plank roof on two posts over the doorway, keeping the rain off the
            # powder: a lean-to against the tower's face.
            for dx in (-1.0, 1.0):
                blk("wood", (cx + dx, y + (H - 0.3) / 2, Z + R + 0.75), (0.16, H - 0.3, 0.16))
            blk("wood", (cx, y + H - 0.15, Z + R + 0.5), (2.5, 0.1, 1.1), rotation=[-14, 0, 0])
        else:
            for dx in (-0.55, 0.55):
                blk("stone", (cx + dx, y + H / 2, Z + R), (0.6, H, 0.36))
        y += H
        if last:
            # The walk, laid in three slabs around the pillars that run on through it.
            blk("stone", (cx, y + F / 2, Z), (2.8, F, 1.8))
            for sz in (-1.15, 1.15):
                blk("stone", (cx, y + F / 2, Z + sz), (1.8, F, 0.5))
        else:
            blk("stone", (cx, y + F / 2, Z), (2.8, F, 2.8))
        y += F
    # The magazine in the cellar: big barrels, two at the front and one behind. Where the
    # doors show the powder, a white arrow bobs in front of the tower, above the doorway's
    # roof, to point it out. (The offset is from the barrel's centre to the arrow's tip.)
    for mx, mz in ((-0.47, 0.45), (0.47, 0.45), (0.0, -0.5)):
        mark = {"marker": [0.0, round(1.9 * S, 3), round(2.8 * S, 3)]} if doors and mx == 0.0 else {}
        blk("tnt", (cx + mx, 0.7, Z + mz), (0.9, 1.4, 0.9), **mark)
    # A stone drum between the parapet corners carries the spire; a lookout on the front walk.
    blk("stone", (cx, y + P / 2, Z), (1.8, P, 1.8))
    blk("stone", (cx, y + P + 1.0, Z), (2.6, 2.0, 2.6), style="spire")
    guard(cx + 0.55 * (1 if cx < 0 else -1), y, Z + 1.15)
    # Four round turrets lean on the tower's corners, both sides, front and back.
    for sx in (-1.0, 1.0):
        for dz in (-1.15, 1.15):
            blk("stone", (cx + sx * (R + 0.77), turret / 2, Z + dz), (1.0, turret, 1.0), style="tower")


def curtain_wall(c=0.0, gate=True):
    """A wall between two towers, centred at x=c: two courses of stone and merlons on top.
    The middle wall has the gate (an iron grate) with a guard either side; the flank walls are
    plain, with one guard on the walk and a powder store behind them."""
    xs = (c - 2.3, c, c + 2.3)
    for x in xs:
        if gate and x == c:
            # An iron portcullis: a ball rings off it, only the blast can throw it down.
            blk("metal", (c, 1.0, Z), (2.4, 2.0, 0.2), style="grate")   # flush with the wall either side
        else:
            blk("stone", (x, 1.0, Z), (2.4 if x == c else 2.2, 2.0, 0.4))
    for x in xs:
        blk("stone", (x, 2.55, Z), (2.4 if x == c else 2.2, 1.1, 0.4))
    for i in range(7):
        blk("stone", (c - 2.9 + i * 0.95, 3.35, Z), (0.45, 0.5, 0.4))
    if gate:
        guard(c - 1.5, 3.1, Z)
        guard(c + 1.5, 3.1, Z)
        # Stores against the wall, inside the fort.
        blk("wood", (c - 1.8, 0.4, Z - 1.1), (0.8, 0.8, 0.8), style="crate")
        blk("wood", (c + 1.5, 0.375, Z - 1.1), (0.55, 0.75, 0.55), style="barrel")
        blk("wood", (c + 2.05, 0.375, Z - 1.0), (0.55, 0.75, 0.55), style="barrel")
    else:
        guard(c, 3.1, Z)
        # A powder store behind the flank wall: it carries the blast on to the end tower and
        # throws the wall down with it.
        for dx in (-0.5, 0.5):
            blk("tnt", (c + dx, 0.7, Z - 0.9), (0.9, 1.4, 0.9))


def fort():
    for cx in (-CX, CX):
        tower(cx, storeys=4, turret=4.2 + 2.2 + 0.22)   # a storey taller, like the tower itself
    for cx in (-OX, OX):
        tower(cx, doors=False)
    curtain_wall()
    for c in (-(CX + OX) / 2, (CX + OX) / 2):
        curtain_wall(c, gate=False)


fort()

# Islanders caged beyond each fort, away from the pirates. The cages are man-sized (not
# scaled with the fort), so they are placed in final coordinates.
for n, sx in enumerate((-1.0, 1.0), start=1):
    x = sx * (OX * S + 5.6)
    cz = Z + 2.0 * S
    for dx in (-0.45, 0.45):
        for dz in (-0.45, 0.45):
            blk("wood", (x + dx, 0.62, cz + dz), (0.1, 1.24, 0.1), cage=n, scale=1.0)
    blk("wood", (x, 1.3, cz), (1.1, 0.12, 1.1), cage=n, scale=1.0)
    captives.append({"position": [round(x, 3), 0.55, cz], "cage": n, "deserter": False})

d = json.load(open(PATH))
d["blocks"] = blocks
d["targets"] = targets
d["captives"] = captives
d["camera"] = {"lookAt": [0, round(4.8 * S, 3), Z], "pitch": -6.5}
d["blast_radius"] = round(1.9 * S, 3)   # one magazine lights the other across the gap
d["big_blast"] = True     # stone flies in slow motion, long and heavy
d["embers"] = 0.18        # this share of the blown rubble smoulders and smokes a while
d.pop("bonfires", None)   # no fire on the beach
d["rain"] = 0.5           # half the rain of a normal storm
d["fog"] = 0.5            # and half the haze, so the big fort reads clearly
d.setdefault("terrain", {})["tree_max"] = round(6.5 * S, 3)     # no palm overtops the towers
d["projectiles"] = 6
d["par"] = 3
d["stars"] = {"three": 3, "two": 5}
json.dump(d, open(PATH, "w"), indent=1)
print(len(blocks), "blocks", len(targets), "targets")
