// battery_holder.scad: snap-together holders for cylindrical cells, a grid
// to arrange them, and a box with a cover to hold a grid.
//
// A holder is a square block with a bore for one end of a cell. A lip at the
// bottom keeps the cell in, and two crossed slots through the lip carry the
// nickel strip that joins cells. Each holder has a male dovetail on its +x
// and +y sides and a socket on its -x and -y sides, so holders slide together
// into any grid. A pack is two grids, one on each end of the cells.
//
// The holder's bore floor is at z = 0; the lip is below it.

EPS = 0.01;

// ---------------- Sizes ----------------
// Width of a holder's block, without its dovetails.
function holder_block(diameter, wall_thickness) = diameter + wall_thickness;
// Distance between neighbouring holders' centres in a grid.
function holder_pitch(diameter, wall_thickness, connector_depth, connector_allowance = 0.2) =
  holder_block(diameter, wall_thickness) + connector_depth + connector_allowance / 2;
// Width of a row of n holders, dovetails and sockets included.
function grid_span(n, diameter, wall_thickness, connector_depth, connector_allowance = 0.2) =
  (n - 1) * holder_pitch(diameter, wall_thickness, connector_depth, connector_allowance)
  + holder_block(diameter, wall_thickness) + 2 * connector_depth;

// A trapezium with its `bottom` edge at y = -h / 2 and its `top` edge at
// y = h / 2, centred on x.
function trapezium(bottom, top, h) = [[bottom / 2, -h / 2], [top / 2, h / 2], [-top / 2, h / 2], [-bottom / 2, -h / 2]];

// ---------------- One holder ----------------
// diameter            cell diameter
// height              depth of the bore
// wall_thickness      block width is diameter + wall_thickness
// retainer_thickness  thickness of the lip under the cell (wall_thickness / 2)
// retainer_radius     how far the lip reaches in under the cell (diameter / 10)
// connector_depth     depth of the dovetails (wall_thickness)
// wire_cut            width of the strip slots ((diameter - 2 retainer_radius) / 2)
// arc_cutout          arch the slots' roofs, so a holder printed lip-up needs no support
// cell_allowance      bore diameter over the cell
// connector_allowance socket width over the dovetail
// retainer            false leaves the lip out, for an open bore
// tie_slot            false fills the -y socket's outer corner, closing the cable tie slot
module battery_holder(diameter, height, wall_thickness, retainer_thickness = undef, retainer_radius = undef,
                      connector_depth = undef, wire_cut = undef, arc_cutout = true, cell_allowance = 0.2,
                      connector_allowance = 0.2, retainer = true, tie_slot = true) {
  lip = is_undef(retainer_thickness) ? wall_thickness / 2 : retainer_thickness;
  reach = is_undef(retainer_radius) ? diameter / 10 : retainer_radius;
  slot = is_undef(wire_cut) ? (diameter - 2 * reach) / 2 : wire_cut;
  depth = is_undef(connector_depth) ? wall_thickness : connector_depth;
  block = holder_block(diameter, wall_thickness);
  tail = diameter - wall_thickness; // widest part of the dovetail
  total = height + lip;
  side = (block + depth) / 2; // from the centre to the middle of a dovetail

  translate([0, 0, -lip]) difference() {
    union() {
      translate([-block / 2, -block / 2, 0]) cube([block, block, total]);
      for (a = [0, -90]) rotate(a) translate([0, side, 0]) dovetail(tail, depth, total);
      rotate(90) translate([0, side, 0]) socket(block, tail, depth, total, connector_allowance, true);
      rotate(180) translate([0, side, 0]) socket(block, tail, depth, total, connector_allowance, tie_slot);
    }
    // The bore, and the opening through the lip
    translate([0, 0, lip]) cylinder(d = diameter + cell_allowance, h = height + EPS, $fn = 64);
    translate([0, 0, -EPS]) cylinder(r = retainer ? diameter / 2 - reach : diameter / 2 + cell_allowance / 2,
                                     h = total + 2 * EPS, $fn = 64);
    // The strip slots, through the lip and as deep again into the block
    for (a = [0, 90]) rotate(a) {
      translate([-slot / 2, -block, -lip]) cube([slot, 2 * block, 2 * lip]);
      if (arc_cutout)
        translate([0, 0, lip]) rotate([90, 0, 0]) scale([1, 1 / 3, 1]) cylinder(d = slot, h = 2 * block, center = true, $fn = 128);
    }
  }
}

