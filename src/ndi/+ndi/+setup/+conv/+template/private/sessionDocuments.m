function out = sessionDocuments(dataFolder, cfg, outputRoot, throwErrors)
%SESSIONDOCUMENTS Stage 1 (template): the dataset, its study, and the sessions.
%
%   OUT = sessionDocuments(DATAFOLDER, CFG, OUTPUTROOT, THROWERRORS) builds
%
%     * the DATASET-LEVEL documents, once: the dataset entity (its id IS the
%       dataset's session id: session_id is an edge) and its studies, each
%       `included_in` the dataset, from the spec's `dataset` and `studies`
%       sections through ndi.setup.V2.datasetMetadata -- which also takes the
%       spec's people, organizations, funding, publications, software,
%       products, strains, chemicals, formulations and instruments, when a
%       real import's spec lists them;
%     * the SESSION LIST: one session per folder of DATAFOLDER whose name
%       matches CFG.sessions.folder_pattern. Each gets its session id now, so
%       every later stage can build documents for it; its `session` document
%       and `included_in` relation are made when it is written.
%
%   TEMPLATE: one session per data folder is this template's rule. A real
%   importer replaces it with the source's own day index (the Haley import
%   reads a table of contents: ndi.setup.conv.haley.sessionList) and records
%   the rule in its decision log.
%
%   Each session's output folder is OUTPUTROOT/<local_identifier>, never in
%   the raw data: the session points at its raw files by location.
%
%   OUT fields: datasetSessionId, documents (the dataset-level documents),
%   ids (containers.Map, spec key -> id), sessions (table: local_identifier,
%   name, folder, path, session_id, session_doc_id, study_ids), report.

arguments
    dataFolder {mustBeFolder}
    cfg (1,1) struct
    outputRoot {mustBeText}
    throwErrors (1,1) logical
end
r = newReport('sessions');

% ---- the dataset and its studies (dataset level) ------------------------------
dsid = char(ndi.ido.unique_id());
meta = struct('dataset', cfg.dataset, 'studies', {cfg.studies});
for k = {'organizations', 'people', 'funding', 'publications', 'web_resources', 'software', ...
        'products', 'strains', 'chemicals', 'formulations', 'instruments'}
    if isfield(cfg, k{1}) && ~isempty(cfg.(k{1}))
        meta.(k{1}) = cfg.(k{1});
    end
end
m = ndi.setup.V2.datasetMetadata(meta, dsid, 'Studies', "include");
for k = 1:numel(m.unrepresented)
    u = m.unrepresented(k);
    r = skipRow(r, sprintf('spec %s %s', u.kind, u.key), sprintf('`%s` not recorded: %s', u.field, u.why));
end
studyKey = char(cfg.sessions.study);
if ~isKey(m.ids, studyKey)
    error('ndi:setup:conv:template:noStudy', ...
        'The spec''s sessions.study names "%s", which is not a key in `studies`.', studyKey);
end

% ---- the sessions: one per data folder -----------------------------------------
listing = dir(dataFolder);
listing = listing([listing.isdir] & ~ismember({listing.name}, {'.', '..'}));
rows = {};
for k = 1:numel(listing)
    folder = listing(k).name;
    r.read = r.read + 1;
    try
        if isempty(regexp(folder, cfg.sessions.folder_pattern, 'once'))
            r = skipRow(r, folder, sprintf('does not match sessions.folder_pattern %s', ...
                cfg.sessions.folder_pattern));
            continue;
        end
        % the stable, spaceless handle; the display name from the spec's format
        localId = regexprep(folder, '\s+', '_');
        sid = char(ndi.ido.unique_id());
        rows(end+1, :) = {localId, sprintf(cfg.sessions.name_format, folder), ...
            fullfile(dataFolder, folder), fullfile(outputRoot, localId), sid, sid, ...
            {m.ids(studyKey)}}; %#ok<AGROW>
        r.written = r.written + 1;
    catch err
        r = rowError(r, folder, err, throwErrors);
    end
end
vars = {'local_identifier', 'name', 'folder', 'path', 'session_id', 'session_doc_id', 'study_ids'};
if isempty(rows)
    sessions = cell2table(cell(0, numel(vars)), 'VariableNames', vars);
else
    sessions = cell2table(rows, 'VariableNames', vars);
end
r.documents = numel(m.documents);

out = struct('datasetSessionId', dsid, 'documents', {m.documents}, 'ids', m.ids, ...
    'sessions', sessions, 'report', r);
end
