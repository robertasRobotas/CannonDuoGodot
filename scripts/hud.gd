## In game overlay, built in code: top card, hearts, ammo row, power bar, loading cover,
## intro card, the single hint, results.
class_name Hud
extends CanvasLayer

signal next_level
signal replay
signal quit
signal paused(on: bool)

var level: Level
var _title: Label
var _ammo: HBoxContainer
var _ammo_shown := -1
var _stats: Label
var _hearts: Label
var _duel_fill: ColorRect
var _duel_label: Label
var _power_fill: ColorRect
var _power_label: Label
var _hint: Label
var _cover: Control
var _intro: Control
var _intro_title: Label
var _result: Control
var _flash: ColorRect
var _pop: Label
var _load_hint: Control
var _tutorial: TutorialHint
var _last_yaw := 0.0
var _last_pitch := 0.0
var _knob: Control
var _track_fill: ColorRect
var _last_interaction := 0.0
var _gyro_btn: Button
var _pause_menu: Control
var _pause_panel: Control
var _pause_settings: Control
var _banner: Label
var _banner_sub: Label
var _bars: Array[ColorRect] = []
var _specials: HBoxContainer
var _gold: Label
var _loading: LoadingScreen

const FONT_SIZE := 30

func setup(lv: Level, loading: LoadingScreen = null) -> void:
    level = lv
    level.event.connect(_on_event)
    layer = 10
    _loading = loading
    _build()

func _label(text: String, size: int, color: Color = Color.WHITE, bold: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
    l.add_theme_constant_override("outline_size", 4 if bold else 0)
    return l

func _panel(radius: int = 24, alpha: float = 0.42) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.10, 0.14, alpha)
    sb.corner_radius_top_left = radius
    sb.corner_radius_top_right = radius
    sb.corner_radius_bottom_left = radius
    sb.corner_radius_bottom_right = radius
    sb.content_margin_left = 24
    sb.content_margin_right = 24
    sb.content_margin_top = 16
    sb.content_margin_bottom = 16
    return sb

