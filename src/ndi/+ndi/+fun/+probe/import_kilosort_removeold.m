function import_kilosort_removeold(S, kc_doc)
% NDI.FUN.PROBE.IMPORT_KILOSORT_REMOVEOLD - remove a previous kilosort import
%
% NDI.FUN.PROBE.IMPORT_KILOSORT_REMOVEOLD(S, KC_DOC)
%
% Removes a previously imported set of kilosort neurons from the ndi.session S.
% KC_DOC is a 'kilosort_clusters' ndi.document. This function finds every
% 'neuron_extracellular' document that depends on KC_DOC (via its spike_clusters_id
% dependency), removes those documents, removes the underlying neuron elements
% (including their epoch documents), and finally removes KC_DOC itself.
%
% See also: NDI.FUN.PROBE.IMPORT_KILOSORT

    % find neuron_extracellular docs that point at this cluster document
    q = ndi.query('','isa','neuron_extracellular','') & ...
        ndi.query('','depends_on','spike_clusters_id', kc_doc.id());
    neuron_docs = S.database_search(q);

    for i=1:numel(neuron_docs),
        element_id = neuron_docs{i}.dependency_value('element_id');
        if ~isempty(element_id),
            % remove the neuron element document and anything that depends on it
            % (its epoch documents)
            q_elem = ndi.query('base.id','exact_string',element_id) | ...
                ndi.query('','depends_on','element_id',element_id);
            elem_docs = S.database_search(q_elem);
            if ~isempty(elem_docs),
                S.database_rm(elem_docs);
            end;
        end;
    end;

    if ~isempty(neuron_docs),
        S.database_rm(neuron_docs);
    end;

    S.database_rm(kc_doc);

end
