function [activity, neuron_ids, neuron_names, info, spike_rows] = load(S, element, epochid, options)
% ndi.fun.ensemble.load - build a neuron ensemble by reading spikes for an epoch
%
% [ACTIVITY, NEURON_IDS, NEURON_NAMES, INFO, SPIKE_ROWS] = ndi.fun.ensemble.LOAD(S, ELEMENT, EPOCHID, ...)
%
% Builds the spiking "ensemble" of all neurons recorded during epoch EPOCHID of
% ELEMENT. It finds the spiking-neuron elements built on ELEMENT (the elements
% of type 'spikes' that have ELEMENT as their underlying element), reads each
% neuron's spike times relative to ELEMENT's epoch, and packs them into a
% sparse matrix ACTIVITY where ACTIVITY(i,n) is the time of the n-th spike of
% neuron i.
%
% Spike times are read with the element's readtimeseries method using a time
% reference built on ELEMENT for EPOCHID, so every neuron's spikes are returned
% in the SAME clock as ELEMENT's epoch and are directly comparable. A neuron
% that was not recorded during EPOCHID (its data cannot be mapped into that
% epoch) is skipped. This is the same construction used by
% suarezCasanovaetal2026.export.sessionEnsembles, generalized so that any
% element can be the time reference.
%
% =========================================================================
% INPUTS
% =========================================================================
%   S        - an ndi.session or ndi.dataset object.
%   ELEMENT  - the element (usually a probe) that the ensemble belongs to and
%              that provides the time reference. May be an ndi.element object
%              or an element document id string.
%   EPOCHID  - the epoch id (of ELEMENT) to build the ensemble for.
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   neurons ({})            - a cell array of the spiking-neuron elements
%                             (ndi.element objects or id strings) to consider.
%                             If empty (default), the neurons are the elements
%                             of type 'spikes' that have ELEMENT as their
%                             underlying element (found with a depends_on query
%                             on underlying_element_id); of those, the ones
%                             recorded during EPOCHID are included.
%   clocktype ('')          - the name of the ndi.time.clocktype to express the
%                             spike times in. If empty, ELEMENT's clock for
%                             EPOCHID (the first clock of that epoch) is used.
%   value_type ('spiketimes')     - stored in INFO.value_type.
%   value_description ('')  - stored in INFO.value_description; a default
%                             describing spike times is used if empty.
%   Verbose (false)         - print cell-by-cell progress ('reading cell n of
%                             m'), spike counts, skipped cells, and a summary.
%
% =========================================================================
% OUTPUTS
% =========================================================================
%   ACTIVITY     - an N-neurons-by-Smax sparse matrix of spike times.
%                  ACTIVITY(i,n) is the time of the n-th spike of neuron i,
%                  packed left-to-right; rows are zero-padded on the right.
%   NEURON_IDS   - a 1-by-N cell array of the neuron element document ids, in
%                  the row order of ACTIVITY.
%   NEURON_NAMES - a 1-by-N cell array of the neuron element strings, same order.
%   INFO         - a struct with fields num_neurons, num_dimensions (2),
%                  value_type, value_description, clocktype (the name of the
%                  clock the spike times are in), clock (the ndi.time.clocktype
%                  object), and t0_t1 (the [t0 t1] extent of the epoch in that
%                  clock).
%   SPIKE_ROWS   - a 1-by-N cell array; SPIKE_ROWS{i} is the row vector of
%                  spike times of neuron i (the same data as row i of ACTIVITY,
%                  but without the zero padding).
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   [E, nids, nnames] = ndi.fun.ensemble.load(S, probe, 'epoch_1');
%
% See also: ndi.fun.ensemble.create, ndi.fun.ensemble.read,
%   suarezCasanovaetal2026.export.sessionEnsembles

    arguments
        S
        element
        epochid (1,:) char
        options.neurons cell = {}
        options.clocktype (1,:) char = ''
        options.value_type (1,:) char = 'spiketimes'
        options.value_description (1,:) char = ''
        options.Verbose (1,1) logical = false
    end

    element_obj = local_element_object(element, S);

    % --- time reference and extent of ELEMENT's epoch ----------------------
    et = element_obj.epochtable();
    idx = find(strcmp(epochid, {et.epoch_id}), 1);
    if isempty(idx)
        error('ndi:ensemble:load:noEpoch', ...
            'Element ''%s'' has no epoch ''%s''.', ...
            element_obj.elementstring(), epochid);
    end
    if isempty(options.clocktype)
        % Prefer dev_local_time -- the clock that
        % ndi.element.timeseries.readtimeseries resolves epochs through -- when
        % the epoch has it, so the stored ensemble epoch can be read back. Fall
        % back to the epoch's first clock otherwise (e.g. a global-clock-only
        % epoch).
        clock_index = local_clock_index(et(idx), ndi.time.clocktype('dev_local_time'), false);
        if isempty(clock_index)
            clock_index = 1;
        end
        ref_clock = et(idx).epoch_clock{clock_index};
        if ~isa(ref_clock, 'ndi.time.clocktype')
            ref_clock = ndi.time.clocktype(ref_clock);
        end
    else
        ref_clock = ndi.time.clocktype(options.clocktype);
        clock_index = local_clock_index(et(idx), ref_clock, true);
    end
    ref_t0_t1 = et(idx).t0_t1{clock_index};
    clockname = ref_clock.type;
    timeref = ndi.time.timereference(element_obj, ref_clock, epochid, 0);

    % --- the candidate neurons --------------------------------------------
    % By default, the ensemble is made of the spiking-neuron elements that are
    % built on ELEMENT (i.e. whose underlying_element_id is ELEMENT), not every
    % 'spikes' element in the session. Of those, the loop below keeps the ones
    % actually recorded during EPOCHID.
    if isempty(options.neurons)
        q = ndi.query('','isa','element','') & ...
            ndi.query('element.type','exact_string','spikes','') & ...
            ndi.query('','depends_on','underlying_element_id', element_obj.id());
        neuron_docs = S.database_search(q);
        neurons = cell(1, numel(neuron_docs));
        for k = 1:numel(neuron_docs)
            neurons{k} = ndi.database.fun.ndi_document2ndi_object(neuron_docs{k}, S);
        end
    else
        neurons = options.neurons;
    end

    % --- read each neuron's spikes in ELEMENT's epoch ----------------------
    if options.Verbose
        disp(['ndi.fun.ensemble.load: considering ' int2str(numel(neurons)) ...
            ' candidate cell(s) for epoch ' epochid '.']);
    end
    spike_rows = {};
    neuron_ids = {};
    neuron_names = {};
    for j = 1:numel(neurons)
        e = local_element_object(neurons{j}, S);
        if options.Verbose
            disp(['ndi.fun.ensemble.load: reading cell ' int2str(j) ' of ' ...
                int2str(numel(neurons)) ' (' e.elementstring() ')...']);
        end
        try
            % readtimeseries with a timereference returns the spike times (2nd
            % output) in the reference clock and errors if this neuron was not
            % recorded during the reference epoch.
            [~, st] = e.readtimeseries(timeref, -Inf, Inf);
        catch ME
            if options.Verbose
                disp(['ndi.fun.ensemble.load:   skipping ' e.elementstring() ...
                    ' (not recorded in epoch ' epochid '): ' ME.message]);
            end
            continue;
        end
        if options.Verbose
            disp(['ndi.fun.ensemble.load:   ' int2str(numel(st)) ' spike(s).']);
        end
        spike_rows{end+1} = st(:).'; %#ok<AGROW>
        neuron_ids{end+1} = e.id(); %#ok<AGROW>
        neuron_names{end+1} = e.elementstring(); %#ok<AGROW>
    end

    % --- pack into a sparse N-by-Smax matrix -------------------------------
    N = numel(spike_rows);
    Smax = 0;
    for k = 1:N
        Smax = max(Smax, numel(spike_rows{k}));
    end
    activity = sparse(N, max(Smax,1));
    for k = 1:N
        v = spike_rows{k};
        if ~isempty(v)
            activity(k,1:numel(v)) = v;
        end
    end

    if options.Verbose
        disp(['ndi.fun.ensemble.load: built an ensemble of ' int2str(N) ...
            ' neuron(s) for epoch ' epochid '.']);
    end

    % --- metadata ----------------------------------------------------------
    if isempty(options.value_description)
        vdesc = ['time of the n-th spike of neuron i, in the ' clockname ' clock'];
    else
        vdesc = options.value_description;
    end
    info = struct('num_neurons', N, 'num_dimensions', 2, ...
        'value_type', options.value_type, 'value_description', vdesc, ...
        'clocktype', clockname, 'clock', ref_clock, 't0_t1', ref_t0_t1(:).');

end % load()

% -------------------------------------------------------------------------

function ci = local_clock_index(et_entry, clk, errorIfMissing)
% index, within an epochtable entry's epoch_clock list, of the clock CLK.
% Returns [] if not found (unless errorIfMissing is true, then it errors).
    ci = [];
    for i = 1:numel(et_entry.epoch_clock)
        c = et_entry.epoch_clock{i};
        if ~isa(c,'ndi.time.clocktype'), c = ndi.time.clocktype(c); end
        if strcmp(c.type, clk.type)
            ci = i;
            return;
        end
    end
    if isempty(ci) && errorIfMissing
        error('ndi:ensemble:load:noClock', ...
            'The epoch does not have a clock of type ''%s''.', clk.type);
    end
end % local_clock_index()

% -------------------------------------------------------------------------

function obj = local_element_object(x, S)
% return an ndi.element object from an object or a document id string
    if isa(x, 'ndi.element')
        obj = x;
    elseif ischar(x) || (isstring(x) && isscalar(x))
        obj = ndi.database.fun.ndi_document2ndi_object(char(x), S);
        if isempty(obj)
            error('ndi:ensemble:load:badElement', ...
                'Could not load an ndi.element for document id ''%s''.', char(x));
        end
    else
        error('ndi:ensemble:load:badElement', ...
            'Elements must be ndi.element objects or document id strings.');
    end
end % local_element_object()
