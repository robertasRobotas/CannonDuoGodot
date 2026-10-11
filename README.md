# Cannon Duo (Godot)

The Godot 4.7 version of Cannon Duo: a pirate ship at sea, castles on the shore, fold or drag
to fire. Replaces the RealityKit prototype in `../CannonDuo`, which stays as the reference for
tuning and level design.

## Requirements

- Godot 4.7.2 at `~/Applications/Godot.app` with the iOS export template installed
  (`~/Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip`).
- Xcode 27 for the iOS build. Signing uses team S246Z44JS6 automatically.

## Run and build

```
Tools/shot.sh 1 9 /tmp/level1.png            # run level 1 on the Mac, screenshot after 9 s
Tools/shot.sh 1 9 /tmp/shot.png 0.55,0,9      # same, auto-firing at 55% power, yaw 0, pitch 9
Tools/export_ios.sh                            # export to build/ios and install on the iPhone
```

Debug launch arguments (after `--`): `--level=N`, `--shot=N,SECONDS,PATH`, `--fire=POWER,YAW,PITCH`,
`--probe=N` (prints the cannon mount and quits), `--autopilot` (a voyage steers itself), `--miss-berth`
(with `--autopilot` on the sail level: holds off the berth and runs into the quay).

## Layout

```
scenes/main.tscn      root scene, runs scripts/main.gd
scripts/main.gd       menu, level select, settings, progress (user://progress.json)
scripts/level.gd      builds the world from levels/levelNN.json and runs the game loop
scripts/hud.gd        overlay: top card, ammo row, hearts, power bar, hint, results
scripts/block.gd      castle piece (RigidBody3D) that breaks on contact impulse
scripts/enemy.gd      enemy figure with marker; pops on impulse or on landing after a fall
scripts/projectile.gd cannonballs (iron, stone, wood, TNT)
scripts/enemy_gun.gd  castle guns; enemy_ship.gd: sloops and boats
scripts/sea.gd        water: shaders/sea.gdshader displaces the mesh, height() matches on CPU
scripts/ship.gd       the player's ship (Dutch ship model), deck found by raycast
scripts/decor.gd      island, backdrop and vegetation per biome
scripts/weather.gd    wind, rain, lightning; fx.gd: particles
scripts/models.gd     GLB loading, bounds, fit and tint helpers
levels/               the same JSON as the Swift project (Tools/generate_levels.py there)
assets/               Kenney kits (CC0, LICENSE-kenney.txt); hq/ ship, trees, mountain (CREDITS.txt); foliage/ trees baked by Tools/bake_foliage.gd
```

Level JSON coordinates: x right, y up, z toward the ship; the shore is at z 2.5, the ship at
z 8. Castle pieces are frozen until the first shot. Stone breaks only from TNT, boulders or
big falls; wood and glass are the weak spots.

## Controls and camera

Aim by dragging the left half (gyro off) or by moving the phone (gyro on, with a deadzone,
gain and smoothing in `Tuning.GYRO_*`). Pull down on the right half to load, release to fire.
Two fingers pinch to zoom out and see the whole ship. Touch is handled in `Level._input` so
HUD panels never swallow a drag; only the top right button column is excluded.

The camera orbits the cannon (`Level._desired_camera`), so the cannon stays on screen at any
aim. The ship's masts, yards and sails are tagged onto render layer 2 in `Ship._tag_rigging`
and culled by the play camera, so nothing blocks the view; the fly-in and the zoomed out view
show the whole ship.

## Not yet ported

Sound, the iPhone Duo hinge (needs a small native plugin), StoreKit subscriptions.
