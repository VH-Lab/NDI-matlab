function [docs, swId, key] = softwareEntity(name, version, url, sessionId, datestamp)
%SOFTWAREENTITY A program NAME at VERSION as a `software` entity plus its
%   version assertion: DID-matlab's private jSoftware, built with did2.build.
%
%   [DOCS, SWID, KEY] = ndi.migrate.internal.softwareEntity(NAME, VERSION, ...
%       URL, SESSIONID, DATESTAMP)
%     DOCS{1}  an `entity`, type `software`: name, local_identifier
%              NAME@VERSION (NAME without a version), global_identifier {URL}
%     DOCS{2}  when VERSION is given: a text `assertion` about it, variable
%              IAO:0000129 'version number'
%   SWID is the entity's id; KEY its local_identifier. DOCS is {}, SWID and
%   KEY '' when NAME or SESSIONID is empty (no identity, or no session).
%   Duplicates are merged later by ndi.migrate.internal.softwareDedup.

docs = {};
swId = '';
key = '';
name = char(name); version = char(version); url = char(url);
sessionId = char(sessionId);
if isempty(name) || isempty(sessionId)
    return;
end
restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
ent = struct('type', did2.build.term('', 'software'), 'name', name, ...
    'local_identifier', name);
if ~isempty(version)
    ent.local_identifier = [name '@' version];
end
if ~isempty(url)
    ent.global_identifier = {url};
end
opts = {'SessionId', sessionId, 'CreationTimestamp', char(datestamp), 'Validate', false};
e = did2.build.document('entity', ent, opts{:});
swId = e.base.id;
key = ent.local_identifier;
docs = {e};
if ~isempty(version)
    docs{end+1} = did2.build.statement('assertion', swId, ...
        did2.build.term('IAO:0000129', 'version number'), ...
        did2.build.valueCell('text', {version}, 'Canonical', 'text'), ...
        'ValueKind', 'text', opts{:});
end
end
