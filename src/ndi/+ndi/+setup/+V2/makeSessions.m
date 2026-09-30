function [T, sessions] = makeSessions(T, options)
%MAKESESSIONS Stage 3 of a V2 import: create one session per row of T.
%
%   [T, SESSIONS] = ndi.setup.V2.makeSessions(T) creates a V2 session for
%   each row of the table T (with ndi.setup.V2.createSession) and returns T
%   with a `session_id` column filled in, plus the opened ndi.session.dir
%   objects in the same order.
%
%   T's columns:
%     local_identifier  the stable, spaceless handle (required, unique)
%     path              the session's directory; created if missing (required)
%     name              display name (optional column)
%     description       free text (optional column)
%     study_ids         a cellstr per row: the studies it is part_of (optional)
%
%   The table is checked BEFORE anything is written: a missing required
%   column, an empty or duplicated local_identifier, or two rows sharing a
%   path is an error (ndi:setup:V2:badSessionTable), so a bad table creates
%   no sessions at all.
%
%   Options:
%     'Overwrite'  passed to createSession (default false)
%     'Verbose'    default true: print the denominator
%
%   See also ndi.setup.V2.createSession, ndi.setup.conv.haley.sessionList.

arguments
    T table
    options.Overwrite (1,1) logical = false
    options.Verbose (1,1) logical = true
end

vars = T.Properties.VariableNames;
for need = {'local_identifier', 'path'}
    if ~any(strcmp(vars, need{1}))
        error('ndi:setup:V2:badSessionTable', 'The session table has no `%s` column.', need{1});
    end
end
ids = cellstr(T.local_identifier);
if any(cellfun(@isempty, ids))
    error('ndi:setup:V2:badSessionTable', 'A row has an empty local_identifier.');
end
[u, ~, j] = unique(ids);
dup = u(accumarray(j(:), 1) > 1);
if ~isempty(dup)
    error('ndi:setup:V2:badSessionTable', 'local_identifier repeated: %s.', strjoin(dup, ', '));
end
paths = cellstr(T.path);
[u, ~, j] = unique(paths);
dup = u(accumarray(j(:), 1) > 1);
if ~isempty(dup)
    error('ndi:setup:V2:badSessionTable', 'Two sessions share a directory: %s.', strjoin(dup, ', '));
end

T.session_id = repmat({''}, height(T), 1);
sessions = cell(height(T), 1);
for k = 1:height(T)
    if ~isfolder(paths{k})
        mkdir(paths{k});
    end
    args = {'Overwrite', options.Overwrite};
    if any(strcmp(vars, 'name')), args = [args, {'Name', char(T.name{k})}]; end %#ok<AGROW>
    if any(strcmp(vars, 'description')), args = [args, {'Description', char(T.description{k})}]; end %#ok<AGROW>
    if any(strcmp(vars, 'study_ids')), args = [args, {'StudyIds', T.study_ids{k}}]; end %#ok<AGROW>
    sessions{k} = ndi.setup.V2.createSession(paths{k}, ids{k}, args{:});
    T.session_id{k} = sessions{k}.id();
end

if options.Verbose
    fprintf('DENOMINATOR: %d session row(s) read, %d session(s) created\n', ...
        height(T), sum(~cellfun(@isempty, T.session_id)));
end
end
