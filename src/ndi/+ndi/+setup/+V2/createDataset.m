function [dataset, report] = createDataset(path, reference, datasetSessionId, datasetDocs, sessionDocs, options)
%CREATEDATASET Create a V2 dataset: ONE did2 database holding every document.
%
%   [DATASET, REPORT] = ndi.setup.V2.createDataset(PATH, REFERENCE,
%   DATASETSESSIONID, DATASETDOCS, SESSIONDOCS) writes, into PATH/.ndi's V2
%   database (did2), the dataset's own `session` document, DATASETDOCS (the
%   dataset-level documents: the dataset, people, studies, ...; each with
%   session id DATASETSESSIONID) and SESSIONDOCS (a cell, one cell of
%   documents per session, each holding that session's `session` document,
%   with its own session_id), then opens it as an ndi.dataset.dir. Every
%   session is INGESTED: its documents live in the dataset's database and
%   ndi.dataset opens it there (ndi.dataset/build_session_info lists a V2
%   dataset's sessions from their `session` documents).
%
%   session_id is an edge (did-schema V_eta_relation_inheritance_plan.md):
%   the dataset's own record is the document whose base.id IS
%   DATASETSESSIONID, which every dataset-level document's `session_id` edge
%   points at. When DATASETDOCS hold the `dataset` entity, it is that record
%   (built with that id, e.g. by ndi.setup.V2.datasetMetadata) and no separate
%   `session` document is written. The entity keeps the local_identifier its
%   metadata gives it (or none): REFERENCE is the FOLDER's and is written only
%   to .ndi/reference.txt, where ndi.session.dir and ndi.dataset.dir read it
%   for a dataset record (Haley decision #115). A `dataset` entity with another id is an error
%   (ndi:setup:V2:datasetId). With no `dataset` entity, the dataset's own
%   `session` document is written with DATASETSESSIONID as its id.
%
%   Files: a body recorded with `ingest` 1 is copied into PATH/.ndi/files; one
%   recorded by location (`ingest` 0, the raw recordings) stays where it is.
%
%   Before writing, it CHECKS the whole set, and REPORT says what it found
%   (nothing is written when 'Strict' is true and a check fails):
%     documents     how many documents, per class and per session
%     edges         every depends_on value that names a document: how many,
%                   and those naming no document in the set (dangling), by
%                   class and edge name
%     duplicateIds  ids carried by more than one document
%     sessions      session documents found, and those not filed under the
%                   dataset, directly or through a study filed under it (the
%                   relation is `included_in`, whose registry row lets a
%                   session's parent be a study or a dataset)
%
%   Options:
%     'Name'        the dataset session's display name
%     'Overwrite'   default false; true deletes PATH/.ndi first
%     'Strict'      default false; true refuses to write when an edge
%                   dangles, an id repeats or a session is not in the dataset
%     'BatchSize'   documents per write batch (default 2000); progress is
%                   printed (and shown in a ProgressBarWindow) per batch
%     'Validate'    default true: validate each document again as it is
%                   inserted. Documents built with did2.build were validated
%                   when built, so false skips only a repeat.
%     'Progress'    default true
%     'External'    a cell of documents CHECKED with the dataset but not
%                   written into it: the documents of its LINKED sessions,
%                   written to their own folders (V_eta_linked_session_plan.md).
%                   Their edges, ids and membership are checked as one set with
%                   the dataset's, and REPORT.documents counts them.
%   See ndi.setup.V2.writeDocuments for how a failed batch is reported.
%
%   See also ndi.setup.V2.createSession, ndi.dataset.dir.

arguments
    path (1,:) char
    reference (1,:) char {mustBeNonzeroLengthText}
    datasetSessionId (1,:) char {mustBeNonzeroLengthText}
    datasetDocs cell
    sessionDocs cell
    options.Name (1,:) char = ''
    options.Overwrite (1,1) logical = false
    options.Strict (1,1) logical = false
    options.BatchSize (1,1) double {mustBePositive, mustBeInteger} = 2000
    options.Validate (1,1) logical = true
    options.Progress (1,1) logical = true
    options.External cell = {}
end

if ~isfolder(path)
    mkdir(path);
end
ndiDir = fullfile(path, '.ndi');
if isfolder(ndiDir)
    existing = [dir(fullfile(ndiDir, '*.sqlite')); dir(fullfile(ndiDir, '*.json'))];
    if ~isempty(existing) && ~options.Overwrite
        error('ndi:setup:V2:datasetExists', ...
            '%s already holds an NDI database (%s). Pass ''Overwrite'', true to replace it.', ...
            ndiDir, strjoin({existing.name}, ', '));
    end
    if options.Overwrite
        rmdir(ndiDir, 's');
    end
end

for k = 1:numel(datasetDocs)
    if ~strcmp(ndi.v2.sessionIdOf(datasetDocs{k}), datasetSessionId)
        error('ndi:setup:V2:wrongSession', ...
            'Dataset document %d (%s) has session_id %s, not the dataset''s %s.', k, ...
            datasetDocs{k}.document_class.class_name, ndi.v2.sessionIdOf(datasetDocs{k}), ...
            datasetSessionId);
    end
end
own = {};
recordAt = [];
% the dataset entity is the dataset's own record: its id is the session id
for k = 1:numel(datasetDocs)
    if ~strcmp(ndi.v2.kindOf(datasetDocs{k}), 'dataset'), continue; end
    if ~strcmp(datasetDocs{k}.base.id, datasetSessionId)
        error('ndi:setup:V2:datasetId', ['The dataset document has id %s; its id must be ' ...
            'the dataset''s session id, %s (ndi.setup.V2.datasetMetadata builds it so by ' ...
            'default).'], datasetDocs{k}.base.id, datasetSessionId);
    end
    recordAt = k;
end
if isempty(recordAt)
    f = struct('local_identifier', reference);
    if ~isempty(options.Name), f.name = options.Name; end
    own = ndi.setup.V2.entityDocuments('session', f, struct(), 'SessionId', datasetSessionId, ...
        'Id', datasetSessionId);
    own = own(1);
end
% A dataset entity standing as the folder's record keeps the local_identifier
% its metadata gave it (or none): the folder's REFERENCE is written to
% .ndi/reference.txt below, where ndi.session.dir reads it (Haley decision
% #115). It is not copied into the entity.
docsAll = [own, reshape(datasetDocs, 1, [])];
for k = 1:numel(sessionDocs)
    docsAll = [docsAll, reshape(sessionDocs{k}, 1, [])]; %#ok<AGROW>
end

report = check([docsAll, reshape(options.External, 1, [])], datasetSessionId);
fprintf(['DENOMINATOR: %d document(s) (%d dataset-level, %d session(s); %d written here, %d ' ...
    'in linked session folders); %d edge value(s) naming a document checked\n'], ...
    numel(docsAll) + numel(options.External), numel(datasetDocs) + numel(own), numel(sessionDocs), ...
    numel(docsAll), numel(options.External), report.edges.checked);
fprintf('  dangling edges: %d   repeated ids: %d   sessions outside the dataset: %d\n', ...
    height(report.edges.dangling), numel(report.duplicateIds), numel(report.sessions.notInDataset));
bad = height(report.edges.dangling) > 0 || ~isempty(report.duplicateIds) || ...
    ~isempty(report.sessions.notInDataset);
if bad && options.Strict
    error('ndi:setup:V2:datasetCheckFailed', ...
        'The dataset did not pass its checks (see the report); nothing was written.');
end

mkdir(ndiDir);
report.write = ndi.setup.V2.writeDocuments(fullfile(ndiDir, ...
    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()), docsAll, ...
    'BatchSize', options.BatchSize, 'Validate', options.Validate, ...
    'Progress', options.Progress, 'Label', 'dataset documents');
vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), datasetSessionId);
vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), reference);
% mark the folder a dataset (ndi.session.dir.directorytype), as ndi.dataset.dir
% would on first open; without it ndi.dataset.dir refuses a folder that only
% looks like a session, and a dataset marker is never downgraded
vlt.file.str2text(fullfile(ndiDir, ndi.session.dir.objecttypemarkerfilename()), 'dataset');

