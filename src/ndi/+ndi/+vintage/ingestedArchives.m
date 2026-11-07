function M = ingestedArchives(S, readerId, epochIds)
%INGESTEDARCHIVES Many ingested epochs' clocks and extents, read in a few searches.
%
%   M = ndi.vintage.ingestedArchives(SESSION, READERID, EPOCHIDS) is a
%   containers.Map from each epoch id in EPOCHIDS (a cellstr of
%   `local_identifier`s of v2 epoch entities) to the struct
%
%       ndi.vintage.ingestedArchive(SESSION, READERID, EPOCHID, 'Channels', false)
%
%   returns for it: its clocks, t0_t1 and data bodies, without its channel
%   list. An epoch for which that call would raise an error (no epoch entity,
%   no recording by a system of READERID, no archive body) is not in M; the
%   caller asks ndi.vintage.ingestedArchive for it and gets the error.
%
%   READ ONCE, JOINED IN MEMORY (Jess Haley, 2026-11-06: "Yes, build the
%   speed fix now"). ndi.vintage.ingestedArchive reads one epoch with six
%   searches, and an acquisition system's epoch table asked it twice per
%   epoch (EPOCHCLOCK_INGESTED and T0_T1_INGESTED): 0.34 s per epoch per
%   call over Dab's 1,604 epochs (VH-Lab/NDI-matlab#785, run 41876678241).
%   Here each kind is read once for all of EPOCHIDS: the epoch entities (200
%   ids to a search), the relative_time_references onto them, the reader's
%   systems, their statements timed by those references, and the data bodies
%   those own (one search each, ndi.vintage.edgeIn). Each epoch takes its
%   own from those lists. Every list is in database order and a filter keeps
%   the order, so each epoch's anchors, statements and bodies are the ones,
%   in the order, its own searches return; the archive is put together by
%   the same code (private/archiveOf). ndi.daq.system/buildepochtable uses
%   it through ndi.daq.reader/ingested2epochs_t0t1_epochclock.
%
%   For a v2 database (ndi.vintage.edgeIn).
%
%   See also ndi.vintage.ingestedArchive, ndi.vintage.ingestedEpochs.

arguments
    S
    readerId (1,:) char
    epochIds
    options.ClocksOnly (1,1) logical = false
end

M = containers.Map('KeyType', 'char', 'ValueType', 'any');
epochIds = unique(reshape(cellstr(epochIds), 1, []), 'stable');
epochIds = epochIds(~cellfun(@isempty, epochIds));
if isempty(epochIds)
    return;
end
inSession = ndi.query('base.session_id', 'exact_string', S.id(), '');

% ---- the epochs: entity id -> the epoch ids (local identifiers) it is ----
lidsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
entityIdsOf = containers.Map(epochIds, repmat({{}}, 1, numel(epochIds)));
% read only for their id and local identifier: every entity of the session
% from the database's text index, in one search with no `or` to compile,
% filtered here by local identifier -- the same documents, in the same
% (database) order, as an `or` of the local identifiers 200 at a time (1.48 s
% of 9 searches in run 42342493540, profiled); where the index cannot
% answer, light documents of that `or`, else the documents
allEntities = ndi.vintage.valueDocs(S, ndi.query('', 'isa', 'entity', '') & inSession, ...
    {'entity.local_identifier'}, 'entity');
if iscell(allEntities)
    allLids = cellfun(@(d) localId(d), allEntities, 'UniformOutput', false);
end
for c = 1:200:numel(epochIds)
    part = epochIds(c:min(c + 199, numel(epochIds)));
    if iscell(allEntities)
        found = allEntities(ismember(allLids, part));
    else
        q = ndi.query('', 'isa', 'entity', '') & ...
            ndi.v2.anyOf(cellfun(@(i) ndi.query('entity.local_identifier', 'exact_string', i, ''), ...
                part, 'UniformOutput', false)) & inSession;
        found = ndi.vintage.valueDocs(S, q, {'entity.local_identifier'}, 'entity');
    end
    if ~iscell(found)
        found = S.database_search(q);
    end
    for k = 1:numel(found)
        p = found{k}.document_properties;
        if ~isfield(p, 'entity') || ~isfield(p.entity, 'local_identifier'), continue; end
        lid = p.entity.local_identifier;
        if ~(ischar(lid) || (isstring(lid) && isscalar(lid))), continue; end
        lid = char(lid);
        if ~any(strcmp(part, lid)), continue; end
        id = char(found{k}.id());
        if ~any(strcmp(entityIdsOf(lid), id))
            entityIdsOf(lid) = [entityIdsOf(lid), {id}];
        end
        if isKey(lidsOf, id)
            lidsOf(id) = unique([lidsOf(id), {lid}], 'stable');
        else
            lidsOf(id) = {lid};
        end
    end
end
if lidsOf.Count == 0
    return;
end

% ---- the anchors onto them, filed by epoch ------------------------------
% read once per epoch-table build, shared with ndi.vintage.ingestedEpochs
% (ndi.vintage.epochReads)
anchors = ndi.vintage.epochReads('anchors', S, lidsOf.keys);
anchorRows = containers.Map(epochIds, repmat({[]}, 1, numel(epochIds)));
lidsOfAnchor = containers.Map('KeyType', 'char', 'ValueType', 'any');
for a = 1:numel(anchors)
    mine = {};
    for r = ndi.vintage.edgeTargets(anchors{a}, 'referent_id')
        if isKey(lidsOf, r{1}), mine = [mine, lidsOf(r{1})]; end %#ok<AGROW>
    end
    mine = unique(mine, 'stable');
    lidsOfAnchor(char(anchors{a}.id())) = mine;
    for e = mine
        anchorRows(e{1}) = [anchorRows(e{1}), a];
    end
end

% ---- this reader's systems and their recordings of those epochs ---------
systems = S.database_search(ndi.query('', 'isa', 'acquisition_system', '') & ...
    ndi.query('', 'depends_on', 'reader_id', readerId) & inSession);
if isempty(systems) || isempty(anchors)
    return;
end
% every statement timed by these anchors (shared, light: edges only), kept
% when it names one of this reader's systems -- the `depends_on
% acquisition_system_id` test the search made, made in memory on the edges
allStatements = ndi.vintage.epochReads('statements', S, lidsOfAnchor.keys);
sysIds = cellfun(@(d) char(d.id()), systems, 'UniformOutput', false);
keepSt = cellfun(@(st) any(ismember(ndi.vintage.edgeTargets(st, 'acquisition_system_id'), sysIds)), ...
    allStatements);
statements = allStatements(keepSt);
statementRows = containers.Map(epochIds, repmat({[]}, 1, numel(epochIds)));
lidsOfStatement = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(statements)
    mine = {};
    for t = ndi.vintage.edgeTargets(statements{i}, 'time_reference_id')
        if isKey(lidsOfAnchor, t{1}), mine = [mine, lidsOfAnchor(t{1})]; end %#ok<AGROW>
    end
    mine = unique(mine, 'stable');
    id = char(statements{i}.id());
    if isKey(lidsOfStatement, id)
        lidsOfStatement(id) = unique([lidsOfStatement(id), mine], 'stable');
    else
        lidsOfStatement(id) = mine;
    end
    for e = mine
        statementRows(e{1}) = [statementRows(e{1}), i];
    end
end
if isempty(statements)
    return;
end

% ---- the bodies they own -----------------------------------------------
% light where the database can (ndi.vintage.lightDocs): the class, filename
% and time dimension archiveOf reads, and the owner edges they are filed by.
% Only the clocks and t0_t1 are read from what this returns
% (ndi.daq.reader/ingested2epochs_t0t1_epochclock); a light body records no
% files, so its member count reads 0.
bq = ndi.query('', 'isa', 'data_body', '') & ndi.vintage.edgeIn('owner_id', lidsOfStatement.keys);
if options.ClocksOnly
    % 'ClocksOnly' (ndi.daq.reader/ingested2epochs_t0t1_epochclock reads
    % each archive's epochclock and t0_t1 and nothing else): the bodies are
    % read for their filename and owner only, which decide whether an epoch
    % has an archive body; their n, chunk and members are left empty. The
    % dimension terms are no sidecar path (one `[*]` level, then a block), so
    % asking for them decoded every body: 6,416 in run 42342493540.
    bodies = ndi.vintage.lightDocs(S, bq, {'data_body.filename'}, {'owner_id'}, 'data_body');
else
    bodies = ndi.vintage.lightDocs(S, bq, {'data_body.filename', ...
        'data.dimensions[*].term.node', 'data.dimensions[*].term.name', ...
        'data.dimensions[*].n', 'data.dimensions[*].chunk'}, {'owner_id'}, 'data_body', ...
        'AllElements', true);
end
if ~iscell(bodies)
    bodies = S.database_search(bq);
end
bodyRows = containers.Map(epochIds, repmat({[]}, 1, numel(epochIds)));
for b = 1:numel(bodies)
    mine = {};
    for o = ndi.vintage.edgeTargets(bodies{b}, 'owner_id')
        if isKey(lidsOfStatement, o{1}), mine = [mine, lidsOfStatement(o{1})]; end %#ok<AGROW>
    end
    for e = unique(mine, 'stable')
        bodyRows(e{1}) = [bodyRows(e{1}), b];
    end
end

% ---- each epoch's archive, put together as ingestedArchive does ---------
for e = 1:numel(epochIds)
    lid = epochIds{e};
    st = statements(unique(statementRows(lid)));
    if isempty(entityIdsOf(lid)) || isempty(st)
        continue;   % ingestedArchive raises ingestedNoEpoch / ingestedNoRecording
    end
    try
        M(lid) = archiveOf(S, lid, anchors(unique(anchorRows(lid))), st, ...
            bodies(unique(bodyRows(lid))), false);
    catch
        % ingestedArchive raises the same error; the caller asks it
    end
end
end

function lid = localId(d)
% an entity's local identifier as char, '' when it has none
lid = '';
p = d.document_properties;
if isfield(p, 'entity') && isstruct(p.entity) && isfield(p.entity, 'local_identifier')
    v = p.entity.local_identifier;
    if ischar(v) || (isstring(v) && isscalar(v)); lid = char(v); end
end
end
