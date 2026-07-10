function [activity, neuron_ids, neuron_names, info] = load(S, element, epochid, options)
% ndi.fun.ensemble.load - build a neuron ensemble by reading spikes for an epoch
%
% [ACTIVITY, NEURON_IDS, NEURON_NAMES, INFO] = ndi.fun.ensemble.LOAD(S, ELEMENT, EPOCHID, ...)
%
% Builds the spiking "ensemble" of all neurons recorded during epoch EPOCHID of
% ELEMENT. It loops over the spiking-neuron elements of the ndi.session (or
% ndi.dataset) S, reads each neuron's spike times relative to ELEMENT's epoch,
% and packs them into a sparse matrix ACTIVITY where ACTIVITY(i,n) is the time
% of the n-th spike of neuron i.
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
%                             If empty (default), every element of type
%                             'spikes' in S is considered, and those recorded
%                             during EPOCHID are included.
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
%                  value_type, value_description, and clocktype (the name of
%                  the clock the spike times are in).
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

    % --- time reference for ELEMENT's epoch --------------------------------
    if isempty(options.clocktype)
        et = element_obj.epochtable();
        idx = find(strcmp(epochid, {et.epoch_id}), 1);
        if isempty(idx)
            error('ndi:ensemble:load:noEpoch', ...
                'Element ''%s'' has no epoch ''%s''.', ...
                element_obj.elementstring(), epochid);
        end
        ref_clock = et(idx).epoch_clock{1};
        if ~isa(ref_clock, 'ndi.time.clocktype')
            ref_clock = ndi.time.clocktype(ref_clock);
        end
    else
        ref_clock = ndi.time.clocktype(options.clocktype);
    end
    clockname = ref_clock.type;
    timeref = ndi.time.timereference(element_obj, ref_clock, epochid, 0);

    % --- the candidate neurons --------------------------------------------
    if isempty(options.neurons)
        neurons = S.getelements('element.type','spikes');
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
        'clocktype', clockname);

end % load()

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
