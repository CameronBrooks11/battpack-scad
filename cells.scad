// cells.scad: sizes of common cylindrical cells, and a simple cell model.
//
// [name, diameter, length] in mm, length over the terminals. The alkaline
// sizes are the IEC 60086-2 maxima; the lithium sizes follow their names
// (diameter and length in tenths of a mm, so 21700 is 21.0 x 70.0), except
// 18650 and 26650, which are measured cells. Real cells vary: measure yours,
// or pass a diameter straight to battery_holder().

CELLS = [
  ["AAA", 10.5, 44.5],
  ["AA", 14.5, 50.5],
  ["C", 26.2, 50.0],
  ["D", 34.2, 61.5],
  ["CR123A", 17.0, 34.5],
  ["18650", 18.3, 64.8],
  ["21700", 21.0, 70.0],
  ["26650", 26.5, 66.0],
];

function cell_row(name) =
  let (i = search([name], CELLS)[0])
  assert(i != [], str("unknown cell ", name, "; known cells are ", [for (c = CELLS) c[0]]))
  CELLS[i];

function cell_diameter(name) = cell_row(name)[1];
function cell_length(name) = cell_row(name)[2];

// A cell standing on its negative end at z = 0, with a small positive nub.
module cell(name) {
  d = cell_diameter(name);
  l = cell_length(name);
  nub = min(1, l / 40);
  cylinder(d = d, h = l - nub);
  translate([0, 0, l - nub - 0.01]) cylinder(d = d / 3, h = nub + 0.01);
}
