# Spike sorting with JRCLUST

NDI can drive [JRCLUST](https://github.com/VH-Lab/JRCLUST) end to end: prepare a probe
for sorting, detect and sort its spikes, curate the units, and import the results back
into NDI as `ndi.neuron` elements. No sample data is copied anywhere — JRCLUST reads the
probe's data directly out of NDI, epoch by epoch.

This page covers both ways to run the pipeline: the **JRCLUST app** in the NDI navigator
and the equivalent **commands**.

## Before you start: installing JRCLUST

NDI needs the VH Lab fork of JRCLUST, which adds the `ndi` recording format. Install it
and put it on the MATLAB path:

```matlab
% git clone https://github.com/VH-Lab/JRCLUST
% cd JRCLUST && git checkout ndi_import
addpath(genpath('/path/to/JRCLUST'));
```

Check what NDI can see at any time:

```matlab
info = ndi.fun.probe.import.jrclust.install();
disp(info.summary);
```

The report gives the installation folder, JRCLUST's version, the checked-out git branch
(`ndi_import` is the one the lab documents) and whether the NDI support files are
present. In the app, the **Check JRCLUST** button shows the same report.

## The app

Open the NDI navigator, select a session, and choose **Apps → Spike Sorters → JRCLUST**
(or open it directly with `ndi.gui.app.jrclust(S)`).

The window lists the session's `n-trode` probes with their pipeline state in parentheses
— `parameters`, `detected`, `sorted`, `curated`, `annotated`, `imported` — and one button
per step. `curated` and `annotated` are not the same thing: `curated` means the sort has
been saved from JRCLUST's curator, `annotated` means at least one unit carries a label.
Only an `annotated` sort can be imported (see [Annotation decides what is
imported](#annotation-decides-what-is-imported)).

| Button | What it does |
| -- | -- |
| Check JRCLUST | Report the JRCLUST installation, its branch and its NDI support. |
| 1. Parameters | Write the JRCLUST parameter file for the selected probe, with the probe's geometry filled in from NDI. |
| 2. Edit Params | Open that parameter file in the MATLAB editor. |
| 3. Traces | Open JRCLUST's trace viewer to check the channels and the site map. |
| 4. Detect | Run JRCLUST spike detection. |
| 5. Sort | Run JRCLUST clustering. |
| 6. Curate | Open JRCLUST's curation GUI, where units are merged, split and **annotated**. |
| 7. Import into NDI | Import the annotated units as `ndi.neuron` elements. |

The **Use GPU**, **Max sec load** and **Group radius** settings on the options row are
written into the parameter file when it is created; everything else is set by editing
the file.

## The same pipeline in code

```matlab
S = ndi.session.dir('/path/to/2024-01-01');
p = S.getprobes('type','n-trode');

% 1. write the JRCLUST parameter file for the first probe
prmFile = ndi.fun.probe.export.jrclust(S, p{1});

% 2. edit the parameters (see below)
ndi.fun.probe.import.jrclust.editParameters(S, p{1});

% 3. check the traces, then detect and sort
ndi.fun.probe.import.jrclust.traces(S, p{1});
ndi.fun.probe.import.jrclust.run(S, p{1});             % 'jrc detect' then 'jrc sort'

% 4. curate: merge, split and ANNOTATE the units, then save
ndi.fun.probe.import.jrclust.curate(S, p{1});          % 'jrc manual'

% 5. import the annotated units into NDI
ndi.fun.probe.import.jrclust.probe(S, p{1});
```

`ndi.fun.probe.import.jrclust.session(S)` imports every sorted probe of a session in one
call.

The files live in `[S.path]/.JRCLUST/[probe name]_|_[reference]/`: `jrclust.prm` (the
parameters) and `jrclust_res.mat` (the results), alongside JRCLUST's intermediate files
`jrclust_raw.jrc`, `jrclust_filt.jrc`, `jrclust_features.jrc` and `jrclust_hist.jrc`.
`ndi.fun.probe.import.jrclust.status(S, probe)` reports where a probe stands.

Detection and sorting each stamp `jrclust_res.mat`, and NDI reads those stamps rather
than guessing:

| State | How NDI decides |
| -- | -- |
| `detected` | `jrclust_res.mat` holds `spikeTimes` (or JRCLUST's `detectedOn` stamp) |
| `features` | `jrclust_features.jrc` is still on disk — `jrc sort` reads it and stops with *cannot sort without features* if it is gone, so detection has to be re-run |
| `sorted` | the file holds `spikeClusters` (or the `sortedOn` stamp) |
| `curated` | JRCLUST stamped `curatedOn`, which it does only when the curator saves |
| `annotated` | at least one unit carries a non-empty note |

## Editing the parameters

The parameter file is a plain MATLAB script of assignments. The ones most often changed:

```matlab
useGPU = 0;             % unless you have a compatible GPU
maxSecLoad = 500;       % seconds of data to load at a time; keep it within your RAM

% probe geometry (filled in from the probe's NDI geometry when it has one)
shankMap = ones(32,1);                  % shank of each site
depths = 0:50:(16-1)*50;
siteLoc = [depths(floor(1+(0:0.5:15.5)))' depths(1+mod(0:31,2))'];
siteMap = [25:32 16:-1:1 17:24];        % site i is recorded on channel siteMap(i)

ignoreChans = [1:8 25:32];  % channels that were not working
nSiteDir = [];              % leave empty so sites are grouped by evtGroupRad
evtGroupRad = 75;           % group sites within 75 um (use ~800 to group them all)
```

If the probe has no geometry document, NDI writes a placeholder single-column geometry
and warns; set `siteLoc`, `siteMap` and `shankMap` by hand before sorting.

## Annotation decides what is imported

The importer reads each unit's JRCLUST curation note. By default, units noted `single`
are imported with `quality_number` 1 and units noted `multi` with `quality_number` 4;
every other unit, including unannotated ones, is skipped. Change that with
`qualityLabels` and `qualityValues`:

```matlab
ndi.fun.probe.import.jrclust.probe(S, p{1}, ...
    'qualityLabels', ["single","multi","unstable"], 'qualityValues', [1 4 5]);
```

Sorting alone does not annotate anything. JRCLUST creates an empty note for every unit
when it commits the clustering during `jrc sort`, so a sort nobody has labelled would
import zero neurons; the importer refuses it instead, with
`ndi:fun:probe:import:jrclust:probe:notAnnotated`. Annotate the units in step 6 and save
before importing.

Use `'dryRun', true` to see what would be imported without touching the database.

## What the import creates

For each imported unit:

* an `ndi.neuron` element named `[probe name]_[reference]_[unit id]`, with the unit's
  spike times added as epochs (JRCLUST's concatenated sample indices are mapped back
  into each epoch's local device time), and
* a `neuron_extracellular` document with the mean waveform, the waveform sample times,
  the cluster index and the quality label/number.

A `jrclust_clusters` document that depends on the probe records the MD5 checksum of the
results file. Importing twice does nothing the second time; if the sort has changed (or
`'force',1` is passed), the previously imported neurons are removed and replaced.

## See also

* `ndi.fun.probe.export.jrclust` — write the parameter file
* `ndi.fun.probe.import.jrclust.run`, `.curate`, `.traces` — drive JRCLUST
* `ndi.fun.probe.import.jrclust.probe`, `.session` — import the results
* `ndi.fun.probe.import.jrclust.status`, `.install` — what is done, what is installed
* `ndi.gui.app.jrclust` — the app
