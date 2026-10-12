## Menu, level select, settings, progress, and the level lifecycle.
extends Node

var LEVEL_COUNT := Campaign.level_count()
var progress: Dictionary = {"stars": {}, "best": {}}
var settings: Dictionary = {"gyro": true, "trajectory": true, "sound": 100, "music": 100, "vibration": true}
const DAILY_ID := 100
var music: Music
var _ui: CanvasLayer
var _level: Level
var _hud: Hud
var _current_id := 1
var _auto_fire: PackedStringArray = []
var _auto_arm := ""
var _loading: LoadingScreen
var _last_won := -1
var _voyage: VoyageLevel

func _ready() -> void:
    _load_state()
    music = Music.new()
    add_child(music)
    Audio.setup()
    Audio.set_volume("Sfx", int(settings.get("sound", 100)))
    music.set_volume(int(settings.get("music", 100)))
    Haptics.enabled = bool(settings.get("vibration", true))
    _preload_assets()
    get_tree().root.content_scale_size = Vector2i(1179, 2556)
    _show_menu()
    # Debug: `godot -- --shot=LEVEL,SECONDS,PATH` starts a level, saves a screenshot, quits.
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--shot="):
            var parts := arg.substr(7).split(",")
            var id := int(parts[0])
            var seconds := float(parts[1])
            var out := parts[2]
            start_level(id)
            get_tree().create_timer(seconds).timeout.connect(func():
                var img := get_viewport().get_texture().get_image()
                img.save_png(out)
                get_tree().quit())
        elif arg.begins_with("--level="):
            start_level(int(arg.substr(8)))
        elif arg.begins_with("--levels="):
            var parts := arg.substr(9).split(",")
            _show_levels()
            get_tree().create_timer(float(parts[0])).timeout.connect(func():
                get_viewport().get_texture().get_image().save_png(parts[1])
                get_tree().quit())
        elif arg == "--upgrades":
            # Debug: every shop upgrade at its top level, some gold.
            var up := {}
            for k in Tuning.SHOP:
                up[k] = (Tuning.SHOP[k].price as Array).size()
            progress["upgrades"] = up
            progress["gold"] = 1234
        elif arg.begins_with("--shop="):
            var parts := arg.substr(7).split(",")
            _show_shop()
            get_tree().create_timer(float(parts[0])).timeout.connect(func():
                get_viewport().get_texture().get_image().save_png(parts[1])
                get_tree().quit())
        elif arg.begins_with("--hullhit="):
            get_tree().create_timer(float(arg.substr(10))).timeout.connect(func():
                if _level:
                    _level._hull_hit())
        elif arg.begins_with("--sink="):
            # --sink=SECONDS  debug: two hits on every enemy ship after SECONDS
            var at := float(arg.substr(7))
            get_tree().create_timer(at).timeout.connect(func():
                if _level:
                    for sh in _level.enemy_ships.duplicate():
                        _level.damage_ship(sh, sh.global_position + Vector3(0, 0.8, 0))
                        _level.damage_ship(sh, sh.global_position + Vector3(0.8, 0.8, 0)))
        elif arg.begins_with("--story="):
            # --story=ID,WHEN,SECONDS,PATH  screenshot of a story scene
            var parts := arg.substr(8).split(",")
            var layer := CanvasLayer.new()
            add_child(layer)
            var card := StoryCard.new()
            layer.add_child(card)
            card.play(Story.beat(int(parts[0]), parts[1]))
            get_tree().create_timer(float(parts[2])).timeout.connect(func():
                get_viewport().get_texture().get_image().save_png(parts[3])
                get_tree().quit())
        elif arg.begins_with("--menu="):
            # --menu=SECONDS,PATH  screenshot of the menu
            var parts := arg.substr(7).split(",")
            get_tree().create_timer(float(parts[0])).timeout.connect(func():
                get_viewport().get_texture().get_image().save_png(parts[1])
                get_tree().quit())
        elif arg.begins_with("--arm="):
            _auto_arm = arg.substr(6)
        elif arg.begins_with("--fire="):
            # --fire=POWER,YAW,PITCH, applied once the level is built
            _auto_fire = arg.substr(7).split(",")
        elif arg.begins_with("--probe="):
            start_level(int(arg.substr(8)))
            get_tree().create_timer(1.0).timeout.connect(func():
                print("cannon mount ", _level.ship.cannon_mount, " cannon world ", _level.cannon_world())
                print("camera ", _level._desired_camera())
                get_tree().quit())

