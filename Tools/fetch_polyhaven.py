#!/usr/bin/env python3
"""Download Poly Haven (CC0) models into assets/ph/<name>/ with only their colour textures,
and strip the normal/ARM references from the glTF. Then run Tools/bake_props.gd.

Usage: Tools/fetch_polyhaven.py barrel_03 [more names...]
"""
import json
import os
import sys
import urllib.request

UA = {"User-Agent": "CannonDuo-asset-fetch/1.0"}
BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "ph")


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()


def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(fetch(url))


def model(name):
    files = json.loads(fetch(f"https://api.polyhaven.com/files/{name}"))
    gl = files["gltf"]["1k"]["gltf"]
    root = os.path.join(BASE, name)
    path = os.path.join(root, f"{name}.gltf")
    get(gl["url"], path)
    for rel, v in gl["include"].items():
        if "_nor_" in rel or "_arm_" in rel:
            continue
        get(v["url"], os.path.join(root, rel))
    g = json.load(open(path))
    for m in g["materials"]:
        m.pop("normalTexture", None)
        m.pop("occlusionTexture", None)
        pbr = m.setdefault("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        pbr["metallicFactor"] = 0.0
        pbr.setdefault("roughnessFactor", 0.85)
    used = sorted({m["pbrMetallicRoughness"]["baseColorTexture"]["index"] for m in g["materials"] if "baseColorTexture" in m["pbrMetallicRoughness"]})
    remap = {old: new for new, old in enumerate(used)}
    g["textures"] = [g["textures"][i] for i in used]
    for m in g["materials"]:
        t = m["pbrMetallicRoughness"].get("baseColorTexture")
        if t:
            t["index"] = remap[t["index"]]
    images = sorted({t["source"] for t in g["textures"]})
    iremap = {old: new for new, old in enumerate(images)}
    g["images"] = [g["images"][i] for i in images]
    for t in g["textures"]:
        t["source"] = iremap[t["source"]]
    json.dump(g, open(path, "w"))
    print(name, "ok")


if __name__ == "__main__":
    for n in sys.argv[1:]:
        model(n)