func _build() -> void:
    _flash = ColorRect.new()
    _flash.color = Color(1, 1, 1, 0)
    _flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_flash)

    var top := PanelContainer.new()
    top.add_theme_stylebox_override("panel", _panel())
    top.position = Vector2(40, 130)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    _title = _label(level.data.name if int(level.data.id) >= 100 else "%d. %s" % [int(level.data.id), level.data.name], 40, Color.WHITE, true)
    col.add_child(_title)
    _ammo = HBoxContainer.new()
    _ammo.add_theme_constant_override("separation", 10)
    col.add_child(_ammo)
    _stats = _label("", FONT_SIZE)
    col.add_child(_stats)
    _gold = _label("", FONT_SIZE, Color(1.0, 0.84, 0.36))
    col.add_child(_gold)
    if level.scenario and "progress" in level.scenario:
        # A duel: how far gone the enemy ship is, 0 to 100 percent.
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 14)
        var track := Control.new()
        track.custom_minimum_size = Vector2(420, 22)
        var bg := ColorRect.new()
        bg.color = Color(1, 1, 1, 0.18)
        bg.size = Vector2(420, 22)
        track.add_child(bg)
        _duel_fill = ColorRect.new()
        _duel_fill.color = Color(0.95, 0.35, 0.25)
        _duel_fill.size = Vector2(0, 22)
        track.add_child(_duel_fill)
        row.add_child(track)
        _duel_label = _label("0%", FONT_SIZE)
        row.add_child(_duel_label)
        col.add_child(row)
    top.add_child(col)
    add_child(top)

    # Letterbox bars for the action camera.
    for i in 2:
        var bar := ColorRect.new()
        bar.color = Color(0, 0, 0, 0.92)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
        bar.custom_minimum_size = Vector2(0, 0)
        bar.size.y = 0
        add_child(bar)
        _bars.append(bar)

    # Big centre banner: combos, multi pops, near misses.
    _banner = _label("", 120, Color(1.0, 0.86, 0.3), true)
    _banner.add_theme_constant_override("outline_size", 14)
    _banner.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02, 0.9))
    _banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _banner.position = Vector2(0, 620)
    _banner.size = Vector2(1179, 170)
    _banner.pivot_offset = Vector2(1179 / 2.0, 85)
    _banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _banner.visible = false
    add_child(_banner)
    _banner_sub = _label("", 46, Color.WHITE, true)
    _banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _banner_sub.position = Vector2(0, 790)
    _banner_sub.size = Vector2(1179, 70)
    _banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _banner_sub.visible = false
    add_child(_banner_sub)

    # Special balls from the harbour shop: tap to load one for the next shot.
    _specials = HBoxContainer.new()
    _specials.add_theme_constant_override("separation", 16)
    _specials.position = Vector2(40, 2556 - 120 - 130)
    add_child(_specials)
    _build_specials()

    add_child(_icon_button("II", 130, _toggle_pause))
    _gyro_btn = _icon_button("GYRO", 260, func():
        level.set_gyro(not level.gyro_enabled)
        _refresh_gyro()
        if _tutorial:
            _tutorial.set_touch_mode(not level.gyro_enabled))
    _gyro_btn.add_theme_font_size_override("font_size", 24)
    add_child(_gyro_btn)
    add_child(_icon_button("⌖", 390, level.recenter))
    _refresh_gyro()

    # Power bar, bottom right.
    var bar_bg := PanelContainer.new()
    bar_bg.add_theme_stylebox_override("panel", _panel(20))
    bar_bg.position = Vector2(1179 - 40 - 150, 2556 - 120 - 520)
    bar_bg.custom_minimum_size = Vector2(150, 520)
    bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bar_col := VBoxContainer.new()
    _power_label = _label("0%", 30)
    _power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bar_col.add_child(_power_label)
    var track := Control.new()
    track.custom_minimum_size = Vector2(100, 420)
    var track_bg := ColorRect.new()
    track_bg.color = Color(1, 1, 1, 0.15)
    track_bg.position = Vector2(30, 0)
    track_bg.size = Vector2(40, 420)
    track.add_child(track_bg)
    _power_fill = ColorRect.new()
    _power_fill.color = Color(1.0, 0.58, 0.18)
    _power_fill.position = Vector2(30, 416)
    _power_fill.size = Vector2(40, 4)
    track.add_child(_power_fill)
    bar_col.add_child(track)
    bar_bg.add_child(bar_col)
    add_child(bar_bg)

    _hint = _label("", 32)
    _hint.position = Vector2(40, 2556 - 120 - 560)
    _hint.size = Vector2(880, 120)
    _hint.autowrap_mode = TextServer.AUTOWRAP_WORD
    add_child(_hint)

    # The single control hint: a knob that glides down a track on the right.
    _load_hint = Control.new()
    _load_hint.position = Vector2(1179 - 40 - 150 - 120, 2556 - 120 - 520 + 60)
    _load_hint.visible = false
    _load_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var track2 := ColorRect.new()
    track2.color = Color(1, 1, 1, 0.18)
    track2.size = Vector2(14, 380)
    _load_hint.add_child(track2)
    _track_fill = ColorRect.new()
    _track_fill.color = Color(1, 1, 1, 0.6)
    _track_fill.size = Vector2(14, 20)
    _load_hint.add_child(_track_fill)
    _knob = ColorRect.new()
    _knob.color = Color.WHITE
    _knob.size = Vector2(56, 56)
    _knob.position = Vector2(-21, -10)
    _load_hint.add_child(_knob)
    add_child(_load_hint)
    if int(level.data.id) == 1:
        _tutorial = TutorialHint.new()
        _tutorial.touch_mode = not level.gyro_enabled
        add_child(_tutorial)

    _pop = _label("", 90, Color(1.0, 0.85, 0.2), true)
    _pop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _pop.visible = false
    add_child(_pop)

    # Loading cover.
    if _loading == null:
        _loading = LoadingScreen.new()
        _loading.build(int(level.data.id), level.data.name, level.data.get("subtitle", ""), "", level.sea_description())
    _cover = _loading
    add_child(_cover)

    # Intro card.
    _intro = Control.new()
    _intro.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var ip := PanelContainer.new()
    ip.add_theme_stylebox_override("panel", _panel(28, 0.6))
    ip.position = Vector2(200, 1750)
    ip.custom_minimum_size = Vector2(779, 260)
    var iv := VBoxContainer.new()
    iv.alignment = BoxContainer.ALIGNMENT_CENTER
    var i1 := _label("Level %d" % int(level.data.id), 30, Color(1, 1, 1, 0.6))
    i1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _intro_title = _label(level.data.name, 70, Color.WHITE, true)
    _intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var i3 := _label("%s · %s" % [level.data.get("subtitle", ""), level.sea_description()], 30, Color(1, 1, 1, 0.75))
    i3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    iv.add_child(i1)
    iv.add_child(_intro_title)
    iv.add_child(i3)
    ip.add_child(iv)
    _intro.add_child(ip)
    _intro.visible = false
    add_child(_intro)

    _result = Control.new()
    _result.set_anchors_preset(Control.PRESET_FULL_RECT)
    _result.visible = false
    add_child(_result)

    _pause_menu = Control.new()
    _pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    _pause_menu.visible = false
    _pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _pause_menu.add_child(dim)
    var pm := PanelContainer.new()
    pm.add_theme_stylebox_override("panel", _panel(28, 0.85))
    pm.position = Vector2(240, 1000)
    pm.custom_minimum_size = Vector2(700, 400)
    var pv := VBoxContainer.new()
    pv.add_theme_constant_override("separation", 20)
    var pt := _label("Paused", 60, Color.WHITE, true)
    pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pv.add_child(pt)
    pv.add_child(_button("Resume", _toggle_pause, true))
    pv.add_child(_button("Restart", func(): _toggle_pause(); replay.emit()))
    pv.add_child(_button("Settings", func(): pm.visible = false; _pause_settings.visible = true))
    pv.add_child(_button("Quit level", func(): _toggle_pause(); quit.emit()))
    pm.add_child(pv)
    _pause_menu.add_child(pm)
    _pause_panel = pm
    # Settings behind the pause menu: the same rows as the settings screen, built by Main.
    var sm := PanelContainer.new()
    sm.add_theme_stylebox_override("panel", _panel(28, 0.85))
    sm.position = Vector2(100, 800)
    sm.custom_minimum_size = Vector2(979, 0)
    sm.visible = false
    var sv := VBoxContainer.new()
    sv.add_theme_constant_override("separation", 20)
    var st := _label("Settings", 60, Color.WHITE, true)
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sv.add_child(st)
    var main := level.get_parent()
    if main and main.has_method("add_settings_rows"):
        main.add_settings_rows(sv)
    sv.add_child(_button("Back", func(): sm.visible = false; pm.visible = true; _refresh_gyro(), true))
    sm.add_child(sv)
    _pause_menu.add_child(sm)
    _pause_settings = sm
    add_child(_pause_menu)
    _refresh()

