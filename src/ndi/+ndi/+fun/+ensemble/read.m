function [activity, neuron_ids, neuron_names, info] = read(S, ensembleElement, epoch, options)
% ndi.fun.ensemble.read - read one epoch of an ensemble element (with optional filtering)
%
% [ACTIVITY, NEURON_IDS, NEURON_NAMES, INFO] = ndi.fun.ensemble.READ(S, ENSEMBLEELEMENT, EPOCH, ...)
%
% Reads the ensemble activity for epoch EPOCH from ENSEMBLEELEMENT, an
% ndi.element.ensemble (or its document / id) belonging to the ndi.session (or
% ndi.dataset) S. Optional name/value pairs filter the returned neurons (see
% OPTIONS); this is the one-step equivalent of calling ndi.fun.ensemble.read
% followed by ndi.fun.ensemble.filter (and, for the quality options,
% ndi.fun.ensemble.neuronQuality).
%
% =========================================================================
% OUTPUTS
% =========================================================================
%   ACTIVITY     - an N-neurons-by-Smax sparse matrix; ACTIVITY(i,n) is the time
%                  of the n-th spike of neuron i (reconstructed from the
%                  element's stored marked point process; see
%                  ndi.element.ensemble/spikeMatrix). For a windowed / streaming
%                  read, call ENSEMBLEELEMENT.readtimeseries directly instead.
%   NEURON_IDS   - a 1-by-N cell array of the neuron element document ids, in
%                  the row order of ACTIVITY.
%   NEURON_NAMES - a 1-by-N cell array of the neuron names, same order.
%   INFO         - the 'ensemble' property structure of the epoch's map document
%                  (num_neurons reflects the number of neurons returned).
%
% If any filter option is given, only the kept neurons are returned.
%
% EPOCH may be an epoch id (char) or an epoch index (number).
%
% =========================================================================
% OPTIONS (name/value pairs)
% =========================================================================
% Neuron selection (applied by ndi.fun.ensemble.filter):
%   IncludeNames ({})  - keep only neurons whose name is in this list.
%   ExcludeNames ({})  - drop neurons whose name is in this list.
%   IncludeIndex ([])  - keep only neurons at these 1-based positions.
%   ExcludeIndex ([])  - drop neurons at these 1-based positions.
%   IncludeIds ({})    - keep only neurons whose element id is in this list.
%   ExcludeIds ({})    - drop neurons whose element id is in this list.
%
% Quality selection (looked up with ndi.fun.ensemble.neuronQuality):
%   MinQuality ([])    - keep only neurons whose neuron_extracellular
%                        quality_number is >= this value.
%   QualityLabel ('')  - keep only neurons whose quality_label is in this list
%                        (a char or cell array of char).
%   KeepUnrated (false)- if true, neurons with no neuron_extracellular document
%                        are kept even when a quality option is active; if false
%                        (default) they are dropped by a quality filter.
%
% A neuron that fails a quality criterion is always dropped (quality acts as an
% additional constraint, regardless of the Include* options).
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   [E, ids, names, info] = ndi.fun.ensemble.read(S, ens, 'epoch_1', ...
%       'MinQuality', 2, 'ExcludeNames', {'ctx_1_5'});
%
% See also: ndi.element.ensemble, ndi.fun.ensemble.create,
%   ndi.fun.ensemble.filter, ndi.fun.ensemble.neuronQuality, ndi.fun.ensemble.plot

    arguments
        S
        ensembleElement
        epoch
        options.IncludeNames cell = {}
        options.ExcludeNames cell = {}
        options.IncludeIndex double = []
        options.ExcludeIndex double = []
        options.IncludeIds cell = {}
        options.ExcludeIds cell = {}
        options.MinQuality double = []
        options.QualityLabel = ''
        options.KeepUnrated (1,1) logical = false
    end

    ens = local_ensemble(ensembleElement, S);

    [activity, neuron_ids] = ens.spikeMatrix(epoch);
    neuron_names = ens.neuronNames(epoch);
    mapdoc = ens.epochEnsembleDoc(epoch);
    info = mapdoc.document_properties.ensemble;

    useQuality = ~isempty(options.MinQuality) || ~isempty(options.QualityLabel);
    anyFilter = useQuality || ~isempty(options.IncludeNames) || ~isempty(options.ExcludeNames) ...
        || ~isempty(options.IncludeIndex) || ~isempty(options.ExcludeIndex) ...
        || ~isempty(options.IncludeIds) || ~isempty(options.ExcludeIds);
    if ~anyFilter
        return;
    end

    % quality-failing neurons become extra exclusions (quality is a hard filter)
    exclude_ids = options.ExcludeIds(:).';
    if useQuality
        [qnum, qlabel] = ndi.fun.ensemble.neuronQuality(S, neuron_ids);
        qmask = true(1, numel(neuron_ids));
        if ~isempty(options.MinQuality)
            qmask = qmask & (qnum >= options.MinQuality);
        end
        if ~isempty(options.QualityLabel)
            qmask = qmask & ismember(qlabel, cellstr(options.QualityLabel));
        end
        if options.KeepUnrated
            qmask(isnan(qnum)) = true;
        end
        exclude_ids = [exclude_ids, neuron_ids(~qmask)];
    end

    [activity, neuron_ids, neuron_names, info] = ndi.fun.ensemble.filter( ...
        activity, neuron_ids, neuron_names, info, ...
        'IncludeNames', options.IncludeNames, 'ExcludeNames', options.ExcludeNames, ...
        'IncludeIndex', options.IncludeIndex, 'ExcludeIndex', options.ExcludeIndex, ...
        'IncludeIds', options.IncludeIds, 'ExcludeIds', exclude_ids);

end % read()

% -------------------------------------------------------------------------

function ens = local_ensemble(x, S)
% return an ndi.element.ensemble from an object, a document, or an id
    if isa(x, 'ndi.element.ensemble')
        ens = x;
    else
        ens = ndi.database.fun.ndi_document2ndi_object(x, S);
        if ~isa(ens, 'ndi.element.ensemble')
            error('ndi:ensemble:read:notEnsemble', ...
                'The provided element is not an ndi.element.ensemble.');
        end
    end
end % local_ensemble()
