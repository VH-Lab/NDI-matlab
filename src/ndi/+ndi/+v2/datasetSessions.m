function [sessions, notes] = datasetSessions(database, datasetSessionId, datasetPath, options)
%DATASETSESSIONS The sessions of a V2 dataset: ingested and linked.
%
%   [SESSIONS, NOTES] = ndi.v2.datasetSessions(DATABASE, DATASETSESSIONID,
%   DATASETPATH) reads a V2 dataset's own database (DATABASE, an ndi.database
%   searched without a session scope) and returns its sessions, one row of a
%   struct array each:
%
%     session_id    the session's id (its documents' base.session_id)
%     reference     its local_identifier
%     entity_id     the id of its `session` entity document
%     is_linked     false: ingested (its documents are in DATABASE)
%                   true:  linked (they are in the folder a `linked_session`
%                          document names)
%     path          a linked session's folder, absolute ('' when ingested)
%     link_id       the `linked_session` document's id ('' when ingested)
%     session       the linked session, opened (an ndi.session.dir; [] when
%                   ingested)
%
%   The rule (V_eta_linked_session_plan.md, signed 2026-10-09): a session is
%   in the dataset when its entity document is `part_of` the dataset, or
%   `part_of` a study that is `part_of` the dataset; the relation is in the
%   dataset's database for both kinds. A session is LINKED when a
%   `linked_session` document names it: its `path` is the session's folder
%   (relative to DATASETPATH when inside it) and its `entity_id` the
%   session's entity document, which must be in that folder.
%
%   NOTES is a cellstr of what was left out and why, the denominator first:
%     - a `session` document in DATABASE that is not part_of the dataset;
%     - a linked folder that is missing, cannot be opened, or holds another
%       session;
%     - a linked session that is not part_of the dataset.
%   When DATABASE holds no `dataset` document (an import whose metadata stage
%   did not run), membership cannot be read, so every session is listed and
%   NOTES says so.
%
%   Options:
%     'OpenLinked'   default true. false lists linked sessions without opening
%                    them (session_id and reference are then '' and
%                    `session` is []), e.g. to find a link whose folder moved.
%
%   See also ndi.dataset, ndi.dataset.dir.

arguments
    database
    datasetSessionId (1,:) char
    datasetPath (1,:) char
    options.OpenLinked (1,1) logical = true
end

sessions = struct('session_id', {}, 'reference', {}, 'entity_id', {}, ...
    'is_linked', {}, 'path', {}, 'link_id', {}, 'session', {});
notes = {};

% --- membership: part_of the dataset, directly or through a study ---
datasetDocs = database.search(ndi.v2.isaQuery('dataset'));
datasetDocs = datasetDocs(cellfun(@(d) strcmp(ndi.v2.kindOf(d.document_properties), ...
    'dataset'), datasetDocs));
knowMembership = ~isempty(datasetDocs);
% level 1: part_of the dataset (studies, or sessions directly); level 2:
% part_of one of those (the sessions of a study)
level1 = {};
for k = 1:numel(datasetDocs)
    level1 = [level1, partOfChildren(database, datasetDocs{k}.id())]; %#ok<AGROW>
end
level1 = unique(level1);
members = level1;
for k = 1:numel(level1)
    members = [members, partOfChildren(database, level1{k})]; %#ok<AGROW>
end
members = unique(members);

% --- ingested: `session` documents in the dataset's own database ---
sessionDocs = database.search(ndi.v2.isaQuery('session'));
nIngested = 0;
left = {};
for i = 1:numel(sessionDocs)
    p = sessionDocs{i}.document_properties;
    if ~strcmp(ndi.v2.kindOf(p), 'session') || strcmp(p.base.session_id, datasetSessionId)
        continue;
    end
    ref = char(ndi.v2.blockOf(p, 'session', 'local_identifier', ''));
    if knowMembership && ~ismember(p.base.id, members)
        left{end+1} = ref; %#ok<AGROW>
        continue;
    end
    nIngested = nIngested + 1;
    sessions(end+1) = struct('session_id', p.base.session_id, 'reference', ref, ...
        'entity_id', p.base.id, 'is_linked', false, 'path', '', 'link_id', '', ...
        'session', []); %#ok<AGROW>
