function probe(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE - import curated Kilosort spike sorting results into NDI
%
% NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE(S, PROBE, ...)
%
% Imports curated Kilosort/Phy output for an ndi.probe (or ndi.element) PROBE that
% is part of the ndi.session S. For each curated cluster that passes the quality
% filter, this function creates:
%
%   1) an ndi.neuron element named [PROBE.name '_' N], where N is the cluster id,
%      with spike times added as epochs (mapped back from the concatenated Kilosort
%      sample stream into each NDI epoch's local time), and
%   2) an 'neuron_extracellular' ndi.document holding the mean waveform, sample
%      counts, cluster index, and quality (label/number) for that neuron.
%
% This function is the import-side analog of NDI.FUN.PROBE.EXPORT.ALL_BINARY /
% NDI.FUN.PROBE.EXPORT.BINARY: it expects the Kilosort output to live in the same
% directory the binary was exported to, namely
%
%       [S.path]/[kilosort_dir]/[probe_directory]/[subdir]/
%
%   The [probe_directory] name comes from ndi.fun.file.elementDirectoryName;
%   for a probe named 'ctx' with reference 1 it is 'ctx_-_1'. Folders written
%   by older versions of NDI, which used a '|' separator ('ctx_|_1'), are still
%   found and used if they are present.
%
%
% (spaces in the element string are replaced by underscores, matching the export).
% By default 'subdir' is 'kilosort_output', so the curated files are expected in
% a 'kilosort_output' subfolder of the probe's directory. Set 'subdir' to a
% different name to use a different subfolder, or pass 'noSubFolder',true to look
% for the files directly in the probe's directory (no subfolder).
% The chosen directory is expected to contain the curated Kilosort/Phy files:
%
%       spike_times.npy      - global (concatenated) sample index of each spike
%       spike_clusters.npy   - curated cluster id of each spike
%       spike_templates.npy  - template id of each spike (for waveforms)
%       templates.npy        - nTemplates x nSamples x nChannels template shapes
%       amplitudes.npy       - per-spike template scaling amplitude
%       cluster_group.tsv    - (or cluster_KSLabel.tsv / cluster_info.tsv) curation labels
%       whitening_mat_inv.npy - (optional) used to un-whiten template waveforms
%       params.py            - (optional) Phy parameters; its 'n_channels_dat',
%                              'dtype' and 'offset' describe the raw recording's
%                              layout (used when recalculating wide mean waveforms,
%                              see below). Its 'dat_path' is NOT used to open a
%                              binary (see the note below).
%
% Note: the raw recording's file name is NOT stored in any of the .npy files
% (they hold only numeric arrays). Phy records a 'dat_path' in params.py, but for
% externally sorted data that path frequently points at Kilosort's whitened,
% filtered temporary file (e.g. 'temp_wh.dat') rather than the true raw recording,
% and cannot be relied on to exist - so this importer never opens it.
%
% The spike sample indices in spike_times.npy are treated as positions in the
% concatenated stream of the probe's epochs (in probe.epochtable() order), the same
% ordering used by ndi.fun.probe.export.binary. The function checks that all spike
% indices fall within the total sample count of the probe's epochs and errors
% (ndi:fun:probe:import:kilosort:probe:sampleOutOfRange) if any fall outside, which
% indicates the sort does not correspond to this probe's epochs.
%
% A 'kilosort_clusters' ndi.document is created that depends on PROBE and stores the
% MD5 checksum of spike_clusters.npy. This is used to detect whether the curation has
% changed since a previous import: if the checksum is unchanged the function does
% nothing (unless 'force' is 1); if it has changed, the previously imported neurons
% and documents are removed and the import is repeated.
%
% MEAN WAVEFORMS AND THE RAW BINARY
% By default ('RecalculateMeanWaveforms' true) each neuron's mean waveform is
% recomputed over a wide window ('RecalculateMeanWaveformT0' to
% 'RecalculateMeanWaveformT1', default -5 ms to +5 ms) by reading the raw binary
% recording directly, because the Kilosort templates are only ~2 ms wide. All
% clusters are recomputed together in a single streaming pass over the binary (see
% ndi.fun.probe.import.kilosort.recalculatemeanwaveforms), so the file is read - and,
% when high-pass filtering, filtered - once rather than once per cluster; pass
% 'progressbar',true to watch its progress. The raw binary is located automatically,
% in this order:
%   1) an explicit 'binary_file' option, if given;
%   2) the '.metadata' sidecar written next to the binary by
%      ndi.fun.probe.export.binary (present when the data were exported from NDI).
% If neither is available (e.g. data sorted OUTSIDE NDI, so there is no '.metadata'
% sidecar), the importer PROMPTS you to select the raw recording and its Neuropixels
% generation. It deliberately does NOT read Kilosort's params.py 'dat_path', because
% for external sorts that often points at Kilosort's whitened, filtered temporary
% file (e.g. 'temp_wh.dat') - which is not the raw data and may not exist. On a
% headless/automated run pass 'RawFile' and 'ProbeType' to supply these without a
% dialog (and 'PromptForRawFile',false to fail rather than block on a dialog).
%
% Because a hand-selected raw recording is UNFILTERED (it carries the DC offset and
% LFP band that Kilosort's temp file had already removed), the raw data are high-pass
% filtered before the spike shapes are extracted ('HighPassFilter' true by default:
% a zero-phase Chebyshev type I filter, 'HighPassCutoff' 300 Hz, 'HighPassOrder' 4,
% 'HighPassRipple' 0.8 dB). The same filtering is applied when reading the NDI
% '.metadata' binary (also raw), so both routes yield comparably conditioned shapes.
%
% NEUROPIXELS UNITS: a raw SpikeGLX recording stores int16 ADC counts; the decode to
% volts is fixed by the probe generation ('ProbeType'): 'NP1' (Neuropixels 1.0) uses
% volts = int16 * 0.6/(512*500); 'NP2' (Neuropixels 2.0) uses volts = int16 *
% 0.5/(8192*80). See ndi.fun.probe.import.kilosort.neuropixelsmultiplier. The read
% stride (channel count) of a user-selected raw file is taken from its SpikeGLX
% '.meta' sidecar (nSavedChans), else 'RawNumChannels', else a prompt - NOT from
% n_channels_dat, which is the count of the (missing) sorted file and usually differs
% (raw AP band 385 = 384 electrodes + 1 sync, vs an NDI export's 384 electrodes).
%
% If the binary cannot be found and no raw file is selected, the mean waveforms fall
% back to the narrow Kilosort templates and a warning is issued.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kilosort_dir ('kilosort')| Name of the directory holding the kilosort output   |
% | subdir                   | Subfolder within the probe's directory that holds   |
% |  ('kilosort_output')     |   the curated files. Set to '' or use noSubFolder   |
% |                          |   to read directly from the probe's directory.      |
% | noSubFolder (false)      | If true, ignore 'subdir' and read the curated files |
% |                          |   directly from the probe's directory.              |
% | quality_labels           | String array of curation labels to import. Labels   |
% |   (["good" "mua"])        |   are matched case-insensitively. You may pass your  |
% |                          |   own custom tags here.                             |
% | quality_values ([1 4])   | Numeric quality_number assigned to each label in    |
% |                          |   quality_labels (parallel array). Defaults follow  |
% |                          |   the convention single=1, multi=4.                 |
% | kilosort_version ('2.5') | Version of Kilosort that produced the sort. Recorded |
% |                          |   in the 'app' provenance of the created documents   |
% |                          |   (app.name = 'Kilosort<ver> to phy to              |
% |                          |   ndi.fun.probe.import.kilosort', app.version=<ver>). |
% |                          |   Defaults to '2.5' (the assumption for MATLAB data).|
% | waveform_source          | 'templates' (amplitude-weighted average of the      |
% |   ('templates')          |   contributing Kilosort templates) or 'none'.       |
% | RecalculateMeanWaveforms | If true (and waveform_source is 'templates'),       |
% |   (true)                 |   recompute each mean waveform by reading a wide    |
% |                          |   window directly from the raw binary recording     |
% |                          |   instead of using the (~2 ms) Kilosort templates.  |
% |                          |   Falls back to templates (with a warning) if the   |
% |                          |   binary cannot be located.                         |
% | RecalculateMeanWaveformT0| Window start relative to each spike, in seconds,    |
% |   (-0.005)               |   used when recalculating from the binary.          |
% | RecalculateMeanWaveformT1| Window end relative to each spike, in seconds,      |
% |   (+0.005)               |   used when recalculating from the binary.          |
% | RecalculateMeanWaveform- | Maximum number of spikes averaged per cluster when  |
% |   MaxSpikes (1000)       |   recalculating (an evenly spaced subset is used    |
% |                          |   beyond this; Inf uses every spike).               |
% | RecalculateChunkMemory-  | Peak-memory ceiling (bytes) for the single-pass     |
% |   Bytes (2e9)            |   recalculation. The streaming chunk size is derived |
% |                          |   from it (accounting for the filtfilt overhead), so |
% |                          |   the whole pass stays under it. Raise it if the     |
% |                          |   machine has spare RAM.                             |
% | binary_file ('')         | Explicit path to the raw binary recording. When     |
% |                          |   empty, it is located from the export '.metadata'  |
% |                          |   sidecar, else the user is prompted (see below).   |
% | HighPassFilter (true)    | High-pass filter the raw data before extracting     |
% |                          |   spike shapes (raw recordings are unfiltered). Uses |
% |                          |   a zero-phase Chebyshev type I filter.             |
% | HighPassCutoff (300)     | High-pass cutoff frequency, Hz.                     |
% | HighPassOrder (4)        | Chebyshev type I filter order.                      |
% | HighPassRipple (0.8)     | Passband ripple Rp, dB.                             |
% | PromptForRawFile (true)  | If the binary is not found automatically, prompt    |
% |                          |   (uigetfile + probe generation) for the raw file.  |
% |                          |   Set false for headless runs (then RawFile and     |
% |                          |   ProbeType must be supplied).                       |
% | RawFile ('')             | Path to the raw recording to use when the binary is |
% |                          |   not found automatically (skips the file dialog).  |
% | ProbeType ('')           | 'NP1' or 'NP2': the Neuropixels generation of a     |
% |                          |   selected raw file, fixing the int16->volts units  |
% |                          |   (skips the probe-generation dialog).              |
% | RawNumChannels (NaN)     | Override the read stride (channel count) of a       |
% |                          |   selected raw file. When NaN it is read from the   |
% |                          |   SpikeGLX .meta sidecar (nSavedChans), else the    |
% |                          |   user is prompted. NOT n_channels_dat (the count   |
% |                          |   of the sorted file, usually 384 vs raw 385).      |
% | force (0)                | Re-import even if the checksum is unchanged.        |
% | dryRun (false)           | If true, report what would be imported (neurons,    |
% |                          |   spike counts, documents that would be removed)    |
% |                          |   without making any changes to the database.       |
% | progressbar (false)      | If true, show an ndi.gui.component.ProgressBarWindow |
% |                          |   tracking the single-pass mean-waveform recalcula-  |
% |                          |   tion and the cluster import loop. Degrades quietly |
% |                          |   if no display is available.                       |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KILOSORT.SESSION, NDI.FUN.PROBE.EXPORT.ALL_BINARY
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.kilosort.probe(S, p{1});
%

    arguments
        S
        probe
        options.kilosort_dir (1,:) char = 'kilosort'
        options.subdir (1,:) char = 'kilosort_output'
        options.noSubFolder (1,1) logical = false
        options.quality_labels (1,:) string = ["good" "mua"]
        options.quality_values (1,:) double = [1 4]
        options.kilosort_version (1,:) char = '2.5'
        options.waveform_source (1,:) char {mustBeMember(options.waveform_source,{'templates','none'})} = 'templates'
        options.RecalculateMeanWaveforms (1,1) logical = true
        options.RecalculateMeanWaveformT0 (1,1) double = -0.005
        options.RecalculateMeanWaveformT1 (1,1) double = 0.005
        options.RecalculateMeanWaveformMaxSpikes (1,1) double = 1000
        options.RecalculateChunkMemoryBytes (1,1) double {mustBePositive} = 2e9
        options.binary_file (1,:) char = ''
        options.HighPassFilter (1,1) logical = true
        options.HighPassCutoff (1,1) double {mustBePositive} = 300
        options.HighPassOrder (1,1) double {mustBePositive} = 4
        options.HighPassRipple (1,1) double {mustBePositive} = 0.8
        options.PromptForRawFile (1,1) logical = true
        options.RawFile (1,:) char = ''
        options.ProbeType (1,:) char = ''
        options.RawNumChannels (1,1) double = NaN
        options.force (1,1) double = 0
        options.dryRun (1,1) logical = false
        options.progressbar (1,1) logical = false
        options.verbose (1,1) double = 1
    end

    if numel(options.quality_labels)~=numel(options.quality_values),
        error('quality_labels and quality_values must have the same number of elements.');
    end;

    verbose = options.verbose;
    dryRun = options.dryRun;
    % In a dry run we always report the plan, regardless of the verbose setting.
    report = verbose || dryRun;
    if dryRun, pfx = '[dry run] '; else, pfx = ''; end;

    % Step 1: locate the kilosort output directory (mirror of the export layout)

    [probedir, elestr] = ndi.fun.file.elementDirectory(fullfile(S.path, options.kilosort_dir), probe);
    subdir = options.subdir;
    if options.noSubFolder,
        subdir = '';
    end;
    kdir = fullfile(probedir, subdir);

    if ~isfolder(kdir),
        error(['Kilosort directory not found: ' kdir '. Was the data exported with ndi.fun.probe.export.all_binary?']);
    end;

    spike_times_file = fullfile(kdir,'spike_times.npy');
    spike_clusters_file = fullfile(kdir,'spike_clusters.npy');
    if ~isfile(spike_times_file) || ~isfile(spike_clusters_file),
        error(['Expected curated files spike_times.npy and spike_clusters.npy in ' kdir '.']);
    end;

    if report,
        disp([pfx 'Importing kilosort results for probe ' elestr ' from ' kdir '.']);
    end;

    % Step 2: idempotency - has this curation already been imported?

    md5_value = ndi.fun.file.MD5(spike_clusters_file);

    q_existing = ndi.query('','isa','kilosort_clusters','') & ...
        ndi.query('','depends_on','element_id',probe.id());
    olddocs = S.database_search(q_existing);

    if ~isempty(olddocs),
        if numel(olddocs)==1 && ~options.force,
            existing_md5 = olddocs{1}.document_properties.kilosort_clusters.curated_output_MD5_checksum;
            if strcmp(existing_md5, md5_value),
                if report,
                    disp([pfx 'Curation is unchanged since the last import; nothing to do (use ''force'',1 to re-import).']);
                end;
                return;
            end;
        end;
        if report,
            disp([pfx 'Would remove ' int2str(numel(olddocs)) ' previously imported kilosort cluster document(s) ' ...
                'and their dependent neurons.']);
        end;
        if ~dryRun,
            for i=1:numel(olddocs),
                ndi.fun.probe.import.kilosort.removeold(S, olddocs{i});
            end;
        end;
    end;

    % Step 3: read the curated kilosort output

    npyread = @(f) ndi.util.readNPY(f);

    spike_samples_global = double(npyread(spike_times_file)); % 0-based sample index into concatenated stream
    spike_clusters = double(npyread(spike_clusters_file));

    [cluster_ids, cluster_labels] = ndi.fun.probe.import.kilosort.labels(kdir);

    % Step 4: build the sample <-> epoch map directly from the probe.
    % This matches how ndi.fun.probe.export.binary concatenated the epochs (in
    % probe.epochtable() order), so the boundaries align with the exported binary.

    et = probe.epochtable();
    nEpochs = numel(et);
    epoch_counts = zeros(nEpochs,1);
    epoch_ids = cell(nEpochs,1);
    epoch_t0t1 = cell(nEpochs,1);
    epoch_clock = cell(nEpochs,1);
    sample_rate = NaN;

    for e=1:nEpochs,
        epoch_ids{e} = et(e).epoch_id;
        ss = probe.times2samples(et(e).epoch_id, et(e).t0_t1{1}); % same convention as export.binary
        epoch_counts(e) = ss(2) - ss(1) + 1;
        % find the dev_local_time clock for spike-time storage
        found = 0;
        for c=1:numel(et(e).epoch_clock),
            if strcmp(et(e).epoch_clock{c}.type,'dev_local_time'),
                found = c; break;
            end;
        end;
        if ~found,
            error(['Epoch ' et(e).epoch_id ' has no ''dev_local_time'' clock.']);
        end;
        epoch_clock{e} = et(e).epoch_clock{found};
        epoch_t0t1{e} = et(e).t0_t1{found};
        if isnan(sample_rate),
            sample_rate = probe.samplerate(et(e).epoch_id);
        end;
    end;

    bounds0 = [0; cumsum(epoch_counts)]; % 0-based, half-open boundaries per epoch
    total_samples = bounds0(end);

    % Step 4b: validate that the kilosort spike indices fit within the NDI epochs.
    % The spike sample indices are positions in the concatenated stream that was
    % (or would have been) exported. If the data were sorted externally (e.g. a
    % SpikeGLX recording) without using ndi.fun.probe.export.all_binary, the
    % concatenation may not match NDI's epochs and spikes can fall past the end of
    % the last epoch. Catch that here rather than silently dropping spikes.
    %
    % total_samples equals sum(epoch_sample_counts) recorded in the '.metadata'
    % sidecar written by ndi.fun.probe.export.binary; both are computed from the
    % probe via times2samples, so the probe is the authoritative reference.
    if ~isempty(spike_samples_global),
        max_sample = max(spike_samples_global); % 0-based
        n_overrun = sum(spike_samples_global >= total_samples | spike_samples_global < 0);
        if n_overrun>0,
            error('ndi:fun:probe:import:kilosort:probe:sampleOutOfRange', ...
                ['%d of %d spike sample indices fall outside the probe''s epochs ' ...
                '[0, %d). The largest spike sample index is %d. This usually means ' ...
                'the kilosort output was sorted on a recording whose concatenation ' ...
                'does not match this probe''s epochs (epochtable order or sample ' ...
                'rate). Verify that the sorted data correspond to this probe and ' ...
                'that sum(epoch_sample_counts) in the .metadata sidecar matches the ' ...
                'length of the sorted recording.'], ...
                n_overrun, numel(spike_samples_global), total_samples, max_sample);
        end;
    end;

    % Step 5: precompute waveform data if requested.
    % When RecalculateMeanWaveforms is set we read wide mean waveforms straight from
    % the raw binary (the Kilosort templates are only ~2 ms wide); locate the binary
    % once here and fall back to the template method if it cannot be found.

    use_recalc = false;
    bininfo = [];
    if strcmp(options.waveform_source,'templates'),
        if options.RecalculateMeanWaveforms,
            bininfo = ndi.fun.probe.import.kilosort.binaryinfo(kdir, 'binary_file', options.binary_file);
            if ~bininfo.found,
                % The NDI binary (explicit file or '.metadata' sidecar) is not
                % available. We deliberately do NOT read Kilosort's params.py
                % 'dat_path' (it often names a whitened/filtered temp file that may
                % not exist); instead prompt the user to select the true raw
                % recording and its Neuropixels generation (which sets the units
                % multiplier). Honors RawFile/ProbeType for headless runs.
                try
                    bininfo = ndi.fun.probe.import.kilosort.promptrawbinary(bininfo, ...
                        'RawFile', options.RawFile, 'ProbeType', options.ProbeType, ...
                        'PromptForRawFile', options.PromptForRawFile, ...
                        'num_channels', options.RawNumChannels, ...
                        'expectedSamples', total_samples);
                catch ME
                    warning('ndi:fun:probe:import:kilosort:probe:rawFileFailed', ...
                        ['Could not obtain a raw recording for waveform recalculation: %s ' ...
                        'Falling back to the (narrow) template-based mean waveforms.'], ...
                        ME.message);
                    bininfo.found = false;
                end
            end;
            if bininfo.found,
                use_recalc = true;
                if report,
                    hpmsg = '';
                    if options.HighPassFilter,
                        hpmsg = [', high-pass ' num2str(options.HighPassCutoff) ' Hz ' ...
                            '(Chebyshev-I order ' num2str(options.HighPassOrder) ')'];
                    end;
                    disp([pfx 'Recalculating mean waveforms from binary ' bininfo.file ...
                        ' over [' num2str(options.RecalculateMeanWaveformT0) ', ' ...
                        num2str(options.RecalculateMeanWaveformT1) '] s' hpmsg '.']);
                end;
            else,
                warning('ndi:fun:probe:import:kilosort:probe:noBinary', ...
                    ['RecalculateMeanWaveforms is true but no raw binary could be located ' ...
                    'near ' kdir ' and none was selected. Falling back to the (narrow) ' ...
                    'template-based mean waveforms. Pass ''binary_file'' or ''RawFile'' to ' ...
                    'specify the recording, or set ''RecalculateMeanWaveforms'',false to ' ...
                    'silence this warning.']);
            end;
        end;
        if ~use_recalc,
            [templates, spike_templates, amplitudes, winv] = ndi.fun.probe.import.kilosort.waveformdata(kdir);
        end;
    end;

    % Step 5b: when recalculating, compute the wide mean waveform for every cluster
    % that will be imported in a SINGLE streaming pass over the binary - reading (and,
    % when filtering, filtering) the file once for all clusters rather than once per
    % cluster. The per-cluster results are looked up by cluster id in the loop below.
    recalc_cids = [];
    recalcWf = {};
    recalcWst = [];
    if use_recalc && ~dryRun,
        recalc_want = lower(string(options.quality_labels));
        keepmask = false(1, numel(cluster_ids));
        for ci=1:numel(cluster_ids),
            keepmask(ci) = any(recalc_want == lower(string(cluster_labels(ci))));
        end;
        recalc_cids = cluster_ids(keepmask);
        if ~isempty(recalc_cids),
            recalc_cb = [];
            recalc_pbw = [];
            if options.progressbar,
                recalc_pbw = ndi.gui.component.ProgressBarWindow(['NDI kilosort import: ' elestr]);
                recalc_pbw.addBar('Label',['Recalculating mean waveforms (' elestr ')'], ...
                    'Tag','recalc_waveforms');
                recalc_cb = @(frac,msg) recalc_pbw.updateBar('recalc_waveforms', max(0,min(1,frac)));
            end;
            if report,
                disp([pfx 'Recalculating mean waveforms for ' int2str(numel(recalc_cids)) ...
                    ' cluster(s) in a single pass over ' bininfo.file '.']);
            end;
            [recalcWf, recalcWst] = ndi.fun.probe.import.kilosort.recalculatemeanwaveforms(...
                bininfo.file, bininfo.num_channels, spike_samples_global, spike_clusters, ...
                recalc_cids, sample_rate, ...
                options.RecalculateMeanWaveformT0, options.RecalculateMeanWaveformT1, ...
                'dtype', bininfo.dtype, 'byteOrder', bininfo.byteOrder, ...
                'headerOffsetBytes', bininfo.headerOffsetBytes, ...
                'multiplier', bininfo.multiplier, ...
                'maxSpikes', options.RecalculateMeanWaveformMaxSpikes, ...
                'epochBounds', bounds0, ...
                'maxChunkBytes', options.RecalculateChunkMemoryBytes, ...
                'highpass', options.HighPassFilter, ...
                'hp_cutoff', options.HighPassCutoff, ...
                'hp_order', options.HighPassOrder, ...
                'hp_ripple', options.HighPassRipple, ...
                'progressfcn', recalc_cb, 'verbose', logical(verbose));
            if ~isempty(recalc_pbw),
                try, recalc_pbw.removeBar('recalc_waveforms'); catch, end; %#ok<CTCH>
            end;
        end;
    end;

    % Step 6: create the provenance/cluster document (neurons will depend on it)

    % These neurons are produced by an external, multi-stage pipeline (a
    % spike sorter, then manual curation in Phy, then this importer) rather
    % than a single program. The 'app' sub-document only describes one app, so
    % as an interim measure we record the whole pipeline in 'app.name' and the
    % Kilosort version in 'app.version'. Kilosort does not reliably write its
    % version into the Phy output directory, so the version is taken from the
    % 'kilosort_version' option (default '2.5', the assumption for MATLAB-origin
    % data). See https://github.com/VH-Lab/NDI-matlab/issues for the proposal to
    % let 'app' hold an array of external program entries.
    matlab_ver = ver('MATLAB');
    ks_ver = options.kilosort_version;
    app_struct = struct('name',['Kilosort' ks_ver ' to phy to ndi.fun.probe.import.kilosort'], ...
        'version', ks_ver, ...
        'url','https://github.com/VH-Lab/NDI-matlab', ...
        'os', computer, 'os_version','', ...
        'interpreter','MATLAB','interpreter_version', matlab_ver.Version);

    if ~dryRun,
        kc = ndi.document('kilosort_clusters','app',app_struct, ...
            'base.session_id', S.id(), ...
            'kilosort_clusters.kilosort_directory', [options.kilosort_dir '/' elestr], ...
            'kilosort_clusters.curated_output_MD5_checksum', md5_value);
        kc = kc.set_dependency_value('element_id', probe.id());
        S.database_add(kc);
    end;

    % Step 7: assemble each cluster that passes the quality filter, then commit
    % them all in batched database writes via ndi.element.timeseries.addMultiple
    % (constructing each neuron and adding each epoch one at a time is far slower
    % because every epoch requires a separate database search and write).

    want_labels = lower(string(options.quality_labels));

    specs = struct('name',{},'reference',{},'type',{},'epochs',{},'extra_documents',{});
    n_imported = 0;
    for ci=1:numel(cluster_ids),
        cid = cluster_ids(ci);
        thislabel = lower(string(cluster_labels(ci)));
        match = find(want_labels==thislabel,1);
        if isempty(match),
            if report,
                disp([pfx '  Cluster ' int2str(cid) ' (label ''' char(cluster_labels(ci)) ''') skipped.']);
            end;
            continue;
        end;
        qnum = options.quality_values(match);

        % this cluster's spikes (0-based global samples)
        I = find(spike_clusters==cid);
        g0 = spike_samples_global(I);
        n_imported = n_imported + 1;

        % neuron name includes the probe reference so neurons from probes that
        % share a name (e.g. gust_ctx ref 1..6) are distinguishable:
        % <probe name>_<probe reference>_<cluster id>
        neuron_name = [probe.name '_' int2str(probe.reference) '_' int2str(cid)];

        if dryRun,
            disp([pfx '  Would import cluster ' int2str(cid) ' as neuron ' neuron_name ...
                ' (' char(cluster_labels(ci)) ', quality ' int2str(qnum) ', ' int2str(numel(I)) ' spikes), ' ...
                'with a neuron_extracellular document and spike trains across ' int2str(nEpochs) ' epoch(s).']);
            continue;
        end;

        % the mean waveform
        if strcmp(options.waveform_source,'templates'),
            if use_recalc,
                % look up this cluster's wide mean waveform from the single-pass
                % result computed in Step 5b; the spike sample is (approximately) the
                % trough, so waveform_sample_times run from T0 to T1 with 0 at the spike.
                pos = find(recalc_cids==cid, 1);
                if isempty(pos),
                    meanWf = zeros(max(numel(recalcWst),1), bininfo.num_channels);
                else,
                    meanWf = recalcWf{pos};
                end;
                wst = recalcWst;
            else,
                meanWf = ndi.fun.probe.import.kilosort.meanwaveform(cid, spike_clusters, ...
                    spike_templates, amplitudes, templates, winv);
                % build waveform_sample_times relative to the trough
                [~, troughchan] = min(min(meanWf,[],1));
                [~, troughsamp] = min(meanWf(:,troughchan));
                wst = ((0:size(meanWf,1)-1)' - (troughsamp-1)) / sample_rate;
            end;
        else,
            meanWf = [];
            wst = [];
        end;

        ne = struct();
        ne.number_of_samples_per_channel = max(size(meanWf,1),1);
        ne.number_of_channels = max(size(meanWf,2),1);
        ne.mean_waveform = meanWf;
        ne.waveform_sample_times = wst;
        ne.cluster_index = cid;
        ne.quality_number = qnum;
        ne.quality_label = char(cluster_labels(ci));

        % the neuron_extracellular document (addMultiple sets its element_id)
        neuron_doc = ndi.document('neuron_extracellular','app',app_struct, ...
            'neuron_extracellular', ne, 'base.session_id', S.id());
        neuron_doc = neuron_doc.set_dependency_value('spike_clusters_id', kc.id());

        % the spike trains, one epoch entry per probe epoch (empty where no spikes)
        clear epochs;
        for e=1:nEpochs,
            in_epoch = find(g0 >= bounds0(e) & g0 < bounds0(e+1));
            if isempty(in_epoch),
                spike_times_local = [];
            else,
                local1 = (g0(in_epoch) - bounds0(e)) + 1; % 1-based local NDI sample
                spike_times_local = probe.samples2times(epoch_ids{e}, double(local1));
                spike_times_local = spike_times_local(:);
            end;
            % wrap array-valued fields in cells so struct() stores them as-is
            % (rather than broadcasting to a struct array)
            epochs(e) = struct('epoch_id', epoch_ids{e}, 'epoch_clock', epoch_clock(e), ...
                't0_t1', {epoch_t0t1{e}}, 'timepoints', {spike_times_local}, ...
                'datapoints', {ones(size(spike_times_local))}); %#ok<AGROW>
        end;

        specs(end+1) = struct('name', neuron_name, 'reference', probe.reference, ...
            'type', 'spikes', 'epochs', {epochs}, ...
            'extra_documents', {{neuron_doc}}); %#ok<AGROW>

        if verbose,
            disp(['  Prepared cluster ' int2str(cid) ' as neuron ' neuron_name ...
                ' (' char(cluster_labels(ci)) ', ' int2str(numel(I)) ' spikes).']);
        end;
    end;

    if ~dryRun && ~isempty(specs),
        ndi.element.timeseries.addMultiple(S, probe, specs, ...
            'element_class','ndi.neuron', ...
            'progressbar', options.progressbar, ...
            'verbose', logical(verbose));
    end;

    if report,
        if dryRun,
            disp([pfx 'Done. Would import ' int2str(n_imported) ' neuron(s) for probe ' elestr '. ' ...
                'No changes were made to the database.']);
        else,
            disp(['Done. Imported ' int2str(n_imported) ' neuron(s) for probe ' elestr '.']);
        end;
    end;

end