func _button(text: String, cb: Callable, accent: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", 38)
    b.custom_minimum_size = Vector2(0, 110)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(1.0, 0.58, 0.18) if accent else Color(1, 1, 1, 0.14)
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        sb.set(c, 55)
    b.add_theme_stylebox_override("normal", sb)
    var sbh: StyleBoxFlat = sb.duplicate()
    sbh.bg_color = sbh.bg_color.lightened(0.15)
    b.add_theme_stylebox_override("hover", sbh)
    b.add_theme_stylebox_override("pressed", sbh)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

func _icon_button(text: String, y: float, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", 34)
    b.position = Vector2(1179 - 40 - 110, y)
    b.custom_minimum_size = Vector2(110, 110)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.12, 0.10, 0.14, 0.5)
    for c in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
        sb.set(c, 55)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_color_override("font_color", Color.WHITE)
    b.pressed.connect(cb)
    return b

func _refresh_gyro() -> void:
    _gyro_btn.text = "📱" if level.gyro_enabled else "☝"
    _gyro_btn.add_theme_font_size_override("font_size", 44)
    _gyro_btn.visible = level.gyro_available

## The app went to the background: pause behind the menu so Resume is one tap away.
func pause_for_background() -> void:
    if level.phase == Level.Phase.FINISHED or level.is_paused:
        return
    level.set_paused(true)
    _show_pause_menu(true)
    paused.emit(true)

func _toggle_pause() -> void:
    if level.phase == Level.Phase.FINISHED:
        return
    var p := not level.is_paused
    level.set_paused(p)
    _show_pause_menu(p)
    paused.emit(p)

## Opens the pause menu on its first page, so settings never stay up across a resume.
func _show_pause_menu(on: bool) -> void:
    _pause_menu.visible = on
    _pause_panel.visible = true
    _pause_settings.visible = false

func _process(delta: float) -> void:
    _refresh()
    _cover.visible = level.phase == Level.Phase.LOADING
    if _cover.visible:
        _loading.progress = 0.3 + 0.7 * clampf(level.time / Tuning.LOADING_DURATION, 0.0, 1.0)
    _intro.visible = level.phase == Level.Phase.INTRO
    if _flash.color.a > 0.0:
        # Real time, not game time: slow motion must not hold the flash on screen.
        var real := delta / maxf(Engine.time_scale, 0.05)
        _flash.color.a = maxf(0.0, _flash.color.a - real * 2.5)
    _load_hint.visible = false
    # Wordless tutorial on level 1, until the first shot.
    if _tutorial:
        var aiming := level.phase == Level.Phase.AIMING
        _tutorial.allowed = aiming
        if aiming or level.shots_used > 0:
            _tutorial.observe(level.aim_yaw - _last_yaw + level.aim_pitch - _last_pitch, level.power, level.shots_used > 0)
    _last_yaw = level.aim_yaw
    _last_pitch = level.aim_pitch

func _refresh() -> void:
    var parts: Array[String] = []
    parts.append(level.sea_description())
    if not level.data.get("enemyCannons", []).is_empty() or not level.data.get("enemyShips", []).is_empty() or level.data.has("orcas"):
        var hearts := ""
        for i in level.max_hull:
            hearts += "♥" if i < level.max_hull - level.hull_hits else "♡"
        parts.append(hearts)
    if not level.data.targets.is_empty():
        parts.append("☠ %d" % level.targets_remaining)
    if not level.data.get("enemyShips", []).is_empty():
        parts.append("⛵ %d" % level.ships_remaining)
    parts.append("◎ %d/%d" % [level.shots_used, int(level.data.par)])
    _stats.text = "   ".join(parts)
    _gold.text = "● %d doubloons" % level.coins if level.coins > 0 else ""
    if level.shots_used != _ammo_shown:
        _ammo_shown = level.shots_used
        _build_ammo()
    _power_label.text = "%d%%" % int(level.power * 100)
    if _duel_fill and level.scenario:
        var k: float = float(level.scenario.get("progress"))
        _duel_fill.size.x = 420.0 * k
        _duel_label.text = "%d%%" % int(round(k * 100.0))
    _power_fill.size.y = maxf(4, 416 * level.power)
    _power_fill.position.y = 420 - _power_fill.size.y
    var hint := ""
    if level.shots_used == 0 and level.phase == Level.Phase.AIMING:
        hint = str(level.data.get("hint", ""))
    _hint.text = "" if _tutorial else hint

## Cannonballs left: round balls with a highlight, the next one larger, spent ones faded.
func _build_ammo() -> void:
    for c in _ammo.get_children():
        c.queue_free()
    var n := int(level.data.projectiles)
    for i in n:
        var color: Color = Tuning.AMMO[level.ammo_for(i)].color
        var sz := 36 if i == level.shots_used else 28
        var ball := Panel.new()
        ball.custom_minimum_size = Vector2(sz, sz)
        ball.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var sb := StyleBoxFlat.new()
        sb.bg_color = color
        sb.set_corner_radius_all(sz / 2)
        sb.border_color = color.lightened(0.45)
        sb.set_border_width_all(2)
        sb.anti_aliasing = true
        ball.add_theme_stylebox_override("panel", sb)
        # Shine.
        var shine := Panel.new()
        var ss := StyleBoxFlat.new()
        ss.bg_color = Color(1, 1, 1, 0.55)
        ss.set_corner_radius_all(sz / 8)
        shine.add_theme_stylebox_override("panel", ss)
        shine.position = Vector2(sz * 0.24, sz * 0.2)
        shine.size = Vector2(sz * 0.26, sz * 0.22)
        ball.add_child(shine)
        ball.modulate.a = 0.25 if i < level.shots_used else 1.0
        _ammo.add_child(ball)
    if level.shots_used < n:
        _ammo.add_child(_label(Tuning.AMMO[level.next_ammo()].name, 28))

func _build_specials() -> void:
    for c in _specials.get_children():
        c.queue_free()
    level.ui_blocks.clear()
    var x := 40.0
    for kind in ["chain", "fire", "shell"]:
        var left := int(level.specials.get(kind, 0))
        if left <= 0:
            continue
        var armed: bool = level.armed_special == kind
        var b := Button.new()
        b.text = "%s ×%d" % [Tuning.AMMO[kind].name, left]
        b.add_theme_font_size_override("font_size", 30)
        b.custom_minimum_size = Vector2(230, 100)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1.0, 0.58, 0.18) if armed else Color(0.12, 0.10, 0.14, 0.62)
        sb.set_corner_radius_all(50)
        sb.border_color = (Tuning.AMMO[kind].color as Color).lightened(0.3)
        sb.set_border_width_all(4)
        b.add_theme_stylebox_override("normal", sb)
        b.add_theme_stylebox_override("hover", sb)
        b.add_theme_stylebox_override("pressed", sb)
        b.add_theme_color_override("font_color", Color.WHITE)
        var k: String = kind
        b.pressed.connect(func(): level.arm_special(k))
        _specials.add_child(b)
        level.ui_blocks.append(Rect2(Vector2(x, _specials.position.y), Vector2(230, 100)))
        x += 246.0

