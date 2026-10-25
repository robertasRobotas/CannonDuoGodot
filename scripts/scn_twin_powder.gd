## Two powder stores, one in the works either side of the tower: the level is not won
## until both have gone up (and the pirates are gone, as ever).
extends Scenario

var _blown := {-1.0: false, 1.0: false}
var _said := false

func setup(lv: Level) -> void:
    super.setup(lv)
    lock()

func on_block_broke(blk: Block) -> void:
    if blk.material_name != "tnt" or blk.is_fragment:
        return
    var side := signf(blk.base_position.x)
    if side == 0.0 or _blown[side]:
        return
    _blown[side] = true
    if level._settle_probe:
        print("TWIN powder blown on the %s" % ("left" if side < 0.0 else "right"))
    if _blown[-1.0] and _blown[1.0]:
        banner("BOTH STORES GONE!", "")
        release(blk.global_position)
    else:
        banner("ONE STORE GONE!", "Now the other side")

func tick(_delta: float) -> void:
    if not playing() or _said:
        return
    _said = true
    banner("POWDER EITHER SIDE", "Blow both stores")
