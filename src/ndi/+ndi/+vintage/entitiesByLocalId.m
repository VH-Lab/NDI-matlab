function found = entitiesByLocalId(S, lids)
%ENTITIESBYLOCALID The session's entities whose local identifier is one of LIDS.
%
%   FOUND = ndi.vintage.entitiesByLocalId(SESSION, LIDS) is a cell of light
%   entity documents (base.id and entity.local_identifier, ndi.vintage.valueDocs)
%   in database order: the session's entities whose `entity.local_identifier`
%   is in LIDS (a cellstr), the documents `isa entity & local_identifier in
%   LIDS & in the session` matches. They are taken from one read of every
%   entity's local identifier in the session, kept for the call when
%   ndi.vintage.elementFieldsScope is open, so the epoch-table readers
%   (ndi.vintage.ingestedArchives, ndi.vintage.ingestedEpochs) share it.
%   FOUND is [] when the database cannot answer from its index; the caller
%   then searches as before.
%
%   See also ndi.vintage.ingestedArchives, ndi.vintage.ingestedEpochs.

lids = reshape(cellstr(lids), 1, []);
key = ['entities|' char(S.id())];
[all_, hit] = ndi.vintage.elementFieldsScope('get', key);
if ~hit
    docs = ndi.vintage.valueDocs(S, ndi.query('', 'isa', 'entity', '') & ...
        ndi.query('base.session_id', 'exact_string', S.id(), ''), ...
        {'entity.local_identifier'}, 'entity');
    all_ = struct('docs', {docs}, 'lids', {{}});
    if iscell(docs)
        all_.lids = cellfun(@(d) localId(d), docs, 'UniformOutput', false);
    end
    ndi.vintage.elementFieldsScope('put', key, all_);
end
found = [];
if iscell(all_.docs)
    found = all_.docs(ismember(all_.lids, lids));
end
end

function lid = localId(d)
% an entity's local identifier as char, '' when it has none
lid = '';
p = d.document_properties;
if isfield(p, 'entity') && isstruct(p.entity) && isfield(p.entity, 'local_identifier')
    v = p.entity.local_identifier;
    if ischar(v) || (isstring(v) && isscalar(v)); lid = char(v); end
end
end
