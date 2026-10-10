## Volume control: a "Music" and an "Sfx" audio bus, set from the 0–100 sliders in settings.
## Music players use the Music bus; every other player uses Sfx.
class_name Audio

static func setup() -> void:
    for bus in ["Music", "Sfx"]:
        if AudioServer.get_bus_index(bus) < 0:
            var i := AudioServer.bus_count
            AudioServer.add_bus(i)
            AudioServer.set_bus_name(i, bus)
            AudioServer.set_bus_send(i, &"Master")

## 0 mutes the bus; 100 is the mix as authored.
static func set_volume(bus: String, percent: int) -> void:
    var i := AudioServer.get_bus_index(bus)
    if i < 0:
        return
    var v := clampi(percent, 0, 100)
    AudioServer.set_bus_mute(i, v == 0)
    AudioServer.set_bus_volume_db(i, linear_to_db(v / 100.0) if v > 0 else -80.0)
