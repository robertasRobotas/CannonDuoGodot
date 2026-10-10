## All game sound. Looping beds (waves always, rain or storm by weather, the ship creaking)
## and one-shots: cannon by power, powder blasts, wood cracking, thunder after lightning.
## Clips are cut from the recordings in games assets (see assets/audio).
class_name Ambience
extends Node

const DIR := "res://assets/audio/"
## At most this many cracks at once, and not closer together than CRACK_GAP seconds, so a
## collapsing fort sounds like splintering, not a wall of noise.
const MAX_CRACKS := 4
const CRACK_GAP := 0.07

var enabled := true
var _thunder: Array[AudioStream] = []
var _cracks: Array[AudioStream] = []
var _cannon: Array[AudioStream] = []
var _blast: AudioStream
var _pops: Array[AudioStream] = []
var _boing: AudioStream
var _coins: Array[AudioStream] = []
var _splashes: Array[AudioStream] = []
var _cracks_playing := 0
var _last_crack := -1.0

func setup(storminess: float, sound_on: bool) -> void:
    enabled = sound_on
    if not enabled:
        return
    _bed("waves_loop.wav", -8.0 if storminess < 0.6 else -12.0)
    _bed("creak_loop.wav", -16.0)
    if storminess >= 0.6:
        _bed("storm_loop.wav", -2.0)
        _bed("wind_loop.wav", -14.0)
    elif storminess >= 0.4:
        _bed("rain_loop.wav", -6.0)
    elif storminess >= 0.15:
        _bed("wind_loop.wav", -12.0)
    _thunder = [load(DIR + "thunder1.mp3"), load(DIR + "thunder2.mp3")]
    _cracks = [load(DIR + "wood1.mp3"), load(DIR + "wood2.mp3")]
    _cannon = [load(DIR + "cannon_weak.mp3"), load(DIR + "cannon.mp3"), load(DIR + "cannon_strong.mp3")]
    _blast = load(DIR + "blast.mp3")
    _pops = [load(DIR + "pop1.mp3"), load(DIR + "pop2.mp3")]
    _boing = load(DIR + "boing.mp3")
    _coins = [load(DIR + "coins1.mp3"), load(DIR + "coins2.mp3"), load(DIR + "coins3.mp3")]
    _splashes = [load(DIR + "splash1.mp3"), load(DIR + "splash2.mp3")]

func _bed(file: String, volume: float) -> void:
    var p := AudioStreamPlayer.new()
    p.stream = load(DIR + file)
    p.bus = &"Sfx"
    p.volume_db = -40.0
    add_child(p)
    # Start somewhere in the loop so layers never line up the same way twice.
    p.play(randf_range(0.0, maxf(p.stream.get_length() - 1.0, 0.0)))
    create_tween().tween_property(p, "volume_db", volume, 1.5)

func _one_shot(stream: AudioStream, volume: float, pitch: float = 1.0, done: Callable = Callable()) -> void:
    if not enabled or stream == null:
        return
    var p := AudioStreamPlayer.new()
    p.stream = stream
    p.bus = &"Sfx"
    p.volume_db = volume
    p.pitch_scale = pitch
    add_child(p)
    p.play()
    p.finished.connect(func():
        if done.is_valid():
            done.call()
        p.queue_free())

func cannon(power: float) -> void:
    if _cannon.is_empty():
        return
    var i := 0 if power < 0.35 else (1 if power < 0.75 else 2)
    _one_shot(_cannon[i], 0.0, randf_range(0.95, 1.05))

func blast() -> void:
    _one_shot(_blast, 2.0, randf_range(0.9, 1.05))

## A guard pops: a plop and a boing as it flies off.
func pop() -> void:
    if _pops.is_empty():
        return
    _one_shot(_pops[randi() % _pops.size()], 0.0, randf_range(0.9, 1.15))
    _one_shot(_boing, -6.0, randf_range(0.95, 1.25))

## Coins land a moment after the pop.
func coins() -> void:
    if _coins.is_empty():
        return
    get_tree().create_timer(0.35).timeout.connect(func():
        _one_shot(_coins[randi() % _coins.size()], -4.0, randf_range(0.95, 1.1)))

func splash() -> void:
    if _splashes.is_empty():
        return
    _one_shot(_splashes[randi() % _splashes.size()], -3.0, randf_range(0.85, 1.1))

func crack() -> void:
    if _cracks.is_empty() or _cracks_playing >= MAX_CRACKS:
        return
    var now := Time.get_ticks_msec() / 1000.0
    if now - _last_crack < CRACK_GAP:
        return
    _last_crack = now
    _cracks_playing += 1
    _one_shot(_cracks[randi() % _cracks.size()], randf_range(-6.0, -1.0), randf_range(0.85, 1.2), func(): _cracks_playing -= 1)

func thunder(delay: float) -> void:
    if _thunder.is_empty():
        return
    get_tree().create_timer(delay).timeout.connect(func():
        _one_shot(_thunder[randi() % _thunder.size()], randf_range(-4.0, 0.0), randf_range(0.9, 1.08)))
