function import_kilosort(S, probe, options)
% NDI.FUN.PROBE.IMPORT_KILOSORT - import curated Kilosort spike sorting results into NDI
%
% NDI.FUN.PROBE.IMPORT_KILOSORT(S, PROBE, ...)
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
% This function is the import-side analog of NDI.FUN.PROBE.EXPORT_ALL_BINARY /
% NDI.FUN.PROBE.EXPORT_BINARY: it expects the Kilosort output to live in the same
% directory the binary was exported to, namely
%
%       [S.path]/[kilosort_dir]/[probe_elementstring]/
%
% (spaces in the element string are replaced by underscores, matching the export).
% That directory is expected to contain the curated Kilosort/Phy files:
%
%       spike_times.npy      - global (concatenated) sample index of each spike
%       spike_clusters.npy   - curated cluster id of each spike
%       spike_templates.npy  - template id of each spike (for waveforms)
%       templates.npy        - nTemplates x nSamples x nChannels template shapes
%       amplitudes.npy       - per-spike template scaling amplitude
%       cluster_group.tsv    - (or cluster_KSLabel.tsv / cluster_info.tsv) curation labels
%       whitening_mat_inv.npy - (optional) used to un-whiten template waveforms
%
% The spike sample indices in spike_times.npy are treated as positions in the
% concatenated stream of the probe's epochs (in probe.epochtable() order), the same
% ordering used by ndi.fun.probe.export_binary. The function checks that all spike
% indices fall within the total sample count of the probe's epochs and errors
% (ndi:fun:probe:import_kilosort:sampleOutOfRange) if any fall outside, which
% indicates the sort does not correspond to this probe's epochs.
%
% A 'kilosort_clusters' ndi.document is created that depends on PROBE and stores the
% MD5 checksum of spike_clusters.npy. This is used to detect whether the curation has
% changed since a previous import: if the checksum is unchanged the function does
% nothing (unless 'force' is 1); if it has changed, the previously imported neurons
% and documents are removed and the import is repeated.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | kilosort_dir ('kilosort')| Name of the directory holding the kilosort output   |
% | quality_labels           | String array of curation labels to import. Labels   |
% |   (["good" "mua"])        |   are matched case-insensitively. You may pass your  |
% |                          |   own custom tags here.                             |
% | quality_values ([1 4])   | Numeric quality_number assigned to each label in    |
% |                          |   quality_labels (parallel array). Defaults follow  |
% |                          |   the convention single=1, multi=4.                 |
% | waveform_source          | 'templates' (amplitude-weighted average of the      |
% |   ('templates')          |   contributing Kilosort templates) or 'none'.       |
% | force (0)                | Re-import even if the checksum is unchanged.        |
% | verbose (1)              | 0/1 Should we be verbose?                           |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.IMPORT_ALL_KILOSORT, NDI.FUN.PROBE.EXPORT_ALL_BINARY
%
% Example:
%    S = ndi.session.dir('/path/to/session');
%    p = S.getprobes('type','n-trode');
%    ndi.fun.probe.import_kilosort(S, p{1});
%

    arguments
        S
        probe
        options.kilosort_dir (1,:) char = 'kilosort'
        options.quality_labels (1,:) string = ["good" "mua"]
        options.quality_values (1,:) double = [1 4]
        options.waveform_source (1,:) char {mustBeMember(options.waveform_source,{'templates','none'})} = 'templates'
        options.force (1,1) double = 0
        options.verbose (1,1) double = 1
    end

    if numel(options.quality_labels)~=numel(options.quality_values),
        error('quality_labels and quality_values must have the same number of elements.');
    end;

    verbose = options.verbose;

    % Step 1: locate the kilosort output directory (mirror of the export layout)

    elestr = probe.elementstring();
    elestr(elestr==' ') = '_';
    kdir = fullfile(S.path, options.kilosort_dir, elestr);

    if ~isfolder(kdir),
        error(['Kilosort directory not found: ' kdir '. Was the data exported with ndi.fun.probe.export_all_binary?']);
    end;

    spike_times_file = fullfile(kdir,'spike_times.npy');
    spike_clusters_file = fullfile(kdir,'spike_clusters.npy');
    if ~isfile(spike_times_file) || ~isfile(spike_clusters_file),
        error(['Expected curated files spike_times.npy and spike_clusters.npy in ' kdir '.']);
    end;

    if verbose,
        disp(['Importing kilosort results for probe ' elestr ' from ' kdir '.']);
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
                if verbose,
                    disp('Curation is unchanged since the last import; nothing to do (use ''force'',1 to re-import).');
                end;
                return;
            end;
        end;
        if verbose,
            disp('Removing previously imported kilosort neurons and documents...');
        end;
        for i=1:numel(olddocs),
            ndi.fun.probe.import_kilosort_removeold(S, olddocs{i});
        end;
    end;

    % Step 3: read the curated kilosort output

    npyread = @(f) ndi.util.readNPY(f);

    spike_samples_global = double(npyread(spike_times_file)); % 0-based sample index into concatenated stream
    spike_clusters = double(npyread(spike_clusters_file));

    [cluster_ids, cluster_labels] = ndi.fun.probe.import_kilosort_labels(kdir);

    % Step 4: build the sample <-> epoch map directly from the probe.
    % This matches how ndi.fun.probe.export_binary concatenated the epochs (in
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
        ss = probe.times2samples(et(e).epoch_id, et(e).t0_t1{1}); % same convention as export_binary
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
    % SpikeGLX recording) without using ndi.fun.probe.export_all_binary, the
    % concatenation may not match NDI's epochs and spikes can fall past the end of
    % the last epoch. Catch that here rather than silently dropping spikes.
    %
    % total_samples equals sum(epoch_sample_counts) recorded in the '.metadata'
    % sidecar written by ndi.fun.probe.export_binary; both are computed from the
    % probe via times2samples, so the probe is the authoritative reference.
    if ~isempty(spike_samples_global),
        max_sample = max(spike_samples_global); % 0-based
        n_overrun = sum(spike_samples_global >= total_samples | spike_samples_global < 0);
        if n_overrun>0,
            error('ndi:fun:probe:import_kilosort:sampleOutOfRange', ...
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

    % Step 5: precompute waveform data if requested

    if strcmp(options.waveform_source,'templates'),
        [templates, spike_templates, amplitudes, winv] = ndi.fun.probe.import_kilosort_waveformdata(kdir);
    end;

    % Step 6: create the provenance/cluster document (neurons will depend on it)

    matlab_ver = ver('MATLAB');
    app_struct = struct('name','ndi.fun.probe.import_kilosort', ...
        'version', ndi.version(), ...
        'url','https://github.com/VH-Lab/NDI-matlab', ...
        'os', computer, 'os_version','', ...
        'interpreter','MATLAB','interpreter_version', matlab_ver.Version);

    kc = ndi.document('kilosort_clusters','app',app_struct, ...
        'base.session_id', S.id(), ...
        'kilosort_clusters.kilosort_directory', [options.kilosort_dir filesep elestr], ...
        'kilosort_clusters.curated_output_MD5_checksum', md5_value);
    kc = kc.set_dependency_value('element_id', probe.id());
    S.database_add(kc);

    % Step 7: import each cluster that passes the quality filter

    want_labels = lower(string(options.quality_labels));

    n_imported = 0;
    for ci=1:numel(cluster_ids),
        cid = cluster_ids(ci);
        thislabel = lower(string(cluster_labels(ci)));
        match = find(want_labels==thislabel,1);
        if isempty(match),
            if verbose,
                disp(['  Cluster ' int2str(cid) ' (label ''' char(cluster_labels(ci)) ''') skipped.']);
            end;
            continue;
        end;
        qnum = options.quality_values(match);

        % 7a: the neuron element (underlying element is the probe)
        element_neuron = ndi.neuron(S, [probe.name '_' int2str(cid)], probe.reference, ...
            'spikes', probe, 0, []);

        % 7b: the mean waveform
        if strcmp(options.waveform_source,'templates'),
            meanWf = ndi.fun.probe.import_kilosort_meanwaveform(cid, spike_clusters, ...
                spike_templates, amplitudes, templates, winv);
            % build waveform_sample_times relative to the trough
            [~, troughchan] = min(min(meanWf,[],1));
            [~, troughsamp] = min(meanWf(:,troughchan));
            wst = ((0:size(meanWf,1)-1)' - (troughsamp-1)) / sample_rate;
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

        neuron_doc = ndi.document('neuron_extracellular','app',app_struct, ...
            'neuron_extracellular', ne, 'base.session_id', S.id());
        neuron_doc = neuron_doc.set_dependency_value('element_id', element_neuron.id());
        neuron_doc = neuron_doc.set_dependency_value('spike_clusters_id', kc.id());
        S.database_add(neuron_doc);

        % 7c: the spike trains, per epoch
        I = find(spike_clusters==cid);
        g0 = spike_samples_global(I); % 0-based global samples for this cluster
        for e=1:nEpochs,
            in_epoch = find(g0 >= bounds0(e) & g0 < bounds0(e+1));
            if isempty(in_epoch),
                spike_times_local = [];
            else,
                local1 = (g0(in_epoch) - bounds0(e)) + 1; % 1-based local NDI sample
                spike_times_local = probe.samples2times(epoch_ids{e}, double(local1));
                spike_times_local = spike_times_local(:);
            end;
            element_neuron.addepoch(epoch_ids{e}, epoch_clock{e}, epoch_t0t1{e}, ...
                spike_times_local, ones(size(spike_times_local)));
        end;

        n_imported = n_imported + 1;
        if verbose,
            disp(['  Imported cluster ' int2str(cid) ' as neuron ' probe.name '_' int2str(cid) ...
                ' (' char(cluster_labels(ci)) ', ' int2str(numel(I)) ' spikes).']);
        end;
    end;

    if verbose,
        disp(['Done. Imported ' int2str(n_imported) ' neuron(s) for probe ' elestr '.']);
    end;

end
