function docs = sessionRecord(reference, sid, options)
%SESSIONRECORD A session's own documents: its `session` entity and its studies.
%
%   DOCS = sessionRecord(REFERENCE, SID, ...) returns the session entity
%   (ndi.setup.V2.entityDocuments 'session', local_identifier REFERENCE, its
%   id SID: session_id is an edge, so the session document's id IS the
%   session id) followed by one `included_in` relation per study id. It is
%   the ONE builder of these documents: ndi.setup.V2.createSession writes them
%   into a session's folder and ndi.setup.V2.writeDataset checks the same
%   documents (same ids) with the dataset, so the two cannot drift.
%
%   Options: 'Name', 'Description', 'TimeReferenceId', 'StudyIds' (anything
%   idList reads), 'Id' (the session document's id; default SID).

arguments
    reference (1,:) char
    sid (1,:) char
    options.Name = ''
    options.Description = ''
    options.TimeReferenceId = ''
    options.StudyIds = {}
    options.Id (1,:) char = ''
end
fields = struct('local_identifier', reference);
if ~isempty(options.Name)
    fields.name = char(options.Name);
end
if ~isempty(options.Description)
    fields.description = char(options.Description);
end
edges = struct();
if ~isempty(options.TimeReferenceId)
    edges.time_reference_id = char(options.TimeReferenceId);
end
docId = options.Id;
if isempty(docId)
    docId = sid;
end
docs = ndi.setup.V2.entityDocuments('session', fields, edges, 'SessionId', sid, ...
    'Id', docId);
studies = idList(options.StudyIds);
for k = 1:numel(studies)
    docs{end+1} = did2.build.directedRelation(docs{1}.base.id, studies{k}, ...
        'included_in', 'SessionId', sid); %#ok<AGROW>
end
end
