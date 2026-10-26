function [docs, swId, env, key] = appSoftware(v1Body)
%APPSOFTWARE A v1 document's `app` block as a `software` entity (rule R1).
%
%   [DOCS, SWID, ENV, KEY] = ndi.migrate.internal.appSoftware(V1BODY)
%
%   TEAM-SIGN-OFF [software] (jess, 2026-08-06, did-schema
%   V_eta_tenet_audit.md): "the `app` mixin is replaced by a `software` ENTITY
%   (deduplicated by name+version) referenced from a statement by
%   `software_id`". Decided by Jess Haley, 2026-10-26 [presentation app is
%   software] and [control selection on the presentation method] (did-schema
%   V_eta_go_forward_class_audit.md) apply it to a v1 stimulus_presentation's
%   and control_stimulus_ids's `app`.
%
%   The SAME SHAPE DID-matlab's private jSoftwareFromApp / jSoftware write
%   (they are private to +migrators_j, so this is the NDI-side copy, built
%   with did2.build so the shape is read from the schema in use):
%     DOCS{1}  an `entity`, type `software`: name, local_identifier
%              NAME@VERSION (NAME without a version), global_identifier {URL}
%     DOCS{2}  when VERSION is given: a text `assertion` about it, variable
%              IAO:0000129 'version number'
%   SWID is the entity's id, for the statement's `software_id` edge; KEY its
%   local_identifier (NAME@VERSION), '' when no entity is minted.
%   Duplicates are merged later by ndi.migrate.internal.softwareDedup
%   (ndi.migrate.local's resolveSoftwareDedup runs after the stimulus pass).
%
%   ENV is the run environment the block names (os, os_version, interpreter,
%   interpreter_version; only the non-empty ones), what jSoftwareFromApp
%   returns as its third output. Placing it is the CALLER's job: on did-schema
%   main only `calculation` declares `operating_system_id` / `interpreter_id`.
%
%   DOCS is {} and SWID '' when the block names no program (no identity, no
%   entity) or the document has no session (base.session_id is required).
%   Both spellings of the name and version are read: NDI's app.json writes
%   `name` / `version`, did2.convert.universalRenames writes `app_name` /
%   `app_version`.

docs = {};
swId = '';
key = '';
env = struct();
app = struct();
if isstruct(v1Body) && isfield(v1Body, 'app') && isstruct(v1Body.app) ...
        && isscalar(v1Body.app)
    app = v1Body.app;
end
for f = {'os', 'os_version', 'interpreter', 'interpreter_version'}
    v = charField(app, f(1));
    if ~isempty(v)
        env.(f{1}) = v;
    end
end
name    = charField(app, {'app_name', 'name'});
version = charField(app, {'app_version', 'version'});
url     = charField(app, {'url', 'app_url'});
sessionId = char(ndi.v2.sessionIdOf(v1Body));
datestamp = '';
if isfield(v1Body, 'base') && isstruct(v1Body.base) && isfield(v1Body.base, 'datestamp')
    datestamp = char(v1Body.base.datestamp);
end
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
opts = {'SessionId', sessionId, 'CreationTimestamp', datestamp, 'Validate', false};
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

function v = charField(s, names)
v = '';
for k = 1:numel(names)
    if isfield(s, names{k}) && ~isempty(s.(names{k})) ...
            && (ischar(s.(names{k})) || (isstring(s.(names{k})) && isscalar(s.(names{k}))))
        v = char(s.(names{k}));
        return;
    end
end
end
