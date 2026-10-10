## Phone vibration with a character per moment: a light tick while pulling, a thump on the
## shot, a heavy rumble on blasts that grows with the combo.
class_name Haptics

static var enabled := true
## Off while a result panel or menu is up.
static var muted := false
static var _busy_until := 0.0

static func tick(power: float) -> void:
    _buzz(8 + int(10 * power), 0.25 + 0.35 * power)

## A short click, like a gear tooth, while the cannon is turned.
static func detent() -> void:
    _buzz(12, 0.55)

static func thump() -> void:
    _buzz(70, 1.0)

static func pop() -> void:
    _buzz(35, 0.6)

static func crack() -> void:
    _buzz(15, 0.35)

## Blast rumble; `combo` 1, 2, 3... makes each link in a chain heavier.
static func rumble(combo: int = 1) -> void:
    _buzz(180 + 90 * mini(combo, 4), minf(0.7 + 0.1 * combo, 1.0))

## A magazine going up in a stone fort: the longest, heaviest buzz, twice more as the stones
## come down. Real seconds, so slow motion does not stretch the gaps.
static func blast_rumble() -> void:
    _buzz(350, 1.0)
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return
    for delay in [0.45, 0.9]:
        tree.create_timer(delay, true, false, true).timeout.connect(func(): _buzz(300, 1.0))

static func hull() -> void:
    _buzz(400, 1.0)

## One buzz at a time: a collapse breaks hundreds of pieces, and queuing a buzz for each kept
## the phone vibrating long after (into the result panel). New buzzes wait for the last one.
static func _buzz(ms: int, amplitude: float) -> void:
    if not enabled or muted:
        return
    var now := Time.get_ticks_msec() / 1000.0
    if now < _busy_until:
        return
    var d := mini(ms, 350)
    _busy_until = now + d / 1000.0 + 0.06
    Input.vibrate_handheld(d, amplitude)
