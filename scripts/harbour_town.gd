## The harbour town at the end of the sail levels: a cobbled waterfront with a terrace of
## narrow houses facing the water, a second row up behind, a church with its tower, a
## warehouse by the quay, lanterns, bollards, moored boats and the clutter of a working
## port. Every piece is a box or a drum batched into one mesh per material, so the whole
## town is a dozen draws. At night the windows and lanterns are lit.
class_name HarbourTown

var parent: Node3D
var rng := RandomNumberGenerator.new()
var night := false
var _batches: Dictionary = {}   # Material -> SurfaceTool

# Materials, made once per town.
var plaster: Array = []
var stone: Material
var brick: Material
var timber: Material
var trim: Material
var roofs: Array = []
var glass: Material
var glass_lit: Material
var shutters: Array = []
var cobbles: Material
var iron: Material
var lamp: Material

static func build(where: Node3D, zq: float, at_night: bool) -> void:
    var t := HarbourTown.new()
    t.parent = where
    t.night = at_night
    t.rng.seed = 11
    t._materials()
    t._ground(zq)
    t._houses(zq)
    t._church(Vector3(24.0, 1.2, zq - 36.0))
    t._warehouse(Vector3(-34.0, 1.2, zq - 16.0))
    t._waterfront(zq)
    t._flush()

func _materials() -> void:
    for c: Color in [Color(0.93, 0.89, 0.8), Color(0.88, 0.74, 0.5), Color(0.9, 0.78, 0.72), Color(0.78, 0.82, 0.84), Color(0.96, 0.95, 0.92), Color(0.8, 0.84, 0.7), Color(0.85, 0.62, 0.5)]:
        plaster.append(Models.flat_material(c, 0.95))
    stone = Models.tex_material("large_sandstone_blocks", 0.5, Color(0.9, 0.88, 0.84))
    brick = Models.tex_material("castle_brick_07", 0.7, Color(1.15, 1.05, 0.95))
    timber = Models.tex_material("brown_planks_07", 0.8, Color(0.55, 0.42, 0.3))
    trim = Models.flat_material(Color(0.92, 0.88, 0.8), 0.9)
    for c: Color in [Color(0.95, 0.72, 0.62), Color(0.5, 0.5, 0.55), Color(0.72, 0.56, 0.46)]:
        roofs.append(Models.tex_material("clay_roof_tiles_02", 1.0, c))
    glass = Models.flat_material(Color(0.1, 0.13, 0.18), 0.25, 0.3)
    glass_lit = Models.flat_material(Color(1.0, 0.85, 0.55), 0.6)
    (glass_lit as StandardMaterial3D).emission_enabled = true
    (glass_lit as StandardMaterial3D).emission = Color(1.0, 0.75, 0.4)
    (glass_lit as StandardMaterial3D).emission_energy_multiplier = 1.8
    for c: Color in [Color(0.3, 0.45, 0.35), Color(0.3, 0.4, 0.55), Color(0.5, 0.28, 0.2), Color(0.85, 0.85, 0.8)]:
        shutters.append(Models.flat_material(c, 0.9))
    cobbles = Models.tex_material("cobblestone_floor_01", 0.5, Color(0.85, 0.85, 0.85))
    iron = Models.flat_material(Color(0.12, 0.12, 0.13), 0.6, 0.4)
    lamp = glass_lit if night else Models.flat_material(Color(0.9, 0.88, 0.8), 0.5)

# MARK: Batched geometry

func _st(mat: Material) -> SurfaceTool:
    if not _batches.has(mat):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        _batches[mat] = st
    return _batches[mat]