// A male dovetail standing out from y = -depth / 2, narrow at the holder.
module dovetail(tail, depth, h) {
  linear_extrude(h) polygon(trapezium(tail - depth, tail, depth));
}

// The socket that takes a neighbour's dovetail: a strip along the block's
// side with the dovetail's shape, plus allowance, cut out of it. `open`
// leaves the strip's +x end as two hooks with a gap between them for a cable
// tie; otherwise that end is filled out to the neighbouring corner.
module socket(block, tail, depth, h, allowance, open) {
  fill = open ? 0 : depth;
  difference() {
    translate([-block / 2, -depth / 2, 0]) cube([block + fill, depth, h]);
    translate([0, 0, -EPS]) linear_extrude(h + 2 * EPS) polygon(trapezium(tail + allowance, tail - depth + allowance, depth));
  }
}

// ---------------- Grid ----------------
// Places a copy of the children at each of cells_x by cells_y positions,
// centred on the origin. `width` is the holder block plus connector depth.
module batteryHolderConfig(cells_x, cells_y, width, connector_allowance = 0.2) {
  pitch = width + connector_allowance / 2;
  for (i = [0:cells_x - 1], j = [0:cells_y - 1])
    translate([(i - (cells_x - 1) / 2) * pitch, (j - (cells_y - 1) / 2) * pitch, 0]) children();
}

// ---------------- Box and cover ----------------
// A box that takes a grid of holders and cells standing on its floor, with a
// mounting flange each side and one screw hole per row of cells. The cover is the same
// box, wide enough to slide over it; its flange is at its open end, so it
// rests on the box's flange when the cover's ceiling meets the box's rim.
// The box's cavity is the grid's span plus box_allowance.
module battery_holder_box(battery_height, battery_diameter, cells_x, cells_y, wall_thickness, retainer_thickness,
                          connector_depth, connector_allowance, flange_width, mounting_hole_diameter,
                          box_wall_thickness, box_floor_thickness, box_allowance, cover = false) {
  h = battery_height + 2 * retainer_thickness + box_floor_thickness + box_allowance;
  span = [for (n = [cells_x, cells_y]) grid_span(n, battery_diameter, wall_thickness, connector_depth, connector_allowance)];
  grow = cover ? 2 * box_wall_thickness + box_allowance : 0;
  cavity = [span[0] + box_allowance + grow, span[1] + box_allowance + grow];
  outer = [cavity[0] + 2 * box_wall_thickness, cavity[1] + 2 * box_wall_thickness];
  t = box_floor_thickness;
  flange_y = outer[1] - grow; // as long as the box's side, cover or not
  flange_z = cover ? h - t : 0;
  hole_pitch = (cavity[1] - grow) / cells_y; // holes spread evenly along the box

  color("Grey") difference() {
    union() {
      translate([-outer[0] / 2, -outer[1] / 2, 0]) cube([outer[0], outer[1], h]);
      for (m = [0, 1]) mirror([m, 0, 0]) translate([(outer[0] - grow) / 2 + flange_width / 2, 0, flange_z])
        difference() {
          translate([-flange_width / 2, -flange_y / 2, 0]) cube([flange_width, flange_y, t]);
          for (j = [0:cells_y - 1])
            translate([0, (j - (cells_y - 1) / 2) * hole_pitch, -EPS]) cylinder(d = mounting_hole_diameter, h = t + 2 * EPS, $fn = 32);
          // Chamfer the flange's outer corners at 45 degrees
          for (k = [0, 1]) mirror([0, k, 0]) translate([flange_width / 2, flange_y / 2, -EPS])
            rotate(45) translate([-flange_width / sqrt(2), -flange_width / sqrt(2), 0])
              cube([flange_width * sqrt(2), flange_width * sqrt(2), t + 2 * EPS]);
        }
    }
    translate([-cavity[0] / 2, -cavity[1] / 2, t]) cube([cavity[0], cavity[1], h]);
  }
}
