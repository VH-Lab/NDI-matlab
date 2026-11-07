function out = epochReads(what, S, ids)
%EPOCHREADS The anchors and statements of a set of migrated epochs, read once per epoch-table build.
%
%   ANCHORS = ndi.vintage.epochReads('anchors', SESSION, EPOCHENTITYIDS)
%   is the `relative_time_reference` documents whose `referent_id` names any
%   of EPOCHENTITYIDS (a cellstr of epoch entity ids), in the database's
%   order, as LIGHT documents holding their referent_id edges and the
%   value's clock and start / duration / end seconds (ndi.vintage.lightDocs),
%   where the database can; else the full documents.
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
% A read of a SUPERSET of IDS in this call answers too: its documents whose
% edge (referent_id for anchors, time_reference_id for statements) names one
% of IDS, in its (database) order -- the documents, in the order, a search
% for IDS returns, since that search is the same filter on the same table.
% ndi.vintage.ingestedArchives and ndi.vintage.ingestedEpochs ask for
% different sets of one acquisition system's epochs (run 42342493540: two
% reads of each kind, 2.2 s each, profiled).
edgeName = 'referent_id';
if strcmp(what, 'statements'); edgeName = 'time_reference_id'; end
listKey = ['sets|' what '|' char(S.id())];
[sets, hasSets] = ndi.vintage.elementFieldsScope('get', listKey);
if ~hasSets; sets = {}; end
for k = 1:numel(sets)
    if all(ismember(ids, sets{k}.ids))
        % each document's edge targets were listed once, flat, when it was
        % read (sets{k}.docOf, .target)
        keep = unique(sets{k}.docOf(ismember(sets{k}.target, ids)));
        out = sets{k}.out(keep);
        ndi.vintage.elementFieldsScope('put', key, out);
        return;
    end
end
% MOSTLY a superset: read only the ids it lacks, and answer with its
% documents onto IDS followed by those -- when no document is in both. Then
% every document belongs to one part, so each epoch's documents (all onto
% it) come from one read, in that read's database order, which is all the
% callers use (each files the answer by epoch). ingestedEpochs reads the
% epochs that have a manifest and ingestedArchives every epoch of the
% table: 1,579 and 1,604 of Dab's (run 42354072404). When a document is
% in both, IDS is read whole.
out = [];
for k = 1:numel(sets)
    missing = ids(~ismember(ids, sets{k}.ids));
    if numel(missing) > numel(ids) / 2
        continue;
    end
    keep = unique(sets{k}.docOf(ismember(sets{k}.target, ids)));
    old = reshape(sets{k}.out(keep), [], 1);
    more = reshape(readKind(what, S, missing), [], 1);
    oldIds = cellfun(@(d) char(d.id()), old, 'UniformOutput', false);
    moreIds = cellfun(@(d) char(d.id()), more, 'UniformOutput', false);
    if ~any(ismember(moreIds, oldIds))
        out = reshape([old; more], 1, []);
    end
    break;
end
if ~iscell(out)
    out = readKind(what, S, ids);
end
ndi.vintage.elementFieldsScope('put', key, out);
if ndi.vintage.elementFieldsScope('isopen')
    targets = cellfun(@(d) reshape(ndi.vintage.edgeTargets(d, edgeName), 1, []), out, ...
        'UniformOutput', false);
    docOf = zeros(1, 0);
    if ~isempty(out)
        docOf = repelem(1:numel(out), cellfun(@numel, targets));
    end
    sets{end+1} = struct('ids', {ids}, 'out', {out}, 'docOf', docOf, ...
        'target', {[{}, targets{:}]});
    ndi.vintage.elementFieldsScope('put', listKey, sets);
end
end

function out = readKind(what, S, ids)
% one read of WHAT for IDS
switch what
    case 'anchors'
        % light: the clock and the start / duration / end seconds archiveOf
        % reads, and the referent edges the probe-map read files them by
        q = ndi.query('', 'isa', 'relative_time_reference', '') & ...
            ndi.vintage.edgeIn('referent_id', ids);
        v = 'relative_time_reference.value.';
        out = ndi.vintage.lightDocs(S, q, {[v 'clock.node'], [v 'clock.name'], ...
            [v 'start.seconds'], [v 'duration.seconds'], [v 'end.seconds']}, ...
            {'referent_id'}, 'relative_time_reference');
        if ~iscell(out)
            out = S.database_search(q);
        end
    case 'statements'
        q = ndi.v2.isaQuery('statement') & ndi.vintage.edgeIn('time_reference_id', ids);
        names = {'time_reference_id', 'acquisition_channels_id', 'acquisition_system_id', ...
            'instrument_id', 'entity_id', 'subject_id'};
        if takesAllNames(S)
            % every edge, so a numbered time_reference_id_<n> (which
            % ndi.v2.edgeIds reads as an anchor too) is in the light
            % statement as in the document (DID-matlab searchEdges '*')
            names = '*';
        end
        out = ndi.vintage.edgeDocs(S, q, names, 'statement');
        if ~iscell(out)
            out = S.database_search(q);
        end
    otherwise
        error('NDI:vintage:epochReads:badKind', 'Unknown read "%s".', what);
end
end

function tf = takesAllNames(S)
% does SESSION's database answer searchEdges(Q, '*') with every edge?
tf = false;
try
    db = S.database;
    tf = isa(db, 'ndi.database.implementations.database.did2sqlite') ...
        && ismethod(db.db, 'searchEdgesTakesAllNames') ...
        && did2.database.sqlitedb.searchEdgesTakesAllNames();
catch
    tf = false;
end
end
