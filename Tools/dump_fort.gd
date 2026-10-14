## Prints a generated fort as JSON: godot --headless --path . --script Tools/dump_fort.gd -- KIND Z [opts-json]
extends SceneTree

func _init() -> void:
    var args := OS.get_cmdline_user_args()
    var kind := args[0] if args.size() > 0 else "harbor"
    var z := float(args[1]) if args.size() > 1 else -11.0
    var opts: Dictionary = JSON.parse_string(args[2]) if args.size() > 2 else {}
    var fort := Fortress.generate(3 * 101 + 7, kind, "sand", z, opts)
    print("FORT " + JSON.stringify(fort))
    quit()
