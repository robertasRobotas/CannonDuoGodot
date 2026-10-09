#!/usr/bin/env python3
"""Generates level 1, Storm Landing: Grimhorn's twin forts, into levels/level01.json.

Two identical forts stand a cable apart, joined by a log fence. Each is a real building with
four walls and depth, not a flat facade: a stone ground floor (stone shrugs off cannonballs;
only a blast cracks it), two boarded wooden storeys, a peaked roof, and a cargo annex leaning
on its seaward side. Each fort keeps all its powder in ONE place: the magazine on the ground
floor, behind the stone footings and two boarded-up front panels.

The magazines stand within each other's catch radius, so blowing one fort throws its timbers
into its twin and lights the other store too: one well-placed low shot brings both down.
"""
import json
import os

PATH = os.path.join(os.path.dirname(__file__), "..", "levels", "level01.json")
Z = -13.0      # the fort line
CX = 6.25      # fort centres at +-CX; the two magazines sit 2*CX apart

blocks = []
targets = []
captives = []


def blk(mat, pos, size, **kw):
    b = {"material": mat, "position": [round(v, 3) for v in pos], "size": [round(v, 3) for v in size]}
    b.update(kw)
    blocks.append(b)


def guard(x, y, z, r=0.35):
    targets.append({"position": [round(x, 3), round(y + r, 3), round(z, 3)], "radius": r})


def fort(cx):
    """One fort, centred on cx."""
    out = 1.0 if cx >= 0 else -1.0   # toward the outside of the pair
    # Ground floor: stone corner pillars, stone back and side walls, a boarded front.
    H0 = 2.4
    for sx in (-1.9, 1.9):
        for sz in (-1.55, 1.55):
            blk("stone", (cx + sx, H0 / 2, Z + sz), (0.55, H0, 0.55))
    blk("stone", (cx, H0 / 2, Z - 1.55), (3.25, H0, 0.42))
    for sx in (-1.9, 1.9):
        blk("stone", (cx + sx, H0 / 2, Z), (0.42, H0, 2.6))
    for sx in (-0.95, 0.95):
        blk("wood", (cx + sx, H0 / 2, Z + 1.55), (1.25, H0, 0.22))
    # The magazine: all the fort's powder in one place, behind the boards.
    for mx, mz in ((-0.45, 0.0), (0.45, 0.0), (0.0, -0.7)):
        blk("tnt", (cx + mx, 0.42, Z + mz), (0.6, 0.84, 0.6))
    blk("wood", (cx, H0 + 0.12, Z), (4.5, 0.24, 3.8))
    # Two wooden storeys walled on three sides; pirates at the open front.
    y = H0 + 0.24
    for h in (2.0, 1.85):
        for sx in (-1.95, 1.95):
            for sz in (-1.6, 1.6):
                blk("wood", (cx + sx, y + h / 2, Z + sz), (0.3, h, 0.3))
        for sx in (-1.95, 1.95):
            blk("wood", (cx + sx, y + h / 2, Z), (0.16, h * 0.9, 2.9))
        blk("wood", (cx, y + h / 2, Z - 1.6), (3.6, h * 0.9, 0.16))
        y += h
        blk("wood", (cx, y + 0.12, Z), (4.3, 0.24, 3.6))
        y += 0.24
        guard(cx, y, Z + 1.25)
    # Peaked roof with the lookout on the ridge.
    blk("wood", (cx - 1.05, y + 0.8, Z), (2.5, 0.2, 3.9), rotation=[0, 0, 38])
    blk("wood", (cx + 1.05, y + 0.8, Z), (2.5, 0.2, 3.9), rotation=[0, 0, -38])
    blk("wood", (cx, y + 1.55, Z), (0.34, 0.3, 3.9))
    guard(cx, y + 1.7, Z)
    # Seaward annex: a raised cargo platform on posts and a brace, barrels and a crate on top.
    ax = cx + out * 3.3
    for dz in (-0.9, 0.9):
        blk("wood", (ax, 1.2, Z + dz), (0.28, 2.4, 0.28))
    blk("wood", (cx + out * 2.6, 1.2, Z), (0.28, 2.4, 0.28))
    blk("wood", (ax - out * 0.35, 2.52, Z), (2.3, 0.22, 2.4))
    blk("wood", (ax - out * 1.1, 1.25, Z + 1.1), (0.22, 2.9, 0.22), rotation=[0, 0, out * 38])
    for i in range(3):
        blk("wood", (ax - out * 0.5 + i * out * 0.62, 2.95, Z + 0.4), (0.55, 0.75, 0.55), style="barrel")
    blk("wood", (ax, 2.95, Z - 0.8), (0.75, 0.75, 0.75), style="crate")
    guard(ax - out * 0.2, 3.35, Z + 0.3)
    # Crates piled against the fort's outer wall.
    blk("wood", (cx + out * 2.45, 0.42, Z + 1.0), (0.8, 0.8, 0.8), style="crate")
    blk("wood", (cx + out * 2.45, 1.2, Z + 1.0), (0.72, 0.72, 0.72), style="crate")


fort(-CX)
fort(CX)

# A log fence joins the forts; it carries the ruin of one into the other.
for i in range(9):
    blk("wood", (-3.2 + i * 0.8, 1.15, Z + 1.3), (0.34, 2.3, 0.34), style="log")
blk("wood", (0, 2.4, Z + 1.3), (6.9, 0.2, 0.7))
guard(0, 2.6, Z + 1.3)

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
d["camera"] = {"lookAt": [0, 4.6, Z], "pitch": -6.5}
d["blast_radius"] = 1.9   # one magazine lights the other across the gap
d["projectiles"] = 6
d["par"] = 3
d["stars"] = {"three": 3, "two": 5}
json.dump(d, open(PATH, "w"), indent=1)
print(len(blocks), "blocks", len(targets), "targets")