func _load_state() -> void:
    if FileAccess.file_exists("user://progress.json"):
        var f := FileAccess.open("user://progress.json", FileAccess.READ)
        var parsed = JSON.parse_string(f.get_as_text())
        if parsed is Dictionary:
            progress = parsed
    if FileAccess.file_exists("user://settings.json"):
        var f := FileAccess.open("user://settings.json", FileAccess.READ)
        var parsed = JSON.parse_string(f.get_as_text())
        if parsed is Dictionary:
            settings.merge(parsed, true)
    # Sound and music were on/off switches before they became 0–100 sliders.
    for key in ["sound", "music"]:
        if settings.get(key) is bool:
            settings[key] = 100 if settings[key] else 0

func _save_state() -> void:
    var f := FileAccess.open("user://progress.json", FileAccess.WRITE)
    f.store_string(JSON.stringify(progress))
    var g := FileAccess.open("user://settings.json", FileAccess.WRITE)
    g.store_string(JSON.stringify(settings))

func _won_count() -> int:
    var n := 0
    for k in progress.stars:
        if int(k) <= LEVEL_COUNT and int(progress.stars[k]) > 0:
            n += 1
    return n

func total_stars() -> int:
    var t := 0
    for k in progress.stars:
        t += int(progress.stars[k])
    return t

func record_result(id: int, won: bool, stars: int, score: int, gold: int = 0, shots: int = 0) -> void:
    var bonus := 1.0 + 0.15 * int(progress.get("upgrades", {}).get("map", 0))
    progress["gold"] = int(progress.get("gold", 0)) + int(gold * bonus)
    if won:
        _last_won = id
        # Olaf and his brothers join after Windmill Vale: they load faster.
        if id == 16:
            var crew: Array = progress.get("crew", [])
            if not "olaf" in crew:
                crew.append("olaf")
            progress["crew"] = crew
    music.duck(true)
    if id == DAILY_ID:
        _record_daily(won, shots, score)
        _save_state()
        return
    if won:
        var key := str(id)
        progress.stars[key] = maxi(int(progress.stars.get(key, 0)), stars)
        progress.best[key] = maxi(int(progress.best.get(key, 0)), score)
    _save_state()

# MARK: Screens

func _clear() -> void:
    if _ui:
        _ui.queue_free()
        _ui = null
    if _hud:
        _hud.queue_free()
        _hud = null
    if _level:
        _level.queue_free()
        _level = null
    if _voyage:
        _voyage.queue_free()
        _voyage = null
    Engine.time_scale = 1.0
    get_tree().paused = false
    Haptics.muted = false

func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l

func _button(text: String, cb: Callable, accent: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", 40)
    b.custom_minimum_size = Vector2(0, 120)
    b.size_flags_horizontal = Control.SIZE_FILL
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1.0, 0.58, 0.18) if accent else Color(1, 1, 1, 0.14)
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        sb.set(c, 60)
    b.add_theme_stylebox_override("normal", sb)
    var sbh: StyleBoxFlat = sb.duplicate()
    sbh.bg_color = sbh.bg_color.lightened(0.15)
    b.add_theme_stylebox_override("hover", sbh)
    b.add_theme_stylebox_override("pressed", sbh)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

func _background() -> Control:
    return _gradient_background()

## A full screen container with side margins whose children stack vertically, centred.
func _column(top_margin: int = 200) -> VBoxContainer:
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 80)
    margin.add_theme_constant_override("margin_right", 80)
    margin.add_theme_constant_override("margin_top", top_margin)
    margin.add_theme_constant_override("margin_bottom", 160)
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 24)
    margin.add_child(v)
    _ui.add_child(margin)
    return v

