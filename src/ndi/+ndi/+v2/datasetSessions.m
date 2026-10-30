function [sessions, notes] = datasetSessions(database, datasetSessionId, datasetPath, options)
%DATASETSESSIONS The sessions of a V2 dataset: ingested and linked.
%
%   [SESSIONS, NOTES] = ndi.v2.datasetSessions(DATABASE, DATASETSESSIONID,
%   DATASETPATH) reads a V2 dataset's own database (DATABASE, an ndi.database
%   searched without a session scope) and returns its sessions, one row of a
%   struct array each:
%
%     session_id    the session's id (its documents' session id:
%                   ndi.v2.sessionIdOf)
%     reference     its local_identifier
%     entity_id     the id of its `session` entity document
%     is_linked     false: ingested (its documents are in DATABASE)
%                   true:  linked (they are in the folder its link names)
%     path          a linked session's folder, absolute ('' when ingested)
%     link_id       the id of the document that links it: its "database
%                   linking" relation, or, in a dataset written before that
%                   relation, its `linked_session` document ('' when ingested)
%     software_class the class that opens a linked session (the relation's
%                   "software class"; 'ndi.session.dir' when not recorded)
%     session       the linked session, opened (an ndi.session.dir; [] when
%                   ingested)
%
%   The rule (V_eta_linked_session_plan.md, signed 2026-10-09; amended by
%   Jess Haley 2026-10-23 [nested studies]): a session is in the dataset when
%   its entity document is filed under the dataset, or under a study that is
%   filed under it at any depth (a study may be filed under a parent study);
%   the relation is in the
%   dataset's database for both kinds. The relation is `included_in`
%   (V_eta_relation_inheritance_plan.md). A session is LINKED when its
%   direct session -> dataset `included_in` relation has the method "database
%   linking" (EMPTY:0000400; Jess Haley 2026-10-29 [linked session link on a
%   direct dataset relation], [linked session link details], did-schema
%   V_eta_go_forward_class_audit.md): the method's Pathname parameter
%   (NCIT:C47922) is the session's folder (relative to DATASETPATH when inside
%   it, ndi.v2.resolveLinkPath) and the relation's child the session's entity
%   document, which must be in that folder (ndi.v2.sessionLinkOf). The
%   relation is read first; a dataset written before it names the folder in
%   a `linked_session` document (withdrawn: V_eta_linked_session_plan.md
%   [linked_session withdrawn]), which is still read for a session no
%   relation links.
%
%   NOTES is a cellstr of what was left out and why, the denominator first:
%     - a `session` document in DATABASE that is not in the dataset;
%     - a linked folder that is missing, cannot be opened, or holds another
%       session;
%     - a linked session that is not in the dataset.
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
    'is_linked', {}, 'path', {}, 'link_id', {}, 'software_class', {}, 'session', {});
notes = {};

% --- membership: filed under the dataset, directly or through a study ---
member = 'included_in';
datasetDocs = database.search(ndi.v2.isaQuery('dataset'));
datasetDocs = datasetDocs(cellfun(@(d) strcmp(ndi.v2.kindOf(d.document_properties), ...
    'dataset'), datasetDocs));
knowMembership = ~isempty(datasetDocs);
% filed under the dataset at any depth: studies, studies within studies
% (Haley #144), and the sessions of any of them (Jess Haley 2026-10-23
% [nested studies]); each record is visited once, so a cycle ends the walk
members = {};
frontier = {};
for k = 1:numel(datasetDocs)
    frontier = [frontier, {datasetDocs{k}.id()}]; %#ok<AGROW>
end
visited = frontier;
memberRels = {};   % every membership relation read on the walk
while ~isempty(frontier)
    next = {};
    for k = 1:numel(frontier)
        [c, r] = memberChildren(database, frontier{k}, member);
        next = [next, c]; %#ok<AGROW>
        memberRels = [memberRels, r]; %#ok<AGROW>
    end
    next = setdiff(unique(next), visited);
    members = [members, next]; %#ok<AGROW>
    visited = [visited, next]; %#ok<AGROW>
    frontier = next;
end
members = unique(members);

% --- ingested: `session` documents in the dataset's own database ---
sessionDocs = database.search(ndi.v2.isaQuery('session'));
nIngested = 0;
left = {};
for i = 1:numel(sessionDocs)
    p = sessionDocs{i}.document_properties;
    if ~strcmp(ndi.v2.kindOf(p), 'session') || strcmp(ndi.v2.sessionIdOf(p), datasetSessionId)
        continue;
    end
    ref = char(ndi.v2.blockOf(p, 'session', 'local_identifier', ''));
    if knowMembership && ~ismember(p.base.id, members)
        left{end+1} = ref; %#ok<AGROW>
        continue;
    end
    nIngested = nIngested + 1;
    sessions(end+1) = struct('session_id', ndi.v2.sessionIdOf(p), 'reference', ref, ...
        'entity_id', p.base.id, 'is_linked', false, 'path', '', 'link_id', '', ...
        'software_class', '', 'session', []); %#ok<AGROW>
end

% --- linked: the "database linking" relation, then (older datasets) the
% `linked_session` document ---
if ~knowMembership
    % no dataset document to walk from: every relation is read
    memberRels = database.search(ndi.query('', 'isa', 'directed_relation', ''));
