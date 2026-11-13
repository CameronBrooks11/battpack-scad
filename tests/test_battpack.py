"""Render the pack's parts at several settings and check that they fit.

usage: python3 tests/test_battpack.py [OPENSCAD]

For each configuration it checks:
  - a holder is one piece of the expected size, and a grid of them is
    cells_x x cells_y separate pieces spanning grid_span();
  - a cell drops into the bore without touching it, and the lip stops it
    (or, with retainer = false, lets it through);
  - neighbouring holders don't touch, and their dovetails lock: pulling
    them 0.3 mm apart, pushing them 0.2 mm together or sliding them 0.1 mm
    sideways makes contact, in x and in y;
  - the pack (holders and cells) stands in the box without touching it, and
    sits no looser than box_allowance;
  - the cover seats on the box without touching it, rests on it 0.05 mm
    lower, clears the pack, and its flanges meet the box's with their holes
    lined up;
  - the box and cover are one piece each, of the expected size.
"""

import os
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "battpack.scad")
PROBE = os.path.join(ROOT, "tests", "probe.scad")

CELLS = {"18650": (18.3, 64.8), "AA": (14.5, 50.5), "26650": (26.5, 66.0), "21700": (21.0, 70.0)}

CONFIGS = {
    "2 x 2 18650 (the defaults)": {},
    "1 x 1 AA": {"cell": '"AA"', "cells_x": 1, "cells_y": 1, "holder_height": 5, "wall_thickness": 2.4},
    "3 x 2 26650, no tie slot": {"cell": '"26650"', "cells_x": 3, "cells_y": 2, "holder_height": 8,
                                 "wall_thickness": 2.4, "connector_depth": 2.4, "tie_slot": "false",
                                 "retainer_thickness": 1.2},
    "4 x 1 21700, open bore": {"cell": '"21700"', "cells_x": 4, "cells_y": 1, "retainer": "false",
                               "connector_allowance": 0.15, "box_allowance": 0.4},
}

DEFAULTS = {"cells_x": 2, "cells_y": 2, "holder_height": 6, "wall_thickness": 2, "connector_depth": 3,
            "retainer_thickness": 1.4, "connector_allowance": 0.2, "box_allowance": 0.3, "flange_width": 10,
            "box_wall_thickness": 2, "box_floor_thickness": 3, "retainer": "true"}


def run(openscad, scad, out, defines):
    cmd = [openscad, "--hardwarnings", "--export-format", "binstl", "-o", out]
    for name, value in defines.items():
        cmd += ["-D", f"{name}={value}"]
    return subprocess.run(cmd + [scad], capture_output=True, text=True)


def mesh(path):
    data = open(path, "rb").read()
    (n,) = struct.unpack_from("<I", data, 80)
    return [struct.unpack_from("<9f", data, 84 + i * 50 + 12) for i in range(n)]


def volume(path):
    v = 0.0
    for a in mesh(path):
        p, q, r = a[0:3], a[3:6], a[6:9]
        v += (p[0] * (q[1] * r[2] - q[2] * r[1]) - p[1] * (q[0] * r[2] - q[2] * r[0])
              + p[2] * (q[0] * r[1] - q[1] * r[0])) / 6
    return abs(v)


def solids_and_size(path):
    tris = mesh(path)
    parent = {}

    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for a in tris:
        corners = [a[0:3], a[3:6], a[6:9]]
        for c in corners:
            parent.setdefault(c, c)
        root = find(corners[0])
        for c in corners[1:]:
            parent[find(c)] = root
    size = [max(p[i] for p in parent) - min(p[i] for p in parent) for i in range(3)]
    return len({find(v) for v in parent}), size


