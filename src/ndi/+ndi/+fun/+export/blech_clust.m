function blech_clust(stimulator, probe, epochID, outputfile, options)
% NDI.FUN.EXPORT.BLECH_CLUST - export an NDI ensemble + tastant stimulus epoch to a blech_clust HMM-ready HDF5 file
%
% NDI.FUN.EXPORT.BLECH_CLUST(STIMULATOR, PROBE, EPOCHID, OUTPUTFILE, ...)
%
% Exports the sorted-unit ensemble recorded on PROBE, together with the
% tastant stimulus identities and delivery times reported by STIMULATOR,
% for a single epoch EPOCHID, into an HDF5 file OUTPUTFILE structured so
% that the blech_clust Hidden Markov Model (HMM) code can consume it
% directly (see https://github.com/vh-lab/blech_clust).
%
% The blech_clust HMM scripts (blech_poisson_hmm.py / blech_multinomial_hmm.py,
% via blech_hmm.py) read a single HDF5 file and, for each tastant, use the
% node:
%
%       /spike_trains/dig_in_<N>/spike_array
%
% a binary (0/1) millisecond raster of shape (n_trials x n_units x
% trial_duration_ms), aligned so that stimulus delivery falls at column
% PRESTIM (in ms). Each tastant is written to its own dig_in_<N> group;
% the group index encodes the stimulus identity. Blech's unit selection
% and raster plotting additionally read /sorted_units and a /unit_descriptor
% table; those are written here as well.
%
% This function produces exactly that structure, using MATLAB's built-in
% HDF5 writer (h5create/h5write and the low-level HDF5 library for the
% compound /unit_descriptor table).
%
% Where the information comes from:
% --------------------------------------------------------------------------
% | blech_clust field   | NDI source                                       |
% |---------------------|--------------------------------------------------|
% | ensemble activity   | spike elements ('spikes') derived from PROBE,    |
% |   (spike_array)     |   one per sorted unit, read per epoch.           |
% | stimulus identity   | the tastant / stimid parameter of each stimulus  |
% |   (dig_in_<N>)      |   in the STIMULATOR's stimulus_presentation doc  |
% |                     |   (e.g. ndi.daq.metadatareader.VHAudreyBPod).    |
% | stimulus times      | presentation_time.onset of each trial, converted |
% |   (trial alignment) |   into PROBE's clock via the session syncgraph.  |
% --------------------------------------------------------------------------
%
% The stimulus identity and delivery times are read from the NDI
% 'stimulus_presentation' document that depends on STIMULATOR and matches
% EPOCHID (built by ndi.app.stimulus.decoder). If no such document exists,
% an error is thrown asking the caller to run the stimulus decoder first.
%
% This function's parameters can be modified by passing name/value pairs:
% --------------------------------------------------------------------------
% | Parameter (default)   | Description                                    |
% |-----------------------|------------------------------------------------|
% | sampleRate (30000)    | Acquisition sample rate (Hz). blech_clust      |
% |                       |   hard-codes 30 kHz; any value other than      |
% |                       |   30000 exactly raises an error.               |
% | preStim (2000)        | Milliseconds retained BEFORE each stimulus     |
% |                       |   delivery. Delivery is placed at column       |
% |                       |   preStim of spike_array. (blech 'pre_stim'.)  |
% | postStim (5000)       | Milliseconds retained AFTER each stimulus      |
% |                       |   delivery.                                    |
% | stimulusOrder ([])    | Optional vector of stimids giving the order in |
% |                       |   which tastants map to dig_in_0, dig_in_1,... |
% |                       |   If empty, the unique stimids present are used|
% |                       |   in ascending order.                          |
% | includeStimids ([])   | Optional vector of stimids to export. If empty,|
% |                       |   all stimids present in the epoch are used.   |
% | tastantField          | Name of the stimulus parameter field holding   |
% |   ('tastant')         |   the tastant label (for reporting/attrs).     |
% | stimidField ('stimid')| Name of the stimulus parameter field holding   |
% |                       |   the integer stimulus identity.               |
% | verbose (1)           | 0/1 Should we be verbose?                      |
% |-----------------------|------------------------------------------------|
%
% Example:
%   S = ndi.session.dir('/path/to/session');
%   p = S.getprobes('type','n-trode'); p = p{1};      % ensemble probe
%   stim = S.getprobes('type','stimulator'); stim = stim{1};
%   ndi.fun.export.blech_clust(stim, p, 't00001', '/tmp/mydata.h5');
%
% STRUCTURE OF THE OUTPUT FILE
% --------------------------------------------------------------------------
% There is no formal published specification of this layout; it is defined
% by the blech_clust code (units_make_arrays.py, blech_setup_hmm.py,
% blech_poisson_hmm.py). This function writes exactly what that code reads:
%
%   /spike_trains/dig_in_<N>/spike_array   uint8 (n_trials x n_units x
%                                          duration_ms); 1 = spike in that
%                                          ms. Delivery is at column preStim.
%                                          One group per tastant; N encodes
%                                          identity. Group attributes record
%                                          the stimid, tastant name, n_trials,
%                                          pre_stim_ms and post_stim_ms.
%   /sorted_units/unit<NNN>/times          uint64 spike times in 30 kHz
%                                          acquisition samples (per unit).
%   /unit_descriptor                       compound table with Int32 columns
%                                          single_unit, regular_spiking,
%                                          fast_spiking (one row per unit).
%
% USING THE OUTPUT FILE WITH BLECH_CLUST
% --------------------------------------------------------------------------
% 1) Put the .h5 file in its own directory on a machine with blech_clust
%    installed (https://github.com/vh-lab/blech_clust).
%
% 2) Configure the HMM. Either run the interactive setup, which lists the
%    dig_in_<N> groups as the available tastes and /sorted_units as the
%    selectable units:
%
%        python blech_setup_hmm.py
%
%    or write the three config files it produces by hand in that directory:
%        blech.dir         one line: the full path to the data directory
%        blech.hmm_units   the chosen unit indices, one per line (0-based)
%        blech.hmm_params  min_states, max_states, max_iterations,
%                          convergence threshold, seeds, transition inertia,
%                          emission inertia, taste_num (the <N> of dig_in_<N>),
%                          pre_stim, bin_size, pre_stim_hmm, post_stim_hmm,
%                          hmm_type ('generic' or 'feedforward'), one per line.
%
%    IMPORTANT: set blech's pre_stim equal to the preStim (ms) used here, and
%    keep pre_stim_hmm <= preStim and post_stim_hmm <= postStim so the HMM
%    window stays inside the exported window. bin_size is typically 10 (ms).
%
% 3) Fit the HMM (the argument is the number of CPUs):
%
%        python blech_poisson_hmm.py 4          % Poisson (per-unit) emissions
%        python blech_multinomial_hmm.py 4      % or collapsed multinomial
%
% 4) Read the results, written back into the SAME .h5 under
%    /spike_trains/dig_in_<N>/<hmm_type>_poisson_hmm_results/states_<K>/ :
%        emission_probs     per-state, per-unit firing rates
%        transition_probs   state transition matrix
%        posterior_proba    (n_trials x time_bins x n_states) state
%                           probabilities over time
%        log_likelihood, aic, bic, time
%    In MATLAB, e.g.:
%        pp = h5read('/tmp/mydata.h5', ...
%             '/spike_trains/dig_in_0/generic_poisson_hmm_results/states_3/posterior_proba');
%
% The HMM is fit to one taste at a time (taste_num); repeat step 2-3 per
% dig_in_<N> to analyze every tastant. The ensemble-state HMM methodology is
% described in Jones, Fontanini, Sadacca, Miller & Katz (2007) PNAS 104:18772.
%
% See also: ndi.fun.probe.export.binary, ndi.app.stimulus.decoder,
%   ndi.example.fun.probe2elements

    arguments
        stimulator
        probe
        epochID (1,:) char
        outputfile (1,:) char
        options.sampleRate (1,1) double = 30000
        options.preStim (1,1) double = 2000
        options.postStim (1,1) double = 5000
        options.stimulusOrder (1,:) double = []
        options.includeStimids (1,:) double = []
        options.tastantField (1,:) char = 'tastant'
        options.stimidField (1,:) char = 'stimid'
        options.verbose (1,1) double = 1
    end

    % --- blech_clust hard-codes a 30 kHz acquisition rate (30 samples/ms) ---
    if options.sampleRate ~= 30000
        error('ndi:fun:export:blech_clust:sampleRate', ...
            ['blech_clust requires an acquisition sample rate of exactly ' ...
             '30000 Hz (30 samples/ms); received %g Hz. Resample the data ' ...
             'or supply data recorded at 30 kHz.'], options.sampleRate);
    end

    if options.preStim < 0 || options.postStim <= 0
        error('ndi:fun:export:blech_clust:window', ...
            'preStim must be >= 0 and postStim must be > 0 (milliseconds).');
    end

    preStim  = round(options.preStim);   % ms before delivery
    postStim = round(options.postStim);  % ms after delivery
    trial_dur_ms = preStim + postStim;   % total ms per trial
    verbose = options.verbose;

    S = probe.session;

    % ---------------------------------------------------------------------
    % 1) Pull the tastant stimulus identities and delivery times
    % ---------------------------------------------------------------------
    if verbose, disp('Reading stimulus presentation (identities and times)...'); end
    [onset_probe, offset_probe, trial_stimid, stimid_tastant] = ...
        local_get_stimulus_presentation(S, stimulator, probe, epochID, options); %#ok<*NASGU>

    % Decide the tastant -> dig_in_<N> ordering
    if ~isempty(options.stimulusOrder)
        dig_in_stimids = options.stimulusOrder;
    else
        dig_in_stimids = unique(trial_stimid(:))';
    end
    if ~isempty(options.includeStimids)
        dig_in_stimids = dig_in_stimids(ismember(dig_in_stimids, options.includeStimids));
    end
    if isempty(dig_in_stimids)
        error('ndi:fun:export:blech_clust:nostimuli', ...
            'No tastant stimuli were found to export for epoch %s.', epochID);
    end

    % ---------------------------------------------------------------------
    % 2) Pull the ensemble spike times (one spike element per sorted unit)
    % ---------------------------------------------------------------------
    if verbose, disp('Reading ensemble spike times from probe...'); end
    [unit_spiketimes, unit_info] = local_get_unit_spiketimes(probe, epochID);
    n_units = numel(unit_spiketimes);
    if n_units == 0
        error('ndi:fun:export:blech_clust:nounits', ...
            'No spike (sorted unit) elements were found on the probe for epoch %s.', epochID);
    end

    % ---------------------------------------------------------------------
    % 3) Build the binary millisecond spike_array for each tastant and
    %    write the HDF5 file
    % ---------------------------------------------------------------------
    if exist(outputfile,'file')
        delete(outputfile);
    end

    for n = 1:numel(dig_in_stimids)
        this_stimid = dig_in_stimids(n);
        trials = find(trial_stimid(:)' == this_stimid);
        n_trials = numel(trials);

        group = sprintf('/spike_trains/dig_in_%d', n-1); % blech is 0-indexed

        if n_trials == 0
            % HDF5 datasets cannot have a zero-length dimension; skip
            % tastants that have no trials in this epoch.
            warning('ndi:fun:export:blech_clust:emptytastant', ...
                'stimid %d has no trials in epoch %s; skipping dig_in_%d.', ...
                this_stimid, epochID, n-1);
            continue;
        end

        spike_array = zeros(n_trials, n_units, trial_dur_ms, 'uint8');
        for ti = 1:n_trials
            t_onset = onset_probe(trials(ti)); % delivery time, probe clock (s)
            win_start = t_onset - preStim/1000;  % seconds
            for u = 1:n_units
                st = unit_spiketimes{u};
                % ms bin index: delivery -> column preStim (0-based -> +1)
                idx = floor((st - win_start) * 1000) + 1;
                idx = idx(idx >= 1 & idx <= trial_dur_ms);
                spike_array(ti, u, idx) = 1;
            end
        end

        % Write /spike_trains/dig_in_<N>/spike_array
        ds = [group '/spike_array'];
        h5create(outputfile, ds, [n_trials n_units trial_dur_ms], 'Datatype', 'uint8');
        h5write(outputfile, ds, spike_array);

        % Record the tastant label + stimid as attributes on the group
        this_tastant = 'unknown';
        if isKey(stimid_tastant, this_stimid) && ~isempty(stimid_tastant(this_stimid))
            this_tastant = stimid_tastant(this_stimid);
        end
        h5writeatt(outputfile, group, 'stimid', this_stimid);
        h5writeatt(outputfile, group, 'tastant', this_tastant);
        h5writeatt(outputfile, group, 'n_trials', n_trials);
        h5writeatt(outputfile, group, 'pre_stim_ms', preStim);
        h5writeatt(outputfile, group, 'post_stim_ms', postStim);

        if verbose
            fprintf('  dig_in_%d: stimid %d (%s), %d trials, %d units, %d ms/trial.\n', ...
                n-1, this_stimid, this_tastant, n_trials, n_units, trial_dur_ms);
        end
    end

    % ---------------------------------------------------------------------
    % 4) Write /sorted_units/unitNNN (spike times in 30 kHz samples) and
    %    the /unit_descriptor compound table so blech unit selection and
    %    raster plotting work.
    % ---------------------------------------------------------------------
    if verbose, disp('Writing /sorted_units and /unit_descriptor...'); end
    local_write_units(outputfile, unit_spiketimes, unit_info, options.sampleRate);

    % Top-level provenance attributes
    h5writeatt(outputfile, '/', 'source', 'NDI-matlab ndi.fun.export.blech_clust');
    h5writeatt(outputfile, '/', 'ndi_epochid', epochID);
    h5writeatt(outputfile, '/', 'sample_rate_hz', options.sampleRate);

    if verbose
        fprintf('Wrote blech_clust HDF5 file: %s\n', outputfile);
    end

