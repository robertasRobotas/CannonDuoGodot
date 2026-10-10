## Background music that lives across screens and crossfades between tracks: a calm shanty
## on the menus, "Pirates!" in levels, war drums on boss castles.
class_name Music
extends Node

const TRACKS := {
    "menu": "res://assets/audio/music/menu.mp3",
    "level": "res://assets/audio/music/level.mp3",
    "boss": "res://assets/audio/music/boss_drums.wav",
}
const VOLUME := {"menu": -10.0, "level": -15.0, "boss": -8.0}
const FADE := 1.2

var enabled := true
var _current := ""
var _player: AudioStreamPlayer

func play(track: String) -> void:
    if track == _current:
        duck(false)
        return
    _current = track
    var old := _player
    if old:
        var out := create_tween()
        out.tween_property(old, "volume_db", -60.0, FADE)
        out.tween_callback(old.queue_free)
    _player = null
    if not enabled or not TRACKS.has(track):
        return
    var p := AudioStreamPlayer.new()
    p.stream = load(TRACKS[track])
    p.bus = &"Music"
    p.volume_db = -60.0
    add_child(p)
    p.play()
    create_tween().tween_property(p, "volume_db", VOLUME[track], FADE)
    _player = p

## Quieter under the result panel or pause menu.
func duck(on: bool) -> void:
    if _player:
        create_tween().tween_property(_player, "volume_db", VOLUME.get(_current, -12.0) - (8.0 if on else 0.0), 0.4)

## Slider volume, 0–100; at 0 the track stops instead of playing silently.
func set_volume(percent: int) -> void:
    Audio.set_volume("Music", percent)
    var on := percent > 0
    if on != enabled:
        set_enabled(on)

func set_enabled(on: bool) -> void:
    enabled = on
    var track := _current
    _current = ""
    if on:
        play(track)
    elif _player:
        _player.queue_free()
        _player = null