end

% --- linked: `linked_session` documents ---
links = {};
try
    links = database.search(ndi.query('', 'isa', 'linked_session', ''));
catch
    % a schema without the class: no linked sessions
end
nLinked = 0;
problems = {};
for i = 1:numel(links)
    p = links{i}.document_properties;
    rel = char(ndi.v2.blockOf(p, 'linked_session', 'path', ''));
    e = ndi.v2.edgeIds(p, 'entity_id');
    if isempty(e)
        problems{end+1} = sprintf('linked_session %s names no session entity', p.base.id); %#ok<AGROW>
        continue;
    end
    entityId = e{1};
    folder = ndi.v2.resolveLinkPath(rel, datasetPath);
    if knowMembership && ~ismember(entityId, members)
        problems{end+1} = sprintf('%s (linked) is not part_of the dataset', folder); %#ok<AGROW>
        continue;
    end
    row = struct('session_id', '', 'reference', '', 'entity_id', entityId, ...
        'is_linked', true, 'path', folder, 'link_id', p.base.id, 'session', []);
    if options.OpenLinked
        [S, sp, why] = openLinked(folder, entityId);
        if isempty(S)
            problems{end+1} = why; %#ok<AGROW>
            continue;
        end
        row.session = S;
        row.session_id = S.id();
        row.reference = char(ndi.v2.blockOf(sp, 'session', 'local_identifier', ''));
    end
    nLinked = nLinked + 1;
    sessions(end+1) = row; %#ok<AGROW>
end

notes{end+1} = sprintf(['DENOMINATOR: %d session document(s) and %d linked_session ' ...
    'document(s) read; %d ingested and %d linked session(s) listed'], ...
    sum(cellfun(@(d) strcmp(ndi.v2.kindOf(d.document_properties), 'session') && ...
    ~strcmp(d.document_properties.base.session_id, datasetSessionId), sessionDocs)), ...
    numel(links), nIngested, nLinked);
if ~knowMembership
    notes{end+1} = ['no dataset document: membership (part_of) cannot be read, so every ' ...
        'session is listed'];
end
if ~isempty(left)
    notes{end+1} = sprintf('%d session document(s) not part_of the dataset, not listed: %s', ...
        numel(left), strjoin(left, ', '));
end
for k = 1:numel(problems)
    notes{end+1} = ['not listed: ' problems{k}]; %#ok<AGROW>
end
end

% -----------------------------------------------------------------------------
function children = partOfChildren(database, parentId)
% the ids of the documents `part_of` PARENTID, read from relations in DATABASE
children = {};
q = ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.query('', 'depends_on', 'parent_id', parentId);
rels = database.search(q);
for k = 1:numel(rels)
    p = rels{k}.document_properties;
    if ~strcmp(ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', '')), 'part_of')
        continue;
    end
    c = ndi.v2.edgeIds(p, 'child_id');
    children = [children, c(:)']; %#ok<AGROW>
end
end

function [S, sp, why] = openLinked(folder, entityId)
% the session in FOLDER, checked to hold the session entity ENTITYID
S = []; sp = []; why = '';
if ~isfolder(folder)
    why = sprintf('%s (linked): no such folder', folder);
    return;
end
try
    S0 = ndi.session.dir(folder);
catch err
    why = sprintf('%s (linked) cannot be opened: %s', folder, err.message);
    return;
end
d = S0.database_search(ndi.query('base.id', 'exact_string', entityId, ''));
if isempty(d)
    why = sprintf(['%s (linked) holds another session (%s): its session document %s ' ...
        'is not there'], folder, S0.id(), entityId);
    return;
end
sp = d{1}.document_properties;
if ~strcmp(ndi.v2.kindOf(sp), 'session')
    why = sprintf('%s (linked): document %s is a %s, not a session', folder, entityId, ...
        ndi.v2.kindOf(sp));
    return;
end
S = S0;
end