## Shows a big banner that punches in and fades, unscaled by slow motion.
func _show_banner(text: String, sub: String, color: Color) -> void:
    _banner.text = text
    _banner.add_theme_color_override("font_color", color)
    _banner.visible = true
    _banner.modulate.a = 1.0
    _banner.scale = Vector2(0.3, 0.3)
    _banner_sub.text = sub
    _banner_sub.visible = sub != ""
    _banner_sub.modulate.a = 1.0
    var tw := create_tween()
    tw.set_ignore_time_scale(true)
    tw.tween_property(_banner, "scale", Vector2(1.15, 1.15), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tw.tween_property(_banner, "scale", Vector2.ONE, 0.1)
    tw.tween_interval(0.9)
    tw.tween_property(_banner, "modulate:a", 0.0, 0.35)
    tw.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.35)
    tw.tween_callback(func(): _banner.visible = false; _banner_sub.visible = false)

func _letterbox(on: bool) -> void:
    for i in _bars.size():
        var bar := _bars[i]
        var tw := create_tween()
        tw.set_ignore_time_scale(true)
        var h := 190.0 if on else 0.0
        tw.tween_property(bar, "size:y", h, 0.25)
        if i == 1:
            tw.parallel().tween_property(bar, "position:y", get_viewport().get_visible_rect().size.y - h, 0.25)