end
nLinked = 0;
nLinkRels = 0;
problems = {};
% a session listed as ingested (its documents are here) is not listed again
linkedEntities = {sessions.entity_id};
for i = 1:numel(memberRels)
    p = memberRels{i}.document_properties;
    link = ndi.v2.sessionLinkOf(p);
    if ~strcmp(link.kind, 'linked')
        continue;
    end
    nLinkRels = nLinkRels + 1;
    if isempty(link.child_id)
        problems{end+1} = sprintf('linking relation %s names no session entity', p.base.id); %#ok<AGROW>
        continue;
    end
    if ismember(link.child_id, linkedEntities)
        continue;   % linked once already
    end
    if isempty(link.path)
        problems{end+1} = sprintf('linking relation %s names no Pathname', p.base.id); %#ok<AGROW>
        continue;
    end
    folder = ndi.v2.resolveLinkPath(link.path, datasetPath);
    [row, why] = linkedRow(folder, link.child_id, p.base.id, link.software_class, options);
    linkedEntities{end+1} = link.child_id; %#ok<AGROW>
    if isempty(row)
        problems{end+1} = why; %#ok<AGROW>
        continue;
    end
    nLinked = nLinked + 1;
    sessions(end+1) = row; %#ok<AGROW>
end

try
    links = database.search(ndi.query('', 'isa', 'linked_session', ''));
catch
    links = {};   % a schema that no longer declares the class
end
for i = 1:numel(links)
    p = links{i}.document_properties;
    rel = char(ndi.v2.blockOf(p, 'linked_session', 'path', ''));
    e = ndi.v2.edgeIds(p, 'entity_id');
    if isempty(e)
        problems{end+1} = sprintf('linked_session %s names no session entity', p.base.id); %#ok<AGROW>
        continue;
    end
    entityId = e{1};
    if ismember(entityId, linkedEntities)
        continue;   % its linking relation is read instead
    end
    folder = ndi.v2.resolveLinkPath(rel, datasetPath);
    if knowMembership && ~ismember(entityId, members)
        problems{end+1} = sprintf('%s (linked) is not %s the dataset', folder, member); %#ok<AGROW>
        continue;
    end
    [row, why] = linkedRow(folder, entityId, p.base.id, '', options);
    linkedEntities{end+1} = entityId; %#ok<AGROW>
    if isempty(row)
        problems{end+1} = why; %#ok<AGROW>
        continue;
    end
    nLinked = nLinked + 1;
    sessions(end+1) = row; %#ok<AGROW>
end

notes{end+1} = sprintf(['DENOMINATOR: %d session document(s), %d linking relation(s) ' ...
    'and %d linked_session document(s) read; %d ingested and %d linked session(s) listed'], ...
    sum(cellfun(@(d) strcmp(ndi.v2.kindOf(d.document_properties), 'session') && ...
    ~strcmp(d.session_id(), datasetSessionId), sessionDocs)), ...
    nLinkRels, numel(links), nIngested, nLinked);
if ~knowMembership
    notes{end+1} = sprintf(['no dataset document: membership (%s) cannot be read, so every ' ...
        'session is listed'], member);
end
if ~isempty(left)
    notes{end+1} = sprintf('%d session document(s) not %s the dataset, not listed: %s', ...
        numel(left), member, strjoin(left, ', '));
end
for k = 1:numel(problems)
    notes{end+1} = ['not listed: ' problems{k}]; %#ok<AGROW>
end
end

% -----------------------------------------------------------------------------
function [children, used] = memberChildren(database, parentId, member)
% the ids of the documents filed under PARENTID by the relation MEMBER
% (`included_in`), read from relations in DATABASE; USED the relations
arguments
    database
    parentId {mustBeText}
    member {mustBeText}
end
children = {};
used = {};
q = ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.query('', 'depends_on', 'parent_id', parentId);
rels = database.search(q);
for k = 1:numel(rels)
    p = rels{k}.document_properties;
    if ~ndi.v2.vocabIs('relation', ndi.v2.blockOf(p, 'directed_relation', 'relation', ''), member)
        continue;   % by node (Jess Haley 2026-10-22 [vocabulary nodes] L1)
    end
    c = ndi.v2.edgeIds(p, 'child_id');
    children = [children, c(:)']; %#ok<AGROW>
    used{end+1} = rels{k}; %#ok<AGROW>
end
end

function [row, why] = linkedRow(folder, entityId, linkId, softwareClass, options)
% the listing row of the session linked from FOLDER ([] and WHY when it
% cannot be listed)
arguments
    folder {mustBeText}
    entityId {mustBeText}
    linkId {mustBeText}
    softwareClass
    options (1,1) struct
end
why = '';
if isempty(softwareClass)
    softwareClass = 'ndi.session.dir';
end
row = struct('session_id', '', 'reference', '', 'entity_id', entityId, ...
    'is_linked', true, 'path', folder, 'link_id', linkId, ...
    'software_class', char(softwareClass), 'session', []);
if ~options.OpenLinked
    return;
end
[S, sp, why] = openLinked(folder, entityId);
if isempty(S)
    row = [];
    return;
end
row.session = S;
row.session_id = S.id();
row.reference = char(ndi.v2.blockOf(sp, 'session', 'local_identifier', ''));
end

function [S, sp, why] = openLinked(folder, entityId)
% the session in FOLDER, checked to hold the session entity ENTITYID
arguments
    folder {mustBeText}
    entityId {mustBeText}
end
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
