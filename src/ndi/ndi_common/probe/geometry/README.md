# NDI electrode-layout library

This directory holds a library of reusable **electrode layouts** (probe geometries)
that ship with NDI, organized as a directory of directories of JSON files:

```
probe/geometry/<group>/<model>.json
```

`<group>` is normally the manufacturer or source (e.g. `neuropixels`,
`cambridgeneurotech`, `neuronexus`, `generic`, or a lab name for custom arrays).
`<model>` is the layout name.

## What a layout describes

A layout describes the **physical electrode sites only** — their coordinates,
shanks, and contact shapes. It intentionally does **not** describe how sites are
wired to recording channels: that mapping (`site2channelmap`) depends on the
headstage/adapter/recording, not on the electrode, so it is created per-probe when
the wiring is known.

## File format

Each `.json` file is an object whose fields mirror the `probe_geometry` document
(missing fields get sensible defaults). Coordinates are in the units given by
`unit` (microns by convention).

| field | meaning |
|-------|---------|
| `probe_model` | model name string |
| `manufacturer` | manufacturer string |
| `ndim` | number of spatial dimensions (usually 2) |
| `unit` | spatial unit, e.g. `"um"` |
| `site_locations_leftright` | N×1 left(−)/right(+) position of each site |
| `site_locations_frontback` | N×1 front(−)/back(+) position (0 for planar probes) |
| `site_locations_depth` | N×1 depth of each site |
| `shank_id` | N×1 integer shank id per site |
| `contact_shape` | contact shape name(s), e.g. `"circle"` |
| `contact_shape_radius` / `_width` / `_height` | per-contact shape parameters |

See `generic/tetrode.json` and `generic/linear16_25um.json` for minimal examples.

## Using layouts (MATLAB)

```matlab
ndi.fun.probe.geometry.listLibrary()                 % all layouts ('group/model')
ndi.fun.probe.geometry.listLibrary('generic')        % layouts in one group
geom = ndi.fun.probe.geometry.readLibrary('generic/tetrode');   % the layout struct

% attach a layout to a probe (creates a probe_geometry document):
p = S.getprobes('type','n-trode');
ndi.fun.probe.geometry.fromLibrary(S, p{1}, 'generic/linear16_25um');
```

## Adding layouts

The easiest way to add manufacturer probes is to import a
[ProbeInterface](https://probeinterface.readthedocs.io) file (the format
SpikeInterface uses; a community library covers Neuropixels, Cambridge NeuroTech,
NeuroNexus, and more) rather than transcribing coordinates by hand:

```matlab
[geom, map] = ndi.fun.probe.geometry.fromProbeInterface('NP2.json');
ndi.fun.probe.geometry.writeLibrary('neuropixels/NP2_1shank', geom);
```

`map` (the site→channel wiring from `device_channel_indices`) is returned
separately and is not stored in the library.