end % blech_clust

% =========================================================================
% Local helper: stimulus identities + delivery times (in the probe clock)
% =========================================================================
function [onset_probe, offset_probe, trial_stimid, stimid_tastant] = ...
        local_get_stimulus_presentation(S, stimulator, probe, epochID, options)
    % Find the stimulus_presentation document for this stimulator + epoch.
    q = ndi.query('','isa','stimulus_presentation') & ...
        ndi.query('','depends_on','stimulus_element_id', stimulator.id()) & ...
        ndi.query('epochid.epochid','exact_string', epochID,'');
    stim_docs = S.database_search(q);

    if isempty(stim_docs)
        error('ndi:fun:export:blech_clust:nopresentation', ...
            ['No stimulus_presentation document was found for stimulator %s, ' ...
             'epoch %s. Run ndi.app.stimulus.decoder on this session first.'], ...
            stimulator.elementstring, epochID);
    end
    stim_doc = stim_docs{1};

    sp = stim_doc.document_properties.stimulus_presentation;
    presentation_order = vlt.data.colvec([sp.presentation_order]); % 1 x n_trials -> unique stim index per trial

    % Map each unique stimulus index -> its stimid, and stimid -> tastant name
    n_stims = numel(sp.stimuli);
    unique_stimid = nan(n_stims,1);
    stimid_tastant = containers.Map('KeyType','double','ValueType','char');
    for k = 1:n_stims
        p = sp.stimuli(k).parameters;
        if isfield(p, options.stimidField)
            unique_stimid(k) = double(p.(options.stimidField));
        else
            unique_stimid(k) = k; % fall back to index if no stimid field
        end
        tastant_name = '';
        if isfield(p, options.tastantField)
            tastant_name = char(string(p.(options.tastantField)));
        end
        stimid_tastant(unique_stimid(k)) = tastant_name;
    end

    % Per-trial stimid
    trial_stimid = unique_stimid(presentation_order);

    % Load per-trial presentation times (onset/offset) in the stimulus clock
    ndi_decoder = ndi.app.stimulus.decoder(S);
    presentation_time = ndi_decoder.load_presentation_time(stim_doc);
    onset_stim  = vlt.data.colvec([presentation_time.onset]);
    offset_stim = vlt.data.colvec([presentation_time.offset]);

    % Convert stimulus onset/offset times into the probe's (recording) clock
    stim_timeref = ndi.time.timereference(stimulator, ...
        ndi.time.clocktype(presentation_time(1).clocktype), ...
        stim_doc.document_properties.epochid.epochid, 0);

    [t_probe, ~, msg] = S.syncgraph.time_convert(stim_timeref, ...
        [onset_stim offset_stim], probe, ndi.time.clocktype('dev_local_time'));
    if isempty(t_probe)
        error('ndi:fun:export:blech_clust:sync', ...
            ['Could not convert stimulus times into the probe clock via the ' ...
             'session syncgraph: %s'], msg);
    end
    t_probe = reshape(t_probe, numel(onset_stim), 2);
    onset_probe  = t_probe(:,1);
    offset_probe = t_probe(:,2);