def check_config(openscad, tmp, name, defines, report):
    c = {**DEFAULTS, **defines}
    d, length = CELLS[c.get("cell", '"18650"').strip('"')]
    nx, ny = c["cells_x"], c["cells_y"]
    wall, depth, allow = c["wall_thickness"], c["connector_depth"], c["connector_allowance"]
    block = d + wall
    pitch = block + depth + allow / 2
    stl = os.path.join(tmp, "case.stl")

    # Parts that overlap by more than 0.001 cu mm. Faces that only meet,
    # like a cell resting on its lip, leave zero-volume slivers.
    def touches(**probe):
        result = run(openscad, PROBE, stl, {**defines, **probe})
        if "top level object is empty" in result.stderr.lower():
            return False
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip().splitlines()[-1])
        return volume(stl) > 0.001

    result = run(openscad, PACK, stl, {**defines, "part": '"holder"'})
    n, size = solids_and_size(stl)
    want = [block + 2 * depth, block + 2 * depth, c["holder_height"] + c["retainer_thickness"]]
    report(f"{name}: a holder is one piece, {want[0]:.2f} x {want[1]:.2f} x {want[2]:.2f}",
           result.returncode == 0 and n == 1 and all(abs(a - b) < 0.01 for a, b in zip(size, want)),
           f"{n} pieces, " + " x ".join(f"{v:.2f}" for v in size))

    result = run(openscad, PACK, stl, {**defines, "part": '"grid"'})
    n, size = solids_and_size(stl)
    span = [(k - 1) * pitch + block + 2 * depth for k in (nx, ny)]
    report(f"{name}: the grid is {nx * ny} separate holders spanning {span[0]:.2f} x {span[1]:.2f}",
           n == nx * ny and all(abs(a - b) < 0.01 for a, b in zip(size, span)),
           f"{n} pieces, {size[0]:.2f} x {size[1]:.2f}")

    rest = touches(CHECK='"cell"', DROP=0)
    if c["retainer"] == "true":
        stop = touches(CHECK='"cell"', DROP=-0.1)
        report(f"{name}: a cell drops into the bore and the lip stops it", not rest and stop,
               f"at rest {'touches' if rest else 'clear'}, 0.1 lower {'stopped' if stop else 'falls through'}")
    else:
        through = not touches(CHECK='"cell"', DROP=-c["retainer_thickness"] - 1)
        report(f"{name}: with no lip, a cell passes through", not rest and through,
               f"at rest {'touches' if rest else 'clear'}, lowered {'passes' if through else 'stopped'}")

    for axis in ("x", "y"):
        along = [1, 0, 0] if axis == "x" else [0, 1, 0]
        across = [0, 1, 0] if axis == "x" else [1, 0, 0]
        move = lambda v, s: "[" + ", ".join(str(s * x) for x in v) + "]"
        free = not touches(CHECK='"pair"', NEIGHBOUR=f'"{axis}"', MOVE="[0, 0, 0]")
        pulled = touches(CHECK='"pair"', NEIGHBOUR=f'"{axis}"', MOVE=move(along, 0.3))
        pushed = touches(CHECK='"pair"', NEIGHBOUR=f'"{axis}"', MOVE=move(along, -0.2))
        slid = all(touches(CHECK='"pair"', NEIGHBOUR=f'"{axis}"', MOVE=move(across, s)) for s in (0.1, -0.1))
        report(f"{name}: neighbours in {axis} are clear and their dovetail locks", free and pulled and pushed and slid,
               f"clear {free}, held pulling 0.3 {pulled}, pushing 0.2 {pushed}, sliding 0.1 {slid}")

    clear = not touches(CHECK='"box"', MOVE="[0, 0, 0]")
    gap = c["box_allowance"] / 2 + 0.05
    snug = all(touches(CHECK='"box"', MOVE=m) for m in (f"[{gap}, 0, 0]", f"[{-gap}, 0, 0]", f"[0, {gap}, 0]", f"[0, {-gap}, 0]"))
    report(f"{name}: the pack stands in the box clear of it, within box_allowance", clear and snug,
           f"clear {clear}, touches when moved {gap:.2f} each way {snug}")

    seated = not touches(CHECK='"cover"', LIFT=0)
    rests = touches(CHECK='"cover"', LIFT=-0.05)
    inside = not touches(CHECK='"inside"')
    report(f"{name}: the cover seats on the box and clears the pack", seated and rests and inside,
           f"seated clear {seated}, rests on the box {rests}, clears the pack {inside}")

    bw, bf = c["box_wall_thickness"], c["box_floor_thickness"]
    cavity = [s + c["box_allowance"] for s in span]
    edge = cavity[0] / 2 + bw + 2 * bw + c["box_allowance"]  # outside the cover's walls
    meet = touches(CHECK='"flanges"', LIFT=-0.05, FLANGE_X=edge) and not touches(CHECK='"flanges"', LIFT=0, FLANGE_X=edge)
    report(f"{name}: the cover's flanges rest on the box's", meet, "they meet" if meet else "they don't meet")
    through = not touches(CHECK='"holes"', GROW=-0.2) and touches(CHECK='"holes"', GROW=0.2)
    report(f"{name}: a screw 0.2 mm under the hole size passes through both flanges, one 0.2 over doesn't",
           through, "lined up" if through else "not lined up")
    height = length + 2 * c["retainer_thickness"] + bf + c["box_allowance"]
    for part, grow in (("box", 0), ("cover", 2 * bw + c["box_allowance"])):
        result = run(openscad, PACK, stl, {**defines, "part": f'"{part}"'})
        n, size = solids_and_size(stl)
        want = [cavity[0] + grow + 2 * bw + 2 * c["flange_width"] - grow, cavity[1] + grow + 2 * bw, height]
        report(f"{name}: the {part} is one piece, " + " x ".join(f"{v:.2f}" for v in want),
               n == 1 and all(abs(a - b) < 0.01 for a, b in zip(size, want)),
               f"{n} pieces, " + " x ".join(f"{v:.2f}" for v in size))


def main():
    openscad = sys.argv[1] if len(sys.argv) > 1 else "openscad"
    failures = []

    def report(label, ok, got):
        print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")
        if not ok:
            failures.append(label)

    with tempfile.TemporaryDirectory() as tmp:
        for name, defines in CONFIGS.items():
            check_config(openscad, tmp, name, defines, report)
        result = run(openscad, PACK, os.path.join(tmp, "x.stl"), {"cell": '"18600"'})
        report("refuses an unknown cell", result.returncode != 0 and "unknown cell 18600" in result.stderr,
               "refused" if "unknown cell" in result.stderr else result.stderr.strip().splitlines()[-1:])

    print("all checks passed" if not failures else f"{len(failures)} failed")
    sys.exit(1 if failures else 0)


main()