func _show_menu() -> void:
    _clear()
    music.play("menu")
    _ui = CanvasLayer.new()
    _ui.add_child(_background())
    add_child(_ui)
    var v := _column()
    v.add_child(_label("Kingdom of Valora", 34, Color(1.0, 0.84, 0.4)))
    v.add_child(_label("Cannon Duo", 110))
    var story := _label("Grimhorn's pirates have taken the Valora Islands.\nOne ship. One cannon. Free them, Captain.", 34, Color(1, 1, 1, 0.8))
    story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    v.add_child(story)
    v.add_child(_spacer(40))
    v.add_child(_button("Play", _show_levels, true))
    v.add_child(_button("Daily castle", _start_daily))
    v.add_child(_button("Cannon workshop", _show_shop))
    v.add_child(_button("Settings", _show_settings))
    v.add_child(_spacer(40))
    v.add_child(_label("%d / %d islands freed    ● %d doubloons" % [_won_count(), LEVEL_COUNT, int(progress.get("gold", 0))], 30, Color(1, 1, 1, 0.6)))

const BIOME_NAMES := {"tropic": "Palm island", "meadow": "Windmill fields", "harbor": "Harbour", "highlands": "Pine highlands",
    "badlands": "Red cliffs", "volcano": "Volcano island", "opensea": "Open sea"}
const BIOME_COLORS := {"coast": Color(0.36, 0.72, 0.42), "highlands": Color(0.28, 0.62, 0.66), "badlands": Color(0.90, 0.52, 0.30), "opensea": Color(0.32, 0.52, 0.92)}

func _show_levels() -> void:
    _clear()
    music.play("menu")
    _ui = CanvasLayer.new()
    add_child(_ui)
    var best_won := 0
    for k in progress.stars:
        best_won = maxi(best_won, int(k))
    var infos: Array = []
    for i in range(1, LEVEL_COUNT + 1):
        infos.append(_level_info(i))
    var map := MapScreen.new()
    map.build(infos, progress.stars, best_won + 1, int(progress.get("gold", 0)), total_stars(), LEVEL_COUNT * 3, _daily_note())
    map.play.connect(play_level)
    map.daily.connect(_start_daily)
    map.shop.connect(_show_shop)
    map.back.connect(_show_menu)
    _ui.add_child(map)

# MARK: Harbour shop

func _show_shop() -> void:
    _clear()
    music.play("menu")
    _ui = CanvasLayer.new()
    _ui.add_child(_background())
    add_child(_ui)
    var upgrades: Dictionary = progress.get("upgrades", {})
    var gold := int(progress.get("gold", 0))
    var stars := total_stars()
    var rank: Array = Tuning.rank(upgrades)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _ui.add_child(scroll)
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 50)
    margin.add_theme_constant_override("margin_top", 130)
    margin.add_theme_constant_override("margin_bottom", 120)
    scroll.add_child(margin)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 22)
    margin.add_child(v)
    v.add_child(_label("Cannon workshop", 70))
    # The cannon itself, in the colour of its rank.
    var preview := CannonPreview.new()
    preview.barrel_color = rank[2]
    preview.custom_minimum_size = Vector2(0, 260)
    v.add_child(preview)
    v.add_child(_label("%s cannon" % rank[1], 50, (rank[2] as Color).lightened(0.2)))
    v.add_child(_label("● %d doubloons      ★ %d stars" % [gold, stars], 40, Color(1.0, 0.84, 0.36)))
    v.add_child(_label("Better parts need more stars. Replay islands for three stars.", 28, Color(1, 1, 1, 0.6)))
    for id in Tuning.SHOP:
        var item: Dictionary = Tuning.SHOP[id]
        var lvl := int(upgrades.get(id, 0))
        var levels: int = (item.price as Array).size()
        var maxed := lvl >= levels
        var price: int = 0 if maxed else int(item.price[lvl])
        var need: int = 0 if maxed else int(item.stars[lvl])
        var locked := stars < need
        var card := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1, 1, 1, 0.08)
        sb.set_corner_radius_all(34)
        sb.content_margin_left = 30
        sb.content_margin_right = 24
        sb.content_margin_top = 22
        sb.content_margin_bottom = 22
        card.add_theme_stylebox_override("panel", sb)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 22)
        var icon := _label(item.icon, 64, Color(1.0, 0.8, 0.4))
        icon.custom_minimum_size = Vector2(90, 0)
        row.add_child(icon)
        var text := VBoxContainer.new()
        text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var name := _label(item.name, 40)
        name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        text.add_child(name)
        var pips := _label("■".repeat(lvl) + "□".repeat(levels - lvl), 30, Color(1.0, 0.72, 0.3))
        pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        text.add_child(pips)
        var desc := _label(item.desc, 26, Color(1, 1, 1, 0.65))
        desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        text.add_child(desc)
        row.add_child(text)
        var label := "Max" if maxed else ("★ %d" % need if locked else "● %d" % price)
        var buy := _button(label, func(): _buy(id), not maxed and not locked and gold >= price)
        buy.custom_minimum_size = Vector2(210, 110)
        buy.size_flags_horizontal = Control.SIZE_SHRINK_END
        buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        buy.disabled = maxed or locked or gold < price
        row.add_child(buy)
        card.add_child(row)
        v.add_child(card)
    v.add_child(_spacer(10))
    v.add_child(_button("Back", _show_levels))

