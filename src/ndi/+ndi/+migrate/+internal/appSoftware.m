function [docs, swId, env, key] = appSoftware(v1Body)
%APPSOFTWARE A v1 document's `app` block as a `software` entity (rule R1).
%
%   [DOCS, SWID, ENV, KEY] = ndi.migrate.internal.appSoftware(V1BODY)
%
%   TEAM-SIGN-OFF [software] (jess, 2026-08-06, did-schema
%   V_eta_tenet_audit.md): "the `app` mixin is replaced by a `software` ENTITY
%   (deduplicated by name+version) referenced from a statement by
%   `software_id`". Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [presentation app is software] and
%   [software_id is what produced the statement] apply it to a v1
%   stimulus_presentation's `app` (the decoder that produced the
%   presentation); [control pairing is a calculation] to a
%   control_stimulus_ids's `app` (the tuning_response app that computed it).
%
%   The SAME SHAPE DID-matlab's private jSoftwareFromApp / jSoftware write
%   (ndi.migrate.internal.softwareEntity):
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
[docs, swId, key] = ndi.migrate.internal.softwareEntity(name, version, url, ...
    sessionId, datestamp);
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
