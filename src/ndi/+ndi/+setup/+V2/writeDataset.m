function out = writeDataset(path, reference, datasetSessionId, datasetDocs, sessions, options)
%WRITEDATASET Write a V2 dataset and its sessions, checked as one set.
%
%   OUT = ndi.setup.V2.writeDataset(PATH, REFERENCE, DATASETSESSIONID,
%   DATASETDOCS, SESSIONS) writes the dataset at PATH and, by default, each of
%   its sessions to its own folder, LINKED from the dataset
%   (DID-schema V_eta_linked_session_plan.md):
%
%     * the dataset's database (PATH/.ndi) holds DATASETDOCS (the dataset-level
%       documents, each with session id DATASETSESSIONID: the dataset entity,
%       its studies, people, software, ... e.g. from
%       ndi.setup.V2.datasetMetadata) and, per session, its `included_in`
%       relations (one per study id) and ONE direct session -> dataset
%       `included_in` relation whose method records the link: "database
%       linking" (EMPTY:0000400) with "software class" ndi.session.dir and the
%       session folder's Pathname (NCIT:C47922; ndi.v2.linkPath: relative,
%       with '/', when it is inside PATH; absolute otherwise). Ingested
%       ('Linked' false), that relation's method is "database ingestion"
%       (EMPTY:0000399). (did-schema V_eta_go_forward_class_audit.md, Jess
%       Haley 2026-10-29 [linked session link on a direct dataset relation],
%       [linked session link details], [linked session pathname]; it replaces
%       the withdrawn `linked_session` document,
%       V_eta_linked_session_plan.md [linked_session withdrawn].) Where
%       DATASETDOCS hold no `dataset` document the method goes on the
%       session's relation to its first study; a linked session with neither
%       is ndi:setup:V2:noLinkParent;
%     * each session's own documents -- its `session` entity (whose id IS the
%       session id) and SESSIONS.documents -- are written ONCE, to its folder
%       (ndi.setup.V2.makeSessions), after the dataset;
%     * before anything is written the whole set, the sessions' documents
%       included, is checked by ndi.setup.V2.createDataset ('External'): with
%       'Strict' (the default) a dangling edge, a repeated id or a session not
%       in the dataset writes nothing.
%
%   SESSIONS is a table, one row per session:
%     local_identifier  the session's stable, spaceless handle (required)
%     path              the session's folder (required with 'Linked')
%     session_id        its session id (required; a new import makes it with
%                       ndi.ido.unique_id before building its documents)
%     session_doc_id    optional; must equal session_id when given
%     name, description optional
%     study_ids         the studies it is filed under: a cellstr, one id as
%                       char, or a cell holding either -- cell2table unwraps a
%                       one-id cell to char, and both read the same here
%     time_reference_id optional: the session's own time reference
%     documents         optional: a cell per row, that session's documents
%
%   Options:
%     'Linked'         default true. false INGESTS every session into the
%                      dataset's own database (its session document,
%                      relations and documents) and writes no session folder.
%     'WriteSessions'  default true: with 'Linked', write the session folders
%                      after the dataset (makeSessions) and list the dataset's
%                      sessions. false leaves that to the caller (the Haley
%                      import writes them itself, with or without a dataset).
%     'KeepOriginals'  default false: ingested files are not deleted once
%                      copied (for an ingested dataset whose files the caller
%                      ingests again into session folders)
%     'Name'           the dataset's display name ('' = from its entity)
%     'Strict'         default true (see above)
%     'Overwrite', 'Validate', 'BatchSize', 'Progress'  passed to
%                      createDataset and makeSessions (defaults false, true,
%                      2000, true)
%
%   OUT fields: path, id (the dataset's id), report (createDataset's check),
%   sessions (SESSIONS with session_id filled in), sessionObjects (the opened
%   sessions, when written here), sessionReferences / sessionIds (as
%   ndi.dataset lists them: empty when 'Linked' and the sessions are not yet
%   written), documents (how many were written or checked).
%
%   Errors from createDataset (ndi:setup:V2:datasetExists, ...:datasetId,
%   ...:wrongSession) and makeSessions (ndi:setup:V2:badSessionTable) pass
%   through; a session row with no session_id is ndi:setup:V2:badSessionTable.
%
%   See also ndi.setup.V2.createDataset, ndi.setup.V2.makeSessions,
%   ndi.setup.V2.createSession, ndi.setup.conv.template.import_V2.

arguments
    path (1,:) char {mustBeNonzeroLengthText}
    reference (1,:) char {mustBeNonzeroLengthText}
    datasetSessionId (1,:) char {mustBeNonzeroLengthText}
    datasetDocs cell
    sessions table
    options.Linked (1,1) logical = true
    options.WriteSessions (1,1) logical = true
    options.KeepOriginals (1,1) logical = false
    options.Name (1,:) char = ''
    options.Strict (1,1) logical = true
    options.Overwrite (1,1) logical = false
    options.Validate (1,1) logical = true
    options.BatchSize (1,1) double {mustBePositive, mustBeInteger} = 2000
    options.Progress (1,1) logical = true
end

T = sessions;
vars = T.Properties.VariableNames;
need = {'local_identifier', 'session_id'};
if options.Linked
    need{end+1} = 'path';
