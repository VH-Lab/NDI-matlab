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
%       relations (one per study id) and a `linked_session` naming the
%       session's folder (ndi.v2.linkPath: relative when it is inside PATH);
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
    if options.Linked
        % in the dataset: the session's included_in relations and where it
        % lives; its own documents go to its folder (checked here as one set)
        link = did2.build.document('linked_session', ...
            struct('path', ndi.v2.linkPath(char(cellOf(T, 'path', k)), path)), ...
            'SessionId', datasetSessionId, 'Edges', struct('entity_id', own{1}.base.id));
        sessDocs{k} = [own(2:end), {link}];
        external = [external, own(1), docs]; %#ok<AGROW>
    else
        d = [own, docs];
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
