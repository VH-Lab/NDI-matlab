function body = withSessionId(body, sessionId)
%WITHSESSIONID Put a minted body's session id where the schema in use keeps it.
%
%   BODY = ndi.migrate.internal.withSessionId(BODY, SESSIONID) is the one place
%   the second pass decides how a document it MINTS records its session:
%     - the `base.session_id` FIELD, when the schema in use declares it (every
%       V_eta schema before did-schema V_eta_relation_inheritance_plan.md, and
%       no schema set at all). This is exactly what the second pass wrote
%       before: an existing base.session_id is overwritten in place, so the
%       field order of `base` does not change.
%     - otherwise (ndi.v2.sessionIdIsEdge) a `session_id` depends_on EDGE to
%       the session or dataset entity whose base.id IS the session id, and no
%       base.session_id field. A `session_id` edge already on BODY is replaced,
%       not repeated. An empty SESSIONID writes no edge: an edge with no id
%       names no document.
%   The edge is written in the shape BODY's depends_on already uses (`value`,
%   as every second-pass builder writes, or `document_id`).
%
%   Reading a session id goes through ndi.v2.sessionIdOf, which reads either.
%
%   See also ndi.v2.sessionIdIsEdge, ndi.v2.sessionIdOf, ndi.document/set_session_id.

arguments
    body (1,1) struct
    sessionId
end

if isempty(sessionId)
    sessionId = '';
end
sessionId = char(sessionId);

if ~isEdge()
    if ~isfield(body, 'base') || ~isstruct(body.base)
        body.base = struct();
    end
    body.base.session_id = sessionId;
    return;
end

if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, 'session_id')
    body.base = rmfield(body.base, 'session_id');
end

deps = struct('name', {}, 'value', {});
if isfield(body, 'depends_on') && ~isempty(body.depends_on)
    deps = body.depends_on;
    if iscell(deps)
        deps = [deps{:}];
    end
end
valueField = 'value';
if isstruct(deps) && ~isempty(fieldnames(deps)) && ~isfield(deps, 'value') ...
        && isfield(deps, 'document_id')
    valueField = 'document_id';
end
if isstruct(deps) && isfield(deps, 'name') && ~isempty(deps)
    deps = deps(~strcmp(arrayfun(@(d) char(d.name), deps, 'UniformOutput', false), 'session_id'));
end
if ~isempty(sessionId)
    e = struct('name', 'session_id', valueField, sessionId);
    if isempty(deps)
        deps = e;
    else
        % the fields the existing entries carry, in their order
        f = fieldnames(deps);
        add = cell2struct(cell(numel(f), 1), f, 1);
        add.name = 'session_id';
        add.(valueField) = sessionId;
        deps = [reshape(deps, 1, []), add];
    end
end
body.depends_on = deps;
end

% -----------------------------------------------------------------------------
function tf = isEdge()
%ISEDGE ndi.v2.sessionIdIsEdge, read once per schema file rather than per body.
persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'logical');
end
p = getenv('DID_SCHEMA_PATH');
f = '';
if ~isempty(p)
    f = fullfile(p, 'base.json');
end
if isempty(f) || ~isfile(f)
    tf = false;
    return;
end
info = dir(f);
key = sprintf('%s|%.12g|%d', f, info.datenum, info.bytes);
if ~isKey(cache, key)
    cache(key) = ndi.v2.sessionIdIsEdge();
end
tf = cache(key);
end
