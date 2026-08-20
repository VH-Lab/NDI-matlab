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
%     resolver.subjectsForPresentation(presentationId)
%         The animal subject_id(s) a stimulus_presentation was shown to,
%         reached through the response link (stimulus_response carries both
%         stimulus_presentation_id and the responding element_id -> its
%         subject). A stimulus_presentation only names the stimulator, so
%         this is how the second pass puts the stimulus manipulation on the
%         animal. Returns a de-duplicated cell of subject_ids.
%
%         WIDENED 2026-08-17 FROM AN EXACT NAME MATCH TO THE IS-A RELATION,
%         because the exact match could not fire on production data. It read
%         `strcmp(classNameOf(b), 'stimulus_response')`, and the production
%         writer mints the SUBCLASS: `+ndi/+app/+stimulus/tuning_response.m`
%         writes `stimulus_response_scalar`. Measured on the 20211116 corpus
%         (1220 documents read): 0 named `stimulus_response`, 273 named
%         `stimulus_response_scalar`, all 273 carrying BOTH
%         `stimulus_presentation_id` and `element_id`, covering all 11
%         presentations and resolving to 1 subject each.
%
%         The IS-A is read from the DOCUMENT'S OWN `document_class.
%         superclasses`, not from a hard-coded list of names: a real
%         stimulus_response_scalar body carries
%         `{definition: '$NDIDOCUMENTPATH/base.json'},
%          {definition: '$NDIDOCUMENTPATH/stimulus/stimulus_response.json'}`,
%         which is the v1 template's own declaration
%         (ndi_common/database_documents/stimulus/stimulus_response_scalar.json).
%         A future subclass therefore needs no edit here, and a class that
%         merely SOUNDS like a response is not swept in.
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

% Pre-index the two session-graph lookups that would otherwise linear-scan
% ALL bodies on EVERY call -- O(N) per call, hence O(N^2) across a corpus,
% invisible at ~1e3 documents and pathological at ~1e5. One O(N) pass builds
% the maps; the readers below then answer in O(1)/O(matches). The ordering
% and first-match semantics of the old scans are preserved exactly: each map
% stores its bodies in body order and the readers stop at the first hit.
[responsesByPresentation, elementEpochByKey, clocktimesByEpoch] = ...
    indexGraph(bodies);

resolver = struct();
resolver.subjectOfElement   = @(elementId) subjectOfElement(byId, elementId);
resolver.epochClockOfElement = @(elementId, epochId) ...
    epochClockOfElement(elementEpochByKey, clocktimesByEpoch, elementId, epochId);
resolver.subjectsForPresentation = @(presentationId) ...
    subjectsForPresentation(responsesByPresentation, byId, presentationId);
end

% ===================== graph index (one O(N) pass) =======================

function [responsesByPresentation, elementEpochByKey, clocktimesByEpoch] = ...
        indexGraph(bodies)
% Build, in a single pass over BODIES and in body order:
%   responsesByPresentation : stimulus_presentation_id -> cell of the
%                             stimulus_response bodies that name it
%   elementEpochByKey       : '<element_id>|<epoch_id>' -> cell of the
%                             element_epoch bodies for that pair
%   clocktimesByEpoch       : epoch_id -> cell of the epochclocktimes bodies
% Each holds exactly the subset the old per-call scans would have visited, in
% the same order, so the readers reproduce the old first-match results.
responsesByPresentation = containers.Map('KeyType', 'char', 'ValueType', 'any');
elementEpochByKey        = containers.Map('KeyType', 'char', 'ValueType', 'any');
clocktimesByEpoch        = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    b = bodies{k};
    if isaStimulusResponse(b)
        pid = dependencyValue(b, 'stimulus_presentation_id');
        if ~isempty(pid)
            responsesByPresentation = appendToMap(responsesByPresentation, pid, b);
        end
    end
    cls = classNameOf(b);
    if strcmp(cls, 'element_epoch')
        eid = dependencyValue(b, 'element_id');
        ep  = epochIdOf(b);
        if ~isempty(eid) && ~isempty(ep)
            elementEpochByKey = appendToMap(elementEpochByKey, [eid '|' ep], b);
        end
    elseif strcmp(cls, 'epochclocktimes')
        ep = epochIdOf(b);
        if ~isempty(ep)
            clocktimesByEpoch = appendToMap(clocktimesByEpoch, ep, b);
        end
    end
end
end

function map = appendToMap(map, key, value)
if isKey(map, key)
    lst = map(key);
else
    lst = {};
end
lst{end+1} = value; %#ok<AGROW>
map(key) = lst;
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

% ===================== stimulus animal resolution ========================

function subs = subjectsForPresentation(responsesByPresentation, byId, presentationId)
% The animal subject(s) a stimulus_presentation was shown to. A presentation only
% names the STIMULATOR, so the animal is reached through the response link:
% stimulus_response carries both stimulus_presentation_id and element_id (the
% responding element), so presentation <- stimulus_response -> element ->
% subjectOfElement -> the animal. Returns a de-duplicated cell of subject_ids
% (usually one; empty if nothing responded / no element resolves).
%
% RESPONSESBYPRESENTATION (from indexGraph) already holds exactly the
% stimulus_response bodies that name this presentation, in body order, so the
% de-dup below yields the same subject_ids in the same order as the old scan.
presentationId = char(presentationId);
subs = {};
if ~isKey(responsesByPresentation, presentationId)
    return;
end
responses = responsesByPresentation(presentationId);
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(responses)
    b = responses{k};
    elementId = dependencyValue(b, 'element_id');
    if isempty(elementId)
        continue;
    end
    try
        sid = subjectOfElement(byId, elementId);
    catch
        continue;   % element does not resolve to a subject -> skip
    end
    if ~isempty(sid) && ~isKey(seen, sid)
        seen(sid) = true;
        subs{end+1} = sid; %#ok<AGROW>
    end
end
end

% ===================== epoch clock resolution ============================

function clock = epochClockOfElement(elementEpochByKey, clocktimesByEpoch, elementId, epochId)
elementId = char(elementId);
epochId   = char(epochId);

% 1) element_epoch document for this element + epoch -- the first one (in body
%    order) carrying a non-empty epoch_clock, exactly as the old scan chose.
key = [elementId '|' epochId];
if isKey(elementEpochByKey, key)
    matches = elementEpochByKey(key);
    for k = 1:numel(matches)
        c = subField(matches{k}, 'element_epoch', 'epoch_clock');
        if ~isempty(c)
            clock = c;
            return;
        end
    end
end

% 2) any epochclocktimes for this epoch; prefer the device-local clock.
fallback = '';
if isKey(clocktimesByEpoch, epochId)
    matches = clocktimesByEpoch(epochId);
    for k = 1:numel(matches)
        c = subField(matches{k}, 'epochclocktimes', 'clocktype');
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

function tf = isaStimulusResponse(body)
%ISASTIMULUSRESPONSE True for `stimulus_response` and for any document whose
%   OWN document_class declares it as a superclass.
%
%   Both spellings of a superclass entry are read, because both occur in the
%   body sets this resolver is handed:
%     v1     {definition: '$NDIDOCUMENTPATH/stimulus/stimulus_response.json'}
%     V_eta  {class_name: 'stimulus_response'}
%   The v1 form is matched on the FILE STEM rather than the whole path, so a
%   `$NDIDOCUMENTPATH` that expands differently, or a template that moves
%   folder, still matches. Only ONE hop is walked -- v1 templates declare the
%   full ancestor list on every class (stimulus_response_scalar names base AND
%   stimulus_response), so there is no chain to climb and climbing one would
%   need the template set, which a body set does not carry.
tf = false;
if strcmp(classNameOf(body), 'stimulus_response')
    tf = true;
    return;
end
if ~isstruct(body) || ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) ...
        || ~isfield(body.document_class, 'superclasses')
    return;
end
supers = body.document_class.superclasses;
if isstruct(supers)
    items = num2cell(supers(:)');
elseif iscell(supers)
    items = supers(:)';
else
    return;
end
for k = 1:numel(items)
    s = items{k};
    if ~isstruct(s) || ~isscalar(s)
        continue;
    end
    if isfield(s, 'class_name') && strcmp(char(s.class_name), 'stimulus_response')
        tf = true;
        return;
    end
    if isfield(s, 'definition')
        [~, stem] = fileparts(char(s.definition));
        if strcmp(stem, 'stimulus_response')
            tf = true;
            return;
        end
    end
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