end

% =========================================================================
% Local helper: per-unit spike times (probe clock, seconds) for the epoch
% =========================================================================
function [unit_spiketimes, unit_info] = local_get_unit_spiketimes(probe, epochID)
    [ed, e] = ndi.example.fun.probe2elements(probe, 'type', 'spikes');
    unit_spiketimes = {};
    unit_info = vlt.data.emptystruct('name','single_unit','regular_spiking','fast_spiking');
    for i = 1:numel(e)
        % Only include this unit if it has data for the requested epoch
        et = e{i}.epochtable();
        has_epoch = false;
        for j = 1:numel(et)
            if strcmp(et(j).epoch_id, epochID)
                has_epoch = true;
                break;
            end
        end
        if ~has_epoch, continue; end

        [~, st] = e{i}.readtimeseries(epochID, -inf, inf);
        unit_spiketimes{end+1} = st(:); %#ok<AGROW>

        % Derive unit-quality flags from the associated neuron_extracellular
        % document if present (single unit vs multi-unit; RSU vs FS).
        info = struct('name', ed{i}.document_properties.element.name, ...
            'single_unit', 0, 'regular_spiking', 0, 'fast_spiking', 0);
        info = local_fill_unit_quality(e{i}, info);
        unit_info(end+1) = info; %#ok<AGROW>
    end