dataset = ndi.dataset.dir(path);
if ~strcmp(dataset.id(), datasetSessionId)
    error('ndi:setup:V2:datasetMismatch', ...
        'The dataset opened with id %s, not the id just written (%s).', dataset.id(), datasetSessionId);
end
end

% -----------------------------------------------------------------------------
function report = check(docs, dsid)
arguments
    docs cell
    dsid {mustBeText}
end
n = numel(docs);
ids = cellfun(@(d) d.base.id, docs, 'UniformOutput', false);
cls = cellfun(@ndi.v2.kindOf, docs, 'UniformOutput', false);   % an entity's type since 2026-10-08
sids = cellfun(@ndi.v2.sessionIdOf, docs, 'UniformOutput', false);
[u, ~, j] = unique(ids);
report.duplicateIds = u(accumarray(j(:), 1) > 1);
% counted by the class each document is STORED as (an `entity` is `entity`),
% so the census compares with what the database holds (verifyDataset reads
% its classname column); KNOWN below names an entity by its type
stored = cellfun(@(d) char(d.document_class.class_name), docs, 'UniformOutput', false);
report.documents.byClass = groupsummary(table(stored(:), 'VariableNames', {'class'}), 'class');
report.documents.bySession = groupsummary(table(sids(:), 'VariableNames', {'session_id'}), 'session_id');

