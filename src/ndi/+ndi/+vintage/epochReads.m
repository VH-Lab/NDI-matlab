function out = epochReads(what, S, ids)
%EPOCHREADS The anchors and statements of a set of migrated epochs, read once per epoch-table build.
%
%   ANCHORS = ndi.vintage.epochReads('anchors', SESSION, EPOCHENTITYIDS)
%   is SESSION.database_search of the `relative_time_reference` documents
%   whose `referent_id` names any of EPOCHENTITYIDS (a cellstr of epoch
%   entity ids), in the database's order.
%
%   STATEMENTS = ndi.vintage.epochReads('statements', SESSION, ANCHORIDS)
%   is the statements whose `time_reference_id` names any of ANCHORIDS, in
%   the database's order, as LIGHT documents: each an ndi.document holding
%   only its base.id, document_class.class_name and the depends_on entries
%   the probe-map and archive reads use (time_reference_id,
%   acquisition_channels_id, acquisition_system_id, instrument_id,
%   entity_id, subject_id), read as edges (ndi.session/database_search_edges)
%   without decoding the statement documents. Where the database cannot
%   answer as edges, they are the full documents, searched as before.
%
%   ONE READ PER BUILD. ndi.vintage.ingestedEpochs (the navigator's probe
%   maps) and ndi.vintage.ingestedArchives (the reader's clocks and t0_t1)
%   ask for the same anchors and statements of the same epochs while one
%   acquisition system builds its epoch table. While a call scope is open
%   (ndi.vintage.elementFieldsScope; ndi.daq.system/buildepochtable opens
%   one), the answer is kept under the session and the exact id set, so the
%   second asker reuses it; a different id set is read anew. Outside a
%   scope nothing is kept. Jess Haley, 2026-11-06: "Speed can't be slower
%   than v1."
%
%   See also ndi.vintage.ingestedEpochs, ndi.vintage.ingestedArchives.

ids = unique(reshape(cellstr(ids), 1, []));
key = [what '|' char(S.id()) '|' strjoin(ids, ',')];
[out, hit] = ndi.vintage.elementFieldsScope('get', key);
if hit
    return;
end
switch what
    case 'anchors'
        out = S.database_search(ndi.query('', 'isa', 'relative_time_reference', '') & ...
            ndi.vintage.edgeIn('referent_id', ids));
    case 'statements'
        q = ndi.v2.isaQuery('statement') & ndi.vintage.edgeIn('time_reference_id', ids);
        names = {'time_reference_id', 'acquisition_channels_id', 'acquisition_system_id', ...
            'instrument_id', 'entity_id', 'subject_id'};
        edges = [];
        if ismethod(S, 'database_search_edges')
            edges = S.database_search_edges(q, names);
        end
        if isstruct(edges)
            out = lightDocs(edges);
        else
            out = S.database_search(q);
        end
    otherwise
        error('NDI:vintage:epochReads:badKind', 'Unknown read "%s".', what);
end
ndi.vintage.elementFieldsScope('put', key, out);
end

function docs = lightDocs(edges)
% one light ndi.document per document, in the edges' (database) order; every
% statement the query matches has a time_reference_id, so none is missing
docs = {};
if isempty(edges)
    return;
end
ids = {edges.doc_id};
[order, ~, which] = unique(ids, 'stable');
docs = cell(1, numel(order));
for d = 1:numel(order)
    rows = edges(which == d);
    p = struct('base', struct('id', order{d}), ...
        'document_class', struct('class_name', 'statement'), ...
        'depends_on', struct('name', {rows.name}, 'value', {rows.document_id}));
    docs{d} = ndi.document(p);
end
end
