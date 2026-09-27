## Every tunable number, mirrored from the Swift Tuning.swift where it made sense.
class_name Tuning

const GRAVITY := 9.8
const LAUNCH_SPEED_BASE := 12.0   # raised with SHIP_OFFSHORE so low shots still reach
const LAUNCH_SPEED_SCALE := 16.0
const SEA_LEVEL := -0.12
const SHORE_Z := 2.5
const CALM_AMPLITUDE := 0.07
const STORM_AMPLITUDE := 0.32
const SHIP_FREEBOARD := 0.22
const SHIP_ROLL_GAIN := 1.0
const SHIP_PITCH_GAIN := 0.8
const CAMERA_OFFSET := Vector3(0, 2.6, 3.9)     # from the cannon: up, back across the deck to port
## Extra metres between each level's cannon spot and the shore, so every castle is seen from
## its own distance. Level 1 is tuned at 5. A level can override it with "offshore".
const SHIP_OFFSHORE := [5.0, 3.0, 4.5, 6.0, 3.5, 7.0, 5.0, 8.0, 4.0, 6.5, 2.5, 9.0, 5.5, 7.5, 4.0, 8.5, 3.0, 10.0, 6.0, 7.0]

static func offshore(level_id: int) -> float:
    return SHIP_OFFSHORE[(level_id - 1) % SHIP_OFFSHORE.size()]
const CAMERA_PITCH := -12.0                      # degrees; keeps the cannon low and centred
const CAMERA_FOV := 62.0
const ZOOM_OUT_BACK := 7.0
const ZOOM_OUT_UP := 4.5
const AIM_PAN_YAW := 0.9
const AIM_PAN_PITCH := 0.3   # low, so aiming high never tilts the cannon off screen
const YAW_RANGE := 75.0
const PITCH_MIN := -30.0
const PITCH_MAX := 45.0
# Touch coordinates are in the 1179 wide canvas, about three units per point.
const DRAG_FULL_POWER_PX := 640.0
const AIM_DEG_PER_PX := 0.06
const GYRO_GAIN := 1.6        # aim degrees per degree the phone turns
const GYRO_DEADZONE := 0.03
const GYRO_SMOOTH := 6.0
const MIN_FIRE_POWER := 0.05
const RELOAD_TIME := 0.7       # after a shot, seconds until the next one can be loaded
const INTRO_DURATION := 3.4
const TREE_SWAY_CALM := 0.02   # radians of sway on a calm day...
const TREE_SWAY_STORM := 0.09  # ...and added at full storm
const SAIL_IN := 6.0         # metres the ship sails in from the right, bow first...
const SAIL_IN_AFTER := 3.5   # ...still drifting this many seconds after aiming starts, about 1 m/s at most
const INTRO_HOLD := 0.4
const LOADING_DURATION := 1.6
const TARGET_BREAK_IMPULSE := 2.2
const TARGET_GROUND_POP_DISTANCE := 0.45
const TARGET_GRACE := 0.3
const TARGET_FALL_POP := 1.0   # metres below its perch at which a knocked-off figure pops
const TNT_RADIUS := 4.6
const TNT_BLAST_SPEED := 11.0
const TNT_CHAIN_DELAY := 0.14   # seconds between one powder crate and the next it sets off
const FRAGMENT_COUNT := 3
const MAX_FRAGMENTS := 240     # rubble never vanishes; past this, blocks stop splitting and fall whole
const PROJECTILE_LIFETIME := 5.0
const PROJECTILE_MAX_DISTANCE := 32.0
const OUT_OF_AMMO_SETTLE := 2.0
const WIN_LINGER := 3.5         # seconds after the last figure pops before the result panel
const WIN_LINGER_MAX := 6.0     # ...or until the debris stops moving, whichever is later, up to this
const SETTLE_TIMEOUT := 4.0
const ENEMY_BALL_SPEED := 13.0
const ENEMY_HIT_RADIUS := 1.3
const MAX_HULL_HITS := 3
const ENEMY_FIRST_SHOT_DELAY := 2.5
const ENEMY_AIM_ERROR := 0.9
const ENEMY_CANNON_BREAK := 2.5
const SHIP_RAM_DISTANCE := 3.2
const SHIP_SINK_DURATION := 2.2
const THUNDER_MIN := 4.0
const THUNDER_MAX := 10.0

## density, static friction, dynamic friction, bounce, break impulse (m/s of velocity change), or -1 = unbreakable
const MATERIALS := {
    "wood": {"density": 260.0, "friction": 0.6, "bounce": 0.2, "break": 2.6},
    "glass": {"density": 700.0, "friction": 0.3, "bounce": 0.1, "break": 1.0},
    "stone": {"density": 2200.0, "friction": 0.9, "bounce": 0.03, "break": 5.5},
    "metal": {"density": 5000.0, "friction": 0.4, "bounce": 0.3, "break": -1.0},
    "tnt": {"density": 120.0, "friction": 0.6, "bounce": 0.2, "break": 0.8},
}

const AMMO := {
    "iron": {"radius": 0.16, "mass": 26.0, "bounce": 0.15, "speed": 1.0, "name": "Iron ball", "color": Color(0.16, 0.14, 0.22)},
    "stone": {"radius": 0.2, "mass": 40.0, "bounce": 0.05, "speed": 0.85, "name": "Stone ball", "color": Color(0.62, 0.60, 0.62)},
    "wood": {"radius": 0.18, "mass": 9.0, "bounce": 0.6, "speed": 1.25, "name": "Wood ball", "color": Color(0.76, 0.55, 0.34)},
    "tnt": {"radius": 0.17, "mass": 18.0, "bounce": 0.1, "speed": 1.0, "name": "TNT ball", "color": Color(0.98, 0.42, 0.40)},
}
