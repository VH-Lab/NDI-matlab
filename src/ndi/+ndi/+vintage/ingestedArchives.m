function [M, D] = ingestedArchives(S, readerId, epochIds, options)
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
    options.UseIndex (1,1) logical = true
end

M = containers.Map('KeyType', 'char', 'ValueType', 'any');
D = containers.Map('KeyType', 'char', 'ValueType', 'any');   % 'ClocksOnly': each epoch's read ids (the index's deps)
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
allEntities = ndi.vintage.entitiesByLocalId(S, epochIds);
for c = 1:200:numel(epochIds)
    part = epochIds(c:min(c + 199, numel(epochIds)));
    if iscell(allEntities)
        found = allEntities(ismember(cellfun(@(d) localId(d), allEntities, ...
            'UniformOutput', false), part));
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
if options.ClocksOnly && options.UseIndex && ndi.vintage.epochIndex('available', S)
    M = fromIndexOrRead(S, readerId, epochIds, entityIdsOf);
    return;
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
    % set-wise, from the index rows (no body, statement or archive struct
    % built per epoch): see clocksOnly below
    [C, D] = clocksOnly(S, bq, epochIds, entityIdsOf, anchors, anchorRows, statements, statementRows);
    if isa(C, 'containers.Map')
        M = C;
        return;
    end
end
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

function [M, D] = clocksOnly(S, bq, epochIds, entityIdsOf, anchors, anchorRows, statements, statementRows)
D = containers.Map('KeyType', 'char', 'ValueType', 'any');
% ingestedArchives 'ClocksOnly', set-wise: each epoch's epochclock, t0_t1
% and clock_problem as private/archiveOf gives them, and no other part
% ('bodies' is an empty map). The bodies are read as index rows -- each
% one's filename and owner (ndi.session/database_search_values and
% database_search_edges) -- and an epoch is left out, as archiveOf's error
% leaves it out, when none of its recordings owns an archive series body.
% Each anchor's clock and extent are read once, not once per epoch. M is []
% when the database cannot answer from its index; the caller then reads the
% bodies as documents.
M = [];
if ~ismethod(S, 'database_search_values') || ~ismethod(S, 'database_search_edges')
    return;
end
rows = S.database_search_values(bq, {'data_body.filename'});
if ~isstruct(rows); return; end
edges = S.database_search_edges(bq, {'owner_id'});
if ~isstruct(edges); return; end
M = containers.Map('KeyType', 'char', 'ValueType', 'any');
% the statements owning an archive series body (archiveOf's seriesKind)
fns = cellfun(@(v) char(v{1}), {rows.values}, 'UniformOutput', false);
isSeries = strcmp(fns, 'channel_list.bin') | ~cellfun(@isempty, ...
    regexp(fns, '^(ai|ao|ax|di|do|ti|evmktx)_group\d+_seg\.nbf_#$', 'once'));
seriesDocs = {rows(isSeries).doc_id};
seriesOwners = {};
if ~isempty(edges)
    seriesOwners = unique({edges(ismember({edges.doc_id}, seriesDocs)).document_id});
end
% each anchor's id and clock extent; each statement's id and anchors
aIds = cellfun(@(d) char(d.id()), anchors, 'UniformOutput', false);
aOk = false(1, numel(anchors)); aClk = cell(1, numel(anchors)); aT = cell(1, numel(anchors));
handles = containers.Map('KeyType', 'char', 'ValueType', 'char');
for a = 1:numel(anchors)
    [aOk(a), aClk{a}, t0, t1] = anchorClockExtent(anchors{a}.document_properties, handles);
    aT{a} = [t0 t1];
end
sIds = cellfun(@(d) char(d.id()), statements, 'UniformOutput', false);
sUsed = cellfun(@(d) ndi.v2.edgeIds(d.document_properties, 'time_reference_id'), statements, ...
    'UniformOutput', false);
for e = 1:numel(epochIds)
    lid = epochIds{e};
    si = unique(statementRows(lid));
    % what this epoch's answer is read from (the derived index's deps): its
    % entities, the anchors onto them and the statements they time
    D(lid) = [reshape(entityIdsOf(lid), 1, []), reshape(aIds(unique(anchorRows(lid))), 1, []), ...
        reshape(sIds(si), 1, [])];
    if isempty(entityIdsOf(lid)) || isempty(si)
        continue;   % ingestedArchive raises ingestedNoEpoch / ingestedNoRecording
    end
    if ~any(ismember(sIds(si), seriesOwners))
        continue;   % archiveOf raises ingestedNoBodies
    end
    ai = unique(anchorRows(lid));
    used = [{}, sUsed{si}];
    isUsed = ismember(aIds(ai), used);
    A = struct('vintage', 'v2', 'epoch_id', lid, ...
        'bodies', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
        'channels', [], 'epochclock', {{}}, 't0_t1', {{}}, 'clock_problem', '');
    for a = [ai(isUsed), ai(~isUsed)]
        if aOk(a) && ~any(strcmp(A.epochclock, aClk{a}))
            A.epochclock{end+1} = aClk{a};
            A.t0_t1{end+1} = aT{a};
        end
    end
    if isempty(A.epochclock)
        A.clock_problem = sprintf(['The migrated epoch %s states no clock: none of its %d time ' ...
            'reference(s) (relative_time_reference onto the epoch entity) names a clock and a start, ' ...
            'so its epoch clock and t0_t1 cannot be read (did-schema [clock only on the time ' ...
            'reference]: "the recording observation''s time references say when the epoch starts ' ...
            'on each clock").'], lid, numel(ai));
    end
    M(lid) = A;
