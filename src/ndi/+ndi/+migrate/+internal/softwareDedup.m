function [kept, report] = softwareDedup(structs)
%SOFTWAREDEDUP V_eta second pass: merge duplicate `software` ENTITIES and
%   retarget every edge that pointed at the ones that go away.
%
%   ON did-schema #88 (V_eta_entity_composition_plan.md sec. 4): software is
%   an `entity` of type `software`; its name is `entity.name`, its handle
%   `entity.local_identifier` (NAME@VERSION) and its version a TEXT ASSERTION
%   about it (variable `version number`, IAO:0000129 -- what DID-side
%   jSoftware writes). This pass reads both spellings: the pre-#88 `software`
%   class with its `software` block, and the #88 entity with its version
%   assertion. On #88 two more edge names are SOFTWARE REFERENCES rather than
%   pins -- a calculation's `interpreter_id` and `operating_system_id` (the run
%   environment became two software edges, #73 item 53) -- and a merged-away
%   entity's own version assertion is dropped with it (the survivor carries an
%   identical one: the version is part of the merge key), counted in
%   REPORT.version_assertions_dropped.
%
%   SIGNED MODEL (DID-schema `V_eta_tenet_audit.md`:10, TEAM-SIGN-OFF
%   [software] jess 2026-08-06): "the `app` mixin is replaced by a `software`
%   ENTITY (DEDUPLICATED BY NAME+VERSION) referenced from a statement by
%   `software_id`". Pass 1 cannot do the deduplicating half -- a single-document
%   migrator sees one source document and cannot know that another document in
%   another file already minted `ndi.calc.vis.oridir @ 1.2`. So pass 1 mints one
%   entity per consuming document and this pass merges them, exactly as
%   ndi.migrate.internal.pathSPromotion does a find-or-create keyed on
%   (animal, site) and RETARGETS the edges of what it merges.
%
%   STRUCTS is a cell of V_eta document body structs (from
%   did2.document.toStruct) -- the same contract pathSPromotion,
%   ensembleMembership and strainAssembly take. Returns KEPT (the surviving
%   bodies, with retargeted edges) and REPORT (denominator first;
%   REPORT.changed is false when nothing merged, so the caller can skip the
%   rebuild). NOTHING IS MINTED, so there is no `minted` output: every survivor
%   is a body that was already in STRUCTS.
%
%   ---------------------------------------------------------------------
%   THE MERGE KEY IS (scope, name, version) -- NOT local_identifier
%   ---------------------------------------------------------------------
%   `software.local_identifier` is a CONVENIENCE the DID-side helper writes
%   (private/jSoftware.m composes NAME or NAME@VERSION), and keying on it would
%   make this pass depend on every minter having written it. Three minters
%   existed and only one did until the 2026-08-10 consolidation. Keying on the
%   fields the sign-off actually names removes that dependency: an entity whose
%   local_identifier is missing, stale or hand-written still merges correctly,
%   and this pass REPAIRS the handle on the survivor rather than trusting it.
%
%   THE SCOPE IS THE DATASET WHEN A DATASET IS MIGRATED, THE SESSION
%   OTHERWISE. Decided by Jess Haley, 2026-10-21: "When a dataset is migrated,
%   shared entities (strains, software, people, organizations, instruments,
%   products) move to the dataset level as in native V2 imports (Haley
%   import_V2_decisions.md #20): one entity per distinct thing in the
%   dataset's database, with session documents pointing at it and merged-away
%   ids remapped so every link still resolves; a lone session with no dataset
%   keeps them in the session." ndi.migrate.internal.datasetScope decides:
%   with exactly one `dataset` entity in the batch the key's scope is that
%   dataset, and every software entity (with its version assertions) is then
%   stored at the dataset level -- its `session_id` names the dataset entity,
%   as the native import writes dataset-level documents
%   (REPORT.moved_to_dataset_level). Otherwise the scope is the entity's
%   session, as before. REPORT.cross_session_groups /
%   REPORT.cross_session_collapsible measure, in both modes, how many entities
%   a session-scoped key would leave beyond a dataset-scoped one;
%   REPORT.scope / REPORT.dataset_id say which this run used.
%
%   ---------------------------------------------------------------------
%   RETARGETING IS BY TARGET ID, NOT BY EDGE NAME
%   ---------------------------------------------------------------------
%   Seven V_eta edges declare must_refer_to_document_class == "software", and
%   ONE OF THEM IS NOT CALLED `software_id`:
%
%       clock_alignment_configuration.software_id
%       clock_alignment_policy.software_id
%       acquisition_metadata_reader.software_id
%       epoch_file_pattern.software_id
%       method_parameters.software_id
%       subject_interaction.software_id
%       acquisition_system.reader_id          <-- the odd one
%
%   `reader_id` exists because did_v1 `daqreader` DISSOLVES into a software
%   entity (migrators_j/daqreader.m). A name-based sweep would have silently
%   skipped it and left dangling references -- the same shape as the standing
%   CLAUDE.md lesson that a `depends_on` sweep is not a reference check. So this
%   pass walks EVERY edge of EVERY document and rewrites any whose target id is
%   a merged-away software id, whatever the edge is called. New edge names cost
%   nothing and cannot be missed.
%
%   ---------------------------------------------------------------------
%   AN ENTITY WITH A PRESERVED did_v1 ID IS NEVER MERGED AWAY
%   ---------------------------------------------------------------------
%   Most `software` bodies carry a freshly minted id, but daqreader.m PRESERVES
%   the v1 document's id onto the entity, deliberately ("base.id PRESERVED ...
%   here the id is the point of the fold"). Merging such an entity away would
%   destroy an id that v1 documents refer to -- and edges are not the only way
%   v1 refers to things (CLAUDE.md: "a `depends_on` sweep is not a reference
%   check ... grep for the NAME too"). This pass cannot see string references,
%   so it will not gamble on their absence.
%
%   The mechanical proxy for "this id is load-bearing beyond software_id" is
%   available in the body set: an entity is PINNED when some edge pointing at it
%   is named anything other than `software_id`. A pinned entity may be a
%   survivor but is never merged away. If two pinned entities share a key,
%   NEITHER is merged and the collision is reported
%   (REPORT.pinned_key_collisions) rather than resolved by guessing.
%
%   ---------------------------------------------------------------------
%   WHAT IS DELIBERATELY NOT DONE
%   ---------------------------------------------------------------------
%   - No cross-session merge for a lone session (no dataset entity in the
%     batch, or more than one); measured, see above.
%   - No fuzzy matching. 'ndi.calc.vis.oridir' and 'ndi.calc.vis.oridir '
%     are different software. Names come from class() and from the app block;
%     inventing an equivalence is the ground-truth fabrication this repo keeps
%     paying for. Only an EXACT match merges.
%   - An entity with an EMPTY software.name is never merged with anything, in
%     either direction, and is counted (REPORT.unnamed_seen). "Both nameless"
%     is not evidence of being the same program.
%   - `entity.global_identifier` is UNIONED onto the survivor rather than
%     dropped or overwritten: two mints of one program can carry different URLs
%     (a homepage from one app block, a repository from another) and both are
%     facts. Duplicate {scheme, value} pairs collapse; nothing is invented.
%
%   STATUS: authored without local MATLAB. The unit tests
%   (tests/+ndi/+unittest/+migrate/TestSoftwareDedup.m) have NOT been run.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.pathSPromotion,
%     ndi.migrate.internal.strainAssembly,
%     did2.convert.migrators_j.private.jSoftware.

arguments
    structs cell
end

kept = structs;

% ------------------------------------------------------------------ report
% Rule 5: the denominator first and UNCONDITIONALLY, before any early return,
% so "did not run" (the caller reports []) and "ran and found nothing" (a
% populated report whose counts are zero) can never be confused.
report = struct();
report.documents_inspected       = numel(structs);
report.edges_examined            = 0;
report.software_seen             = 0;
report.unnamed_seen              = 0;   % software.name empty -> never merged
report.software_pinned           = 0;   % inbound edge not named software_id
report.merge_groups              = 0;   % keys with >1 mergeable entity
report.software_merged_away      = 0;
report.software_surviving        = 0;
report.pinned_key_collisions     = 0;   % >1 pinned entity on one key -> untouched
report.edges_retargeted          = 0;
report.local_identifier_repaired = 0;
report.version_assertions_dropped = 0;  % #88: the merged-away entity's own
report.cross_session_groups      = 0;   % (name,version) keys spanning >1 session
report.cross_session_collapsible = 0;   % extra entities a dataset-scoped key removes
report.scope                     = 'session';
report.dataset_id                = '';
report.moved_to_dataset_level    = 0;   % entities + version assertions
report.changed                   = false;

n = numel(structs);
if n == 0
    return;
end

% ------------------------------------------------- index the software bodies
isSoftware = false(1, n);
idOf       = cell(1, n);
sessOf     = cell(1, n);
nameOf     = cell(1, n);
versOf     = cell(1, n);
% #88: the version is an assertion about the software; index those first
S = ndi.migrate.internal.etaShape;
versionAssertion = containers.Map('KeyType', 'char', 'ValueType', 'any');
isVersionAssertion = false(1, n);
for i = 1:n
    if ~S.isStatement(structs{i}, 'assertion', 'text')
        continue;
    end
    v = S.variable(structs{i});
    if ~(strcmp(v.node, 'IAO:0000129') || strcmpi(v.name, 'version number'))
        continue;
    end
    about = S.aboutId(structs{i});
    if isempty(about)
        continue;
    end
    isVersionAssertion(i) = true;
    if isKey(versionAssertion, about)
        versionAssertion(about) = [versionAssertion(about), i];
    else
        versionAssertion(about) = i;
    end
end
for i = 1:n
    idOf{i} = baseField(structs{i}, 'id', '');
    if strcmp(classNameOf(structs{i}), 'software')
        isSoftware(i)  = true;
        sessOf{i} = ndi.v2.sessionIdOf(structs{i});
        nameOf{i} = blockField(structs{i}, 'software', 'name', '');
        versOf{i} = blockField(structs{i}, 'software', 'version', '');
    elseif S.isEntity(structs{i}, {'software'})
        isSoftware(i)  = true;
        sessOf{i} = ndi.v2.sessionIdOf(structs{i});
        nameOf{i} = blockField(structs{i}, 'entity', 'name', '');
        versOf{i} = '';
        if isKey(versionAssertion, idOf{i})
            va = versionAssertion(idOf{i});
            versOf{i} = textValue(structs{va(1)});
        end
    end
end
report.software_seen = sum(isSoftware);

softwareIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = find(isSoftware)
    if ~isempty(idOf{i}) && ~isKey(softwareIdx, idOf{i})
        softwareIdx(idOf{i}) = i;
    end
end

% ------------------------------------------------------- pin what is pointed
% at by anything other than a `software_id` edge. This walk is also the
% edges_examined denominator, so it runs over EVERY document, not just the
% ones that happen to carry a software edge -- AND IT RUNS BEFORE THE
% no-software EARLY RETURN. A body set with no `software` in it still has
% edges, and reporting `edges_examined = 0` for it would be the silentLoss
% defect in miniature: a denominator that reads as "nothing to look at" when
% what happened is "looked at everything, matched nothing".
pinned = false(1, n);
referenceEdges = {'software_id', 'interpreter_id', 'operating_system_id'};
for j = 1:n
    deps = depsOf(structs{j});
    for k = 1:numel(deps)
        report.edges_examined = report.edges_examined + 1;
        tgt = depTarget(deps(k));
        if isempty(tgt) || ~isKey(softwareIdx, tgt)
            continue;
        end
        if isVersionAssertion(j) && strcmp(depName(deps(k)), 'entity_id')
            continue;   % the entity's own version, not a pin
        end
        if strcmp(depName(deps(k)), 'session_id')
            continue;   % #88: a record's session edge is not a reference to it
        end
        if ~any(strcmp(depName(deps(k)), referenceEdges))
            pinned(softwareIdx(tgt)) = true;
        end
    end
end
report.software_pinned = sum(pinned);

if report.software_seen == 0
    return;     % denominators are populated; there is simply nothing to merge
end

% --------------------------------------------------------------- group them
% Key = scope | name | version, the scope being the dataset when one is
% migrated and the session otherwise (Jess Haley, 2026-10-21; see header). An
% entity with no name is excluded from grouping entirely but still counted.
scope = ndi.migrate.internal.datasetScope(structs);
if scope.is_dataset
    report.scope      = 'dataset';
    report.dataset_id = scope.dataset_id;
end
groups = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = find(isSoftware)
    if isempty(nameOf{i})
        report.unnamed_seen = report.unnamed_seen + 1;
        continue;
    end
    if scope.is_dataset
        key = [scope.dataset_id '|' nameOf{i} '|' versOf{i}];
    else
        key = [sessOf{i} '|' nameOf{i} '|' versOf{i}];
    end
    if isKey(groups, key)
        groups(key) = [groups(key), i];
    else
        groups(key) = i;
    end
end

% ------------------------------------- measure the cross-session collapse
report = measureCrossSession(report, isSoftware, sessOf, nameOf, versOf);

% ------------------------------------------------------------------ merge
% survivorOf maps a merged-away software id -> the surviving software id.
survivorOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
removeMask = false(1, n);
keys_ = groups.keys();
for g = 1:numel(keys_)
    members = groups(keys_{g});
    if numel(members) < 2
        continue;
    end
    pinnedMembers = members(pinned(members));
    if numel(pinnedMembers) > 1
        % Two ids that other documents depend on by a non-software_id edge and
        % that describe the same program. Merging would destroy one of them;
        % which to keep is not decidable here. Report and leave alone.
        report.pinned_key_collisions = report.pinned_key_collisions + 1;
        continue;
    end
    report.merge_groups = report.merge_groups + 1;
    if numel(pinnedMembers) == 1
        survivor = pinnedMembers(1);
    else
        % Deterministic and order-independent: the smallest id. Migration
        % output must not depend on the order documents came out of a database.
        ids = idOf(members);
        [~, ord] = sort(ids);
        survivor = members(ord(1));
    end
    for m = members
        if m == survivor
            continue;
        end
        if ~isempty(idOf{m})
            survivorOf(idOf{m}) = idOf{survivor};
        end
        structs{survivor} = unionGlobalIdentifiers(structs{survivor}, structs{m});
        removeMask(m) = true;
        report.software_merged_away = report.software_merged_away + 1;
        if isKey(versionAssertion, idOf{m})
            va = versionAssertion(idOf{m});
            removeMask(va) = true;
            report.version_assertions_dropped = ...
                report.version_assertions_dropped + numel(va);
        end
    end
    % Repair the dedup handle on the survivor from the fields that ARE the key.
    [structs{survivor}, fixed] = repairLocalIdentifier(structs{survivor}, ...
        nameOf{survivor}, versOf{survivor});
    report.local_identifier_repaired = report.local_identifier_repaired + fixed;
end

report.software_surviving = report.software_seen - report.software_merged_away;

% ------------------------------------------- the dataset level, when there is one
% Every surviving software entity and its version assertions are stored with
% the dataset (their `session_id` names the dataset entity).
if scope.is_dataset
    for i = find(isSoftware | isVersionAssertion)
        if removeMask(i)
            continue;
        end
        if isVersionAssertion(i) && ~isKey(softwareIdx, S.aboutId(structs{i}))
            continue;   % a version of something that is not a software entity here
        end
        if ~strcmp(ndi.v2.sessionIdOf(structs{i}), scope.dataset_id)
            structs{i} = ndi.migrate.internal.withSessionId(structs{i}, scope.dataset_id);
            report.moved_to_dataset_level = report.moved_to_dataset_level + 1;
        end
    end
end

if report.software_merged_away == 0
    kept = structs;   % global_identifier unions/handle repairs cannot have run
    report.changed = report.moved_to_dataset_level > 0;
    return;
end

% ------------------------------------------------------------- retarget
% By TARGET ID, over every edge of every document (see header).
for j = 1:n
    if removeMask(j)
        continue;
    end
    [structs{j}, nFixed] = retargetDeps(structs{j}, survivorOf);
    report.edges_retargeted = report.edges_retargeted + nFixed;
end

kept = structs(~removeMask);
report.changed = true;
end

% ===================== cross-session measurement ==========================

function report = measureCrossSession(report, isSoftware, sessOf, nameOf, versOf)
%MEASURECROSSSESSION How many entities a session-scoped key leaves beyond a
%   dataset-scoped one. Measured in both modes; the merge itself happens only
%   when the scope is a dataset (Jess Haley, 2026-10-21; see the header).
bySoftware = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = find(isSoftware)
    if isempty(nameOf{i})
        continue;
    end
    key = [nameOf{i} '|' versOf{i}];
    if isKey(bySoftware, key)
        bySoftware(key) = [bySoftware(key), {sessOf{i}}];
    else
        bySoftware(key) = {sessOf{i}};
    end
end
keys_ = bySoftware.keys();
for g = 1:numel(keys_)
    sessions = bySoftware(keys_{g});
    distinct = unique(sessions);
    if numel(distinct) > 1
        report.cross_session_groups = report.cross_session_groups + 1;
        % A dataset-scoped key leaves ONE entity per (name, version); a
        % session-scoped key leaves one per distinct session. The difference is
        % what dropping session from the key would additionally remove.
        report.cross_session_collapsible = ...
            report.cross_session_collapsible + numel(distinct) - 1;
    end
end
end

% ===================== body edits =========================================

function s = unionGlobalIdentifiers(s, other)
%UNIONGLOBALIDENTIFIERS The survivor keeps every identifier either carried.
%   #88 writes a list of CURIE / IRI strings; before #88, an array of
%   {scheme, value}. Union in whichever shape the survivor has.
add = gidsOf(other);
if isempty(add)
    return;
end
have = gidsOf(s);
if iscell(have) || (isempty(have) && iscell(add))
    out = reshape(have, 1, []);
    if ~iscell(out); out = {}; end
    addc = add;
    if ~iscell(addc)
        addc = arrayfun(@(e) gidKey(e), addc, 'UniformOutput', false);
    end
    for k = 1:numel(addc)
        if ~any(strcmp(out, addc{k}))
            out{end+1} = addc{k}; %#ok<AGROW>
        end
    end
    if ~isfield(s, 'entity') || ~isstruct(s.entity)
        s.entity = struct();
    end
    s.entity.global_identifier = out;
    return;
end
if iscell(add)
    return;     % a mixed pair: leave the survivor as it is
end
seen = {};
for k = 1:numel(have)
    seen{end+1} = gidKey(have(k)); %#ok<AGROW>
end
out = have;
for k = 1:numel(add)
    key = gidKey(add(k));
    if any(strcmp(seen, key))
        continue;
    end
    seen{end+1} = key; %#ok<AGROW>
    if isempty(out)
        out = add(k);
    else
        out(end+1) = add(k); %#ok<AGROW>
    end
end
if ~isfield(s, 'entity') || ~isstruct(s.entity)
    s.entity = struct();
end
s.entity.global_identifier = out;
end

function g = gidsOf(s)
g = struct('scheme', {}, 'value', {});
if isfield(s, 'entity') && isstruct(s.entity) && isscalar(s.entity) ...
        && isfield(s.entity, 'global_identifier')
    x = s.entity.global_identifier;
    if isstruct(x) || iscell(x)
        g = x;
    elseif ischar(x) && ~isempty(x)
        g = {x};
    end
end
end

function k = gidKey(entry)
scheme = ''; value = '';
if isfield(entry, 'scheme'); scheme = char(entry.scheme); end
if isfield(entry, 'value');  value  = char(entry.value);  end
k = [scheme '|' value];
end

function [s, fixed] = repairLocalIdentifier(s, name, version)
%REPAIRLOCALIDENTIFIER Recompose the dedup handle from the merge key.
%   Same composition private/jSoftware.m uses: NAME, or NAME@VERSION when a
%   version is known. FIXED is 1 only when the stored value actually changed, so
%   the count means "handles that were wrong or missing", not "survivors".
fixed = 0;
if isempty(name)
    return;
end
want = name;
if ~isempty(version)
    want = [name '@' version];
end
% the handle lives on the `software` block before #88, `entity` on #88
blk = 'software';
if ~isfield(s, 'software') && isfield(s, 'entity')
    blk = 'entity';
end
have = '';
if isfield(s, blk) && isstruct(s.(blk)) && isscalar(s.(blk)) ...
        && isfield(s.(blk), 'local_identifier')
    have = char(s.(blk).local_identifier);
end
if strcmp(have, want)
    return;
end
if ~isfield(s, blk) || ~isstruct(s.(blk))
    s.(blk) = struct();
end
s.(blk).local_identifier = want;
fixed = 1;
end

function [s, nFixed] = retargetDeps(s, survivorOf)
%RETARGETDEPS Point every edge at the survivor of whatever it referenced.
%   Writes back through the SAME key it read (`value` or `document_id`), because
%   both spellings are live on this path -- a body a migrator built carries
%   `value`, a body that came through did2.convert.universalRenames carries
%   `document_id` -- and rewriting one while the validator reads the other would
%   leave the edge silently unchanged.
nFixed = 0;
if ~isfield(s, 'depends_on') || ~isstruct(s.depends_on) || isempty(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    moved = false;
    for key = {'value', 'document_id'}
        f = key{1};
        if ~isfield(d, f) || isempty(d.(f))
            continue;
        end
        tgt = char(d.(f));
        if isKey(survivorOf, tgt)
            s.depends_on(k).(f) = survivorOf(tgt);
            moved = true;   % both keys are rewritten when both are populated,
        end                 % but the COUNT is per edge, not per spelling --
    end                     % edges_retargeted has to be comparable with
    if moved                % edges_examined, which counts edges.
        nFixed = nFixed + 1;
    end
end
end

% ===================== struct accessors ===================================

function t = textValue(s)
%TEXTVALUE The first text of a text assertion's value, '' when none.
t = '';
if isfield(s, 'text') && isstruct(s.text) && isfield(s.text, 'value') ...
        && isstruct(s.text.value) && ~isempty(s.text.value) ...
        && isfield(s.text.value, 'text')
    x = s.text.value(1).text;
    if iscell(x) && ~isempty(x); x = x{1}; end
    if ischar(x) || (isstring(x) && isscalar(x)); t = char(x); end
end
end

function c = classNameOf(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isscalar(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isfield(s, 'base') && isstruct(s.base) && isscalar(s.base) ...
        && isfield(s.base, name) && ~isempty(s.base.(name))
    v = char(s.base.(name));
end
end

function v = blockField(s, block, name, default)
v = default;
if isfield(s, block) && isstruct(s.(block)) && isscalar(s.(block)) ...
        && isfield(s.(block), name) && ~isempty(s.(block).(name))
    v = char(s.(block).(name));
end
end

function d = depsOf(s)
d = struct('name', {}, 'value', {});
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    d = s.depends_on;
end
end

function nm = depName(entry)
nm = '';
if isfield(entry, 'name') && ~isempty(entry.name)
    nm = char(entry.name);
end
end

function v = depTarget(entry)
%DEPTARGET The referenced id, accepting both live spellings.
%   Precedence copied from +did2/+validate/references.m:176-179.
v = '';
for key = {'document_id', 'value', 'id'}
    f = key{1};
    if isfield(entry, f) && ~isempty(entry.(f))
        v = char(entry.(f));
        return;
    end
end
end
