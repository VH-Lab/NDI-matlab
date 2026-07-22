function [kept, minted, changed] = pathSPromotion(structs)
%PATHSPROMOTION V_eta second pass: promote attributed anatomical loci to Path-S
%   part-subjects, using the whole migrated body set (the corpus-wide subject
%   graph) that a single-document migrator cannot see.
%
%   The did_v1 -> V_eta pass-1 migrators (did2.convert.migrators_j) emit an
%   anatomical site as a LOCATED-BY-DEFAULT `term_observation` (D3): a bare value
%   on the animal (`subject_statement.variable.name == 'anatomical location'`),
%   minting no subject. Most sites should stay that way. But a site that is the
%   TARGET of an intervention (an optogenetic/injection/drug `treatment`) is an
%   ATTRIBUTED part and deserves promotion to Path S:
%
%       located site term_observation  ->  a part-`subject`
%                                        +  a `term_assertion` of its anatomical
%                                           kind (the site ontology term)
%                                        +  a `part_of` `directed_relation`
%                                           (the part -> the animal)
%       and every co-anchored manipulation on that animal is RETARGETED to the
%       part-subject (the intervention is on the part, not the whole animal).
%
%   "Attributed" is decided by the corpus graph, conservatively: a site is
%   promoted only when its source document also produced a manipulation (they
%   share the migrated anchor id). A probe_location / ontology_label site (no
%   co-anchored manipulation) is left located-by-default. This is the D3 mint
%   allowlist realised as a graph predicate; discovery measured only 49 such loci
%   (all Dab optogenetic, all distinct subjects), so a find-or-create/dedup keyed
%   on (animal, site) is sufficient -- no heavier service is warranted.
%
%   STRUCTS is a cell of V_eta document body structs (from did2.document.toStruct).
%   Returns KEPT (the surviving bodies, with retargeted subject_id edges and the
%   promoted site observations removed), MINTED (the new part-subject /
%   term_assertion / directed_relation bodies, tagged schema_version 'V_eta' so
%   they can be folded back through v1_to_v2), and CHANGED (false if nothing was
%   promoted, so the caller can skip the rebuild).
%
%   See also: ndi.migrate.local, did2.convert.migrators_j.treatment,
%   did-schema V_eta_migration_plan.md (C.1, D3, D6 -- Path S).

changed = false;
minted = {};
kept = structs;
n = numel(structs);
if n == 0
    return;
end

removeMask = false(1, n);
partOfAnimalSite = containers.Map('KeyType', 'char', 'ValueType', 'char');
partBodies = {};

for i = 1:n
    s = structs{i};
    if ~isSiteObservation(s)
        continue;
    end
    animal = depVal(s, 'subject_id');
    anchor = depVal(s, 'time_reference_1');
    if isempty(anchor) || isempty(animal)
        continue;
    end
    if ~groupHasManipulation(structs, anchor, animal)
        continue;   % merely-located: leave as a value (probe/label/etc.)
    end
    siteTerm = siteValue(s);

    key = [animal '|' termKey(siteTerm)];
    if isKey(partOfAnimalSite, key)
        partId = partOfAnimalSite(key);
    else
        newPart = mintPart(animal, siteTerm, s);
        partId = newPart.subject.base.id;
        partOfAnimalSite(key) = partId;
        partBodies = [partBodies, {newPart.subject, newPart.assertion, newPart.relation}]; %#ok<AGROW>
        changed = true;
    end

    % retarget every co-anchored manipulation on this animal to the part
    for j = 1:n
        if removeMask(j); continue; end
        t = structs{j};
        if isManipulation(t) ...
                && strcmp(depVal(t, 'time_reference_1'), anchor) ...
                && strcmp(depVal(t, 'subject_id'), animal)
            structs{j} = setDep(t, 'subject_id', partId);
            changed = true;
        end
    end
    removeMask(i) = true;   % the located value is superseded by the part-subject
end

if ~changed
    kept = structs;   % unchanged (may include no-op setDep rewrites; none here)
    return;
end
kept = structs(~removeMask);
minted = partBodies;
end

% ===================== predicates ======================================

function tf = isSiteObservation(s)
tf = strcmp(classNameOf(s), 'term_observation') ...
    && strcmp(variableName(s), 'anatomical location');
end

function tf = isManipulation(s)
c = classNameOf(s);
tf = ~isempty(c) && (numel(c) >= 13) && strcmp(c(end-12:end), '_manipulation');
end

function tf = groupHasManipulation(structs, anchor, animal)
tf = false;
for j = 1:numel(structs)
    t = structs{j};
    if isManipulation(t) ...
            && strcmp(depVal(t, 'time_reference_1'), anchor) ...
            && strcmp(depVal(t, 'subject_id'), animal)
        tf = true;
        return;
    end