func _buy(id: String) -> void:
    var upgrades: Dictionary = progress.get("upgrades", {})
    var item: Dictionary = Tuning.SHOP[id]
    var lvl := int(upgrades.get(id, 0))
    if lvl >= (item.price as Array).size() or total_stars() < int(item.stars[lvl]):
        return
    var price := int(item.price[lvl])
    if int(progress.get("gold", 0)) < price:
        return
    var before: String = Tuning.rank(upgrades)[1]
    progress["gold"] = int(progress.get("gold", 0)) - price
    upgrades[id] = lvl + 1
    progress["upgrades"] = upgrades
    _save_state()
    Haptics.pop()
    _show_shop()
    var after: String = Tuning.rank(upgrades)[1]
    if after != before:
        # A new rank: Pip has something to say.
        var layer := CanvasLayer.new()
        layer.layer = 30
        add_child(layer)
        var card := StoryCard.new()
        layer.add_child(card)
        card.play([["mate", "A %s cannon, Captain! She shines so bright the gulls are jealous." % after]])
        card.done.connect(layer.queue_free)

# MARK: Daily castle

func _today() -> String:
    var d := Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _daily_note() -> String:
    var daily: Dictionary = progress.get("daily", {})
    var today: Dictionary = daily.get(_today(), {})
    var streak := int(progress.get("daily_streak", 0))
    if today.is_empty():
        return "Today's castle is waiting." + ("   Streak: %d days" % streak if streak > 0 else "")
    return "Today: best %d shots, %d points.   Streak: %d days" % [int(today.shots), int(today.score), streak]

func _daily_data() -> Dictionary:
    var d := Time.get_date_dict_from_system()
    var seed_value: int = int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var biomes := ["tropic", "meadow", "highlands", "badlands"]
    var fort := Fortress.generate(seed_value, "daily")
    return {
        "id": DAILY_ID,
        "name": "Daily Castle",
        "subtitle": "%02d.%02d.%04d" % [d.day, d.month, d.year],
        "hint": "A new pirate fort every day. Fewest shots wins.",
        "projectiles": 6, "par": 3, "stars": {"three": 3, "two": 4},
        "camera": {"lookAt": fort.lookAt, "pitch": fort.pitch},
        "cannon": [0, 0.9, 7.0],
        "offshore": fort.offshore,
        "blocks": fort.blocks, "targets": fort.targets,
        "sea": [0.0, 0.2, 0.35, 0.7][rng.randi_range(0, 3)],
        "ammo": [], "enemyCannons": fort.enemyCannons, "enemyShips": [],
        "terrain": {"biome": biomes[rng.randi_range(0, 3)], "elevation": 0.0,
            "shore": fort.shore, "beach": fort.beach,
            "sky": ["noon", "sunset", "night", "overcast"][rng.randi_range(0, 3)]},
    }

