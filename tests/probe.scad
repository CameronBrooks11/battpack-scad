// Fit checks, chosen by CHECK. Each renders an intersection that should be
// empty, or, moved by a small amount, not empty.
//   "cell":   a holder against a cell standing DROP above its bore floor
//   "pair":   a holder against its neighbour at the grid pitch, moved by MOVE
//   "box":    the box against the pack moved by MOVE
//   "cover":  the box against the cover seated LIFT above its rest
//   "inside": the seated cover against the pack
//   "flanges": the box against the cover seated LIFT above its rest, beyond
//             |x| = FLANGE_X, where only the flanges are
//   "holes":  the seated box and cover against a pin GROW over the hole
//             diameter through each flange hole position, worked out here
include <../battpack.scad>

part = "none";
CHECK = "cell";
DROP = 0;
MOVE = [0, 0, 0];
LIFT = 0;
NEIGHBOUR = "x";
FLANGE_X = 0;
GROW = 0;

if (CHECK == "cell")
  intersection() { holder(); translate([0, 0, DROP]) cell_of(D, holder_height + 1); }
else if (CHECK == "pair")
  intersection() { holder(); translate((NEIGHBOUR == "x" ? [PITCH, 0, 0] : [0, PITCH, 0]) + MOVE) holder(); }
else if (CHECK == "box")
  intersection() { box(); translate(MOVE) pack(); }
else if (CHECK == "cover")
  intersection() { box(); seated_cover(LIFT); }
else if (CHECK == "inside")
  intersection() { seated_cover(0); pack(); }
else if (CHECK == "flanges")
  intersection() {
    box();
    seated_cover(LIFT);
    for (m = [0, 1]) mirror([m, 0, 0]) translate([FLANGE_X, -500, -500]) cube(1000);
  }
else if (CHECK == "holes") {
  span = [for (n = [cells_x, cells_y]) grid_span(n, D, wall_thickness, connector_depth, connector_allowance)];
  cavity = [span[0] + box_allowance, span[1] + box_allowance];
  x = cavity[0] / 2 + box_wall_thickness + flange_width / 2;
  intersection() {
    union() { box(); seated_cover(0); }
    for (m = [0, 1], j = [0:cells_y - 1]) mirror([m, 0, 0])
      translate([x, (j - (cells_y - 1) / 2) * cavity[1] / cells_y, -1])
        cylinder(d = mounting_hole_diameter + GROW, h = 2 * box_floor_thickness + 2, $fn = 32);
  }
}
