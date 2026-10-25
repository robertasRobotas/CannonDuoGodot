## The Lighthouse: no ship to wreck, only the light to put out. The lantern's beam sweeps;
## the powder is up in the lantern itself, and a ball there takes the top of the tower
## with it. The level ends as any castle does, when the pirates are gone.
extends Scenario

const Marker := preload("res://scripts/tnt_marker.gd")

var _spins: Array[Node3D] = []
var _said := false
var _dark := false

func setup(lv: Level) -> void:
    super.setup(lv)
    for n in level.get_tree().get_nodes_in_group("blocks"):
        var blk := n as Block
        if blk and blk.style == "lamp":
            # A white arrow over the lantern, half as big again as the ones over the beach
            # guns: it goes with the lantern when the lantern goes.
            var m := Marker.new()
            m.offset = Vector3(0.0, blk.size.y / 2.0 + 1.1, 0.0)
            m.amp = 0.06
            m.size = 1.5
            blk.add_child(m)
        for c in (n as Node).find_children("*", "Node3D", true, false):
            if (c as Node).has_meta("spin"):
                _spins.append(c as Node3D)

func on_block_broke(blk: Block) -> void:
    if blk.style == "lamp" and not _dark:
        _dark = true
        for s in _spins:
            if is_instance_valid(s):
                s.queue_free()
        banner("THE LIGHT IS OUT!", "")

func tick(delta: float) -> void:
    if not playing():
        return
    if not _said:
        _said = true
        banner("SHOOT OUT THE LIGHT", "The powder is in the lantern")
    for s in _spins:
        if is_instance_valid(s):
            s.rotation.y += delta * 0.9