end
end

function M = fromIndexOrRead(S, readerId, epochIds, entityIdsOf)
% 'ClocksOnly' through the derived index (ndi.vintage.epochIndex; Jess
% Haley, 2026-11-09: "Build the derived index"). An epoch's row holds its
% answer (present or left out, and the clocks) and the ids of its entities;
% it is used when those are the entities that have its local identifier
% now (read just above, so a new entity with that identifier is seen), and
% the row is current (every other document it was read from is recorded
% with it). The other epochs are read as before and their rows stored.
M = containers.Map('KeyType', 'char', 'ValueType', 'any');
got = ndi.vintage.epochIndex('get', S, 'ndi.epochs.reader', readerId, epochIds);
missing = {};
for e = 1:numel(epochIds)
    lid = epochIds{e};
    ents = sort(reshape(cellstr(entityIdsOf(lid)), 1, []));
    if isKey(got, lid)
        v = got(lid);
        if isequal(sort(reshape(asCellstr(v.entities), 1, [])), ents)
            if v.present
                M(lid) = archiveFromIndex(lid, v);
            end
            continue;
        end
    end
    missing{end+1} = lid; %#ok<AGROW>
end
if isempty(missing)
    return;
end
[M2, D2] = ndi.vintage.ingestedArchives(S, readerId, missing, 'ClocksOnly', true, 'UseIndex', false);
values = cell(1, numel(missing));
deps = cell(1, numel(missing));
for e = 1:numel(missing)
    lid = missing{e};
    ents = sort(reshape(cellstr(entityIdsOf(lid)), 1, []));
    d = [{readerId}, ents];
    if isKey(D2, lid); d = [d, D2(lid)]; end %#ok<AGROW>
    deps{e} = d;
    if isKey(M2, lid)
        A = M2(lid);
        M(lid) = A;
        values{e} = archiveToIndex(ents, true, A);
    else
        values{e} = archiveToIndex(ents, false, []);
    end
end
ndi.vintage.epochIndex('put', S, 'ndi.epochs.reader', readerId, missing, values, deps);
end

function v = archiveToIndex(ents, present, A)
% an epoch's row: its entities, whether it has an answer, and the answer's
% clocks, t0 / t1 written with 17 significant digits (exact round trip)
v = struct('entities', {ents}, 'present', present, 'epochclock', {{}}, ...
    't0', {{}}, 't1', {{}}, 'clock_problem', '');
if ~present; return; end
v.epochclock = A.epochclock;
v.t0 = cellfun(@(t) sprintf('%.17g', t(1)), A.t0_t1, 'UniformOutput', false);
v.t1 = cellfun(@(t) sprintf('%.17g', t(2)), A.t0_t1, 'UniformOutput', false);
v.clock_problem = A.clock_problem;
end

function A = archiveFromIndex(lid, v)
% the struct clocksOnly makes, from an epoch's row
A = struct('vintage', 'v2', 'epoch_id', lid, ...
    'bodies', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'channels', [], 'epochclock', {{}}, 't0_t1', {{}}, 'clock_problem', char(v.clock_problem));
clk = asCellstr(v.epochclock); t0 = asCellstr(v.t0); t1 = asCellstr(v.t1);
for i = 1:numel(clk)
    A.epochclock{end+1} = clk{i};
    A.t0_t1{end+1} = [str2double(t0{i}) str2double(t1{i})];
end
end

function c = asCellstr(x)
% a decoded JSON list of strings as a row cellstr
if isempty(x)
    c = {};
elseif ischar(x)
    c = {x};
else
    c = reshape(cellstr(x), 1, []);
end
end
