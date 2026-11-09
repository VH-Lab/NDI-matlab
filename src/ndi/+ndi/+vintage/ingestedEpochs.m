function E = ingestedEpochs(ndi_session_obj, docs, probemapClass, options)
%INGESTEDEPOCHS Each ingested epoch's id, files and probe map, read from either vintage.
%
%   E = ndi.vintage.ingestedEpochs(SESSION, DOCS, PROBEMAPCLASS). DOCS are
%   the documents ndi.vintage.ingestedQuery found (a cell of ndi.document);
%   PROBEMAPCLASS the navigator's epochprobemap class (already validated by
%   the caller). E is a struct array, one per document, with fields
%
%     epoch_id   the epoch's id string ('t00001')
%     files      the files ingested for it (cellstr)
%     probemap   the epoch's probe map, an object of PROBEMAPCLASS, or []
%                when none can be read
%     vintage    'v1' or 'V_eta'
%
%   v1 `epochfiles_ingested` holds all three in its block. A migrated
%   `ingestion_manifest` (did-schema #88; Jess Haley 2026-10-22 [ingested
%   epochs found]) holds only `files`:
%
%     epoch_id   is the `local_identifier` of the `epoch` entity its
%                `epoch_id` edge names (DID-matlab epochMint)
%     probemap   was DECOMPOSED by DID-matlab's resolveEpochProbemap into one
%                observation (or, for a stimulator, manipulation) per row,
%                timed by a relative_time_reference onto that epoch entity.
%                Each row is put back together from its statement:
%                  name, reference, type  the instrument_id element entity
%                                         (ndi.vintage.elementFields)
%                  subjectstring          the entity_id entity's
%                                         local_identifier
%                  devicestring           the statement's acquisition_system_id
%                                         system's name, ':', then the
%                                         conditions of the probe's wiring
%                                         relation (a directed_relation
%                                         `connected to`, RO:0002170, child
%                                         the probe, parent the system, timed
%                                         by the statement's anchor; did-schema
%                                         [probe wiring is a relation]), each
%                                         a channel type's v1 prefix -- found
%                                         BY NODE through
%                                         ndi.vintage.channelPrefix ([channel
%                                         types]) -- and its numbers. A
%                                         session migrated before that names
%                                         system and channels through an
%                                         acquisition_channels_id document;
%                                         both are read.
%                Rows are kept once each, in statement order. A manifest whose
%                statements give no row reads as probemap [].
%
%                ONLY THE MANIFEST'S OWN SYSTEM. One epoch is one recording,
%                shared by every acquisition system that wrote files for it
%                (Decided by Jess Haley, 2026-10-26 [device clocks on one
%                epoch]: B's vhspike2 and vhvis_spike2 share "t00001"), so
%                the epoch's statements are those of all its systems. A v1
%                navigator's epoch held only its own system's rows, so a row
%                is kept only when its system's `epoch_file_pattern_id` is the
%                manifest's (a row whose system states none is kept). Without
%                this, B's vhvis_spike2 epochs read vhspike2's tet1 row too
%                (VH-Lab/NDI-matlab#785 corpus equivalence: 1,242 epochs).
%
%   Lookups (element fields, systems, subjects) are cached across DOCS, so a
%   navigator reading a session's ingested epochs reads each element once.
%
%   E = ndi.vintage.ingestedEpochs(..., 'Batch', TF). READ ONCE, JOINED IN
%   MEMORY (Jess Haley, 2026-11-06: "Yes, build the speed fix now"). With
%   Batch true (the default on a v2 database), the documents every migrated
%   epoch of DOCS needs are read before the first epoch is put together, a
%   kind at a time: the epoch entities by id; the relative_time_references
%   onto them (one search, ndi.vintage.edgeIn); the statements timed by those
%   (one search); the systems, acquisition channels, probes and subjects the
%   statements name, by id (200 to a search); and the wiring relations timed
%   by the statements' anchors (one search). Each epoch then takes its own
%   from those lists, in the order its own searches would have returned them
%   (each list is in database order, and a filter keeps the order), so E is
%   the same. Before it, every epoch cost about 13 searches: Dab's
%   1,604-epoch session read its acquisition system's epoch table in 0.86 s
%   per epoch (VH-Lab/NDI-matlab#785, run 41876678241). Batch false reads
%   each epoch with its own searches, as before; the unit test
%   ndi.unittest.vintage.TestIngestedReadsBatched checks the two agree.
%   Element fields (ndi.vintage.elementFields) are still read per element,
%   once per call.
%
%   See also ndi.vintage.ingestedQuery, ndi.file.navigator/selectfilegroups.

arguments
    ndi_session_obj
    docs cell
    probemapClass (1,:) char
    options.Batch (1,1) logical = ndi.daq.reader.isv2database(ndi_session_obj)
    options.UseIndex (1,1) logical = true
end

E = struct('epoch_id', {}, 'files', {}, 'probemap', {}, 'vintage', {});
% statements: epoch entity id -> the statements timed onto it, read ahead
% (Batch); relations: the wiring relations read ahead, [] when not read
cache = struct('doc', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'element', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'statements', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'relations', [], ...
    'wiringGroups', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'own', containers.Map('KeyType', 'char', 'ValueType', 'logical'), ...
    'subjectString', containers.Map('KeyType', 'char', 'ValueType', 'char'));
% THE DERIVED INDEX (ndi.vintage.epochIndex; Jess Haley, 2026-11-09:
% "Build the derived index"): each migrated manifest's entry (epoch id,
% files, probe-map rows) as computed below, kept with the ids it was read
% from; a manifest whose row is current is answered from it, the others are
% computed (and their rows stored). 'UseIndex', false computes every entry.
useIndex = options.Batch && options.UseIndex && ndi.vintage.epochIndex('available', ndi_session_obj);
indexed = containers.Map('KeyType', 'char', 'ValueType', 'any');
toCompute = docs;
if useIndex
    mids = manifestIds(docs);
    indexed = ndi.vintage.epochIndex('get', ndi_session_obj, 'ndi.epochs.navigator', ...
        probemapClass, mids(~cellfun(@isempty, mids)));
    toCompute = docs(~ismember(mids, indexed.keys));
end
newKeys = {}; newValues = {}; newDeps = {};
if options.Batch
    % the instruments' fields are read for all of them at once and kept for
    % this call (ndi.vintage.prefetchElementFields)
    scope = ndi.vintage.elementFieldsScope('open'); %#ok<NASGU>
    cache = readAhead(ndi_session_obj, toCompute, cache);
end
for k = 1:numel(docs)
    p = docs{k}.document_properties;
    if isfield(p, 'epochfiles_ingested')
        blk = p.epochfiles_ingested;
        pm = [];
        if isfield(blk, 'epochprobemap') && ~isempty(blk.epochprobemap)
            pm = feval(probemapClass, blk.epochprobemap);
        end
        E(end+1) = struct('epoch_id', char(blk.epoch_id), 'files', {asCellstr(blk.files)}, ...
            'probemap', {pm}, 'vintage', 'v1'); %#ok<AGROW>
        continue;
    end
    if ~isfield(p, 'ingestion_manifest')
        continue;
    end
    files = {};
    if isfield(p.ingestion_manifest, 'files')
        files = asCellstr(p.ingestion_manifest.files);
    end
    mid = char(p.base.id);
    if isKey(indexed, mid)
        E(end+1) = fromIndex(indexed(mid), files, probemapClass); %#ok<AGROW>
        continue;
    end
    epochDocId = docs{k}.dependency_value('epoch_id', 'ErrorIfNotFound', 0);
    [epochDoc, cache] = docById(ndi_session_obj, epochDocId, cache);
    epochId = '';
    if ~isempty(epochDoc)
        epochId = localIdentifier(epochDoc.document_properties);
    end
    patternId = docs{k}.dependency_value('epoch_file_pattern_id', 'ErrorIfNotFound', 0);
    if isempty(patternId)
        patternId = docs{k}.dependency_value('filenavigator_id', 'ErrorIfNotFound', 0);
    end
    [pm, cache, rowsUsed] = probemapOf(ndi_session_obj, epochDocId, probemapClass, cache, patternId);
    E(end+1) = struct('epoch_id', epochId, 'files', {files}, 'probemap', {pm}, ...
        'vintage', 'V_eta'); %#ok<AGROW>
    if useIndex
        newKeys{end+1} = mid; %#ok<AGROW>
        newValues{end+1} = toIndex(epochId, pm, rowsUsed); %#ok<AGROW>
        newDeps{end+1} = depsOf(cache, mid, epochDocId, patternId); %#ok<AGROW>
    end
end
if useIndex && ~isempty(newKeys)
    ndi.vintage.epochIndex('put', ndi_session_obj, 'ndi.epochs.navigator', probemapClass, ...
        newKeys, newValues, newDeps);
end
end

function ids = manifestIds(docs)
% each document's id when it is a migrated ingestion_manifest, else ''
ids = repmat({''}, 1, numel(docs));
for k = 1:numel(docs)
    p = docs{k}.document_properties;
    if isfield(p, 'ingestion_manifest') && ~isfield(p, 'epochfiles_ingested')
        ids{k} = char(p.base.id);
    end
end
end

function v = toIndex(epochId, pm, rows)
% a manifest's index entry: its epoch id and the probe-map rows, as
% probemapOf made them (the files are the manifest's own, read each time)
v = struct('epoch_id', epochId, 'has_pm', ~isempty(pm), ...
    'n', {rows.n}, 'r', rows.r, 't', {rows.t}, 'd', {rows.d}, 's', {rows.s});
end

function e = fromIndex(v, files, probemapClass)
% the E element an index entry stands for: the probe map made by the same
% constructor calls, in the same order, as probemapOf made it
pm = [];
if v.has_pm
    n = asCellstr(v.n); t = asCellstr(v.t); d = asCellstr(v.d); s = asCellstr(v.s);
    r = double(v.r);
    for i = 1:numel(n)
        row = feval(probemapClass, n{i}, r(i), t{i}, d{i}, s{i});
        if isempty(pm); pm = row; else; pm(end+1) = row; end %#ok<AGROW>
    end
end
e = struct('epoch_id', char(v.epoch_id), 'files', {files}, 'probemap', {pm}, 'vintage', 'V_eta');
end

function ids = depsOf(cache, mid, epochDocId, patternId)
% the ids a manifest's entry was read from: the manifest, its epoch entity
% and pattern, the anchors onto the epoch, the statements they time and
% every document those name (rig, probe, subject, the acquisition
% channels' system), and the wiring relations used. A document added or
% removed that points at one of these drops the entry (assertions about a
% probe, a new statement or wiring timed by an anchor, a new body).
ids = {mid, char(epochDocId), char(patternId)};
if isfield(cache, 'anchorsOf') && isKey(cache.anchorsOf, epochDocId)
    ids = [ids, cache.anchorsOf(epochDocId)];
end
if isfield(cache, 'stIdx') && isKey(cache.stIdx, epochDocId)
    idx = cache.stIdx(epochDocId);
    st = cache.allStatements(idx);
    ids = [ids, cellfun(@(d) char(d.id()), st, 'UniformOutput', false)];
    for f = {'ac', 'sys', 'el', 'entity', 'subject'}
        ids = [ids, cache.ed.(f{1})(idx)]; %#ok<AGROW>
    end
    ids = [ids, cache.ed.anchors{idx}];
    for a = cache.ed.ac(idx)
        if ~isempty(a{1}) && isKey(cache.doc, a{1}) && ~isempty(cache.doc(a{1}))
            ids{end+1} = char(cache.doc(a{1}).dependency_value('acquisition_system_id', ...
                'ErrorIfNotFound', 0)); %#ok<AGROW>
        end
    end
    first = cache.first(idx);
    for w = first(isfinite(first))
        ids{end+1} = char(cache.relations.docs{w}.id()); %#ok<AGROW>
    end
end
ids = unique(ids(~cellfun(@isempty, ids)));
end

% ===================== the probe map, put back together ===================

function [pm, cache, rows] = probemapOf(S, epochDocId, probemapClass, cache, patternId)
pm = [];
rows = struct('n', {{}}, 'r', [], 't', {{}}, 'd', {{}}, 's', {{}});   % the rows made, for the index
if isempty(epochDocId)
    return;
end
first = [];
if isfield(cache, 'stIdx') && isKey(cache.stIdx, epochDocId)
    % read ahead (readAhead): this epoch's statements are positions in the
    % call's one list, whose edges and first wiring relations were read in
    % one pass over all of them
    idx = cache.stIdx(epochDocId);
    statements = cache.allStatements(idx);
    ed = subsetEdges(cache.ed, idx);
    first = cache.first(idx);
elseif isKey(cache.statements, epochDocId)
    statements = cache.statements(epochDocId);   % read ahead (readAhead)
else
    anchors = S.database_search(anchorQuery(epochDocId));
    if isempty(anchors)
        return;
    end
    statements = S.database_search(statementQuery(cellfun(@(a) a.id(), anchors, ...
        'UniformOutput', false)));
end
seen = {};
% every statement's edges, read once from its depends_on list (what
% dependency_value answers: the first entry of each name, case-insensitive)
if isempty(first)
    ed = statementEdges(statements);
end
for i = 1:numel(statements)
    acId = ed.ac{i};
    sysId = ed.sys{i};
    elId = ed.el{i};
    if (isempty(acId) && isempty(sysId)) || isempty(elId)
        continue;   % not a probe-map row: no rig or no probe
    end
    ownKey = [char(sysId) char(0) char(acId) char(0) char(patternId)];
    if isKey(cache.own, ownKey)
        own = cache.own(ownKey);
    else
        [own, cache] = isOwnSystem(S, sysId, acId, patternId, cache);
        cache.own(ownKey) = own;
    end
    if ~own
        continue;   % another acquisition system's row of this recording
    end
    [el, cache] = elementOf(S, elId, cache);
    if isempty(el)
        continue;
    end
    sId = ed.entity{i};
    if isempty(sId), sId = ed.subject{i}; end
    [subjectString, cache] = subjectStringOf(S, sId, cache);
    if ~isempty(acId)
        [devicestring, cache] = deviceString(S, acId, cache);
    else
        if isempty(first)
            [devicestring, cache] = ndi.vintage.wiredDeviceString(S, statements{i}, sysId, elId, ...
                cache, ed.anchors{i});
        else
            [devicestring, cache] = ndi.vintage.wiredDeviceString(S, statements{i}, sysId, elId, ...
                cache, ed.anchors{i}, first(i));
        end
    end
    key = strjoin({el.name, num2str(el.reference), el.type, devicestring, subjectString}, char(0));
    if any(strcmp(seen, key))
        continue;
    end
    seen{end+1} = key; %#ok<AGROW>
    row = feval(probemapClass, el.name, el.reference, el.type, devicestring, subjectString);
    rows.n{end+1} = el.name; rows.r(end+1) = double(el.reference); rows.t{end+1} = el.type;
    rows.d{end+1} = devicestring; rows.s{end+1} = subjectString;
    if isempty(pm)
        pm = row;
    else
        pm(end+1) = row; %#ok<AGROW>
    end
end
end

function e = subsetEdges(ed, idx)
% statementEdges' answer for the statements at positions IDX
e = struct();
for f = fieldnames(ed)'
    e.(f{1}) = ed.(f{1})(idx);
end
end

function ed = statementEdges(statements)
% Each statement's probe-map edges, as dependency_value('...',
% 'ErrorIfNotFound', 0) reads them (the first entry of the name, compared
% case-insensitively; its value or document_id), from one pass over each
% depends_on list rather than five method calls per statement.
names = {'acquisition_channels_id', 'acquisition_system_id', 'instrument_id', ...
    'entity_id', 'subject_id'};
fields = {'ac', 'sys', 'el', 'entity', 'subject'};
n = numel(statements);
ed = struct();
for f = 1:numel(fields)
    ed.(fields{f}) = repmat({''}, 1, n);
end
% and its anchors, as ndi.v2.edgeIds(..., 'time_reference_id') reads them:
% every non-empty time_reference_id or time_reference_id_<digits> target
ed.anchors = repmat({{}}, 1, n);
for i = 1:n
    p = statements{i}.document_properties;
    if ~isfield(p, 'depends_on') || isempty(p.depends_on)
        continue;
    end
    dep = p.depends_on;
    ed.anchors{i} = ndi.v2.edgeIds(p, 'time_reference_id');
    have = lower({dep.name});
    for f = 1:numel(names)
        m = find(strcmp(have, names{f}), 1);
        if ~isempty(m)
            v = did.document.i_readDependencyTarget(dep(m));
            if ~isempty(v)
                ed.(fields{f}){i} = char(v);
            end
        end
    end
end
end

function [s, cache] = subjectStringOf(S, sId, cache)
% the local identifier of the statement's subject (cached per id)
s = '';
if isempty(sId)
    return;
end
if isKey(cache.subjectString, sId)
    s = cache.subjectString(sId);
    return;
end
[sDoc, cache] = docById(S, sId, cache);
if ~isempty(sDoc)
    s = localIdentifier(sDoc.document_properties);
end
cache.subjectString(sId) = s;
end

function [tf, cache] = isOwnSystem(S, sysId, acId, patternId, cache)
% Is the row's acquisition system the one whose epoch file pattern is
% PATTERNID? True when either is not stated.
tf = true;
if isempty(patternId)
    return;
end
if isempty(sysId) && ~isempty(acId)
    [ac, cache] = docById(S, acId, cache);
    if ~isempty(ac)
        sysId = ac.dependency_value('acquisition_system_id', 'ErrorIfNotFound', 0);
    end
end
[sys, cache] = docById(S, sysId, cache);
if isempty(sys)
    return;
end
p = sys.dependency_value('epoch_file_pattern_id', 'ErrorIfNotFound', 0);
if isempty(p)
    p = sys.dependency_value('filenavigator_id', 'ErrorIfNotFound', 0);
end
tf = isempty(p) || strcmp(p, patternId);
end

function [s, cache] = deviceString(S, acId, cache)
% 'vhspike2:ai11-14;di1' from an acquisition_channels document (a session
% migrated before [probe wiring is a relation])
s = '';
[ac, cache] = docById(S, acId, cache);
if isempty(ac)
    return;
end
sysName = '';
sysId = ac.dependency_value('acquisition_system_id', 'ErrorIfNotFound', 0);
[sys, cache] = docById(S, sysId, cache);
if ~isempty(sys)
    sysName = char(ndi.vintage.objectName(sys));
end
groups = {};
p = ac.document_properties;
if isfield(p, 'acquisition_channels') && isfield(p.acquisition_channels, 'channels')
    ch = p.acquisition_channels.channels;
    if isstruct(ch), ch = num2cell(ch); end
    for g = 1:numel(ch)
        c = ch{g};
        if ~isstruct(c) || ~isfield(c, 'type'), continue; end
        nums = [];
        if isfield(c, 'numbers'), nums = double(c.numbers(:)'); end
        groups{end+1} = [char(ndi.vintage.channelPrefix(c.type)) ranges(nums)]; %#ok<AGROW>
    end
end
s = sysName;
if ~isempty(groups)
    s = [sysName ':' strjoin(groups, ';')];
end
end

function t = ranges(n)
% [11 12 13 14 20] -> '11-14,20' (ndi.daq.daqsystemstring's own spelling)
t = '';
if isempty(n), return; end
n = n(:)';
parts = {};
i = 1;
while i <= numel(n)
    j = i;
    while j < numel(n) && n(j+1) == n(j) + 1
        j = j + 1;
    end
    if j > i
        parts{end+1} = sprintf('%d-%d', n(i), n(j)); %#ok<AGROW>
    else
        parts{end+1} = sprintf('%d', n(i)); %#ok<AGROW>
    end
    i = j + 1;
end
t = strjoin(parts, ',');
end

function [el, cache] = elementOf(S, id, cache)
% name, reference and type of the element entity ID (cached)
el = [];
if isKey(cache.element, id)
    el = cache.element(id);
    return;
end
[d, cache] = docById(S, id, cache);
if ~isempty(d)
    f = ndi.vintage.elementFields(d, S);
    if ~isempty(f.name)
        el = struct('name', char(f.name), 'reference', f.reference, 'type', char(f.type));
        if isempty(el.reference), el.reference = 0; end
    end
end
cache.element(id) = el;
end

function [d, cache] = docById(S, id, cache)
d = [];
if isempty(id)
    return;
end
if isKey(cache.doc, id)
    d = cache.doc(id);
    return;
end
r = S.database_search(ndi.query('base.id', 'exact_string', id, ''));
if ~isempty(r)
    d = r{1};
end
cache.doc(id) = d;
end

% ===================== the per-epoch searches, and read ahead ===============

function q = anchorQuery(epochDocIds)
% the relative_time_references onto the epoch entity (or any of a list)
if ischar(epochDocIds)
    q = ndi.query('', 'isa', 'relative_time_reference', '') & ...
        ndi.query('', 'depends_on', 'referent_id', epochDocIds);
else
    q = ndi.query('', 'isa', 'relative_time_reference', '') & ...
        ndi.vintage.edgeIn('referent_id', epochDocIds);
end
end

function q = statementQuery(anchorIds, asList)
% the statements timed by any of the anchors
if nargin > 1 && asList
    q = ndi.v2.isaQuery('statement') & ndi.vintage.edgeIn('time_reference_id', anchorIds);
else
    q = ndi.v2.isaQuery('statement') & ndi.v2.anyOf(cellfun(@(a) ...
        ndi.query('', 'depends_on', 'time_reference_id', a), anchorIds, 'UniformOutput', false));
end
end

function cache = readAhead(S, docs, cache)
% Every document the migrated epochs of DOCS need, a kind at a time; each
% epoch's statements filed under its entity id (see 'Batch' above).
epochDocIds = {};
for k = 1:numel(docs)
    p = docs{k}.document_properties;
    if isfield(p, 'epochfiles_ingested') || ~isfield(p, 'ingestion_manifest')
        continue;
    end
    epochDocIds{end+1} = docs{k}.dependency_value('epoch_id', 'ErrorIfNotFound', 0); %#ok<AGROW>
end
epochDocIds = unique(epochDocIds(~cellfun(@isempty, epochDocIds)), 'stable');
if isempty(epochDocIds)
    return;
end
% the epoch entities are read only for their local identifier (localIdentifier)
cache = remember(cache, ndi.vintage.docsById(S, epochDocIds, ...
    'LightPaths', {'entity.local_identifier'}, 'RawBlocks', {'base', 'entity'}));
% the anchors onto each epoch, then the statements each anchor times. Each
% epoch's statements are kept by their position in the one answer, so they
% stay in the order its own search would have returned them.
% read once per epoch-table build, shared with ndi.vintage.ingestedArchives
% (ndi.vintage.epochReads); the statements as light documents (edges only)
% The anchors are asked for onto every entity with the local identifier of
% one of these epochs: the set ndi.vintage.ingestedArchives asks for next in
% ndi.daq.system/buildepochtable, so the two share one read
% (ndi.vintage.epochReads; two reads of each kind in run 42346955349). Only
% the anchors onto EPOCHDOCIDS are used below.
readIds = epochDocIds;
lids = {};
for e = 1:numel(epochDocIds)
    if isKey(cache.doc, epochDocIds{e}) && ~isempty(cache.doc(epochDocIds{e}))
        lids{end+1} = localIdentifier(cache.doc(epochDocIds{e}).document_properties); %#ok<AGROW>
    end
end
same = ndi.vintage.entitiesByLocalId(S, lids(~cellfun(@isempty, lids)));
if iscell(same)
    readIds = unique([epochDocIds, cellfun(@(d) char(d.id()), reshape(same, 1, []), ...
        'UniformOutput', false)], 'stable');
end
anchors = ndi.vintage.epochReads('anchors', S, readIds);
epochsOfAnchor = containers.Map('KeyType', 'char', 'ValueType', 'any');
cache.anchorsOf = containers.Map('KeyType', 'char', 'ValueType', 'any');   % epoch -> its anchors' ids (the index's deps)
for a = 1:numel(anchors)
    onto = ndi.vintage.edgeTargets(anchors{a}, 'referent_id');
    mine = onto(ismember(onto, epochDocIds));
    epochsOfAnchor(char(anchors{a}.id())) = mine;
    for e = mine
        if isKey(cache.anchorsOf, e{1})
            cache.anchorsOf(e{1}) = [cache.anchorsOf(e{1}), {char(anchors{a}.id())}];
        else
            cache.anchorsOf(e{1}) = {char(anchors{a}.id())};
        end
    end
end
statements = {};
if epochsOfAnchor.Count > 0
    statements = ndi.vintage.epochReads('statements', S, epochsOfAnchor.keys);
end
rowsOf = containers.Map(epochDocIds, repmat({[]}, 1, numel(epochDocIds)));
for i = 1:numel(statements)
    for t = ndi.vintage.edgeTargets(statements{i}, 'time_reference_id')
        if ~isKey(epochsOfAnchor, t{1}), continue; end
        for e = epochsOfAnchor(t{1})
            rowsOf(e{1}) = [rowsOf(e{1}), i];
        end
    end
end
cache.stIdx = containers.Map('KeyType', 'char', 'ValueType', 'any');
for e = 1:numel(epochDocIds)
    cache.stIdx(epochDocIds{e}) = unique(rowsOf(epochDocIds{e}));
end
cache.allStatements = statements;
% the documents the statements name, by id: systems, channels, probes, subjects
% The probes and subjects are read light when they are entities: their
% readers (localIdentifier; ndi.vintage.elementFields and
% prefetchElementFields) read nothing of an entity but these fields and its
% id (Jess Haley, 2026-11-06: "Speed can't be slower than v1"); a document of
% another class is read whole (ndi.vintage.docsById 'LightClass').
ed = statementEdges(statements);
rigIds = [ed.ac, ed.sys];
entityIds = [ed.el, ed.entity, ed.subject];
rigIds = rigIds(~cellfun(@isempty, rigIds));
entityIds = entityIds(~cellfun(@isempty, entityIds));
cache = remember(cache, ndi.vintage.docsById(S, rigIds));
cache = remember(cache, ndi.vintage.docsById(S, entityIds, 'LightPaths', ...
    {'entity.local_identifier', 'entity.name', 'entity.type.node', 'entity.type.name'}, ...
    'RawBlocks', {'base', 'entity'}));
ids = unique([rigIds, entityIds], 'stable');
instruments = {};
for i = 1:numel(statements)
    el = ed.el{i};
    if ~isempty(el) && isKey(cache.doc, el) && ~isempty(cache.doc(el))
        instruments{end+1} = cache.doc(el); %#ok<AGROW>
    end
end
ndi.vintage.prefetchElementFields(S, instruments);
sysIds = {};   % the systems an acquisition_channels document names
for i = 1:numel(ids)
    d = cache.doc(ids{i});
    if ~isempty(d)
        sysIds{end+1} = d.dependency_value('acquisition_system_id', 'ErrorIfNotFound', 0); %#ok<AGROW>
    end
end
sysIds = sysIds(cellfun(@(x) ischar(x) && ~isempty(x), sysIds));
cache = remember(cache, ndi.vintage.docsById(S, sysIds));
% the wiring relations timed by the statements' anchors, filed by (probe,
% system) for ndi.vintage.wiredDeviceString, in database order
wiringAnchors = unique([{}, ed.anchors{:}], 'stable');   % ndi.v2.edgeIds, read by statementEdges
rels = {};
if ~isempty(wiringAnchors)
    rels = wiringRelations(S, ndi.query('', 'isa', 'directed_relation', '') & ...
        ndi.vintage.edgeIn('time_reference_id', wiringAnchors));
end
cache.relations = ndi.vintage.wiringIndex(rels);
cache.ed = ed;
cache.first = firstWirings(ed, cache.relations);
end

function first = firstWirings(ed, W)
% For every statement, the position in W.docs of the first wiring relation
% of its probe and system timed by any of its anchors (Inf for none): what
% ndi.vintage.wiredDeviceString looks up per row in W.firstWiring, here in
% one ismember over every (statement, anchor) key
n = numel(ed.el);
first = inf(1, n);
if n == 0 || W.firstWiring.Count == 0
    return;
end
counts = cellfun(@numel, ed.anchors);
owner = repelem(1:n, counts);
anchors = [{}, ed.anchors{:}];
if isempty(anchors)
    return;
end
keys = cellfun(@(e, s, a) [e char(0) s char(0) a], ed.el(owner), ed.sys(owner), anchors, ...
    'UniformOutput', false);
wk = W.firstWiring.keys;
wv = cell2mat(W.firstWiring.values);
[tf, loc] = ismember(keys, wk);
if any(tf)
    [u, ~, g] = unique(owner(tf));
    v = wv(loc(tf));
    first(u) = reshape(accumarray(g(:), v(:), [], @min), 1, []);
end
end

function rels = wiringRelations(S, q)
% The wiring relations Q finds, in its order, holding what their readers use
% (ndi.vintage.wiringIndex: the depends_on edges; wiredDeviceString: the
% directed_relation's relation term and conditions), decoded from the stored
% documents without rebuilding them (ndi.session/database_search_json). Each
% reader reads only leaf values and takes a struct array or a cell, so
% jsondecode's shapes read as the rebuilt ones do. The rebuild was most of a
% document's read (NDI-matlab run 42334220421). Read whole where the
% database cannot answer this way.
rows = [];
if ismethod(S, 'database_search_json')
    rows = S.database_search_json(q, {'document_class.class_name', 'depends_on', ...
        'directed_relation.relation', 'directed_relation.conditions'});
end
if ~isstruct(rows)
    rels = S.database_search(q);
    return;
end
rels = cell(1, numel(rows));
for k = 1:numel(rows)
    v = rows(k).values;
    dep = v{2};
    if isempty(dep); dep = struct('name', {}, 'value', {}); end
    dr = struct();
    if ~isempty(v{3}); dr.relation = v{3}; end
    dr.conditions = v{4};
    rels{k} = ndi.document(struct('base', struct('id', rows(k).doc_id), ...
        'document_class', struct('class_name', char(v{1})), ...
        'depends_on', {dep}, 'directed_relation', dr));
end
end

function cache = remember(cache, found)
% file each document read by id (or [] for an id with none) in the cache
keys = found.keys;
for k = 1:numel(keys)
    if ~isKey(cache.doc, keys{k})
        cache.doc(keys{k}) = found(keys{k});
    end
end
end

function lid = localIdentifier(p)
lid = '';
for blk = {'entity', 'subject'}
    if isfield(p, blk{1}) && isstruct(p.(blk{1})) && isfield(p.(blk{1}), 'local_identifier')
        lid = char(p.(blk{1}).local_identifier);
        return;
    end
end
end

function c = asCellstr(x)
if isempty(x)
    c = {};
elseif iscell(x)
    c = x;
else
    c = cellstr(x);
end
end
