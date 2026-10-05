function [dataset, report] = createDataset(path, reference, datasetSessionId, datasetDocs, sessionDocs, options)
%CREATEDATASET Create a V2 dataset: ONE did2 database holding every document.
%
%   [DATASET, REPORT] = ndi.setup.V2.createDataset(PATH, REFERENCE,
%   DATASETSESSIONID, DATASETDOCS, SESSIONDOCS) writes, into PATH/.ndi's V2
%   database (did2), the dataset's own `session` document, DATASETDOCS (the
%   dataset-level documents: the dataset, people, studies, ...; each with
%   base.session_id = DATASETSESSIONID) and SESSIONDOCS (a cell, one cell of
%   documents per session, each holding that session's `session` document,
%   with its own session_id), then opens it as an ndi.dataset.dir. Every
%   session is INGESTED: its documents live in the dataset's database and
%   ndi.dataset opens it there (ndi.dataset/build_session_info lists a V2
%   dataset's sessions from their `session` documents).
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
%     sessions      session documents found, and those with no `part_of`
%                   relation to a study that is itself `part_of` the dataset
%
%   Options:
%     'Name'        the dataset session's display name
%     'Overwrite'   default false; true deletes PATH/.ndi first
%     'Strict'      default false; true refuses to write when an edge
%                   dangles, an id repeats or a session is not in the dataset
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

f = struct('local_identifier', reference);
if ~isempty(options.Name), f.name = options.Name; end
own = did2.build.document('session', f, 'SessionId', datasetSessionId);
for k = 1:numel(datasetDocs)
    if ~strcmp(datasetDocs{k}.base.session_id, datasetSessionId)
        error('ndi:setup:V2:wrongSession', ...
            'Dataset document %d (%s) has session_id %s, not the dataset''s %s.', k, ...
            datasetDocs{k}.document_class.class_name, datasetDocs{k}.base.session_id, datasetSessionId);
    end
end
docsAll = [{own}, reshape(datasetDocs, 1, [])];
for k = 1:numel(sessionDocs)
    docsAll = [docsAll, reshape(sessionDocs{k}, 1, [])]; %#ok<AGROW>
end

report = check(docsAll, datasetSessionId);
fprintf(['DENOMINATOR: %d document(s) (%d dataset-level, %d session(s)); %d edge value(s) ' ...
    'naming a document checked\n'], numel(docsAll), numel(datasetDocs) + 1, numel(sessionDocs), ...
    report.edges.checked);
fprintf('  dangling edges: %d   repeated ids: %d   sessions outside the dataset: %d\n', ...
    height(report.edges.dangling), numel(report.duplicateIds), numel(report.sessions.notInDataset));
bad = height(report.edges.dangling) > 0 || ~isempty(report.duplicateIds) || ...
    ~isempty(report.sessions.notInDataset);
if bad && options.Strict
    error('ndi:setup:V2:datasetCheckFailed', ...
        'The dataset did not pass its checks (see the report); nothing was written.');
end

mkdir(ndiDir);
db = did2.database.sqlitedb(fullfile(ndiDir, ...
    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
db.add(cellfun(@(d) did2.document(d), docsAll, 'UniformOutput', false));
db.close();
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
n = numel(docs);
ids = cellfun(@(d) d.base.id, docs, 'UniformOutput', false);
cls = cellfun(@(d) d.document_class.class_name, docs, 'UniformOutput', false);
sids = cellfun(@(d) d.base.session_id, docs, 'UniformOutput', false);
[u, ~, j] = unique(ids);
report.duplicateIds = u(accumarray(j(:), 1) > 1);
report.documents.byClass = groupsummary(table(cls(:), 'VariableNames', {'class'}), 'class');
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

% sessions: part_of a study that is part_of the dataset
isRel = strcmp(cls, 'directed_relation');
parentsOf = containers.Map();
for i = find(isRel)
    d = docs{i};
    if ~strcmp(relationName(d), 'part_of'), continue; end
    c = edgeOf(d, 'child_id'); p = edgeOf(d, 'parent_id');
    if isKey(parentsOf, c), parentsOf(c) = [parentsOf(c), {p}]; else, parentsOf(c) = {p}; end
end
datasetIds = ids(strcmp(cls, 'dataset'));
sess = find(strcmp(cls, 'session') & ~strcmp(sids, dsid));
report.sessions.found = numel(sess);
report.sessions.notInDataset = {};
for i = sess
    ok = false;
    if isKey(parentsOf, ids{i})
        for p = parentsOf(ids{i})
            if isKey(parentsOf, p{1}) && any(ismember(parentsOf(p{1}), datasetIds))
                ok = true;
            end
        end
    end
    if ~ok
        report.sessions.notInDataset{end+1} = docs{i}.session.local_identifier;
    end
end
end

function r = relationName(d)
r = '';
if isfield(d, 'directed_relation') && isfield(d.directed_relation, 'relation')
    x = d.directed_relation.relation;
    if isstruct(x) && isfield(x, 'name'), r = x.name; else, r = char(x); end
end
end

function v = edgeOf(d, name)
v = '';
dep = d.depends_on;
if isstruct(dep), dep = num2cell(dep); end
for e = 1:numel(dep)
    if strcmp(dep{e}.name, name), v = edgeTarget(dep{e}); return; end
end
end

function v = edgeTarget(e)
% V2 (did2.build) stores an edge as {name, document_id}; v1 as {name, value}
v = '';
if isfield(e, 'document_id')
    v = e.document_id;
elseif isfield(e, 'value')
    v = e.value;
end
v = char(v);
end
