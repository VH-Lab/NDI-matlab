function probe(S, probe, options)
% NDI.FUN.PROBE.IMPORT.KIASORT.PROBE - import KIASORT spike sorting results into NDI
%
% NDI.FUN.PROBE.IMPORT.KIASORT.PROBE(S, PROBE, ...)
%
% Imports KIASORT (https://github.com/VH-Lab/KIASORT) output for an ndi.probe (or
% ndi.element) PROBE that is part of the ndi.session S. For each cross-channel unit
% that passes the quality filter, this function creates:
%
%   1) an ndi.neuron element named [PROBE.name '_' PROBE.reference '_' N], where N
%      is the KIASORT unit id, with spike times added as epochs (mapped back from
%      the concatenated exported sample stream into each NDI epoch's local time), and
%   2) an 'neuron_extracellular' ndi.document holding the mean waveform, sample
%      counts, cluster index, and quality (label/number) for that neuron.
%
% This function is the KIASORT analog of NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE and the
% import-side complement of NDI.FUN.PROBE.EXPORT.ALL_BINARY / .BINARY: it expects
% KIASORT to have been run with its output folder set to
%
%       [S.path]/[kiasort_dir]/[probe_elementstring]/[subdir]/
%
% (spaces in the element string are replaced by underscores, matching the export).
% By default 'subdir' is 'kiasort_output'. KIASORT writes its results into two
% subfolders of that output folder:
%
%       RES_Sorted/spike_idx.h5      - 1-based absolute sample index of each spike
%       RES_Sorted/unifiedLabels.h5  - cross-channel unit id of each spike
%       RES_Sorted/channelNum.h5     - detection channel of each spike
%       Sorted_Samples/sorted_samples.mat - per-unit stats (mean waveforms)
%
% KIASORT spike indices are 1-based positions in the sorted recording; NDI treats
% them (after conversion to 0-based in ndi.fun.probe.import.kiasort.results) as
% positions in the concatenated stream of the probe's epochs, in probe.epochtable()
% order - the same ordering ndi.fun.probe.export.binary used to write the data.
% The function checks that all spike indices fall within the total sample count of
% the probe's epochs and errors (ndi:fun:probe:import:kiasort:probe:sampleOutOfRange)
% if any fall outside, which indicates the sort does not correspond to this probe.
%
% A 'kiasort_clusters' ndi.document is created that depends on PROBE and stores the
% MD5 checksum of the unifiedLabels HDF5 file. This detects whether the sort has
% changed since a previous import: if the checksum is unchanged the function does
% nothing (unless 'force' is 1); if it has changed, the previously imported neurons
% and documents are removed and the import is repeated.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kiasort_dir ('kiasort')  | Name of the directory holding the KIASORT output    |
% | subdir                   | Subfolder within the probe's directory that is the  |
% |  ('kiasort_output')      |   KIASORT output folder (containing RES_Sorted/).   |
% |                          |   Set '' or use noSubFolder to read directly from   |
% |                          |   the probe's directory.                            |
% | noSubFolder (false)      | If true, ignore 'subdir' and read directly from the |
% |                          |   probe's directory.                                |
% | curated (false)          | Prefer KIASORT's '_curated' output files if present.|
% | quality_labels (["good"])| String array of curation labels to import. A plain  |
% |                          |   KIASORT sort labels every unit "good" (see        |
% |                          |   ndi.fun.probe.import.kiasort.labels).             |
% | quality_values ([1])     | quality_number assigned to each label (parallel).   |
% | kiasort_version ('')     | Version of KIASORT that produced the sort. Recorded |
% |                          |   in the 'app' provenance of the created documents. |
% | waveform_source          | 'samples' (mean waveform from KIASORT's per-unit    |
% |   ('samples')            |   sample statistics) or 'none'.                     |
% | force (0)                | Re-import even if the checksum is unchanged.        |
% | dryRun (false)           | Report what would be imported without changing the  |
% |                          |   database.                                         |
% | progressbar (false)      | Show an ndi.gui.component.ProgressBarWindow.        |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT.KIASORT.SESSION, NDI.FUN.PROBE.EXPORT.ALL_BINARY,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import.kiasort.probe(S, p{1});
%

    arguments
        S
        probe
        options.kiasort_dir (1,:) char = 'kiasort'
        options.subdir (1,:) char = 'kiasort_output'
        options.noSubFolder (1,1) logical = false
        options.curated (1,1) logical = false
        options.quality_labels (1,:) string = "good"
        options.quality_values (1,:) double = 1
        options.kiasort_version (1,:) char = ''
        options.waveform_source (1,:) char {mustBeMember(options.waveform_source,{'samples','none'})} = 'samples'
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

    % Step 1: locate the KIASORT output directory (mirror of the export layout)

    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    subdir = options.subdir;
    if options.noSubFolder,
        subdir = '';
    end;
    kdir = fullfile(S.path, options.kiasort_dir, elestr, subdir);

    if ~isfolder(kdir),
        error(['KIASORT directory not found: ' kdir '. Was the data exported with ndi.fun.probe.export.all_binary and sorted with KIASORT?']);
    end;

    res_dir = fullfile(kdir,'RES_Sorted');
    if ~isfolder(res_dir),
        error(['KIASORT RES_Sorted folder not found in ' kdir '. Was KIASORT run with this folder as its output?']);
    end;

    % resolve which output files (curated or not) will be read, so the idempotency
    % checksum targets the same file that ndi.fun.probe.import.kiasort.results reads
    suffix = '';
    if options.curated,
        if isfile(fullfile(res_dir,'spike_idx_curated.h5')) && ...
                isfile(fullfile(res_dir,'unifiedLabels_curated.h5')),
            suffix = '_curated';
        end;
    end;
    unified_file = fullfile(res_dir, ['unifiedLabels' suffix '.h5']);
    spike_idx_file = fullfile(res_dir, ['spike_idx' suffix '.h5']);
    if ~isfile(unified_file) || ~isfile(spike_idx_file),
        error(['Expected KIASORT files spike_idx' suffix '.h5 and unifiedLabels' suffix '.h5 in ' res_dir '.']);
    end;

    if report,
        disp([pfx 'Importing KIASORT results for probe ' elestr ' from ' res_dir '.']);
    end;

    % Step 2: idempotency - has this sort already been imported?

    md5_value = ndi.fun.file.MD5(unified_file);

    q_existing = ndi.query('','isa','kiasort_clusters','') & ...
        ndi.query('','depends_on','element_id',probe.id());
    olddocs = S.database_search(q_existing);

    if ~isempty(olddocs),
        if numel(olddocs)==1 && ~options.force,
            existing_md5 = olddocs{1}.document_properties.kiasort_clusters.curated_output_MD5_checksum;
            if strcmp(existing_md5, md5_value),
                if report,
                    disp([pfx 'Sort is unchanged since the last import; nothing to do (use ''force'',1 to re-import).']);
                end;
                return;
            end;
        end;
        if report,
            disp([pfx 'Would remove ' int2str(numel(olddocs)) ' previously imported KIASORT cluster document(s) ' ...
                'and their dependent neurons.']);
        end;
        if ~dryRun,
            for i=1:numel(olddocs),
                ndi.fun.probe.import.kiasort.removeold(S, olddocs{i});
            end;
        end;
    end;

    % Step 3: read the KIASORT output (spike samples are converted to 0-based here)

    R = ndi.fun.probe.import.kiasort.results(kdir, 'curated', options.curated, ...
        'need_stats', ~strcmp(options.waveform_source,'none'));

    spike_samples_global = R.spike_samples_global; % 0-based sample index into concatenated stream
    spike_units = R.spike_units;

    [unit_ids, unit_labels] = ndi.fun.probe.import.kiasort.labels(kdir, 'curated', options.curated);

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

    % Step 4b: validate that the KIASORT spike indices fit within the NDI epochs.
    % The (0-based) spike sample indices are positions in the concatenated stream
    % that was exported. If the data were sorted on a recording whose concatenation
    % does not match NDI's epochs, spikes can fall past the end of the last epoch;
    % catch that here rather than silently dropping spikes. total_samples equals
    % sum(epoch_sample_counts) recorded in the '.metadata' sidecar written by
    % ndi.fun.probe.export.binary; both are computed from the probe via
    % times2samples, so the probe is the authoritative reference.
    if ~isempty(spike_samples_global),
        max_sample = max(spike_samples_global); % 0-based
        n_overrun = sum(spike_samples_global >= total_samples | spike_samples_global < 0);
        if n_overrun>0,
            error('ndi:fun:probe:import:kiasort:probe:sampleOutOfRange', ...
                ['%d of %d spike sample indices fall outside the probe''s epochs ' ...
                '[0, %d). The largest spike sample index is %d. This usually means ' ...
                'the KIASORT output was sorted on a recording whose concatenation ' ...
                'does not match this probe''s epochs (epochtable order or sample ' ...
                'rate). Verify that the sorted data correspond to this probe and ' ...
                'that sum(epoch_sample_counts) in the .metadata sidecar matches the ' ...
                'length of the sorted recording.'], ...
                n_overrun, numel(spike_samples_global), total_samples, max_sample);
        end;
    end;

    % Step 5: provenance/cluster document (neurons will depend on it)

    % These neurons are produced by an external pipeline (KIASORT, optionally
    % followed by curation, then this importer). The 'app' sub-document only
    % describes one app, so we record the pipeline in 'app.name' and the KIASORT
    % version (if known) in 'app.version'.
    matlab_ver = ver('MATLAB');
    ks_ver = options.kiasort_version;
    app_struct = struct('name','KIASORT to ndi.fun.probe.import.kiasort', ...
        'version', ks_ver, ...
        'url','https://github.com/VH-Lab/KIASORT', ...
        'os', computer, 'os_version','', ...
        'interpreter','MATLAB','interpreter_version', matlab_ver.Version);

    if ~dryRun,
        kc = ndi.document('kiasort_clusters','app',app_struct, ...
            'base.session_id', S.id(), ...
            'kiasort_clusters.kiasort_directory', [options.kiasort_dir filesep elestr], ...
            'kiasort_clusters.curated_output_MD5_checksum', md5_value);
        kc = kc.set_dependency_value('element_id', probe.id());
        S.database_add(kc);
    end;

    % Step 6: assemble each unit that passes the quality filter, then commit them
    % all in batched database writes via ndi.element.timeseries.addMultiple.

    want_labels = lower(string(options.quality_labels));

    specs = struct('name',{},'reference',{},'type',{},'epochs',{},'extra_documents',{});
    n_imported = 0;
    for ci=1:numel(unit_ids),
        cid = unit_ids(ci);
        thislabel = lower(string(unit_labels(ci)));
        match = find(want_labels==thislabel,1);
        if isempty(match),
            if report,
                disp([pfx '  Unit ' int2str(cid) ' (label ''' char(unit_labels(ci)) ''') skipped.']);
            end;
            continue;
        end;
        qnum = options.quality_values(match);

        % this unit's spikes (0-based global samples)
        I = find(spike_units==cid);
        g0 = spike_samples_global(I);
        n_imported = n_imported + 1;

        % neuron name includes the probe reference so neurons from probes that
        % share a name (e.g. gust_ctx ref 1..6) are distinguishable:
        % <probe name>_<probe reference>_<unit id>
        neuron_name = [probe.name '_' int2str(probe.reference) '_' int2str(cid)];

        if dryRun,
            disp([pfx '  Would import unit ' int2str(cid) ' as neuron ' neuron_name ...
                ' (' char(unit_labels(ci)) ', quality ' int2str(qnum) ', ' int2str(numel(I)) ' spikes), ' ...
                'with a neuron_extracellular document and spike trains across ' int2str(nEpochs) ' epoch(s).']);
            continue;
        end;

        % the mean waveform
        if strcmp(options.waveform_source,'samples'),
            meanWf = ndi.fun.probe.import.kiasort.meanwaveform(cid, R.unit_stats);
        else,
            meanWf = [];
        end;
        if ~isempty(meanWf),
            % build waveform_sample_times relative to the trough
            [~, troughchan] = min(min(meanWf,[],1));
            [~, troughsamp] = min(meanWf(:,troughchan));
            wst = ((0:size(meanWf,1)-1)' - (troughsamp-1)) / sample_rate;
        else,
            wst = [];
        end;

        ne = struct();
        ne.number_of_samples_per_channel = max(size(meanWf,1),1);
        ne.number_of_channels = max(size(meanWf,2),1);
        ne.mean_waveform = meanWf;
        ne.waveform_sample_times = wst;
        ne.cluster_index = cid;
        ne.quality_number = qnum;
        ne.quality_label = char(unit_labels(ci));

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
            epochs(e) = struct('epoch_id', epoch_ids{e}, 'epoch_clock', epoch_clock(e), ...
                't0_t1', {epoch_t0t1{e}}, 'timepoints', {spike_times_local}, ...
                'datapoints', {ones(size(spike_times_local))}); %#ok<AGROW>
        end;

        specs(end+1) = struct('name', neuron_name, 'reference', probe.reference, ...
            'type', 'spikes', 'epochs', {epochs}, ...
            'extra_documents', {{neuron_doc}}); %#ok<AGROW>

        if verbose,
            disp(['  Prepared unit ' int2str(cid) ' as neuron ' neuron_name ...
                ' (' char(unit_labels(ci)) ', ' int2str(numel(I)) ' spikes).']);
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