func _on_event(name: String, d: Dictionary) -> void:
    match name:
        "combo":
            var n := int(d.count)
            var words := ["", "", "CHAIN ×2!", "CHAIN ×3!", "MEGA CHAIN ×4!", "UNSTOPPABLE ×5!"]
            _show_banner(words[mini(n, 5)] if n <= 5 else "LEGENDARY ×%d!" % n, "+%d" % int(d.points), Color(1.0, 0.86 - 0.08 * mini(n, 5), 0.3))
        "multi":
            var n := int(d.count)
            _show_banner(["", "", "DOUBLE!", "TRIPLE!"][n] if n <= 3 else "MULTI ×%d!" % n, "", Color(0.6, 0.95, 1.0))
        "banner":
            if str(d.text) != "":
                _show_banner(str(d.text), str(d.get("sub", "")), Color(0.8, 0.95, 1.0))
        "near_miss":
            _show_banner("So close!", "", Color(1, 1, 1))
        "freed":
            if bool(d.deserter):
                _show_banner("He surrenders!", "+500", Color(0.85, 0.95, 1.0))
            else:
                _show_banner("Freed!", "+500", Color(0.6, 1.0, 0.6))
        "touch_aim_tried":
            if _tutorial:
                _tutorial.nudge()
        "cine":
            _letterbox(bool(d.on))
        "ammo":
            _build_specials()
            _ammo_shown = -1
        "power":
            if float(d.power) > 0.02:
                _last_interaction = level.time
        "fired":
            _last_interaction = level.time
            _build_specials()
        "hull":
            # Red flash at the edges when our ship is hit.
            _flash.color = Color(0.8, 0.05, 0.02, 0.45)
            var tw := create_tween()
            tw.set_ignore_time_scale(true)
            tw.tween_property(_flash, "color:a", 0.0, 0.6)
            tw.tween_callback(func(): _flash.color = Color(1, 1, 1, 0))
        "blast":
            # A light blink on the first blast only; a chain must stay clearly visible.
            if level.combo <= 1:
                _flash.color.a = maxf(_flash.color.a, 0.12)
        "thunder":
            _flash.color.a = maxf(_flash.color.a, 0.25)
        "target":
            _pop.text = "+1000"
            _pop.visible = true
            _pop.modulate.a = 1.0
            _pop.scale = Vector2(0.4, 0.4)
            var tw := create_tween()
            tw.tween_property(_pop, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT)
            tw.tween_interval(0.6)
            tw.tween_property(_pop, "modulate:a", 0.0, 0.3)
            tw.tween_callback(func(): _pop.visible = false)
        "finished":
            if bool(d.won) and int(level.data.id) == 1:
                # The first battle ends in the fog with the game's title.
                var card := TitleCard.new()
                add_child(card)
                card.done.connect(func():
                    _show_result(true, int(d.shots), int(d.remaining))
                    var tw := card.create_tween()
                    tw.tween_property(card, "modulate:a", 0.0, 0.8)
                    tw.tween_callback(card.queue_free))
            else:
                _show_result(bool(d.won), int(d.shots), int(d.remaining))

