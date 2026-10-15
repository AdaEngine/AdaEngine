# MagicaVoxel sample files

`chr_knight.vox`, `cars.vox` and `anim/deer.vox` (stored here as `deer.vox`) are unmodified
files from the `vox` folder of the MagicaVoxel 0.99.7.2 release
(https://github.com/ephtracy/ephtracy.github.io/releases/tag/0.99.7). They are saved by
MagicaVoxel itself (format version 200), unlike the files in the parent directory that
`script/generate_vox_fixtures.py` writes, so they check the importer against real data.

- `chr_knight.vox`: one 20x21x20 model, a palette, 256 `MATL` chunks and layers.
- `cars.vox`: two models placed by a scene graph; the first node has a 90 degree rotation (`_r = 17`).
- `deer.vox`: four 26x9x27 models switched by frame in one shape node (frame-by-frame animation).

The license of these samples was not checked when they were added; confirm that the
repository may redistribute them or replace them with files you own.
