## Phone vibration with a character per moment: a light tick while pulling, a thump on the
## shot, a heavy rumble on blasts that grows with the combo.
class_name Haptics

static var enabled := true

static func tick(power: float) -> void:
    _buzz(8 + int(10 * power), 0.25 + 0.35 * power)

static func thump() -> void:
    _buzz(70, 1.0)

static func pop() -> void:
    _buzz(35, 0.6)

static func crack() -> void:
    _buzz(15, 0.35)

## Blast rumble; `combo` 1, 2, 3... makes each link in a chain heavier.
static func rumble(combo: int = 1) -> void:
    _buzz(180 + 90 * mini(combo, 4), minf(0.7 + 0.1 * combo, 1.0))

static func hull() -> void:
    _buzz(400, 1.0)

static func _buzz(ms: int, amplitude: float) -> void:
    if enabled:
        Input.vibrate_handheld(ms, amplitude)
