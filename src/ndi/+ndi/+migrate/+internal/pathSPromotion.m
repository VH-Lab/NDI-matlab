function [kept, minted, changed, report] = pathSPromotion(structs, options)
%PATHSPROMOTION V_eta second pass: a statement about an anatomical region of a
%   subject targets that region's PART ENTITY, using the whole migrated body
%   set (the corpus-wide subject graph) that a single-document migrator cannot
%   see.
%
%   [KEPT, MINTED, CHANGED, REPORT] = PATHSPROMOTION(STRUCTS)
%   [...] = PATHSPROMOTION(STRUCTS, 'Mode', MODE)
%
%   ---------------------------------------------------------------------
%   DECIDED BY JESS HALEY, 2026-10-21 (did-schema
%   V_eta_go_forward_class_audit.md; it replaces D3's located-by-default):
%     "Any statement about an anatomical region of a subject -- manipulation
%      or observation -- targets that region's part entity (one per subject
%      and region, shared, type tissue, `part_of` the subject). A statement
%      about the whole subject (a whole-prep or whole-slice bath, i.e. the
%      generic 'bath' location NCIm:C0179246) targets the subject."
%   ---------------------------------------------------------------------
%
%   A part is an `entity` of type `tissue` + a term ASSERTION of its
%   anatomical kind (variable `anatomical structure`, value the region term)
%   + a `part_of` `directed_relation` (child_id the part -> parent_id the
%   subject). There is ONE per (subject, region): every pass and every mode
%   finds an existing part before minting one, so an injection into a region
%   and a recording from it share a single part entity. The region key is the
%   term's node, case-folded (the name when there is no node), so
%   `UBERON:0001880` written by a probe_location and `uberon:0001880` written
%   by a treatment are one region.
%
%   MODE (default 'all') selects which statements are moved. ndi.migrate.local
%   runs 'sites' early (before sliceTetanus, which reads the parts it makes)
%   and 'located' late (after resolveEpochProbemap has made the recording
%   observations and sliceTetanus has moved slice statements onto slices):
%
%     'sites'    A pass-1 site term observation (variable `anatomical
%                location`) about a subject and CO-ANCHORED with a manipulation
%                on that subject (they share the migrated anchor id: one source
%                document produced both -- treatment, treatment_drug,
%                virus_injection, and a bath at an anatomical location) is
%                promoted to the part, the co-anchored manipulations are
%                retargeted onto it, and the site observation is removed (the
%                part's kind assertion now says it). A generic-bath location is
%                never emitted as a site (the migrators drop it), so a
%                whole-prep or whole-slice bath stays on its subject.
%
%     'located'  (1) A statement -- observation or manipulation -- whose
%                INSTRUMENT carries a location (a pass-1 probe_location: a site
%                term observation ABOUT the probe) is retargeted from the
%                subject it is about to that subject's part for the probe's
%                region. The probe_location observation itself stays: it is a
%                fact about the probe. (2) A label term observation
%                (ndi.migrate.internal.ontologyLabelSubjects: variable `label`)
%                whose value is an anatomical term (an UBERON node) is
%                retargeted to the part for that region.
%
%     'all'      both, 'sites' first.
%
%   WHAT 'located' DOES NOT DECIDE, AND COUNTS INSTEAD (none of these is
%   moved; each has its own counter in REPORT):
%     * an instrument with MORE THAN ONE location (Soph and 20211116 probes
%       carry both `primary visual cortex` and a cerebral hemisphere):
%       which region the recording is "from" is a modelling question.
%     * a statement already about a `tissue` entity (a Dabrowska slice that
%       sliceTetanus moved it to, or an existing part): the decision speaks of
%       a part of the SUBJECT; a region part of a slice is not decided.
%     * a statement whose subject is not in the batch, is not an entity, or
%       is a device.
%
%   STRUCTS is a cell of V_eta document body structs (from did2.document.toStruct).
%   Returns KEPT (the surviving bodies, with retargeted statements and the
%   promoted site observations removed), MINTED (the new part entity / term
%   assertion / directed_relation bodies, tagged schema_version 'V_eta' so they
%   can be folded back through v1_to_v2), CHANGED (false if nothing moved, so
%   the caller can skip the rebuild) and REPORT (every count, denominators
%   first).
%
%   THE SHAPE IS did-schema #88's (V_eta_entity_composition_plan.md secs. 1
%   and 4). The reads accept the pre-#88 spelling too (etaShape).
%
%   See also: ndi.migrate.local, did2.convert.migrators_j.treatment,
%   did2.convert.migrators_j.probe_location, ndi.migrate.internal.etaShape,
%   ndi.migrate.internal.sliceTetanus.