known = containers.Map(ids, cls);
dang = {};
checked = 0;
for i = 1:n
    if ~isfield(docs{i}, 'depends_on'), continue; end
    dep = docs{i}.depends_on;
    if isstruct(dep), dep = num2cell(dep); end
    for e = 1:numel(dep)
        v = edgeTarget(dep{e});
        if isempty(v), continue; end
        checked = checked + 1;
        if ~isKey(known, v)
            dang(end+1, :) = {cls{i}, dep{e}.name}; %#ok<AGROW>
        end
    end
end
report.edges.checked = checked;
if isempty(dang)
    report.edges.dangling = table(cell(0, 1), cell(0, 1), zeros(0, 1), ...
        'VariableNames', {'class', 'edge', 'GroupCount'});
else
    report.edges.dangling = groupsummary(cell2table(dang, 'VariableNames', {'class', 'edge'}), ...
        {'class', 'edge'});
end

% sessions: filed under the dataset, directly or through studies at any depth
% (included_in: a session's parent is a study or a dataset; a study's parent
% is a dataset or a parent study; Jess Haley 2026-10-23 [nested studies])
member = 'included_in';
isRel = strcmp(cls, 'directed_relation');
parentsOf = containers.Map();
for i = find(isRel)
    d = docs{i};
    if ~ndi.v2.vocabIs('relation', relationTerm(d), member), continue; end   % by node (L1)
    c = edgeOf(d, 'child_id'); p = edgeOf(d, 'parent_id');
    if isKey(parentsOf, c), parentsOf(c) = [parentsOf(c), {p}]; else, parentsOf(c) = {p}; end
end
datasetIds = ids(strcmp(cls, 'dataset'));
sess = find(strcmp(cls, 'session') & ~strcmp(sids, dsid));
report.sessions.found = numel(sess);
report.sessions.notInDataset = {};
for i = sess
    ok = false;
    seen = ids(i);
    frontier = ids(i);
    while ~ok && ~isempty(frontier)
        up = {};
        for f = frontier
            if isKey(parentsOf, f{1}), up = [up, parentsOf(f{1})]; end %#ok<AGROW>
        end
        up = setdiff(unique(up), seen);   % each record once, so a cycle ends the walk
        ok = any(ismember(up, datasetIds));
        seen = [seen, up]; %#ok<AGROW>
        frontier = up;
    end
    if ~ok
        [~, blk] = ndi.v2.kindOf(docs{i});
        report.sessions.notInDataset{end+1} = docs{i}.(blk).local_identifier;
    end
end
end

function r = relationTerm(d)
% the relation a directed_relation stores ({node, name} or a name)
arguments
    d (1,1) struct
end
r = '';
if isfield(d, 'directed_relation') && isfield(d.directed_relation, 'relation')
    r = d.directed_relation.relation;
end
end

function v = edgeOf(d, name)
arguments
    d (1,1) struct
    name {mustBeText}
end
v = '';
dep = d.depends_on;
if isstruct(dep), dep = num2cell(dep); end
for e = 1:numel(dep)
    if strcmp(dep{e}.name, name), v = edgeTarget(dep{e}); return; end
end
end

function v = edgeTarget(e)
% V2 (did2.build) stores an edge as {name, document_id}; v1 as {name, value}
arguments
    e (1,1) struct
end
v = '';
if isfield(e, 'document_id')
    v = e.document_id;
elseif isfield(e, 'value')
    v = e.value;
end
v = char(v);
end
