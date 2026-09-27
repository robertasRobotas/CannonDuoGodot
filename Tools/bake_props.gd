## Bakes the Poly Haven props in assets/ph into light meshes for phones: one surface per
## material, simplified to about TARGET_TRIS triangles, unused vertices dropped. Real scale
## (metres), standing on the origin. Output: assets/props/<name>.res
## Run: Godot --headless --path . --script Tools/bake_props.gd
extends SceneTree

const OUT := "res://assets/props/"
const TARGET_TRIS := 6000

func _init() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    for name in ["boulder_01", "wooden_crate_01", "wooden_barrels_01", "treasure_chest", "tree_stump_01", "dead_tree_trunk", "shrub_02", "fern_02", "barrel_03"]:
        _bake("res://assets/ph/%s/%s.gltf" % [name, name], name, TARGET_TRIS)
    # Cliffs and big rocks for rocky shores and headlands.
    for name in ["namaqualand_cliff_01", "coastal_cliff_01", "namaqualand_boulder_02"]:
        _bake("res://assets/ph/%s/%s.gltf" % [name, name], name, 12000)
    # The pinnace (enemy ships and boats moored off the beach) keeps more detail.
    _bake("res://assets/hq/pinnace/ship_pinnace_1k.gltf", "pinnace", 22000)
    quit()

func _bake(path: String, out_name: String, target_tris: int) -> void:
    var root: Node3D = (load(path) as PackedScene).instantiate()
    var tools: Dictionary = {}
    var mats: Dictionary = {}
    for n in root.find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        var xf := _to_root(root, mi)
        for i in mi.mesh.get_surface_count():
            var m := mi.get_active_material(i)
            var key := m.resource_name if m != null else "none"
            if not tools.has(key):
                var st := SurfaceTool.new()
                st.begin(Mesh.PRIMITIVE_TRIANGLES)
                tools[key] = st
                mats[key] = m
            (tools[key] as SurfaceTool).append_from(mi.mesh, i, xf)
    var im := ImporterMesh.new()
    var bounds := AABB()
    var first := true
    var total_tris := 0
    for key in tools:
        var st := tools[key] as SurfaceTool
        st.index()
        var a: Array = st.commit_to_arrays()
        total_tris += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
        for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
            bounds = AABB(v, Vector3.ZERO) if first else bounds.expand(v)
            first = false
        im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, _material(mats[key]), key)
    im.generate_lods(25.0, 60.0, [])
    var shift := Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
    var ratio := minf(1.0, float(target_tris) / maxf(float(total_tris), 1.0))
    var out := ArrayMesh.new()
    var kept := 0
    for s in im.get_surface_count():
        var arrays := im.get_surface_arrays(s)
        var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        var want := int(idx.size() * ratio)
        # Pick the coarsest LOD that still has at least the wanted index count.
        for l in im.get_surface_lod_count(s):
            var li := im.get_surface_lod_indices(s, l)
            if li.size() >= want and li.size() < idx.size():
                idx = li
        var compact := _compact(arrays, idx, shift)
        kept += (compact[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
        out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, compact)
        out.surface_set_material(s, im.get_surface_material(s))
    var err := ResourceSaver.save(out, OUT + out_name + ".res")
    print("%s: %d -> %d tris, %.2f m tall, err %d" % [out_name, total_tris, kept, bounds.size.y, err])
    root.free()

## Keeps only the vertices the chosen indices use, renumbered, shifted onto the origin.
func _compact(arrays: Array, idx: PackedInt32Array, shift: Vector3) -> Array:
    var remap := {}
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
    var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
    var out_idx := PackedInt32Array()
    for i in idx:
        if not remap.has(i):
            remap[i] = verts.size()
            verts.append(src_v[i] + shift)
            if not src_n.is_empty():
                normals.append(src_n[i])
            if not src_uv.is_empty():
                uvs.append(src_uv[i])
        out_idx.append(remap[i])
    var a := []
    a.resize(Mesh.ARRAY_MAX)
    a[Mesh.ARRAY_VERTEX] = verts
    if not normals.is_empty():
        a[Mesh.ARRAY_NORMAL] = normals
    if not uvs.is_empty():
        a[Mesh.ARRAY_TEX_UV] = uvs
    a[Mesh.ARRAY_INDEX] = out_idx
    return a

func _to_root(root: Node, n: Node3D) -> Transform3D:
    var t := Transform3D.IDENTITY
    var cur: Node = n
    while cur != null and cur != root:
        if cur is Node3D:
            t = (cur as Node3D).transform * t
        cur = cur.get_parent()
    return t

## Colour map only; foliage cards cut out and double sided.
func _material(src: Material) -> Material:
    if not (src is BaseMaterial3D):
        return src
    var m: BaseMaterial3D = src.duplicate()
    m.normal_enabled = false
    m.normal_texture = null
    m.ao_enabled = false
    m.ao_texture = null
    m.metallic_texture = null
    m.roughness_texture = null
    m.metallic = 0.0
    m.roughness = 0.85
    if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        m.alpha_scissor_threshold = 0.4
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m
