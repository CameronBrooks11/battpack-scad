// Using the library in your own model: one holder for an 18650 cell.
use <../cells.scad>
use <../battery_holder.scad>

battery_holder(diameter = cell_diameter("18650"), height = 6, wall_thickness = 3, retainer_thickness = 2);