func _start_daily() -> void:
    start_level(DAILY_ID)

func _record_daily(won: bool, shots: int, score: int) -> void:
    if not won:
        return
    var daily: Dictionary = progress.get("daily", {})
    var today := _today()
    var prev: Dictionary = daily.get(today, {})
    if prev.is_empty():
        # First win today: the streak grows if yesterday was won too.
        var y := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
        var yesterday := "%04d-%02d-%02d" % [y.year, y.month, y.day]
        progress["daily_streak"] = int(progress.get("daily_streak", 0)) + 1 if daily.has(yesterday) else 1
        daily[today] = {"shots": shots, "score": score}
    else:
        daily[today] = {"shots": mini(int(prev.shots), shots), "score": maxi(int(prev.score), score)}
    progress["daily"] = daily

func _level_info(id: int) -> Dictionary:
    var d: Dictionary = _level_data(id)
    var sea := float(d.get("sea", 0.0))
    return {
        "name": d.get("name", "Castle %d" % id),
        "biome": d.get("terrain", {}).get("biome", "tropic"),
        "sea": "Calm sea" if sea < 0.15 else ("Rough sea" if sea < 0.45 else "Storm"),
        "boss": bool(d.get("boss", false)),
    }

## A level's data: the JSON, the daily castle, or a boss fortress every fifth level.
func _level_data(id: int) -> Dictionary:
    if id == DAILY_ID:
        return _daily_data()
    var f := FileAccess.open("res://levels/level%02d.json" % Campaign.file_id(id), FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text()) if f else {}
    if not (d is Dictionary):
        return {}
    return Campaign.level(id, d)

func _rounded(color: Color, radius: int, pad: int) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = color
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        sb.set(c, radius)
    sb.content_margin_left = pad
    sb.content_margin_right = pad
    sb.content_margin_top = pad / 2.0
    sb.content_margin_bottom = pad / 2.0
    return sb

## Dusk sky: deep indigo at the top fading to warm purple, like the game's horizon.
func _gradient_background() -> TextureRect:
    var g := Gradient.new()
    g.set_color(0, Color(0.10, 0.09, 0.22))
    g.set_color(1, Color(0.36, 0.22, 0.38))
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.fill_from = Vector2(0, 0)
    gt.fill_to = Vector2(0, 1)
    var tr := TextureRect.new()
    tr.texture = gt
    tr.stretch_mode = TextureRect.STRETCH_SCALE
    tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    return tr

func _spacer(h: int) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c

func _show_settings() -> void:
    _clear()
    _ui = CanvasLayer.new()
    _ui.add_child(_background())
    add_child(_ui)
    var v := _column()
    v.add_child(_label("Settings", 70))
    add_settings_rows(v)
    v.add_child(_button("Reset progress", func(): progress = {"stars": {}, "best": {}, "gold": 0}; _save_state(); _show_menu()))
    v.add_child(_button("Back", func(): _save_state(); _show_menu()))

## The settings rows, shared by the settings screen and the pause menu. Every change is
## saved and applied at once, including to a level in progress.
func add_settings_rows(v: Control) -> void:
    for entry in [["gyro", "Aim with gyroscope"], ["trajectory", "Trajectory helper"], ["sound", "Sound effects"], ["music", "Music"], ["vibration", "Vibration"]]:
        var key: String = entry[0]
        if key == "sound" or key == "music":
            v.add_child(_volume_row(entry[1], key))
            continue
        var cb := CheckButton.new()
        cb.text = entry[1]
        cb.add_theme_font_size_override("font_size", 36)
        cb.button_pressed = bool(settings.get(key, true))
        cb.toggled.connect(func(on):
            settings[key] = on
            _save_state()
            if key == "vibration":
                Haptics.enabled = on
            elif _level and is_instance_valid(_level):
                if key == "gyro":
                    _level.set_gyro(on)
                else:
                    _level.settings[key] = on
            elif _voyage and is_instance_valid(_voyage):
                if key == "gyro":
                    _voyage.set_gyro(on)
                else:
                    _voyage.settings[key] = on)
        v.add_child(cb)