end

function info = local_fill_unit_quality(e, info)
    % Look for a neuron_extracellular doc that depends on this element and,
    % if found, set single_unit / regular_spiking / fast_spiking flags.
    try
        q = ndi.query('','depends_on','element_id', e.id()) & ...
            ndi.query('','isa','neuron_extracellular');
        nd = e.session.database_search(q);
        if ~isempty(nd)
            ne = nd{1}.document_properties.neuron_extracellular;
            if isfield(ne,'quality_number') && ne.quality_number <= 2
                info.single_unit = 1;
            elseif isfield(ne,'quality') && any(strcmpi(ne.quality,{'good','single'}))
                info.single_unit = 1;
            end
            if isfield(ne,'cell_type')
                if any(strcmpi(ne.cell_type,{'rsu','regular_spiking','pyramidal'}))
                    info.regular_spiking = 1;
                elseif any(strcmpi(ne.cell_type,{'fs','fast_spiking','interneuron'}))
                    info.fast_spiking = 1;
                end
            end
        end
    catch
        % leave defaults (treated as multi-unit) if anything is unavailable
    end
end

% =========================================================================
% Local helper: write /sorted_units and the /unit_descriptor table
% =========================================================================
function local_write_units(outputfile, unit_spiketimes, unit_info, sampleRate)
    n_units = numel(unit_spiketimes);
    samples_per_sec = sampleRate; % 30000

    for u = 1:n_units
        % blech expects /sorted_units/unitNNN.times in acquisition samples
        times_samples = round(unit_spiketimes{u} * samples_per_sec);
        times_samples = uint64(times_samples(times_samples >= 0));
        ds = sprintf('/sorted_units/unit%03d/times', u-1);
        if isempty(times_samples)
            h5create(outputfile, ds, 1, 'Datatype', 'uint64');
            h5write(outputfile, ds, uint64(0));
        else
            h5create(outputfile, ds, numel(times_samples), 'Datatype', 'uint64');
            h5write(outputfile, ds, times_samples(:));
        end
    end

    % Write /unit_descriptor as an HDF5 compound (pytables-style) table with
    % Int32 columns single_unit, regular_spiking, fast_spiking.
    local_write_unit_descriptor(outputfile, unit_info);