arguments
    structs
    options.Mode (1,:) char {mustBeMember(options.Mode, {'all', 'sites', 'located'})} = 'all'
end

changed = false;
minted = {};
kept = structs;
report = newReport(options.Mode);
n = numel(structs);
report.documents_read = n;
if n == 0
    return;
end
S = ndi.migrate.internal.etaShape;

idx = indexBatch(structs);
report.parts_found_existing = double(idx.parts.Count);

removeMask = false(1, n);
partBodies = {};

% ======================= 'sites' =======================================
if any(strcmp(options.Mode, {'all', 'sites'}))
    for i = 1:n
        s = structs{i};
        if ~isSiteObservation(s)
            continue;
        end
        report.site_observations_seen = report.site_observations_seen + 1;
        subject = S.aboutId(s);
        anchor = firstAnchor(s);
        if isempty(anchor) || isempty(subject)
            report.site_observations_unanchored = report.site_observations_unanchored + 1;
            continue;
        end
        hits = coAnchoredManipulations(structs, removeMask, anchor, subject);
        if isempty(hits)
            % a site about a probe (probe_location) or with no intervention:
            % the 'located' mode reads the probe ones
            report.site_observations_not_co_anchored = ...
                report.site_observations_not_co_anchored + 1;
            continue;
        end
        siteTerm = siteValue(s);
        [partId, idx, newBodies] = findOrMintPart(idx, subject, siteTerm, s);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
            report.parts_minted = report.parts_minted + 1;
        end
        for j = hits
            structs{j} = S.setAbout(structs{j}, partId);
            report.manipulations_retargeted = report.manipulations_retargeted + 1;
        end
        removeMask(i) = true;   % the located value is superseded by the part
        report.site_observations_promoted = report.site_observations_promoted + 1;
        changed = true;
    end
end

% ======================= 'located' =====================================
if any(strcmp(options.Mode, {'all', 'located'}))
    % (1) where each instrument is: the site term observations about it
    locOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:n
        s = structs{i};
        if removeMask(i) || ~isSiteObservation(s)
            continue;
        end
        x = S.aboutId(s);
        if isempty(x); continue; end
        t = siteValue(s);
        k = regionKey(t);
        if isempty(k); continue; end
        if isKey(locOf, x)
            m = locOf(x);
        else
            m = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end
        m(k) = struct('term', t, 'source', i);
        locOf(x) = m;
    end
    report.located_instruments = double(locOf.Count);

    for i = 1:n
        if removeMask(i); continue; end
        s = structs{i};
        d = S.direction(s);
        if ~any(strcmp(d, {'observation', 'manipulation'}))
            continue;
        end
        instr = S.edge(s, 'instrument_id');
        if isempty(instr) || ~isKey(locOf, instr)
            continue;
        end
        report.statements_with_located_instrument = ...
            report.statements_with_located_instrument + 1;
        m = locOf(instr);
        if m.Count > 1
            report.left_instrument_has_several_locations = ...
                report.left_instrument_has_several_locations + 1;
            continue;
        end
        loc = m.values; loc = loc{1};
        [ok, why] = movableSubject(idx, S.aboutId(s));
        if ~ok
            report.(why) = report.(why) + 1;
            continue;
        end
        [partId, idx, newBodies] = findOrMintPart(idx, S.aboutId(s), loc.term, s);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
            report.parts_minted = report.parts_minted + 1;
        end
        structs{i} = S.setAbout(s, partId);
        if strcmp(d, 'observation')
            report.observations_retargeted = report.observations_retargeted + 1;
        else
            report.manipulations_retargeted = report.manipulations_retargeted + 1;
        end
        changed = true;
    end

    % (2) a label naming an anatomical region
    for i = 1:n
        if removeMask(i); continue; end
        s = structs{i};
        if ~S.isStatement(s, 'observation', 'term') ...
                || ~strcmp(S.variable(s).name, 'label')
            continue;
        end
        report.label_observations_seen = report.label_observations_seen + 1;
        t = S.termValue(s);
        if ~isAnatomical(t)
            continue;
        end
        report.label_observations_anatomical = report.label_observations_anatomical + 1;
        [ok, why] = movableSubject(idx, S.aboutId(s));
        if ~ok
            report.(why) = report.(why) + 1;
            continue;
        end
        [partId, idx, newBodies] = findOrMintPart(idx, S.aboutId(s), t, s);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
            report.parts_minted = report.parts_minted + 1;
        end
        structs{i} = S.setAbout(s, partId);
        report.label_observations_retargeted = report.label_observations_retargeted + 1;
        changed = true;
    end
