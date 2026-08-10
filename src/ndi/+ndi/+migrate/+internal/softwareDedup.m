function [kept, report] = softwareDedup(structs)
%SOFTWAREDEDUP V_eta second pass: merge duplicate `software` ENTITIES and
%   retarget every edge that pointed at the ones that go away.
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
%   THE MERGE KEY IS (session_id, name, version) -- NOT local_identifier
%   ---------------------------------------------------------------------
%   `software.local_identifier` is a CONVENIENCE the DID-side helper writes
%   (private/jSoftware.m composes NAME or NAME@VERSION), and keying on it would
%   make this pass depend on every minter having written it. Three minters
%   existed and only one did until the 2026-08-10 consolidation. Keying on the
%   fields the sign-off actually names removes that dependency: an entity whose
%   local_identifier is missing, stale or hand-written still merges correctly,
%   and this pass REPAIRS the handle on the survivor rather than trusting it.
%
%   SESSION IS PART OF THE KEY, and that is a deliberate narrowing, not an
%   oversight. `base.session_id` is "mustBeNonEmpty": true (did-schema
%   schemas/V_eta/stable/base.json), so a survivor carries exactly one session,
%   and merging across sessions would leave documents in session B pointing at
%   an entity stamped session A. Whether that is acceptable is a MODELLING
%   QUESTION (is `software` a per-session entity or a dataset-level one?), and
%   this pass does not answer it -- it MEASURES it: REPORT.cross_session_groups
%   and REPORT.cross_session_collapsible say exactly how many further entities a
%   dataset-scoped key would remove. Same shape as epochMint, whose key is also
%   the PAIR and for the same reason.
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
%   - No cross-session merge (measured, see above).
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
report.cross_session_groups      = 0;   % (name,version) keys spanning >1 session
report.cross_session_collapsible = 0;   % extra entities a dataset-scoped key removes
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
for i = 1:n
    idOf{i} = baseField(structs{i}, 'id', '');
    if ~strcmp(classNameOf(structs{i}), 'software')
        continue;
    end
    isSoftware(i)  = true;
    sessOf{i} = baseField(structs{i}, 'session_id', '');
    nameOf{i} = blockField(structs{i}, 'software', 'name', '');
    versOf{i} = blockField(structs{i}, 'software', 'version', '');
end
report.software_seen = sum(isSoftware);
if report.software_seen == 0
    return;
end

softwareIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
for i = find(isSoftware)
    if ~isempty(idOf{i}) && ~isKey(softwareIdx, idOf{i})
        softwareIdx(idOf{i}) = i;
    end
end

% ------------------------------------------------------- pin what is pointed
% at by anything other than a `software_id` edge. This walk is also the
% edges_examined denominator, so it runs over EVERY document, not just the
% ones that happen to carry a software edge.
pinned = false(1, n);
for j = 1:n
    deps = depsOf(structs{j});
    for k = 1:numel(deps)
        report.edges_examined = report.edges_examined + 1;
        tgt = depTarget(deps(k));
        if isempty(tgt) || ~isKey(softwareIdx, tgt)
            continue;
        end
        if ~strcmp(depName(deps(k)), 'software_id')
            pinned(softwareIdx(tgt)) = true;
        end
    end
end
report.software_pinned = sum(pinned);

% --------------------------------------------------------------- group them
% Key = session_id | name | version. An entity with no name is excluded from
% grouping entirely (see header) but still counted.
groups = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = find(isSoftware)
    if isempty(nameOf{i})
        report.unnamed_seen = report.unnamed_seen + 1;
        continue;
    end
    key = [sessOf{i} '|' nameOf{i} '|' versOf{i}];
    if isKey(groups, key)
        groups(key) = [groups(key), i];
    else
        groups(key) = i;
    end
end

% --------------------------- measure (do NOT perform) the cross-session merge
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
    end
    % Repair the dedup handle on the survivor from the fields that ARE the key.
    [structs{survivor}, fixed] = repairLocalIdentifier(structs{survivor}, ...
        nameOf{survivor}, versOf{survivor});
    report.local_identifier_repaired = report.local_identifier_repaired + fixed;
end

report.software_surviving = report.software_seen - report.software_merged_away;

if report.software_merged_away == 0
    kept = structs;   % global_identifier unions/handle repairs cannot have run
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
%MEASURECROSSSESSION How much MORE a dataset-scoped key would collapse.
%   Recorded, never acted on: dropping session from the key is a modelling
%   decision about what a `software` entity is, and rule 4 says the team makes
%   it. Reporting the number is what turns "should we?" into a question with an
%   answer attached.
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
%UNIONGLOBALIDENTIFIERS Add OTHER's entity.global_identifier entries to S.
%   Two mints of one program can carry different URLs; both are facts about the
%   same software, so the survivor gets both. Duplicate {scheme, value} pairs
%   collapse. Nothing is invented and nothing is overwritten.
add = gidsOf(other);
if isempty(add)
    return;
end
have = gidsOf(s);
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
        && isfield(s.entity, 'global_identifier') ...
        && isstruct(s.entity.global_identifier)
    g = s.entity.global_identifier;
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
have = '';
if isfield(s, 'software') && isstruct(s.software) && isscalar(s.software) ...
        && isfield(s.software, 'local_identifier')
    have = char(s.software.local_identifier);
end
if strcmp(have, want)
    return;
end
if ~isfield(s, 'software') || ~isstruct(s.software)
    s.software = struct();
end
s.software.local_identifier = want;
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
    for key = {'value', 'document_id'}
        f = key{1};
        if ~isfield(d, f) || isempty(d.(f))
            continue;
        end
        tgt = char(d.(f));
        if isKey(survivorOf, tgt)
            s.depends_on(k).(f) = survivorOf(tgt);
            nFixed = nFixed + 1;
        end
    end
end
end

% ===================== struct accessors ===================================

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