end

function local_write_unit_descriptor(outputfile, unit_info)
    n_units = numel(unit_info);
    single_unit     = int32([unit_info.single_unit]');
    regular_spiking = int32([unit_info.regular_spiking]');
    fast_spiking    = int32([unit_info.fast_spiking]');
    if n_units == 0
        single_unit = int32([]); regular_spiking = int32([]); fast_spiking = int32([]);
    end

    fid = H5F.open(outputfile, 'H5F_ACC_RDWR', 'H5P_DEFAULT');

    int32Type = H5T.copy('H5T_NATIVE_INT');
    sz = H5T.get_size(int32Type);

    % Build compound type: 3 Int32 fields
    memtype = H5T.create('H5T_COMPOUND', 3*sz);
    H5T.insert(memtype, 'single_unit',     0,    int32Type);
    H5T.insert(memtype, 'regular_spiking', sz,   int32Type);
    H5T.insert(memtype, 'fast_spiking',    2*sz, int32Type);

    dims = max(n_units,1);
    space = H5S.create_simple(1, dims, dims);
    dset = H5D.create(fid, 'unit_descriptor', memtype, space, 'H5P_DEFAULT');

    data = struct('single_unit', single_unit, ...
                  'regular_spiking', regular_spiking, ...
                  'fast_spiking', fast_spiking);
    if n_units > 0
        H5D.write(dset, memtype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', data);
    end

    H5D.close(dset);
    H5S.close(space);
    H5T.close(memtype);
    H5T.close(int32Type);
    H5F.close(fid);
end
