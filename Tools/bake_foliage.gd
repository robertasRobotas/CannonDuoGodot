## Merges the Sketchfab tree scenes in assets/hq into one mesh per tree (one surface per
## material, with LODs) so scattering dozens of trees stays a handful of draw calls.
## Output meshes stand on the origin and are 1 m tall, so scale = height in metres.
## Run: Godot --headless --path . --script Tools/bake_foliage.gd
extends SceneTree

const OUT := "res://assets/foliage/"

func _init() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    _bake("res://assets/hq/pine_tree/scene.gltf", "", "pine")
    # The oak file holds three trees side by side; bake each on its own.
    _bake("res://assets/hq/oak_trees/scene.gltf", "Treesmall", "oak_small")
    _bake("res://assets/hq/oak_trees/scene.gltf", "Treemedium", "oak_medium")
    _bake("res://assets/hq/oak_trees/scene.gltf", "treelarge", "oak_large")
    # The maple ships with a patch of ground and grass under it; keep only bark and leaves.
    _bake("res://assets/hq/maple_tree/scene.gltf", "", "maple", ["Groundcover_Wood_Mix", "grass"])
    _bake("res://assets/hq/palm_coconut/scene.gltf", "", "palm_coconut")
    _bake("res://assets/hq/palm_plant/scene.gltf", "", "palm_plant")
    quit()

func _bake(path: String, subtree: String, out_name: String, skip: Array = []) -> void:
    var root: Node3D = (load(path) as PackedScene).instantiate()
    var start: Node = root if subtree == "" else root.find_child(subtree, true, false)
    if start == null:
        push_error("No node %s in %s" % [subtree, path])
        return
    # Gather triangles per material, in the root's space.
    var tools: Dictionary = {}
    var mats: Dictionary = {}
    var stack: Array = [start]
    while not stack.is_empty():
        var n: Node = stack.pop_back()
        if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
            var mi := n as MeshInstance3D
            var xf := _to_root(root, mi)
            for i in mi.mesh.get_surface_count():
                var m := mi.get_active_material(i)
                var key := m.resource_name if m != null else "none"
                if key in skip:
                    continue
                if not tools.has(key):
                    var st := SurfaceTool.new()
                    st.begin(Mesh.PRIMITIVE_TRIANGLES)
                    tools[key] = st
                    mats[key] = m
                (tools[key] as SurfaceTool).append_from(mi.mesh, i, xf)
        for c in n.get_children():
            stack.push_back(c)
    # Bounds of the merged tree, to stand it on the origin at 1 m tall.
    var arrays: Array = []
    var bounds := AABB()
    var first := true
    for key in tools:
        var a: Array = (tools[key] as SurfaceTool).commit_to_arrays()
        arrays.append([key, a])
        for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
            if first:
                bounds = AABB(v, Vector3.ZERO)
                first = false
            else:
                bounds = bounds.expand(v)
    var s := 1.0 / maxf(bounds.size.y, 0.001)
    var shift := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
    var im := ImporterMesh.new()
    for entry in arrays:
        var a: Array = entry[1]
        var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
        for i in verts.size():
            verts[i] = (verts[i] + shift) * s
        a[Mesh.ARRAY_VERTEX] = verts
        # Positions, normals, UVs and indices only; some sources carry bone or custom data.
        var clean := []
        clean.resize(Mesh.ARRAY_MAX)
        for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
            clean[k] = a[k]
        im.add_surface(Mesh.PRIMITIVE_TRIANGLES, clean, [], {}, _material(mats[entry[0]]), entry[0])
    im.generate_lods(25.0, 60.0, [])
    var mesh := im.get_mesh()
    var err := ResourceSaver.save(mesh, OUT + out_name + ".res")
    print("%s: %d surfaces, %d source materials, err %d" % [out_name, mesh.get_surface_count(), tools.size(), err])
    root.free()

func _to_root(root: Node, n: Node3D) -> Transform3D:
    var t := Transform3D.IDENTITY
    var cur: Node = n
    while cur != null and cur != root:
        if cur is Node3D:
            t = (cur as Node3D).transform * t
        cur = cur.get_parent()
    return t

## Leaves are cut-out cards: alpha scissor (no sorting), both sides. No normal or specular
## maps on anything, to keep the download small.
func _material(src: Material) -> Material:
    if not (src is BaseMaterial3D):
        return src
    var m: BaseMaterial3D = src.duplicate()
    var leafy := m.resource_name.to_lower().contains("lea") or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
    if leafy:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        m.alpha_scissor_threshold = 0.4
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
    # Only the base colour ships with the game (see exclude_filter in export_presets.cfg).
    m.normal_enabled = false
    m.normal_texture = null
    m.metallic = 0.0
    m.roughness = 0.9
    m.metallic_texture = null
    m.roughness_texture = null
    m.ao_enabled = false
    m.ao_texture = null
    return m
