function [kept, minted, changed] = pathSPromotion(structs)
%PATHSPROMOTION V_eta second pass: promote attributed anatomical loci to Path-S
%   part-subjects, using the whole migrated body set (the corpus-wide subject
%   graph) that a single-document migrator cannot see.
%
%   The did_v1 -> V_eta pass-1 migrators (did2.convert.migrators_j) emit an
%   anatomical site as a LOCATED-BY-DEFAULT term observation (D3): a bare value
%   on the animal (`statement.variable.name == 'anatomical location'`), minting
%   no entity. Most sites should stay that way. But a site that is the TARGET of
%   an intervention (an optogenetic/injection/drug `treatment`) is an
%   ATTRIBUTED part and deserves promotion to Path S:
%
%       located site term observation  ->  a part ENTITY (did-schema #88:
%                                           `entity`, type `tissue`, "part of
%                                           an organism")
%                                        +  a term ASSERTION of its anatomical
%                                           kind (the site ontology term)
%                                        +  a `part_of` `directed_relation`
%                                           (child_id the part -> parent_id
%                                           the animal)
%       and every co-anchored manipulation on that animal is RETARGETED to the
%       part (its `entity_id`: the intervention is on the part, not the whole
%       animal).
%
%   THE SHAPE IS did-schema #88's (V_eta_entity_composition_plan.md secs. 1
%   and 4): statements are a direction plus a value-kind mixin and point at
%   what they are about by `entity_id`; one `entity` class with a bound `type`.
%   The reads accept the pre-#88 spelling too (ndi.migrate.internal.etaShape).
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
%   Returns KEPT (the surviving bodies, with retargeted manipulations and the
%   promoted site observations removed), MINTED (the new part entity / term
%   assertion / directed_relation bodies, tagged schema_version 'V_eta' so they
%   can be folded back through v1_to_v2), and CHANGED (false if nothing was
%   promoted, so the caller can skip the rebuild).
%
%   See also: ndi.migrate.local, did2.convert.migrators_j.treatment,
%   ndi.migrate.internal.etaShape,
%   did-schema V_eta_migration_plan.md (C.1, D3, D6 -- Path S).

changed = false;
minted = {};
kept = structs;
n = numel(structs);
if n == 0
    return;
end
S = ndi.migrate.internal.etaShape;

removeMask = false(1, n);
partOfAnimalSite = containers.Map('KeyType', 'char', 'ValueType', 'char');
partBodies = {};

for i = 1:n
    s = structs{i};
    if ~isSiteObservation(s)
        continue;
    end
    animal = S.aboutId(s);
    anchor = firstAnchor(s);
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
        partId = newPart.entity.base.id;
        partOfAnimalSite(key) = partId;
        partBodies = [partBodies, {newPart.entity, newPart.assertion, newPart.relation}]; %#ok<AGROW>
        changed = true;
    end

    % retarget every co-anchored manipulation on this animal to the part
    for j = 1:n
        if removeMask(j); continue; end
        t = structs{j};
        if isManipulation(t) ...
                && strcmp(firstAnchor(t), anchor) ...
                && strcmp(S.aboutId(t), animal)
            structs{j} = S.setAbout(t, partId);
            changed = true;
        end
    end
    removeMask(i) = true;   % the located value is superseded by the part
end

if ~changed
    kept = structs;
    return;
end
kept = structs(~removeMask);
minted = partBodies;
end

% ===================== predicates ======================================

function tf = isSiteObservation(s)
S = ndi.migrate.internal.etaShape;
v = S.variable(s);
tf = S.isStatement(s, 'observation', 'term') ...
    && strcmp(v.name, 'anatomical location');
end

function tf = isManipulation(s)
tf = strcmp(ndi.migrate.internal.etaShape.direction(s), 'manipulation');
end

function a = firstAnchor(s)
ids = ndi.migrate.internal.etaShape.timeReferenceIds(s);
a = '';
if ~isempty(ids)
    a = ids{1};
end
end

function tf = groupHasManipulation(structs, anchor, animal)
tf = false;
for j = 1:numel(structs)
    t = structs{j};
    if isManipulation(t) ...
            && strcmp(firstAnchor(t), anchor) ...
            && strcmp(ndi.migrate.internal.etaShape.aboutId(t), animal)
        tf = true;
        return;
    end
end
end

% ===================== builders ========================================

function parts = mintPart(animalId, siteTerm, siteObs)
%MINTPART Build the part entity, its anatomical-kind term assertion, and the
%   part_of relation for an attributed locus. The part is an `entity` of type
%   `tissue` ("part of an organism: a slice, a biopsy, a region",
%   binding_registry_meta.json entity_type_bindings), identity only; the
%   anatomical term is its kind (an assertion, D9), not a field.
S = ndi.migrate.internal.etaShape;
sessionId = ndi.v2.sessionIdOf(siteObs);
ds = baseField(siteObs, 'creation_timestamp', '');
if isempty(ds)
    ds = baseField(siteObs, 'datestamp', '');
end
common = {'SessionId', sessionId, 'Datestamp', ds};
partName = safeName(siteTerm);
partId = did.ido.unique_id();

% local_identifier is REQUIRED on a tissue entity. Compose animal+part; trim any
% degenerate leading/trailing underscores (an empty animalId would leave one), and
% fall back to the document id if somehow empty -- the same guarantee the DID-side
% jEnsureLocalId gives.
lid = regexprep([shortId(animalId) '_' partName], '^_+|_+$', '');
if isempty(lid); lid = partId; end
ent = S.entity('tissue', struct('local_identifier', lid), 'Id', partId, common{:});

assertion = S.statement('assertion', 'term', partId, ...
    S.term('', 'anatomical structure'), siteTerm, common{:});

relation = S.relation(partId, animalId, S.term('BFO:0000050', 'part_of'), common{:});

parts = struct('entity', ent, 'assertion', assertion, 'relation', relation);
end

% ===================== struct accessors ================================

function t = siteValue(s)
t = struct('node', '', 'name', '');
% a term observation's value lives on the `term` value-kind block. Accept the
% pre-composite shape too, so a body migrated before that change still
% resolves.
if isfield(s, 'term') && isstruct(s.term) ...
        && isfield(s.term, 'value') && isstruct(s.term.value)
    t = ndi.migrate.internal.etaShape.asTerm(s.term.value(1));
elseif isfield(s, 'term_observation') && isstruct(s.term_observation) ...
        && isfield(s.term_observation, 'value') && isstruct(s.term_observation.value)
    t = ndi.migrate.internal.etaShape.asTerm(s.term_observation.value(1));
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