## A box of `size` centred at `at`, turned `yaw` about the vertical.
func _box(at: Vector3, size: Vector3, mat: Material, yaw: float = 0.0) -> void:
    var st := _st(mat)
    var b := Basis(Vector3.UP, yaw)
    var h := size * 0.5
    for face: Array in [
        [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
        [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
        [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
        [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
        [Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
        [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
    ]:
        var n: Vector3 = face[0]
        var u: Vector3 = face[1]
        var v: Vector3 = face[2]
        var c := n * h
        var du := u * h
        var dv := v * h
        var p0 := at + b * (c - du - dv)
        var p1 := at + b * (c + du - dv)
        var p2 := at + b * (c + du + dv)
        var p3 := at + b * (c - du + dv)
        st.set_normal(b * n)
        for p: Vector3 in [p0, p1, p2, p0, p2, p3]:
            st.add_vertex(p)

## A drum of `sides` standing on `base`, `r0` at the foot and `r1` at the top.
func _drum(base: Vector3, r0: float, r1: float, height: float, mat: Material, sides: int = 10) -> void:
    var st := _st(mat)
    var top := base + Vector3(0, height, 0)
    for i in sides:
        var a0 := TAU * float(i) / sides
        var a1 := TAU * float(i + 1) / sides
        var d0 := Vector3(cos(a0), 0, sin(a0))
        var d1 := Vector3(cos(a1), 0, sin(a1))
        var n := (d0 + d1).normalized()
        st.set_normal(n)
        for p: Vector3 in [base + d0 * r0, top + d0 * r1, top + d1 * r1, base + d0 * r0, top + d1 * r1, base + d1 * r0]:
            st.add_vertex(p)
        if r1 > 0.01:
            st.set_normal(Vector3.UP)
            for p: Vector3 in [top, top + d1 * r1, top + d0 * r1]:
                st.add_vertex(p)

## A gable roof over a footprint `w` (along the ridge) by `d`, its eaves at `y`, `rise`
## high, turned `yaw`: two tiled slopes and two boarded gable ends.
func _roof(at: Vector3, w: float, d: float, rise: float, mat: Material, yaw: float = 0.0) -> void:
    var st := _st(mat)
    var b := Basis(Vector3.UP, yaw)
    var hw := w * 0.5
    var hd := d * 0.5
    var ridge0 := at + b * Vector3(-hw, rise, 0)
    var ridge1 := at + b * Vector3(hw, rise, 0)
    for s: float in [-1.0, 1.0]:
        var e0 := at + b * Vector3(-hw, 0, s * hd)
        var e1 := at + b * Vector3(hw, 0, s * hd)
        var n := (b * Vector3(0, hd, s * rise)).normalized()
        st.set_normal(n)
        var tris: Array = [e0, e1, ridge1, e0, ridge1, ridge0] if s > 0 else [e1, e0, ridge0, e1, ridge0, ridge1]
        for p: Vector3 in tris:
            st.add_vertex(p)
        # The underside of the eaves, so the overhang is not see-through.
        st.set_normal(-n)
        var under: Array = [e1, e0, ridge0, e1, ridge0, ridge1] if s > 0 else [e0, e1, ridge1, e0, ridge1, ridge0]
        for p: Vector3 in under:
            st.add_vertex(p)
    var ends := _st(trim)
    for s: float in [-1.0, 1.0]:
        var g0 := at + b * Vector3(s * hw, 0, -hd)
        var g1 := at + b * Vector3(s * hw, 0, hd)
        var gt := at + b * Vector3(s * hw, rise, 0)
        ends.set_normal(b * Vector3(s, 0, 0))
        var tri: Array = [g0, gt, g1] if s > 0 else [g1, gt, g0]
        for p: Vector3 in tri:
            ends.add_vertex(p)

func _flush() -> void:
    for mat: Material in _batches:
        var st: SurfaceTool = _batches[mat]
        var mi := MeshInstance3D.new()
        mi.mesh = st.commit()
        mi.material_override = mat
        parent.add_child(mi)
    _batches.clear()

# MARK: The town

## The cobbled ground the town stands on, level with the quay, and the sand beyond.
func _ground(zq: float) -> void:
    _box(Vector3(0, 0.7, zq - 25.0), Vector3(118.0, 1.0, 32.0), cobbles)
    # A kerb of stone along the back of the quay's street
    _box(Vector3(0, 1.22, zq - 9.3), Vector3(118.0, 0.1, 0.6), stone)

## Two rows of houses: a close terrace along the waterfront street and a looser row
## behind it, each house its own width, height, colour and roof.
func _houses(zq: float) -> void:
    for row in 2:
        var x := -56.0 + rng.randf_range(0.0, 4.0)
        var z := zq - (19.0 if row == 0 else 31.0)
        while x < 54.0:
            var w := rng.randf_range(4.5, 7.5)
            var d := rng.randf_range(5.0, 7.0)
            var storeys := 2 if rng.randf() < (0.75 if row == 0 else 0.45) else 1
            var h := storeys * rng.randf_range(2.7, 3.1)
            var cx := x + w * 0.5
            var cz := z - rng.randf_range(0.0, 2.5 if row == 0 else 6.0)
            # Keep the street open behind the berth, and off the church and the warehouse.
            var blocked := absf(cx) < 6.5 and row == 0
            blocked = blocked or (row == 1 and cx > 14.0 and cx < 36.0)
            blocked = blocked or (row == 0 and cx < -24.0 and cx > -44.0)
            if not blocked:
                _house(Vector3(cx, 1.2, cz), w, h, d, storeys)
            x += w + rng.randf_range(0.6 if row == 0 else 2.5, 2.2 if row == 0 else 7.0)

## One house: a stone plinth, plastered walls with a timber band between storeys, framed
## windows with sills and shutters, a doorway with its step, a tiled roof with a chimney
## and, on some, a dormer.
func _house(at: Vector3, w: float, h: float, d: float, storeys: int) -> void:
    var wall: Material = plaster[rng.randi_range(0, plaster.size() - 1)]
    if rng.randf() < 0.18:
        wall = brick if rng.randf() < 0.5 else stone
    var gable_front := rng.randf() < 0.3   # ridge running back from the street
    _box(at + Vector3(0, 0.25, 0), Vector3(w + 0.3, 0.5, d + 0.3), stone)
    _box(at + Vector3(0, 0.5 + h * 0.5, 0), Vector3(w, h, d), wall)
    var storey_h := h / storeys
    if storeys == 2:
        _box(at + Vector3(0, 0.5 + storey_h, 0), Vector3(w + 0.16, 0.16, d + 0.16), timber)
    # Roof
    var roof: Material = roofs[rng.randi_range(0, roofs.size() - 1)]
    var eaves := at + Vector3(0, 0.5 + h, 0)
    var rise := (d if not gable_front else w) * 0.42
    if gable_front:
        _roof(eaves, d + 0.7, w + 0.9, rise, roof, PI / 2.0)
    else:
        _roof(eaves, w + 0.9, d + 0.7, rise, roof)
    # Chimney, a brick stack through the roof near the ridge, with a cap
    var chx := (rng.randf_range(-0.3, 0.3) * w) if not gable_front else 0.0
    var chz := 0.0 if not gable_front else rng.randf_range(-0.3, 0.3) * d
    var ch_top := 0.5 + h + rise + 0.7
    _box(at + Vector3(chx, (ch_top + 0.5 + h * 0.8) * 0.5, chz), Vector3(0.7, ch_top - (0.5 + h * 0.8), 0.7), brick)
    _box(at + Vector3(chx, ch_top + 0.05, chz), Vector3(0.9, 0.1, 0.9), iron)
    # Dormer on the street slope of some two-storey houses
    if storeys == 2 and not gable_front and rng.randf() < 0.45:
        var dx := rng.randf_range(-0.25, 0.25) * w
        var dz := d * 0.5 - 0.9
        var dy := 0.5 + h + 0.7
        _box(at + Vector3(dx, dy, dz), Vector3(1.3, 1.3, 1.6), wall)
        _roof(at + Vector3(dx, dy + 0.65, dz), 1.5, 1.9, 0.55, roof)
        _window(at + Vector3(dx, dy + 0.05, dz + 0.8), Vector3(0, 0, 1), 0.7, 0.8, false)
    # Openings on the street face
    var front := at + Vector3(0, 0, d * 0.5)
    var n := maxi(1, int(w / 2.0))
    var door_i := rng.randi_range(0, n - 1)
    var shut := rng.randf() < 0.6
    var shutter: Material = shutters[rng.randi_range(0, shutters.size() - 1)]
    for s in storeys:
        for i in n:
            var wx := (float(i) + 0.5) / n * w - w * 0.5
            var wy := 0.5 + s * storey_h + storey_h * 0.55
            if s == 0 and i == door_i:
                _door(front + Vector3(wx, 0.5, 0), Vector3(0, 0, 1))
                continue
            _window(front + Vector3(wx, wy, 0), Vector3(0, 0, 1), 0.9, 1.15, shut, shutter)
    # One window a storey on each end wall
    for sx: float in [-1.0, 1.0]:
        for s in storeys:
            var wy := 0.5 + s * storey_h + storey_h * 0.55
            _window(at + Vector3(sx * w * 0.5, wy, rng.randf_range(-0.2, 0.2) * d), Vector3(sx, 0, 0), 0.8, 1.05, shut, shutter)

## A window set in a wall at `p` facing `n`: frame, sill, glass with a cross of glazing
## bars, and shutters either side if `shut`.
func _window(p: Vector3, n: Vector3, w: float, h: float, shut: bool, shutter: Material = null) -> void:
    var yaw := atan2(n.x, n.z)
    _box(p + n * 0.03, Vector3(w + 0.2, h + 0.2, 0.1), trim, yaw)
    var lit := night and rng.randf() < 0.7
    _box(p + n * 0.07, Vector3(w, h, 0.06), glass_lit if lit else glass, yaw)
    _box(p + n * 0.1, Vector3(0.06, h, 0.04), trim, yaw)
    _box(p + n * 0.1, Vector3(w, 0.06, 0.04), trim, yaw)
    _box(p + n * 0.12 + Vector3(0, -h * 0.5 - 0.1, 0), Vector3(w + 0.3, 0.1, 0.3), stone, yaw)
    if shut and shutter:
        var t := Vector3(n.z, 0, -n.x)
        for s: float in [-1.0, 1.0]:
            _box(p + n * 0.05 + t * s * (w * 0.5 + 0.1 + 0.19), Vector3(0.36, h + 0.1, 0.05), shutter, yaw)

## A doorway at `p` (its foot) facing `n`: frame, a planked door, a lintel and a step.
func _door(p: Vector3, n: Vector3) -> void:
    var yaw := atan2(n.x, n.z)
    _box(p + n * 0.03 + Vector3(0, 1.1, 0), Vector3(1.3, 2.3, 0.12), trim, yaw)
    _box(p + n * 0.06 + Vector3(0, 1.05, 0), Vector3(1.0, 2.1, 0.08), timber, yaw)
    _box(p + n * 0.1 + Vector3(0, 2.3, 0), Vector3(1.5, 0.14, 0.2), stone, yaw)
    _box(p + n * 0.3 + Vector3(0, 0.08, 0), Vector3(1.6, 0.16, 0.7), stone, yaw)
    if rng.randf() < 0.5:
        var t := Vector3(n.z, 0, -n.x)
        _lantern(p + n * 0.15 + t * 0.95 + Vector3(0, 2.0, 0), yaw)

## A hanging lantern: an iron bracket and a small lit box.
func _lantern(p: Vector3, yaw: float) -> void:
    _box(p + Vector3(0, 0.25, 0), Vector3(0.06, 0.5, 0.06), iron, yaw)
    _box(p, Vector3(0.28, 0.34, 0.28), lamp, yaw)
    _box(p + Vector3(0, 0.2, 0), Vector3(0.36, 0.06, 0.36), iron, yaw)

## The church: a tall hall with arched-looking windows and a square tower with a spire.
func _church(at: Vector3) -> void:
    var wall: Material = plaster[4]
    _box(at + Vector3(0, 0.3, 0), Vector3(12.6, 0.6, 8.6), stone)
    _box(at + Vector3(0, 0.6 + 3.5, 0), Vector3(12.0, 7.0, 8.0), wall)
    _roof(at + Vector3(0, 7.6, 0), 12.8, 8.8, 4.0, roofs[1])
    var front := at + Vector3(0, 0, 4.0)
    for i in 4:
        var wx := -4.2 + 2.8 * float(i)
        _window(front + Vector3(wx, 4.2, 0), Vector3(0, 0, 1), 0.9, 2.6, false)
    _door(front + Vector3(0, 0.6, 0), Vector3(0, 0, 1))
    _box(front + Vector3(0, 0.6 + 1.6, 0.08), Vector3(1.8, 3.2, 0.1), trim)
    _box(front + Vector3(0, 0.6 + 1.5, 0.12), Vector3(1.5, 2.9, 0.1), timber)
    # The tower, at the hall's seaward corner
    var tx := at + Vector3(8.0, 0, 1.0)
    _box(tx + Vector3(0, 0.3, 0), Vector3(5.0, 0.6, 5.0), stone)
    _box(tx + Vector3(0, 0.6 + 8.0, 0), Vector3(4.4, 16.0, 4.4), wall)
    _box(tx + Vector3(0, 16.7, 0), Vector3(4.9, 0.3, 4.9), stone)
    for s: float in [-1.0, 1.0]:
        _window(tx + Vector3(s * 2.2, 14.2, 0), Vector3(s, 0, 0), 0.8, 1.8, false)
    _window(tx + Vector3(0, 14.2, 2.2), Vector3(0, 0, 1), 0.8, 1.8, false)
    _window(tx + Vector3(0, 9.0, 2.2), Vector3(0, 0, 1), 0.6, 1.2, false)
    _drum(tx + Vector3(0, 16.85, 0), 3.0, 0.0, 6.5, roofs[1], 4)
    _box(tx + Vector3(0, 23.6, 0), Vector3(0.08, 1.0, 0.08), iron)
    _box(tx + Vector3(0, 23.8, 0), Vector3(0.5, 0.08, 0.08), iron)

## The warehouse by the quay's end: long, low and stone, with wide timber doors and a
## hoist beam under the roof.
func _warehouse(at: Vector3) -> void:
    var w := 18.0
    var h := 5.0
    var d := 9.0
    _box(at + Vector3(0, 0.25, 0), Vector3(w + 0.3, 0.5, d + 0.3), stone)
    _box(at + Vector3(0, 0.5 + h * 0.5, 0), Vector3(w, h, d), stone)
    _roof(at + Vector3(0, 0.5 + h, 0), w + 0.9, d + 0.8, 3.2, roofs[2])
    var front := at + Vector3(0, 0, d * 0.5)
    for dx: float in [-5.0, 5.0]:
        _box(front + Vector3(dx, 0.5 + 1.6, 0.04), Vector3(3.6, 3.2, 0.1), trim)
        _box(front + Vector3(dx, 0.5 + 1.55, 0.08), Vector3(3.3, 3.0, 0.08), timber)
        _box(front + Vector3(dx, 0.5 + 1.55, 0.14), Vector3(0.06, 3.0, 0.04), iron)
    _window(front + Vector3(0, 0.5 + 3.9, 0), Vector3(0, 0, 1), 1.2, 0.9, false)
    _box(front + Vector3(0, 0.5 + h - 0.3, 0.9), Vector3(0.3, 0.3, 2.2), timber)
    _box(front + Vector3(0, 0.5 + h - 1.4, 1.8), Vector3(0.06, 2.2, 0.06), iron)
    _lantern(front + Vector3(-8.2, 3.2, 0.2), 0.0)

## The waterfront: bollards and a kerb along the quay's edge, lamp posts along its back,
## crates and barrels, and fishing boats moored at the quay.
func _waterfront(zq: float) -> void:
    var x := -24.0
    while x < 26.0:
        if x < -11.0 or x > -1.0:    # clear of the bridge's landing
            _drum(Vector3(x, 1.2, zq - 0.9), 0.26, 0.22, 0.7, iron, 8)
            _drum(Vector3(x, 1.9, zq - 0.9), 0.3, 0.24, 0.12, iron, 8)
        x += 7.0
    for lx: float in [-22.0, -9.0, 9.0, 22.0]:
        var base := Vector3(lx, 1.2, zq - 8.8)
        _drum(base, 0.16, 0.11, 3.4, iron, 8)
        _box(base + Vector3(0, 3.65, 0), Vector3(0.36, 0.5, 0.36), lamp)
        _box(base + Vector3(0, 3.95, 0), Vector3(0.5, 0.08, 0.5), iron)
    for i in 10:
        var prop := Models.prop("wooden_crate_01" if i % 3 != 1 else "wine_barrel_01")
        prop.scale = Vector3.ONE * rng.randf_range(1.1, 1.6)
        prop.position = Vector3(-24.0 + rng.randf_range(0.0, 10.0) if i < 5 else rng.randf_range(8.0, 24.0), 1.25, zq - 3.0 + rng.randf_range(-2.5, 2.5))
        prop.rotation.y = rng.randf_range(0.0, TAU)
        parent.add_child(prop)
    for bx: float in [18.0, -20.0]:
        var boat := Models.prop("pinnace")
        var k := 7.0 / 33.2
        boat.scale = Vector3(k, k, k)
        boat.position = Vector3(bx, -10.3 * k * 0.28, zq + 3.2)
        boat.rotation.y = rng.randf_range(-0.12, 0.12)
        parent.add_child(boat)
