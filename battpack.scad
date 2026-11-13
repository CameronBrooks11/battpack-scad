// battpack.scad: a battery pack from holders, in a box with a cover.
//
// Pick a cell and a grid, then export each part: one holder (print
// cells_x x cells_y x 2 of them, lip up), the box and the cover. "assembly"
// shows the pack standing in the box, with the cover beside it as printed.

use <cells.scad>
use <battery_holder.scad>

/* [Cells] */
cell = "18650"; // [AAA, AA, C, D, CR123A, 18650, 21700, 26650]
// Cell diameter (mm); 0 uses the cell's listed size
diameter = 0;
// Cell length (mm); 0 uses the cell's listed size
length = 0;
cells_x = 2; // [1:1:8]
cells_y = 2; // [1:1:8]

/* [Holder] */
// Depth of the bore
holder_height = 6;
wall_thickness = 2;
connector_depth = 3;
retainer_thickness = 1.4;
// How far the lip reaches under the cell; 0 uses diameter / 10
retainer_radius = 0;
// Width of the strip slots; 0 uses (diameter - 2 retainer_radius) / 2
wire_cut = 0;
cell_allowance = 0.2;
connector_allowance = 0.2;
arc_cutout = true;
tie_slot = true;
retainer = true;

/* [Box] */
flange_width = 10;
mounting_hole_diameter = 4;
box_wall_thickness = 2;
box_floor_thickness = 3;
// Clearance around the grid inside the box, and between box and cover
box_allowance = 0.3;

/* [Output] */
part = "assembly"; // [assembly, holder, grid, box, cover, none]

D = diameter > 0 ? diameter : cell_diameter(cell);
L = length > 0 ? length : cell_length(cell);
PITCH = holder_pitch(D, wall_thickness, connector_depth, connector_allowance);
BOX_H = L + 2 * retainer_thickness + box_floor_thickness + box_allowance;

module holder() {
  battery_holder(diameter = D, height = holder_height, wall_thickness = wall_thickness,
                 retainer_thickness = retainer_thickness, retainer_radius = retainer_radius > 0 ? retainer_radius : undef,
                 connector_depth = connector_depth, wire_cut = wire_cut > 0 ? wire_cut : undef, arc_cutout = arc_cutout,
                 cell_allowance = cell_allowance, connector_allowance = connector_allowance, retainer = retainer,
                 tie_slot = tie_slot);
}

module grid() {
  batteryHolderConfig(cells_x, cells_y, holder_block(D, wall_thickness) + connector_depth, connector_allowance) children();
}

// One end of the pack as it stands in the box: the bottom holders on the
// floor, the cells, and the top holders turned over onto them.
module pack(show_cells = true) {
  z0 = box_floor_thickness + retainer_thickness;
  translate([0, 0, z0]) grid() {
    holder();
    if (show_cells) color("DodgerBlue") cell_of(D, L);
    translate([0, 0, L]) rotate([0, 180, 0]) holder();
  }
}

module cell_of(d, l) cylinder(d = d, h = l, $fn = 64);

module box(cover = false) {
  battery_holder_box(battery_height = L, battery_diameter = D, cells_x = cells_x, cells_y = cells_y,
                     wall_thickness = wall_thickness, retainer_thickness = retainer_thickness,
                     connector_depth = connector_depth, connector_allowance = connector_allowance,
                     flange_width = flange_width, mounting_hole_diameter = mounting_hole_diameter,
                     box_wall_thickness = box_wall_thickness, box_floor_thickness = box_floor_thickness,
                     box_allowance = box_allowance, cover = cover);
}

// The cover turned over and seated on the box, lifted by `lift`.
module seated_cover(lift = 0) {
  translate([0, 0, box_floor_thickness + BOX_H + lift]) mirror([0, 0, 1]) box(cover = true);
}

if (part != "none")
  echo(str(cells_x, " x ", cells_y, " ", diameter > 0 || length > 0 ? str(D, " x ", L, " mm") : cell,
           " cells; holder pitch ", PITCH, " mm; box ", BOX_H, " mm tall"));

if (part == "holder") holder();
else if (part == "grid") grid() holder();
else if (part == "box") box();
else if (part == "cover") box(cover = true);
else if (part == "assembly") {
  box();
  pack();
  outer_y = grid_span(cells_y, D, wall_thickness, connector_depth, connector_allowance) + box_allowance + 2 * box_wall_thickness;
  translate([0, outer_y + 2 * box_wall_thickness + box_allowance + 15, 0]) box(cover = true);
} else assert(part == "none", str("part must be assembly, holder, grid, box, cover or none, not ", part));
