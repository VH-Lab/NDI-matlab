function [doc, sessionId] = largestSessionRecord(bodies)
%LARGESTSESSIONRECORD The record of the session holding the most documents.
%
%   [DOC, SESSIONID] = ndi.unittest.migrate.largestSessionRecord(BODIES)
%
%   did-schema #88 (T1): a session's record is an `entity` of type session
%   whose base.id IS the session id, and every document names it through its
%   `session_id` edge. A dataset's own session is the dataset (DID-matlab
%   resolveDatasetEntities, 81c78b1: "a dataset's own session is the
%   dataset"), so its record is the entity of type dataset on that id. Before
%   #88 the record was a `session` document and the id was base.session_id;
%   both shapes are read. DOC is [] when no record is found.

counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    sid = sessionOf(bodies{k});
    if isempty(sid); continue; end
    if isKey(counts, sid); counts(sid) = counts(sid) + 1; else; counts(sid) = 1; end
end
doc = []; sessionId = ''; best = -1;
for k = 1:numel(bodies)
    b = bodies{k};
    [isRecord, sid] = recordOf(b);
    if ~isRecord; continue; end
    n = 0;
    if isKey(counts, sid); n = counts(sid); end
    if n > best
        best = n; doc = b; sessionId = sid;
    end
end
end

function [tf, sid] = recordOf(b)
tf = false; sid = '';
if ~isstruct(b) || ~isfield(b, 'document_class'); return; end
cn = b.document_class.class_name;
if strcmp(cn, 'entity') && isfield(b, 'entity') && isfield(b.entity, 'type') ...
        && isfield(b.entity.type, 'name') ...
        && any(strcmp(b.entity.type.name, {'session', 'dataset'}))
    tf = true; sid = char(b.base.id);
elseif strcmp(cn, 'session') && isfield(b.base, 'session_id')
    tf = true; sid = char(b.base.session_id);
end
end

function sid = sessionOf(b)
sid = '';
if ~isstruct(b); return; end
if isfield(b, 'depends_on') && isstruct(b.depends_on)
    for k = 1:numel(b.depends_on)
        d = b.depends_on(k);
        if strcmp(d.name, 'session_id')
            if isfield(d, 'value') && ~isempty(d.value); sid = char(d.value);
            elseif isfield(d, 'document_id'); sid = char(d.document_id); end
            return;
        end
    end
end
if isfield(b, 'base') && isfield(b.base, 'session_id') && ischar(b.base.session_id)
    sid = b.base.session_id;
end
end