func _show_result(did_win: bool, shots: int, remaining: int) -> void:
    for c in _result.get_children():
        c.queue_free()
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.45)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _result.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var pm := PanelContainer.new()
    pm.add_theme_stylebox_override("panel", _panel(36, 0.92))
    pm.custom_minimum_size = Vector2(880, 0)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 22)
    var par := int(level.data.par)
    var stars := 0
    if did_win:
        stars = 3 if shots <= par else (2 if shots <= par + 1 else 1)
    var head := _label("Island freed!" if did_win else ("Hull breached" if level.hull_hits >= level.max_hull else "Out of cannonballs"), 54, Color.WHITE, true)
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(head)
    var sub := _label(level.data.name, 32, Color(1, 1, 1, 0.6))
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sub)
    # Three big stars that pop in one after another.
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 30)
    for i in 3:
        var star := _label("★", 140, Color(1.0, 0.85, 0.2) if i < stars else Color(1, 1, 1, 0.18), true)
        star.pivot_offset = Vector2(70, 90)
        star.scale = Vector2(0.2, 0.2) if i < stars else Vector2.ONE
        row.add_child(star)
        if i < stars:
            var tw := create_tween()
            tw.tween_interval(0.25 + 0.3 * i)
            tw.tween_property(star, "scale", Vector2(1.25, 1.25), 0.22).set_ease(Tween.EASE_OUT)
            tw.tween_property(star, "scale", Vector2.ONE, 0.12)
    v.add_child(row)
    var score: int = (level.data.targets.size() - level.targets_remaining) * 1000 + remaining * 250 + level.blocks_broken * 15 + level.bonus
    var sc := _label("Score %d   ·   %d shots, par %d" % [score, shots, par], 30, Color(1, 1, 1, 0.75))
    sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(sc)
    # Loot: coins picked up plus a bonus per star.
    var gold := level.coins + (stars * 20 if did_win else 0)
    var loot := "● +%d doubloons" % gold
    if level.best_combo >= 2:
        loot += "   ·   best chain ×%d" % level.best_combo
    var lt := _label(loot, 38, Color(1.0, 0.84, 0.36), true)
    lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(lt)
    if level.captives_freed > 0:
        var fr := _label("%d islander%s freed" % [level.captives_freed, "" if level.captives_freed == 1 else "s"], 32, Color(0.7, 1.0, 0.7))
        fr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(fr)
    # Pip has a word after a win (unless a story scene follows).
    if did_win and Story.beat(int(level.data.id), "after").is_empty() and int(level.data.id) < 100:
        var pip_row := HBoxContainer.new()
        pip_row.add_theme_constant_override("separation", 18)
        var pip := Portrait.new("mate", 120.0)
        pip_row.add_child(pip)
        var joke := _label(Story.joke(int(level.data.id)), 28, Color(1, 1, 1, 0.85))
        joke.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        joke.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        joke.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        pip_row.add_child(joke)
        v.add_child(pip_row)
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 10)
    v.add_child(gap)
    if did_win:
        v.add_child(_button("Next castle", func(): next_level.emit(), true))
    v.add_child(_button("Replay", func(): replay.emit(), did_win == false))
    v.add_child(_button("Castles", func(): quit.emit()))
    pm.add_child(v)
    center.add_child(pm)
    _result.add_child(center)
    _result.visible = true
    _load_hint.visible = false
    level.get_parent().call_deferred("record_result", int(level.data.id), did_win, stars, score, gold, shots)
