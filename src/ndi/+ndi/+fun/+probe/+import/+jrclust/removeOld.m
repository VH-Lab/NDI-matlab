function removeOld(S, jcDoc)
% NDI.FUN.PROBE.IMPORT.JRCLUST.REMOVEOLD - remove a previous JRCLUST import
%
% NDI.FUN.PROBE.IMPORT.JRCLUST.REMOVEOLD(S, JCDOC)
%
% Removes a previously imported set of JRCLUST neurons from the ndi.session S.
% JCDOC is a 'jrclust_clusters' ndi.document. This function finds every
% 'neuron_extracellular' document that depends on JCDOC (via its spike_clusters_id
% dependency), removes those documents, removes the underlying neuron elements
% (including their epoch documents), and finally removes JCDOC itself.
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE

    arguments
        S
        jcDoc
    end

    % find neuron_extracellular docs that point at this cluster document
    q = ndi.query('','isa','neuron_extracellular','') & ...
        ndi.query('','depends_on','spike_clusters_id', jcDoc.id());
    neuronDocs = S.database_search(q);

    for i=1:numel(neuronDocs),
        elementId = neuronDocs{i}.dependency_value('element_id');
        if ~isempty(elementId),
            % remove the neuron element document and anything that depends on it
            % (its epoch documents)
            qElem = ndi.query('base.id','exact_string',elementId) | ...
                ndi.query('','depends_on','element_id',elementId);
            elemDocs = S.database_search(qElem);
            if ~isempty(elemDocs),
                S.database_rm(elemDocs);
            end;
        end;
    end;

    if ~isempty(neuronDocs),
        S.database_rm(neuronDocs);
    end;

    S.database_rm(jcDoc);

end % removeOld()