## A settings row with a 0–100 slider: the name, the bar, the value. Volume follows the
## slider as it moves; the file is written when the drag ends (and on Back).
func _volume_row(text: String, key: String) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 24)
    var name := _label(text, 36)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    name.custom_minimum_size = Vector2(290, 0)
    row.add_child(name)
    var value := _label(str(int(settings.get(key, 100))), 36, Color(1, 1, 1, 0.7))
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value.custom_minimum_size = Vector2(80, 0)
    var s := HSlider.new()
    s.min_value = 0
    s.max_value = 100
    s.step = 1
    s.value = int(settings.get(key, 100))
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    s.custom_minimum_size = Vector2(0, 72)
    s.focus_mode = Control.FOCUS_NONE
    var track := StyleBoxFlat.new()
    track.bg_color = Color(1, 1, 1, 0.14)
    track.content_margin_top = 10
    track.content_margin_bottom = 10
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        track.set(c, 10)
    s.add_theme_stylebox_override("slider", track)
    var fill: StyleBoxFlat = track.duplicate()
    fill.bg_color = Color(1.0, 0.58, 0.18)
    s.add_theme_stylebox_override("grabber_area", fill)
    s.add_theme_stylebox_override("grabber_area_highlight", fill)
    var knob := _circle_texture(56)
    s.add_theme_icon_override("grabber", knob)
    s.add_theme_icon_override("grabber_highlight", knob)
    s.add_theme_icon_override("grabber_disabled", knob)
    s.value_changed.connect(func(val):
        var percent := int(val)
        settings[key] = percent
        value.text = str(percent)
        if key == "music":
            music.set_volume(percent)
        else:
            Audio.set_volume("Sfx", percent)
            if _level and is_instance_valid(_level):
                _level.settings[key] = percent
                if _level.ambience:
                    _level.ambience.enabled = percent > 0)
    s.drag_ended.connect(func(_changed): _save_state())
    row.add_child(s)
    row.add_child(value)
    return row

func _circle_texture(size: int) -> ImageTexture:
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var r := size / 2.0
    for y in size:
        for x in size:
            var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r))
            img.set_pixel(x, y, Color(1, 1, 1, clampf(r - d, 0.0, 1.0)))
    return ImageTexture.create_from_image(img)

## Heavy scenes every level uses, loaded on background threads while the menu is up.
const PRELOAD := [
    "res://assets/hq/dutch_ship/dutch_ship_medium_1k.gltf",
    "res://assets/hq/cannon/cannon_01_1k.gltf",
    "res://assets/hq/great_mountain/scene.gltf",
    "res://assets/hq/clouds/scene.gltf",
    "res://assets/foliage/pine.res",
    "res://assets/foliage/oak_small.res",
    "res://assets/foliage/oak_medium.res",
    "res://assets/foliage/oak_large.res",
    "res://assets/foliage/maple.res",
]

func _preload_assets() -> void:
    for path in PRELOAD:
        ResourceLoader.load_threaded_request(path)

var _starting := false

## Starts a level, first playing its "before" scene if the player has not seen it.
func play_level(id: int) -> void:
    _with_story(id, "before", func(): start_level(id))

## Plays a story scene once (remembered in progress), then calls `then`.
func _with_story(id: int, when: String, then: Callable) -> void:
    var key := "%d_%s" % [id, when]
    var lines := Story.beat(id, when)
    var seen: Array = progress.get("seen", [])
    if lines.is_empty() or key in seen or id >= DAILY_ID:
        then.call()
        return
    seen.append(key)
    progress["seen"] = seen
    _save_state()
    var layer := CanvasLayer.new()
    layer.layer = 30
    add_child(layer)
    var card := StoryCard.new()
    layer.add_child(card)
    card.play(lines, Story.is_eavesdrop(id, when))
    card.done.connect(func():
        layer.queue_free()
        then.call())