end
for v = need
    if ~ismember(v{1}, vars)
        error('ndi:setup:V2:badSessionTable', 'The session table has no `%s` column.', v{1});
    end
end
n = height(T);
if n > 0 && any(cellfun(@isempty, cellstr(T.session_id)))
    error('ndi:setup:V2:badSessionTable', ['A session row has no session_id: make it ' ...
        '(ndi.ido.unique_id) before building that session''s documents.']);
end

name = options.Name;
if isempty(name)
    isDataset = cellfun(@(d) strcmp(ndi.v2.kindOf(d), 'dataset'), datasetDocs);
    if any(isDataset)
        ds = datasetDocs{find(isDataset, 1)};
        [~, blk] = ndi.v2.kindOf(ds);
        if isfield(ds.(blk), 'name'), name = char(ds.(blk).name); end
    end
end

% the parent of each session's link relation: the one dataset document
isDs = cellfun(@(d) strcmp(ndi.v2.kindOf(d), 'dataset'), datasetDocs);
datasetDocId = '';
if nnz(isDs) == 1
    datasetDocId = datasetDocs{isDs}.base.id;
end

sessDocs = cell(1, n);
external = {};
for k = 1:n
    own = sessionRecord(char(cellOf(T, 'local_identifier', k)), char(cellOf(T, 'session_id', k)), ...
        'Name', cellOf(T, 'name', k), 'Description', cellOf(T, 'description', k), ...
        'TimeReferenceId', cellOf(T, 'time_reference_id', k), ...
        'StudyIds', cellOf(T, 'study_ids', k), 'Id', char(cellOf(T, 'session_doc_id', k)));
    docs = cellOf(T, 'documents', k);
    if isempty(docs), docs = {}; end
    docs = reshape(docs, 1, []);
    [own, link] = withLink(own, datasetDocId, options.Linked, ...
        char(cellOf(T, 'path', k)), path, datasetSessionId, char(cellOf(T, 'local_identifier', k)));
    if options.Linked
        % in the dataset: the session's included_in relations and how it is
        % linked; its own documents go to its folder (checked here as one set)
        sessDocs{k} = [own(2:end), link];
        external = [external, own(1), docs]; %#ok<AGROW>
    else
        d = [own, link, docs];
        if options.KeepOriginals
            d = keepOriginals(d);
        end
        sessDocs{k} = d;
    end
end

[ds, report] = ndi.setup.V2.createDataset(path, reference, datasetSessionId, datasetDocs, ...
    sessDocs, 'Name', name, 'Overwrite', options.Overwrite, 'Strict', options.Strict, ...
    'Validate', options.Validate, 'BatchSize', options.BatchSize, ...
    'Progress', options.Progress, 'External', external);

out = struct('path', path, 'id', ds.id(), 'report', report, 'sessions', T, ...
    'sessionObjects', {{}}, 'sessionReferences', {{}}, 'sessionIds', {{}}, ...
    'documents', numel(datasetDocs) + sum(cellfun(@numel, sessDocs)) + numel(external));
if ~options.Linked
    [out.sessionReferences, out.sessionIds] = ds.session_list();
    return;
end
if ~options.WriteSessions
    return;
end
% the session folders: membership is the dataset's (its included_in relations
% were written there), so the folders carry no study relations of their own
Tw = T;
if ismember('study_ids', vars)
    Tw = removevars(Tw, 'study_ids');
end
[Tw, out.sessionObjects] = ndi.setup.V2.makeSessions(Tw, 'Overwrite', options.Overwrite, ...
    'Validate', options.Validate, 'Progress', options.Progress, 'BatchSize', options.BatchSize);
out.sessions.session_id = Tw.session_id;
ds = ndi.dataset.dir(path);
[out.sessionReferences, out.sessionIds] = ds.session_list();
end

function [own, link] = withLink(own, datasetDocId, linked, folder, path, datasetSessionId, reference)
% LINK, a cell holding the session's link relation
% (ndi.v2.sessionLinkRelation) to the dataset document; with none, to its
% first study, whose plain relation it replaces in OWN (one relation per
% parent). {} for an ingested session with neither.
arguments
    own cell
    datasetDocId (1,:) char
    linked (1,1) logical
    folder (1,:) char
    path (1,:) char
    datasetSessionId (1,:) char
    reference (1,:) char
end
entityId = own{1}.base.id;
parentId = datasetDocId;
if isempty(parentId) && numel(own) > 1
    p = ndi.v2.edgeIds(own{2}, 'parent_id');
    parentId = p{1};
    own(2) = [];
end
if isempty(parentId)
    if linked
        error('ndi:setup:V2:noLinkParent', ['Session %s is to be linked, but there is no ' ...
            'dataset document and no study to record its link on.'], reference);
    end
    link = {};
    return;
end
pathname = '';
if linked
    pathname = ndi.v2.linkPath(folder, path);
end
link = {ndi.v2.sessionLinkRelation(entityId, parentId, linked, 'ndi.session.dir', ...
    pathname, datasetSessionId)};
end

function v = cellOf(T, var, k)
% row K of T's column VAR, unwrapped from its table cell ('' when absent)
arguments
    T table
    var (1,:) char
    k (1,1) double
end
v = '';
if ~ismember(var, T.Properties.VariableNames)
    return;
end
v = T.(var)(k);
if iscell(v)
    v = v{1};
end
end
