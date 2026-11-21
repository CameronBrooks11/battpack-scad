# Check the holders, box and cover fit, at four settings
test:
    python3 tests/test_battpack.py

# Everything CI runs, bar the tests
check: fmt-check

# Format the .scad sources with topiary (.topiary/languages.ncl)
fmt:
    git ls-files -z '*.scad' | xargs -0 -r topiary format

# Check the .scad sources are formatted, without changing them
fmt-check:
    git ls-files -z '*.scad' | xargs -0 -r -n1 topiary format --check

# Export the holder, box and cover STLs into prints/, for the default 2 x 2 18650 pack
prints:
    mkdir -p prints
    openscad --export-format binstl -D 'part="holder"' -o prints/18650_holder.stl battpack.scad
    openscad --export-format binstl -D 'part="box"' -o prints/18650_holder_box_2x2gridconfig.stl battpack.scad
    openscad --export-format binstl -D 'part="cover"' -o prints/18650_holder_cover_2x2gridconfig.stl battpack.scad

# Render the README pictures into images/
images:
    mkdir -p images
    openscad --render --imgsize 1200,900 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,62,0,30,0 -o images/assembly.png battpack.scad
    openscad --render --imgsize 1000,800 --viewall --autocenter --colorscheme Tomorrow --camera 0,0,0,40,0,30,0 -D 'part="grid"' -D cells_x=3 -o images/grid.png battpack.scad
    openscad --render --imgsize 900,900 --viewall --autocenter --colorscheme Tomorrow --projection=ortho --camera 0,0,0,180,0,0,0 -D 'part="holder"' -o images/holder.png battpack.scad