## After a level: the "after" scene if it was won, then `then`.
func _after_level(id: int, then: Callable) -> void:
    if _last_won == id:
        _with_story(id, "after", then)
    else:
        then.call()

func start_level(id: int) -> void:
    if _starting:
        return
    _starting = true
    _clear()
    _current_id = id
    # Show the loading screen at once; building the level takes a moment on the first run.
    # The same screen stays up (the HUD takes it over) until the fly-in starts.
    _ui = CanvasLayer.new()
    _ui.layer = 20
    _loading = _make_loading(id)
    _ui.add_child(_loading)
    add_child(_ui)
    _loading.progress = 0.15
    await get_tree().process_frame
    await get_tree().process_frame
    _starting = false
    _build_level(id)

func _make_loading(id: int) -> LoadingScreen:
    var d: Dictionary = _level_data(id)
    var info := _level_info(id)
    var ls := LoadingScreen.new()
    ls.build(id, info.name, d.get("subtitle", ""), BIOME_NAMES.get(info.biome, "Island"), info.sea, d.get("hint", ""))
    return ls

func _build_level(id: int) -> void:
    # Keep the loading screen: detach it from the pre-level layer before clearing.
    var loading := _loading
    if loading and loading.get_parent():
        loading.get_parent().remove_child(loading)
    _loading = null
    _clear()
    _current_id = id
    var data := _level_data(id)
    # A voyage at the helm (Set Sail, Wave Rider): its own gameplay, HUD and result panel.
    if data.has("mode"):
        _voyage = VoyageLevel.new()
        add_child(_voyage)
        _voyage.build(data, settings)
        music.play("level")
        _voyage.next_level.connect(func(): _after_level(id, func(): play_level(id + 1) if id < LEVEL_COUNT else _show_levels()))
        _voyage.replay.connect(func(): start_level(id))
        _voyage.quit.connect(func(): _after_level(id, _show_levels))
        _voyage.paused.connect(func(on): music.duck(on))
        if loading:
            var lay := CanvasLayer.new()
            lay.layer = 20
            add_child(lay)
            lay.add_child(loading)
            var tw := create_tween()
            tw.tween_interval(0.7)
            tw.tween_property(loading, "modulate:a", 0.0, 0.4)
            tw.tween_callback(lay.queue_free)
        return
    var level_settings := settings.duplicate()
    var ups: Dictionary = progress.get("upgrades", {}).duplicate()
    if "olaf" in progress.get("crew", []):
        ups["loader"] = int(ups.get("loader", 0)) + 1
    level_settings["upgrades"] = ups
    _level = Level.new()
    add_child(_level)
    _level.build(data, level_settings)
    music.play("boss" if bool(data.get("boss", false)) else "level")
    if _auto_arm != "":
        _level.arm_special(_auto_arm)
    if _auto_fire.size() == 3:
        _level.auto_fire = float(_auto_fire[0])
        _level.auto_fire_yaw = float(_auto_fire[1])
        _level.auto_fire_pitch = float(_auto_fire[2])
    _hud = Hud.new()
    add_child(_hud)
    _hud.setup(_level, loading)
    # Next island (the daily castle and the last island return to the chart); scenes play
    # between.
    _hud.next_level.connect(func(): _after_level(id, func(): play_level(id + 1) if id < LEVEL_COUNT else _show_levels()))
    _hud.paused.connect(func(on): music.duck(on))
    _hud.replay.connect(func(): start_level(id))
    _hud.quit.connect(func(): _after_level(id, _show_levels))

func _notification(what: int) -> void:
    var away := what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
    if away and _hud and is_instance_valid(_hud):
        _hud.pause_for_background()
    if away and _voyage and is_instance_valid(_voyage):
        _voyage.pause_for_background()