end

if ~changed
    kept = structs;
    return;
end
kept = structs(~removeMask);
minted = partBodies;
report.documents_minted = numel(minted);
report.documents_removed = sum(removeMask);
end

% ===================== report ==========================================

function r = newReport(mode)
r = struct( ...
    'mode',                                  mode, ...
    'documents_read',                        0, ...
    'parts_found_existing',                  0, ...
    'site_observations_seen',                0, ...
    'site_observations_promoted',            0, ...
    'site_observations_not_co_anchored',     0, ...
    'site_observations_unanchored',          0, ...
    'located_instruments',                   0, ...
    'statements_with_located_instrument',    0, ...
    'observations_retargeted',               0, ...
    'manipulations_retargeted',              0, ...
    'label_observations_seen',               0, ...
    'label_observations_anatomical',         0, ...
    'label_observations_retargeted',         0, ...
    'left_instrument_has_several_locations', 0, ...
    'left_about_a_tissue',                   0, ...
    'left_about_a_device',                   0, ...
    'left_subject_not_in_batch',             0, ...
    'left_subject_not_an_entity',            0, ...
    'left_no_subject',                       0, ...
    'parts_minted',                          0, ...
    'documents_minted',                      0, ...
    'documents_removed',                     0);
end

% ===================== predicates ======================================

function tf = isSiteObservation(s)
S = ndi.migrate.internal.etaShape;
tf = S.isStatement(s, 'observation', 'term') ...
    && strcmp(S.variable(s).name, 'anatomical location');
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

function hits = coAnchoredManipulations(structs, removeMask, anchor, subject)
hits = [];
for j = 1:numel(structs)
    if removeMask(j); continue; end
    t = structs{j};
    if isManipulation(t) && strcmp(firstAnchor(t), anchor) ...
            && strcmp(ndi.migrate.internal.etaShape.aboutId(t), subject)
        hits(end+1) = j; %#ok<AGROW>
    end
end
end

function tf = isAnatomical(t)
% An UBERON node. The one anatomy ontology the corpora and the lab bath-target
% files use; widening it (WBbt, FBbt, ZFA, ...) is a vocabulary call.
node = '';
if isfield(t, 'node'); node = char(t.node); end
tf = startsWith(lower(strtrim(node)), 'uberon:');
end

function [ok, why] = movableSubject(idx, subject)
ok = false;
if isempty(subject)
    why = 'left_no_subject';
elseif ~isKey(idx.byId, subject)
    why = 'left_subject_not_in_batch';
else
    e = idx.byId(subject);
    if ~ndi.migrate.internal.etaShape.isEntity(e)
        why = 'left_subject_not_an_entity';
    elseif isTissue(e)
        why = 'left_about_a_tissue';
    elseif strcmp(ndi.migrate.internal.etaShape.entityType(e), 'device')
        why = 'left_about_a_device';
    else
        ok = true;
        why = '';
    end
end
end

