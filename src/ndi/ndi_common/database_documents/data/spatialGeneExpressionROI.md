# spatialGeneExpressionROI

The `spatialGeneExpressionROI` document class records the polygon that
carved a `spatialGeneExpressionPyramid` out of a larger source file. It
is a **provenance sidecar**: no analysis tool is required to read it,
no viewer needs to render it, and nothing in the current pyramid or
tile files refers back to it. Its job is to keep the drawn geometry on
record so it is still available after the fact.

## Where it comes from

`ndi.fun.doc.gene.fromGEFbyROI` and `ndi.fun.doc.gene.fromGEFinteractive`
import a .gef into one pyramid per polygon when a single chip's section
captured tissue from multiple animals. Each polygon becomes:

- one `spatialGeneExpressionPyramid` with its own subject, which this
  ROI depends on through `spatialGeneExpressionPyramid_id`;
- one shared `fileReference` or `generic_file` describing the .gef,
  which this ROI points at through `source_file_id`.

All ROI documents produced in a single import share the same
`source_file_id`; that is how a later tool recognises them as the same
chip.

## What it does NOT do

It does not store counts, does not store a mask image, and does not
affect how the pyramid it depends on is read. The pyramid is a
freestanding one-subject document; the ROI exists next to it. A
downstream tool that only knows about pyramids keeps working exactly as
it did before this document class existed.

## Why it exists before V2

NDI V2 lets subjects be groups, and in V2 a multi-subject chip is
naturally one pyramid with a group subject and one ROI per group
member. Until V2, the practical path is one pyramid per subject, which
loses the drawn geometry: a scientist who wants to recut would redraw.
Writing an ROI at ingest keeps that geometry on record so a V2 importer
can lift it rather than ask the scientist again.

## Coordinate space

`vertices_x` and `vertices_y` are stored in the same integer pixel grid
`ndr.format.stereoseq.readGEF` returns in `X`,`Y` -- the raw GEF base
pixel grid -- which is the grid `inpolygon` ran in when the pyramid was
built. `coord_space` is named ("gef_base_pixel") rather than left
implicit so a future ROI drawn on an image aligned to the pyramid (not
the raw GEF) can be stored under a different space without rewriting
the pyramid.

## Fields

| field | type | notes |
|---|---|---|
| `label` | string | human-readable label (optional) |
| `n_vertices` | integer | polygon vertex count; a simple polygon needs at least three |
| `vertices_x` | matrix | x coordinates in `coord_space` |
| `vertices_y` | matrix | y coordinates in `coord_space`, same length as `vertices_x` |
| `coord_space` | string | default `gef_base_pixel` |
| `coord_units` | string | default `pixel` |
| `n_records_in` | integer | records (spots) that fell inside the polygon when the pyramid was built |
| `roi_format_version` | integer | representation version; 1 is a single closed polygon |

## Dependencies

| name | required | description |
|---|---|---|
| `spatialGeneExpressionPyramid_id` | yes | the pyramid built from the records inside this polygon |
| `source_file_id` | no | the shared `.gef` the pyramid came from |

## See also

- `spatialGeneExpressionPyramid`
- `spatialGeneExpressionTiles`
- `fileReference`
