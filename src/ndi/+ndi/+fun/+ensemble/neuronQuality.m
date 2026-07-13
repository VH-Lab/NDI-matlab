function [quality_number, quality_label] = neuronQuality(S, neuron_ids)
% ndi.fun.ensemble.neuronQuality - look up the quality of an ensemble's neurons
%
% [QUALITY_NUMBER, QUALITY_LABEL] = ndi.fun.ensemble.NEURONQUALITY(S, NEURON_IDS)
%
% For each neuron element id in NEURON_IDS (e.g. the ids returned by
% ndi.fun.ensemble.read), looks up its 'neuron_extracellular' document in the
% ndi.session (or ndi.dataset) S and returns the recorded spike-sorting quality.
%
% QUALITY_NUMBER is a 1-by-N double: QUALITY_NUMBER(i) is the quality_number of
% NEURON_IDS{i}, or NaN if that neuron has no neuron_extracellular document.
% QUALITY_LABEL is a 1-by-N cell array of the corresponding quality_label
% strings ('' where there is no document).
%
% The lookup is done with a single database search for the neuron_extracellular
% documents, which are then matched to NEURON_IDS by their element_id
% dependency (rather than one query per neuron). If a neuron has more than one
% neuron_extracellular document, an error is raised.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   E = ndi.fun.ensemble.read(S, ens, 'epoch_1');
%   [qnum, qlabel] = ndi.fun.ensemble.neuronQuality(S, E.neuron_ids);
%   good = E.neuron_ids(qnum >= 2);   % neurons with quality_number at least 2
%
% See also: ndi.fun.ensemble.read, ndi.fun.ensemble.filter

    arguments
        S
        neuron_ids cell
    end

    N = numel(neuron_ids);
    quality_number = nan(1, N);
    quality_label = repmat({''}, 1, N);

    % one search for all neuron_extracellular documents, matched to the neurons
    % by their element_id dependency
    docs = S.database_search(ndi.query('','isa','neuron_extracellular',''));
    if isempty(docs)
        return;
    end

    doc_element_ids = cell(1, numel(docs));
    for i = 1:numel(docs)
        doc_element_ids{i} = docs{i}.dependency_value('element_id');
    end

    for i = 1:N
        matches = find(strcmp(neuron_ids{i}, doc_element_ids));
        if isempty(matches)
            continue;
        end
        if numel(matches) > 1
            error('ndi:ensemble:neuronQuality:multiple', ...
                ['Neuron %s has %d neuron_extracellular documents; expected at ' ...
                'most one.'], neuron_ids{i}, numel(matches));
        end
        ne = docs{matches}.document_properties.neuron_extracellular;
        quality_number(i) = ne.quality_number;
        quality_label{i} = ne.quality_label;
    end

end % neuronQuality()
