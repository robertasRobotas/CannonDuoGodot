## Silent Harbour: a night raid. The guns and gunmen are asleep. Hit with every ball and
## they stay that way; the first miss rings the alarm bell and the harbour wakes.
class_name ScnRaid
extends Scenario

var quiet := true
var _said := false
var _bell: AudioStream

func setup(lv: Level) -> void:
    super.setup(lv)
    _bell = _make_bell()
    level.event.connect(func(name: String, _d: Dictionary):
        if name == "win_start" and quiet:
            level.bonus += 1500
            banner("SILENT AS THE GRAVE", "+1500"))

func guns_silent() -> bool:
    return quiet

func tick(_delta: float) -> void:
    if not _said and playing():
        _said = true
        banner("QUIET NOW", "A miss rings the alarm bell")

func on_shot_settled(nothing: bool) -> void:
    if quiet and nothing:
        _alarm()

func _alarm() -> void:
    quiet = false
    banner("ALARM!", "The whole harbour is awake")
    Haptics.rumble(2)
    Atmosphere.torches(level, 6)
    for n in level.get_tree().get_nodes_in_group("enemies"):
        var e := n as Enemy
        if e.armed:
            e.next_fire = randf_range(1.0, 3.5)
    for i in 3:
        level.get_tree().create_timer(i * 0.9).timeout.connect(func():
            if is_instance_valid(level):
                var p := AudioStreamPlayer.new()
                p.stream = _bell
                p.bus = &"Sfx"
                p.volume_db = -4.0
                p.pitch_scale = randf_range(0.95, 1.05)
                level.add_child(p)
                p.play()
                p.finished.connect(p.queue_free))

## A struck bell, synthesised: a few inharmonic partials dying away.
static func _make_bell() -> AudioStreamWAV:
    var rate := 22050
    var secs := 1.6
    var n := int(rate * secs)
    var data := PackedByteArray()
    data.resize(n * 2)
    var partials := [[640.0, 1.0, 2.2], [1210.0, 0.55, 3.0], [1780.0, 0.35, 4.0], [2520.0, 0.18, 5.0]]
    for i in n:
        var t := float(i) / rate
        var v := 0.0
        for p: Array in partials:
            v += float(p[1]) * sin(TAU * float(p[0]) * t) * exp(-t * float(p[2]))
        v *= 0.4 * minf(t * 400.0, 1.0)
        var s := int(clampf(v, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, s)
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = rate
    wav.stereo = false
    wav.data = data
    return wav
