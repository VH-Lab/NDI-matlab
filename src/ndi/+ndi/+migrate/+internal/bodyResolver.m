function resolver = bodyResolver(bodies)
%BODYRESOLVER Session/element lookups over a set of v1 document bodies.
%
%   RESOLVER = ndi.migrate.internal.bodyResolver(BODIES) indexes the cell
%   array BODIES of did_v1 document body structs and returns a struct of
%   function handles that answer the session-aware questions the
%   context-dependent migrators need but a single document cannot:
%
%     resolver.subjectOfElement(elementId)
%         The subject_id an element resolves to. Reads the element's
%         depends_on `subject_id`; if the element is derived (its own
%         subject is empty) it follows `underlying_element_id` up the
%         chain until a subject is found. Errors if none can be reached.
%
%     resolver.epochClockOfElement(elementId, epochId)
%         The ndi.time.clocktype string for an element's epoch, used as
%         the `epoch_clock` of an epoch_bounded_reference. Prefers the
%         matching `element_epoch` document (depends_on element_id +
%         epochid), then any `epochclocktimes` document for the epoch
%         (favouring 'dev_local_time'), then defaults to 'dev_local_time'.
%
%   This lives in the NDI layer because only here is the whole body set
%   (the session/element graph) available; the per-document DID converter
%   defers anything that needs it (see
%   ndi.migrate.internal.stimulusBathToBath and
%   did2.convert.migrators_e.stimulus_bath).
%
%   STATUS: scaffold. Authored without local MATLAB and exercised only in
%   NDI CI alongside ndi.migrate.local's second pass.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.stimulusBathToBath.

arguments
    bodies cell
end

% The v1 readers (did2.convert.readers.sqliteV1 / dumbJsonV1) return raw
% JSON char bodies, while the idempotent re-run path passes decoded structs.
% Normalise to a cell of scalar structs so the lookups below can index by
% field regardless of which path produced the body set.
bodies = normaliseBodies(bodies);

byId = indexById(bodies);

resolver = struct();
resolver.subjectOfElement   = @(elementId) subjectOfElement(byId, elementId);
resolver.epochClockOfElement = @(elementId, epochId) ...
    epochClockOfElement(bodies, elementId, epochId);
end

% ===================== normalisation ======================================

function out = normaliseBodies(raw)
out = {};
for k = 1:numel(raw)
    b = raw{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            continue;   % unparseable body: not useful for resolution
        end
    end
    if isstruct(b) && isscalar(b)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

% ===================== index ==============================================

function map = indexById(bodies)
map = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    b = bodies{k};
    id = baseId(b);
    if ~isempty(id)
        map(id) = b;   % last writer wins; ids are unique in practice
    end
end
end

% ===================== subject resolution =================================

function subjectId = subjectOfElement(byId, elementId)
% Follow underlying_element_id up the derivation chain until a non-empty
% subject_id is found. Guard against cycles with a visited set.
visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
cur = char(elementId);
while ~isempty(cur) && ~isKey(visited, cur)
    visited(cur) = true;
    if ~isKey(byId, cur)
        break;
    end
    body = byId(cur);
    sid = dependencyValue(body, 'subject_id');
    if ~isempty(sid)
        subjectId = sid;
        return;
    end
    cur = dependencyValue(body, 'underlying_element_id');
end
error('NDI:migrate:noSubjectForElement', ...
    'Could not resolve a subject_id for element "%s".', char(elementId));
end

% ===================== epoch clock resolution ============================

function clock = epochClockOfElement(bodies, elementId, epochId)
elementId = char(elementId);
epochId   = char(epochId);

% 1) element_epoch document for this element + epoch.
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(classNameOf(b), 'element_epoch') ...
            && strcmp(dependencyValue(b, 'element_id'), elementId) ...
            && strcmp(epochIdOf(b), epochId)
        c = subField(b, 'element_epoch', 'epoch_clock');
        if ~isempty(c)
            clock = c;
            return;
        end
    end
end

% 2) any epochclocktimes for this epoch; prefer the device-local clock.
fallback = '';
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(classNameOf(b), 'epochclocktimes') ...
            && strcmp(epochIdOf(b), epochId)
        c = subField(b, 'epochclocktimes', 'clocktype');
        if strcmp(c, 'dev_local_time')
            clock = c;
            return;
        elseif isempty(fallback) && ~isempty(c)
            fallback = c;
        end
    end
end
if ~isempty(fallback)
    clock = fallback;
    return;
end

% 3) conventional default for a device epoch.
clock = 'dev_local_time';
end

% ===================== body field helpers ================================

function id = baseId(body)
id = '';
if isstruct(body) && isfield(body, 'base') && isstruct(body.base) ...
        && isfield(body.base, 'id')
    id = char(body.base.id);
end
end

function name = classNameOf(body)
name = '';
if isstruct(body) && isfield(body, 'document_class') ...
        && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    name = char(body.document_class.class_name);
end
end

function e = epochIdOf(body)
e = '';
if isstruct(body) && isfield(body, 'epochid') && isstruct(body.epochid) ...
        && isfield(body.epochid, 'epochid')
    e = char(body.epochid.epochid);
end
end

function v = subField(body, block, name)
v = '';
if isstruct(body) && isfield(body, block) && isstruct(body.(block)) ...
        && isfield(body.(block), name)
    raw = body.(block).(name);
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        v = char(raw);
    end
end
end

function v = dependencyValue(body, name)
v = '';
if ~isstruct(body) || ~isfield(body, 'depends_on')
    return;
end
deps = body.depends_on;
for k = 1:numel(deps)
    d = deps(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        end
        return;
    end
end
end