function tf = isTissue(e)
S = ndi.migrate.internal.etaShape;
tf = (strcmp(S.className(e), 'entity') && S.isEntity(e, {'tissue'})) ...
    || startsWith(baseField(e, 'name', ''), 'migrated_part_');
end

% ===================== the part index ==================================

function idx = indexBatch(structs)
%INDEXBATCH id -> body, and (subject|region) -> part for every part already in
%   the batch: a tissue entity `part_of` a subject AND carrying an
%   `anatomical structure` kind assertion (a slice has none, so a slice is
%   never taken for a region part).
S = ndi.migrate.internal.etaShape;
idx.byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
idx.parts = containers.Map('KeyType', 'char', 'ValueType', 'char');
parentOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
kindOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(structs)
    s = structs{k};
    id = baseField(s, 'id', '');
    if ~isempty(id); idx.byId(id) = s; end
    if strcmp(S.className(s), 'directed_relation') && strcmp(S.relationName(s), 'part_of')
        [ch, pa] = S.relationEnds(s);
        if ~isempty(ch) && ~isempty(pa); parentOf(ch) = pa; end
    elseif S.isStatement(s, 'assertion', 'term') ...
            && strcmp(S.variable(s).name, 'anatomical structure')
        k2 = regionKey(S.termValue(s));
        a = S.aboutId(s);
        if ~isempty(k2) && ~isempty(a); kindOf(a) = k2; end
    end
end
ps = parentOf.keys;
for i = 1:numel(ps)
    p = ps{i};
    if ~isKey(kindOf, p) || ~isKey(idx.byId, p) || ~isTissue(idx.byId(p))
        continue;
    end
    key = [parentOf(p) '|' kindOf(p)];
    if ~isKey(idx.parts, key)
        idx.parts(key) = p;
    end
end
end

function [partId, idx, bodies] = findOrMintPart(idx, subject, siteTerm, source)
bodies = {};
key = [subject '|' regionKey(siteTerm)];
if isKey(idx.parts, key)
    partId = idx.parts(key);
    return;
end
p = mintPart(subject, siteTerm, source);
partId = p.entity.base.id;
idx.parts(key) = partId;
idx.byId(partId) = p.entity;
bodies = {p.entity, p.assertion, p.relation};
end

function k = regionKey(t)
node = ''; name = '';
if isfield(t, 'node'); node = strtrim(char(t.node)); end
if isfield(t, 'name'); name = strtrim(char(t.name)); end
if ~isempty(node)
    k = lower(node);
elseif ~isempty(name)
    k = ['name:' lower(name)];
else
    k = '';
end
end

% ===================== builders ========================================

function parts = mintPart(subjectId, siteTerm, source)
%MINTPART Build the part entity, its anatomical-kind term assertion, and the
%   part_of relation. The part is an `entity` of type `tissue` ("part of an
%   organism: a slice, a biopsy, a region", binding_registry_meta.json
%   entity_type_bindings), identity only; the anatomical term is its kind (an
%   assertion, D9), not a field. SOURCE (the statement that called for the
%   part) supplies the session and datestamp.
S = ndi.migrate.internal.etaShape;
sessionId = ndi.v2.sessionIdOf(source);
ds = baseField(source, 'creation_timestamp', '');
if isempty(ds)
    ds = baseField(source, 'datestamp', '');
end
common = {'SessionId', sessionId, 'Datestamp', ds};
partName = safeName(siteTerm);
partId = did.ido.unique_id();

% local_identifier is REQUIRED on a tissue entity. Compose subject+part; trim
% any degenerate leading/trailing underscores (an empty subjectId would leave
% one), and fall back to the document id if somehow empty -- the same
% guarantee the DID-side jEnsureLocalId gives.
lid = regexprep([shortId(subjectId) '_' partName], '^_+|_+$', '');
if isempty(lid); lid = partId; end
ent = S.entity('tissue', struct('local_identifier', lid), 'Id', partId, common{:});

assertion = S.statement('assertion', 'term', partId, ...
    S.term('', 'anatomical structure'), siteTerm, common{:});

relation = S.relation(partId, subjectId, S.term('BFO:0000050', 'part_of'), common{:});

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