end
end

% ===================== builders ========================================

function parts = mintPart(animalId, siteTerm, siteObs)
%MINTPART Build the part-subject, its anatomical-kind term_assertion, and the
%   part_of relation for an attributed locus. Bare J subject (identity only);
%   the anatomical term is the kind (a term_assertion, D9), not a field.
sessionId = baseField(siteObs, 'session_id', '');
ds = baseField(siteObs, 'datestamp', '2024-01-01T00:00:00.000Z');
partName = safeName(siteTerm);
partId = did.ido.unique_id();

subj = struct();
subj.document_class = classBlock('subject', {'base'});
subj.depends_on = struct('name', {}, 'value', {});
subj.base = struct('id', partId, 'session_id', sessionId, ...
    'name', ['migrated_part_' partName], 'datestamp', ds);
% local_identifier is REQUIRED on a V_eta subject. Compose animal+part; trim any
% degenerate leading/trailing underscores (an empty animalId would leave one), and
% fall back to the document id if somehow empty -- the same guarantee the DID-side
% jEnsureLocalId gives.
lid = regexprep([shortId(animalId) '_' partName], '^_+|_+$', '');
if isempty(lid); lid = partId; end
subj.subject = struct('local_identifier', lid);

assertion = struct();
assertion.document_class = classBlock('term_assertion', {'subject_assertion'});
assertion.depends_on = struct('name', {'subject_id'}, 'value', {partId});
assertion.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_part_kind', 'datestamp', ds);
assertion.subject_statement = struct('variable', ...
    struct('node', '', 'name', 'anatomical structure'), 'storage_mode', 'inline');
assertion.subject_assertion = struct();
assertion.term_assertion = struct('value', siteTerm);

relation = struct();
% subject_relation was renamed to `relation` (abstract) in V_eta. Use the current
% superclass and emit NO subject_relation block -- a stale block is an undeclared
% top-level block that quarantines (the JH 163k-orphan regression). ensureClassBlocks
% (via the v1_to_v2 re-fold) rebuilds the chain and any needed empty blocks.
relation.document_class = classBlock('directed_relation', {'relation'});
relation.depends_on = [ ...
    struct('name', 'child',  'value', partId), ...     % the part
    struct('name', 'parent', 'value', animalId)];      % the whole animal
relation.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_part_of', 'datestamp', ds);
relation.directed_relation = struct('relation', ...
    struct('node', 'BFO:0000050', 'name', 'part_of'));

parts = struct('subject', subj, 'assertion', assertion, 'relation', relation);
end

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

% ===================== struct accessors ================================

function c = classNameOf(s)
c = '';
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function nm = variableName(s)
nm = '';
if isfield(s, 'subject_statement') && isstruct(s.subject_statement) ...
        && isfield(s.subject_statement, 'variable') ...
        && isstruct(s.subject_statement.variable) ...
        && isfield(s.subject_statement.variable, 'name')
    nm = char(s.subject_statement.variable.name);
end
end

function t = siteValue(s)
t = struct('node', '', 'name', '');
if isfield(s, 'term_observation') && isstruct(s.term_observation) ...
        && isfield(s.term_observation, 'value') && isstruct(s.term_observation.value)
    t = s.term_observation.value;
end
end

function v = depVal(s, name)
v = '';
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        d = s.depends_on(k);
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
end

function s = setDep(s, name, value)
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        if isfield(s.depends_on(k), 'name') && strcmp(s.depends_on(k).name, name)
            s.depends_on(k).value = value;
            return;
        end
    end
    s.depends_on(end+1) = struct('name', name, 'value', value);
else
    s.depends_on = struct('name', name, 'value', value);
end
end

function v = baseField(s, name, default)
v = default;
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) ...
        && ~isempty(s.base.(name))
    v = s.base.(name);
end
end

function k = termKey(t)
node = ''; name = '';
if isfield(t, 'node'); node = char(t.node); end
if isfield(t, 'name'); name = char(t.name); end
k = [node '|' name];
end

function nm = safeName(t)
raw = '';
if isfield(t, 'name') && ~isempty(t.name); raw = char(t.name);
elseif isfield(t, 'node'); raw = char(t.node); end
if isempty(raw); raw = 'part'; end
nm = lower(regexprep(raw, '[^A-Za-z0-9]+', '_'));
nm = regexprep(nm, '^_+|_+$', '');
if isempty(nm); nm = 'part'; end
end

function s = shortId(idStr)
s = char(idStr);
if numel(s) > 8; s = s(1:8); end
end
