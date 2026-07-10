function [activity, neuron_ids, neuron_names, info] = filter(activity, neuron_ids, neuron_names, info, options)
% ndi.fun.ensemble.filter - select a subset of the neurons in an ensemble read
%
% [ACTIVITY, NEURON_IDS, NEURON_NAMES, INFO] = ndi.fun.ensemble.FILTER(...
%     ACTIVITY, NEURON_IDS, NEURON_NAMES, INFO, ...)
%
% Takes the outputs of ndi.fun.ensemble.read and returns the same outputs with
% only the kept neurons: rows of ACTIVITY, and the entries of NEURON_IDS and
% NEURON_NAMES, are subset to the kept neurons; INFO.num_neurons is updated; and
% any all-zero trailing columns of ACTIVITY are trimmed. This is a pure,
% in-memory operation (no database access).
%
% The kept set is computed as follows. If any "include" criterion is given
% (IncludeNames, IncludeIndex, IncludeIds, or Keep), the kept set starts as the
% UNION of everything those criteria select; otherwise it starts as all neurons.
% Then every "exclude" criterion (ExcludeNames, ExcludeIndex, ExcludeIds) is
% removed from the kept set. (So an exclude always wins over an include.)
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
%   IncludeNames ({})  - keep neurons whose name is in this cell array.
%   ExcludeNames ({})  - drop neurons whose name is in this cell array.
%   IncludeIndex ([])  - keep neurons at these 1-based positions.
%   ExcludeIndex ([])  - drop neurons at these 1-based positions.
%   IncludeIds ({})    - keep neurons whose element id is in this cell array.
%   ExcludeIds ({})    - drop neurons whose element id is in this cell array.
%   Keep ([])          - an explicit selection: a 1-by-N logical mask, or a
%                        vector of 1-based indices, to keep. (Used, for example,
%                        to apply a mask computed from ndi.fun.ensemble.neuronQuality.)
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   [A, ids, names, info] = ndi.fun.ensemble.read(S, ens, 'epoch_1');
%   [A, ids, names, info] = ndi.fun.ensemble.filter(A, ids, names, info, ...
%       'ExcludeNames', {'ctx_1_5'});
%
% See also: ndi.fun.ensemble.read, ndi.fun.ensemble.neuronQuality

    arguments
        activity
        neuron_ids cell
        neuron_names cell
        info
        options.IncludeNames cell = {}
        options.ExcludeNames cell = {}
        options.IncludeIndex double = []
        options.ExcludeIndex double = []
        options.IncludeIds cell = {}
        options.ExcludeIds cell = {}
        options.Keep = []
    end

    N = numel(neuron_ids);

    hasInclude = ~isempty(options.IncludeNames) || ~isempty(options.IncludeIndex) ...
        || ~isempty(options.IncludeIds) || ~isempty(options.Keep);

    if hasInclude
        keep = false(1, N);
        keep = keep | local_member_mask(neuron_names, options.IncludeNames);
        keep = keep | local_index_mask(N, options.IncludeIndex);
        keep = keep | local_member_mask(neuron_ids, options.IncludeIds);
        keep = keep | local_keep_mask(N, options.Keep);
    else
        keep = true(1, N);
    end

    % excludes always remove from the kept set
    keep = keep & ~local_member_mask(neuron_names, options.ExcludeNames);
    keep = keep & ~local_index_mask(N, options.ExcludeIndex);
    keep = keep & ~local_member_mask(neuron_ids, options.ExcludeIds);

    idx = find(keep);

    activity = activity(idx, :);
    activity = local_trim_columns(activity);
    neuron_ids = neuron_ids(idx);
    neuron_names = neuron_names(idx);
    if isstruct(info) && isfield(info, 'num_neurons')
        info.num_neurons = numel(idx);
    end

end % filter()

% -------------------------------------------------------------------------

function m = local_member_mask(list, targets)
% 1-by-numel(list) logical: true where list{i} is in the cell array TARGETS
    m = false(1, numel(list));
    if isempty(targets)
        return;
    end
    m = ismember(list, targets);
    m = m(:).';
end % local_member_mask()

function m = local_index_mask(N, idxs)
% 1-by-N logical true at the 1-based positions in IDXS
    m = false(1, N);
    if isempty(idxs)
        return;
    end
    idxs = idxs(:).';
    if any(idxs < 1 | idxs > N | idxs ~= round(idxs))
        error('ndi:ensemble:filter:badIndex', ...
            'Index values must be integers between 1 and %d.', N);
    end
    m(idxs) = true;
end % local_index_mask()

function m = local_keep_mask(N, keep)
% 1-by-N logical from a logical mask or an index vector
    m = false(1, N);
    if isempty(keep)
        return;
    end
    if islogical(keep)
        if numel(keep) ~= N
            error('ndi:ensemble:filter:badKeep', ...
                'A logical Keep mask must have %d elements.', N);
        end
        m = keep(:).';
    else
        m = local_index_mask(N, keep);
    end
end % local_keep_mask()

function A = local_trim_columns(A)
% drop all-zero trailing columns (keeping at least one column)
    if isempty(A)
        return;
    end
    lastcol = find(any(A ~= 0, 1), 1, 'last');
    if isempty(lastcol)
        lastcol = 1;
    end
    A = A(:, 1:lastcol);
end % local_trim_columns()
