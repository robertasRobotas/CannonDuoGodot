## Loads Kenney GLB scenes and fits them into target sizes.
class_name Models

static var _cache: Dictionary = {}

static func load_scene(path: String) -> PackedScene:
    if _cache.has(path):
        return _cache[path]
    # Picks up a background load started at launch, or loads now.
    var scene: PackedScene
    if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
        scene = ResourceLoader.load_threaded_get(path)
    else:
        scene = load(path)
    _cache[path] = scene
    return scene

static func instance(path: String) -> Node3D:
    var scene := load_scene(path)
    if scene == null:
        push_warning("Missing model " + path)
        return Node3D.new()
    return scene.instantiate() as Node3D

## Union AABB of every MeshInstance3D under a node, in the node's local space.
static func aabb_of(node: Node3D) -> AABB:
    var result := AABB()
    var first := true
    var stack: Array = [node]
    while not stack.is_empty():
        var n = stack.pop_back()
        if n is MeshInstance3D and n.mesh != null:
            var a: AABB = n.mesh.get_aabb()
            var t: Transform3D = node.global_transform.affine_inverse() * n.global_transform if node.is_inside_tree() else _relative_transform(node, n)
            a = t * a
            if first:
                result = a
                first = false
            else:
                result = result.merge(a)
        for c in n.get_children():
            stack.push_back(c)
    return result

static func _relative_transform(root: Node3D, n: Node3D) -> Transform3D:
    var t := Transform3D.IDENTITY
    var cur: Node = n
    while cur != null and cur != root:
        if cur is Node3D:
            t = (cur as Node3D).transform * t
        cur = cur.get_parent()
    return t

## Scales and offsets a model so its bounds fill `size` and its base sits at local y = -size.y/2
## (matching a centred box body). Non uniform scale is fine for walls, bad for round things.
static func fit(model: Node3D, size: Vector3, uniform: bool = false) -> void:
    var a := aabb_of(model)
    if a.size.x <= 0.0001 or a.size.y <= 0.0001 or a.size.z <= 0.0001:
        return
    var s := Vector3(size.x / a.size.x, size.y / a.size.y, size.z / a.size.z)
    if uniform:
        var u: float = min(s.x, min(s.y, s.z))
        s = Vector3(u, u, u)
    model.scale = s
    var center := a.get_center() * s
    model.position = Vector3(-center.x, -size.y / 2.0 - a.position.y * s.y, -center.z)

## Tints every material under a node by multiplying albedo (duplicates materials).
static func tint(model: Node3D, color: Color) -> void:
    var stack: Array = [model]
    while not stack.is_empty():
        var n = stack.pop_back()
        if n is MeshInstance3D and n.mesh != null:
            var mi: MeshInstance3D = n
            for i in mi.mesh.get_surface_count():
                var m := mi.get_active_material(i)
                if m is StandardMaterial3D:
                    var d: StandardMaterial3D = m.duplicate()
                    d.albedo_color = d.albedo_color * color
                    mi.set_surface_override_material(i, d)
        for c in n.get_children():
            stack.push_back(c)

## A baked tree from assets/foliage (1 m tall, standing on the origin) scaled to `height`.
static func tree(name: String, height: float) -> MeshInstance3D:
    var path := "res://assets/foliage/%s.res" % name
    if not _cache.has(path):
        if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _cache[path] = ResourceLoader.load_threaded_get(path)
        else:
            _cache[path] = load(path)
    var mi := MeshInstance3D.new()
    mi.mesh = _cache[path]
    mi.scale = Vector3(height, height, height)
    return mi

static var _tex_mats: Dictionary = {}

## Poly Haven colour texture (assets/ph/tex) as a triplanar material, so texel size stays the
## same on every block size. `scale` is repeats per metre.
static func tex_material(name: String, scale: float, tint: Color = Color.WHITE, roughness: float = 0.9) -> StandardMaterial3D:
    var key := "%s|%s|%s" % [name, scale, tint.to_html()]
    if _tex_mats.has(key):
        return _tex_mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/ph/tex/%s.jpg" % name)
    m.albedo_color = tint
    m.uv1_triplanar = true
    m.uv1_world_triplanar = false
    m.uv1_scale = Vector3(scale, scale, scale)
    m.roughness = roughness
    _tex_mats[key] = m
    return m

## Planks for wooden castle pieces.
static func wood_material() -> StandardMaterial3D:
    return tex_material("brown_planks_07", 0.9, Color(1.25, 0.95, 0.72))

## A baked Poly Haven prop (assets/props, real scale, standing on the origin).
static func prop(name: String) -> MeshInstance3D:
    var path := "res://assets/props/%s.res" % name
    if not _cache.has(path):
        _cache[path] = load(path)
    var mi := MeshInstance3D.new()
    mi.mesh = _cache[path]
    return mi

static func flat_material(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m
