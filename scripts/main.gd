## Menu, level select, settings, progress, and the level lifecycle.
extends Node

const LEVEL_COUNT := 20
var progress: Dictionary = {"stars": {}, "best": {}}
var settings: Dictionary = {"gyro": true, "trajectory": true, "sound": true}
var _ui: CanvasLayer
var _level: Level
var _hud: Hud
var _current_id := 1
var _auto_fire: PackedStringArray = []
var _loading: LoadingScreen

func _ready() -> void:
    _load_state()
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
        elif arg.begins_with("--menu="):
            # --menu=SECONDS,PATH  screenshot of the menu
            var parts := arg.substr(7).split(",")
            get_tree().create_timer(float(parts[0])).timeout.connect(func():
                get_viewport().get_texture().get_image().save_png(parts[1])
                get_tree().quit())
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

func _save_state() -> void:
    var f := FileAccess.open("user://progress.json", FileAccess.WRITE)
    f.store_string(JSON.stringify(progress))
    var g := FileAccess.open("user://settings.json", FileAccess.WRITE)
    g.store_string(JSON.stringify(settings))

func total_stars() -> int:
    var t := 0
    for k in progress.stars:
        t += int(progress.stars[k])
    return t

func record_result(id: int, won: bool, stars: int, score: int) -> void:
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
    Engine.time_scale = 1.0
    get_tree().paused = false

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
    _ui = CanvasLayer.new()
    _ui.add_child(_background())
    add_child(_ui)
    var v := _column()
    v.add_child(_label("Cannon Duo", 110))
    v.add_child(_label("You are a pirate. Loot the castles.", 36, Color(1, 1, 1, 0.8)))
    v.add_child(_spacer(40))
    v.add_child(_button("Play", _show_levels, true))
    v.add_child(_button("Settings", _show_settings))
    v.add_child(_spacer(40))
    v.add_child(_label("★ %d / %d stars" % [total_stars(), LEVEL_COUNT * 3], 30, Color(1, 1, 1, 0.6)))

const BIOME_NAMES := {"coast": "Green coast", "highlands": "Pine highlands", "badlands": "Red badlands", "opensea": "Open sea"}
const BIOME_COLORS := {"coast": Color(0.36, 0.72, 0.42), "highlands": Color(0.28, 0.62, 0.66), "badlands": Color(0.90, 0.52, 0.30), "opensea": Color(0.32, 0.52, 0.92)}

func _show_levels() -> void:
    _clear()
    _ui = CanvasLayer.new()
    _ui.add_child(_gradient_background())
    add_child(_ui)
    var best_won := 0
    for k in progress.stars:
        best_won = maxi(best_won, int(k))
    var next_id := mini(best_won + 1, LEVEL_COUNT)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right"]:
        margin.add_theme_constant_override("margin_" + side, 56)
    margin.add_theme_constant_override("margin_top", 150)
    margin.add_theme_constant_override("margin_bottom", 90)
    _ui.add_child(margin)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 28)
    margin.add_child(v)

    # Header: title and the star count.
    var head := HBoxContainer.new()
    var title := _label("Choose a castle", 64)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(title)
    var chip := PanelContainer.new()
    chip.add_theme_stylebox_override("panel", _rounded(Color(1, 1, 1, 0.12), 40, 26))
    chip.add_child(_label("★ %d / %d" % [total_stars(), LEVEL_COUNT * 3], 36, Color(1.0, 0.84, 0.36)))
    chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(chip)
    v.add_child(head)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.scroll_deadzone = 24
    v.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 22)
    scroll.add_child(list)
    var current_card: Control = null
    for i in range(1, LEVEL_COUNT + 1):
        var card := _level_card(i, i > best_won + 1, i == next_id)
        list.add_child(card)
        if i == next_id:
            current_card = card
    v.add_child(_button("Back", _show_menu))
    if current_card:
        scroll.ensure_control_visible.call_deferred(current_card)

