function blech_clust_write(outputfile, unit_spiketimes, unit_info, onset_times, trial_stimid, stimid_tastant, options)
% NDI.FUN.EXPORT.BLECH_CLUST_WRITE - write a blech_clust HMM HDF5 file from prepared arrays
%
% NDI.FUN.EXPORT.BLECH_CLUST_WRITE(OUTPUTFILE, UNIT_SPIKETIMES, UNIT_INFO, ...
%     ONSET_TIMES, TRIAL_STIMID, STIMID_TASTANT, ...)
%
% Low-level writer used by ndi.fun.export.blech_clust. Given ensemble spike
% times and per-trial stimulus identities/delivery times that have already been
% assembled (and expressed in a single common clock, in seconds), it bins the
% activity into blech_clust's binary millisecond spike_array layout and writes
% the HDF5 file OUTPUTFILE. This step has no NDI/session/syncgraph dependencies,
% so it is independently unit-testable; ndi.fun.export.blech_clust is the
% acquisition wrapper that produces these inputs from an NDI stimulator + probe.
%
% =========================================================================
% INPUTS
% =========================================================================
%   OUTPUTFILE      - path of the HDF5 file to write (overwritten if it exists).
%   UNIT_SPIKETIMES - 1-by-nUnits cell array; UNIT_SPIKETIMES{u} is a vector of
%                     spike times (seconds, in the common clock) of unit u.
%   UNIT_INFO       - 1-by-nUnits struct array with fields name (char),
%                     single_unit, regular_spiking, fast_spiking (0/1); written
%                     to the /unit_descriptor table.
%   ONSET_TIMES     - nTrials-by-1 stimulus delivery times (seconds, same clock
%                     as UNIT_SPIKETIMES).
%   TRIAL_STIMID    - nTrials-by-1 integer stimulus id of each trial.
%   STIMID_TASTANT  - containers.Map from stimid (double) to tastant name (char),
%                     used for the dig_in group's 'tastant' attribute.
%
% Name/value options:
% --------------------------------------------------------------------------
% | preStim (2000)      | Milliseconds retained before delivery (delivery is  |
% |                     |   placed at column preStim of spike_array).         |
% | postStim (5000)     | Milliseconds retained after delivery.               |
% | sampleRate (30000)  | Acquisition sample rate (Hz) for /sorted_units.     |
% | stimulusOrder ([])  | Order of stimids -> dig_in_0, dig_in_1, ...; if     |
% |                     |   empty, unique stimids present, ascending.         |
% | includeStimids ([]) | If set, restrict exported stimids to these.         |
% | epochID ('')        | Recorded as the /ndi_epochid top-level attribute.   |
% | verbose (1)         | 0/1 be verbose.                                     |
% --------------------------------------------------------------------------
%
% See also: ndi.fun.export.blech_clust

    arguments
        outputfile (1,:) char
        unit_spiketimes (1,:) cell
        unit_info (1,:) struct
        onset_times (:,1) double
        trial_stimid (:,1) double
        stimid_tastant
        options.preStim (1,1) double = 2000
        options.postStim (1,1) double = 5000
        options.sampleRate (1,1) double = 30000
        options.stimulusOrder (1,:) double = []
        options.includeStimids (1,:) double = []
        options.epochID (1,:) char = ''
        options.verbose (1,1) double = 1
    end

    preStim  = round(options.preStim);
    postStim = round(options.postStim);
    trial_dur_ms = preStim + postStim;
    verbose = options.verbose;
    n_units = numel(unit_spiketimes);

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
        error('ndi:fun:export:blech_clust_write:nostimuli', ...
            'No tastant stimuli were found to export.');
    end

    if exist(outputfile,'file')
        delete(outputfile);
    end

    for n = 1:numel(dig_in_stimids)
        this_stimid = dig_in_stimids(n);
        trials = find(trial_stimid(:)' == this_stimid);
        n_trials = numel(trials);

        group = sprintf('/spike_trains/dig_in_%d', n-1); % blech is 0-indexed

        if n_trials == 0
            % HDF5 datasets cannot have a zero-length dimension; skip tastants
            % that have no trials.
            warning('ndi:fun:export:blech_clust_write:emptytastant', ...
                'stimid %d has no trials; skipping dig_in_%d.', this_stimid, n-1);
            continue;
        end

        spike_array = zeros(n_trials, n_units, trial_dur_ms, 'uint8');
        for ti = 1:n_trials
            t_onset = onset_times(trials(ti)); % delivery time (s)
            win_start = t_onset - preStim/1000; % seconds
            for u = 1:n_units
                st = unit_spiketimes{u};
                % ms bin index: delivery -> column preStim (0-based -> +1)
                idx = floor((st - win_start) * 1000) + 1;
                idx = idx(idx >= 1 & idx <= trial_dur_ms);
                spike_array(ti, u, idx) = 1;
            end
        end

        % Write /spike_trains/dig_in_<N>/spike_array.
        %
        % blech_clust reads this with h5py/numpy, whose row-major (C) index
        % order is the reverse of MATLAB's column-major order: a dataset that
        % MATLAB writes with dimensions [d1 d2 d3] is reported by h5py as shape
        % (d3, d2, d1). blech_clust expects a numpy shape of
        % (n_trials, n_units, trial_dur_ms). We therefore permute spike_array
        % to [trial_dur_ms n_units n_trials] on disk so that Python reads it
        % back as (n_trials, n_units, trial_dur_ms). (Issue #855.)
        spike_array = permute(spike_array, [3 2 1]);
        ds = [group '/spike_array'];
        h5create(outputfile, ds, [trial_dur_ms n_units n_trials], 'Datatype', 'uint8');
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

    % Write /sorted_units/unitNNN (spike times in acquisition samples) and the
    % /unit_descriptor compound table so blech unit selection and raster
    % plotting work.
    if verbose, disp('Writing /sorted_units and /unit_descriptor...'); end
    local_write_units(outputfile, unit_spiketimes, unit_info, options.sampleRate);

    % Top-level provenance attributes
    h5writeatt(outputfile, '/', 'source', 'NDI-matlab ndi.fun.export.blech_clust');
    h5writeatt(outputfile, '/', 'ndi_epochid', options.epochID);
    h5writeatt(outputfile, '/', 'sample_rate_hz', options.sampleRate);

    if verbose
        fprintf('Wrote blech_clust HDF5 file: %s\n', outputfile);
    end

end % blech_clust_write

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