func _level_card(id: int, locked: bool, current: bool) -> Button:
    var info := _level_info(id)
    var stars := int(progress.stars.get(str(id), 0))
    var biome: String = info.biome
    var accent: Color = BIOME_COLORS.get(biome, Color(0.5, 0.6, 0.9))
    var b := Button.new()
    b.custom_minimum_size = Vector2(0, 200)
    b.disabled = locked
    var bg := Color(1.0, 0.58, 0.18) if current else (Color(1, 1, 1, 0.10) if not locked else Color(1, 1, 1, 0.04))
    var sb := _rounded(bg, 36, 0)
    sb.border_width_left = 14
    sb.border_color = accent if not current else Color(1.0, 0.80, 0.45)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("disabled", sb)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    var sbh: StyleBoxFlat = sb.duplicate()
    sbh.bg_color = bg.lightened(0.12)
    b.add_theme_stylebox_override("hover", sbh)
    b.add_theme_stylebox_override("pressed", sbh)
    b.pressed.connect(func(): start_level(id))

    var row := HBoxContainer.new()
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    row.offset_left = 44
    row.offset_right = -36
    row.add_theme_constant_override("separation", 30)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(row)
    var alpha := 0.35 if locked else 1.0
    # Number badge.
    var badge := PanelContainer.new()
    badge.custom_minimum_size = Vector2(112, 112)
    badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    badge.add_theme_stylebox_override("panel", _rounded(Color(0, 0, 0, 0.22) if not current else Color(1, 1, 1, 0.25), 56, 0))
    var num := _label("🔒" if locked else str(id), 48, Color(1, 1, 1, alpha))
    num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    badge.add_child(num)
    row.add_child(badge)
    # Name and details.
    var text := VBoxContainer.new()
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text.alignment = BoxContainer.ALIGNMENT_CENTER
    text.add_theme_constant_override("separation", 6)
    var name := _label(info.name, 44, Color(1, 1, 1, alpha))
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    text.add_child(name)
    var detail := _label("%s · %s" % [BIOME_NAMES.get(biome, "Coast"), info.sea], 28, Color(1, 1, 1, 0.7 * alpha))
    detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    text.add_child(detail)
    row.add_child(text)
    # Stars, or the play marker on the current castle.
    var right := _label("PLAY ▶" if current and stars == 0 else ("" if locked else "★".repeat(stars) + "☆".repeat(3 - stars)), 40 if not current else 36, Color(1.0, 0.86, 0.40) if not current else Color.WHITE)
    right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row.add_child(right)
    for c in row.find_children("*", "Control", true, false):
        (c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    return b

func _level_info(id: int) -> Dictionary:
    var f := FileAccess.open("res://levels/level%02d.json" % id, FileAccess.READ)
    var d = JSON.parse_string(f.get_as_text()) if f else {}
    if not (d is Dictionary):
        d = {}
    var sea := float(d.get("sea", 0.0))
    return {
        "name": d.get("name", "Castle %d" % id),
        "biome": d.get("terrain", {}).get("biome", "coast"),
        "sea": "Calm sea" if sea < 0.15 else ("Rough sea" if sea < 0.45 else "Storm"),
    }

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
    for entry in [["gyro", "Aim with gyroscope"], ["trajectory", "Trajectory helper"], ["sound", "Sound"]]:
        var cb := CheckButton.new()
        cb.text = entry[1]
        cb.add_theme_font_size_override("font_size", 36)
        cb.button_pressed = bool(settings.get(entry[0], true))
        var key: String = entry[0]
        cb.toggled.connect(func(on): settings[key] = on; _save_state())
        v.add_child(cb)
    v.add_child(_button("Reset progress", func(): progress = {"stars": {}, "best": {}}; _save_state(); _show_menu()))
    v.add_child(_button("Back", _show_menu))

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
    var f := FileAccess.open("res://levels/level%02d.json" % id, FileAccess.READ)
    var d: Dictionary = JSON.parse_string(f.get_as_text())
    var info := _level_info(id)
    var ls := LoadingScreen.new()
    ls.build(id, info.name, d.get("subtitle", ""), BIOME_NAMES.get(info.biome, "Coast"), info.sea)
    return ls

func _build_level(id: int) -> void:
    # Keep the loading screen: detach it from the pre-level layer before clearing.
    var loading := _loading
    if loading and loading.get_parent():
        loading.get_parent().remove_child(loading)
    _loading = null
    _clear()
    _current_id = id
    var path := "res://levels/level%02d.json" % id
    var f := FileAccess.open(path, FileAccess.READ)
    var data = JSON.parse_string(f.get_as_text())
    _level = Level.new()
    add_child(_level)
    _level.build(data, settings)
    if _auto_fire.size() == 3:
        _level.auto_fire = float(_auto_fire[0])
        _level.auto_fire_yaw = float(_auto_fire[1])
        _level.auto_fire_pitch = float(_auto_fire[2])
    _hud = Hud.new()
    add_child(_hud)
    _hud.setup(_level, loading)
    _hud.next_level.connect(func(): if id < LEVEL_COUNT: start_level(id + 1) else: _show_levels())
    _hud.replay.connect(func(): start_level(id))
    _hud.quit.connect(_show_levels)

func _notification(what: int) -> void:
    var away := what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
    if away and _hud and is_instance_valid(_hud):
        _hud.pause_for_background()
