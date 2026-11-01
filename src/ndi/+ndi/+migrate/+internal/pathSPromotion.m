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
%
%   DECIDED BY JESS HALEY, 2026-10-21 ("a"), LATERALITY: when a v1 probe /
%   element records several location terms, e.g. a brain area plus a
%   hemisphere ("V1" + "left hemisphere"), the migrator makes ONE part entity
%   for the area, and states the laterality on that part as a term assertion
%   ("this part is in the left hemisphere"). It does NOT make a separate part
%   entity per location term. A probe with several AREA terms (not
%   laterality) is handled as before, and counted.
%
%   DECIDED BY JESS HALEY, 2026-10-21 ("a"), SLICES: for Dabrowska slice
%   recordings, the recording observation points at a region part (BNST, or
%   whatever region the probe records) that is a part of the SLICE, and the
%   slice is a part of the animal (animal -> slice -> region). It does not
%   point at a region part directly on the animal. The bath already targets
%   the slice, so the manipulation and the observation sit on one chain.
%
%   DECIDED BY JESS HALEY, 2026-10-21 ("b"), UBERON: a region part entity's
%   anatomy term must be UBERON. A non-UBERON anatomy term is NOT mapped: it
%   is kept as written and counted and reported, by term. Laterality terms
%   are not anatomy terms for this rule.
%   ---------------------------------------------------------------------
%
%   A part is an `entity` of type `tissue` + a term ASSERTION of its
%   anatomical kind (variable `anatomical structure`, value the region term)
%   + a `part_of` `directed_relation` (child_id the part -> parent_id the
%   subject, or the slice). A part whose instrument also named a side carries
%   a second term assertion, its LATERALITY (variable NCIT:C25185
%   `Laterality`, value the side term as the v1 writer wrote it, e.g.
%   UBERON:0002812 `left cerebral hemisphere`). There is ONE part per
%   (parent, region, laterality): every pass and every mode finds an
%   existing part before minting one, so an injection into a region and a
%   recording from it share a single part entity, and a left-V1 and a
%   right-V1 probe on one animal get two parts (one per side, never one part
%   with both sides). The region key is the term's node, case-folded (the
%   name when there is no node), so `UBERON:0001880` written by a
%   probe_location and `uberon:0001880` written by a treatment are one region.
%
%   LATERALITY IS READ FROM THE TERM, NEVER FROM ITS LABEL. A location term is
%   laterality when its node is in lateralityTable (below), each row taken
%   from the term's own ontology entry: UBERON:0002812 / 0002813 are defined
%   `cerebral hemisphere and (in_left_side_of | in_right_side_of) some brain`
%   (BSPO:0000120 / BSPO:0000121); NCIT:C32955 / C33472 are NCIT's Left /
%   Right Cerebral Hemisphere; NCIT:C25229 / C25228 are NCIT's Left / Right
%   spatial qualifiers. A term not in the table is an area, whatever its
%   label says. The writers that produce laterality today
%   (vhlab-contrast-matlab sophie_add_treatment_info.m, vhlab-speed-matlab
%   +vikko/add_probe_location.m) write only the UBERON pair, as a second
%   probe_location document beside `UBERON:0002436 primary visual cortex`.
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
%                part's kind assertion now says it). When the sites sharing
%                one anchor and subject are ONE area plus ONE side, the side
%                is folded onto the area's part as its laterality and its site
%                observation is removed too. A generic-bath location is never
%                emitted as a site (the migrators drop it), so a whole-prep or
%                whole-slice bath stays on its subject.
%
%     'located'  (1) A statement -- observation or manipulation -- whose
%                INSTRUMENT carries a location (a pass-1 probe_location: a site
%                term observation ABOUT the probe) is retargeted from the
%                entity it is about to that entity's part for the probe's
%                region (with the probe's side as the part's laterality). The
%                entity is the subject, or a slice (a `tissue` entity `part_of`
%                something, that is not itself a region part), in which case
%                the region part is `part_of` the slice. The probe_location
%                observations themselves stay: they are facts about the probe.
%                (2) A label term observation
%                (ndi.migrate.internal.ontologyLabelSubjects: variable `label`)
%                whose value is an anatomical term (an UBERON node) is
%                retargeted to the part for that region.
%
%     'all'      both, 'sites' first.
%
%   WHAT IS NOT DECIDED, AND IS COUNTED INSTEAD (none of these is moved; each
%   has its own counter in REPORT):
%     * an instrument with MORE THAN ONE AREA (not laterality): which region
%       the recording is "from" is a modelling question. In 'sites' a group
%       of several areas is promoted site by site, as before.
%     * an instrument with more than one SIDE (left and right on one probe).
%     * an instrument whose only location is a bare side qualifier (NCIT
%       Left / Right): there is no region to make a part of.
%     * a statement already about a region part, a tissue that is part of
%       nothing, a device, a v1 element (a sorted unit recorded by the probe:
%       the migrators assert its `element type`, or for a device a kind that
%       rebuilds one v1 type), another entity type (a
%       cell, a culture), or a subject not in the batch.
%
%   STRUCTS is a cell of V_eta document body structs (from did2.document.toStruct).
%   Returns KEPT (the surviving bodies, with retargeted statements and the
%   promoted site observations removed), MINTED (the new part entity / term
%   assertions / directed_relation bodies, tagged schema_version 'did_v2' so
%   they can be folded back through v1_to_v2), CHANGED (false if nothing
%   moved, so the caller can skip the rebuild) and REPORT (every count,
%   denominators first; `anatomy_non_uberon` lists the non-UBERON anatomy
%   terms by term).
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
    report = finishReport(report, containers.Map('KeyType', 'char', 'ValueType', 'any'));
    return;
end
S = ndi.migrate.internal.etaShape;

idx = indexBatch(structs);
report.parts_found_existing = double(idx.parts.Count);
nonUberon = containers.Map('KeyType', 'char', 'ValueType', 'any');

removeMask = false(1, n);
partBodies = {};

% ======================= 'sites' =======================================
if any(strcmp(options.Mode, {'all', 'sites'}))
    % the site observations one source document produced share an anchor
    % and a subject: group them, so an area and its side are read together
    groupOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:n
        s = structs{i};
        if ~isSiteObservation(s); continue; end
        g = siteGroupKey(s);
        if isempty(g); continue; end
        if isKey(groupOf, g); groupOf(g) = [groupOf(g), i]; else; groupOf(g) = i; end
    end
    for i = 1:n
        s = structs{i};
        if removeMask(i) || ~isSiteObservation(s)
            continue;
        end
        report.site_observations_seen = report.site_observations_seen + 1;
        subject = S.aboutId(s);
        anchor = firstAnchor(s);
        if isempty(anchor) || isempty(subject)
            report.site_observations_unanchored = report.site_observations_unanchored + 1;
            continue;
        end
        siteTerm = siteValue(s);
        hits = coAnchoredManipulations(structs, removeMask, anchor, subject);
        if isempty(hits)
            % a site about a probe (probe_location) or with no intervention:
            % the 'located' mode reads the probe ones
            report.site_observations_not_co_anchored = ...
                report.site_observations_not_co_anchored + 1;
            continue;
        end
        plan = sitePlan(structs, groupOf(siteGroupKey(s)), removeMask);
        if plan.fold && any(plan.sides == i)
            % this side is folded onto its area's part when the area (same
            % anchor, same subject, so the same manipulations) is promoted
            continue;
        end
        [lat, isSide] = lateralityOf(siteTerm);
        if isSide && ~lat.structure
            % a bare side qualifier with no area beside it: no region
            report.left_side_without_region = report.left_side_without_region + 1;
            continue;
        end
        sideTerm = [];
        if plan.fold
            sideTerm = siteValue(structs{plan.sides(1)});
        elseif plan.severalSides && ~isSide
            report.sites_several_sides = report.sites_several_sides + 1;
        end
        if plan.severalAreas && ~isSide
            report.sites_several_areas = report.sites_several_areas + 1;
        end
        [partId, idx, newBodies, report, nonUberon] = findOrMintPart(idx, ...
            subject, siteTerm, sideTerm, s, report, nonUberon);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
        end
        for j = hits
            structs{j} = S.setAbout(structs{j}, partId);
            report.manipulations_retargeted = report.manipulations_retargeted + 1;
        end
        removeMask(i) = true;   % the located value is superseded by the part
        report.site_observations_promoted = report.site_observations_promoted + 1;
        if plan.fold
            removeMask(plan.sides) = true;
            report.sites_laterality_folded = report.sites_laterality_folded + numel(plan.sides);
        end
        changed = true;
    end
end

% ======================= 'sites': a site CONDITION ======================
% A statement that names its area as a condition {variable NCIT:C13717
% "Anatomic Site", term <UBERON node>} -- DID-matlab #218's ontology_image
% raster, one intensity observation of its region (decided 2026-10-21,
% [ontology image is an observation of its region],
% V_eta_spatial_transcriptomics_plan.md) -- is about that region: it moves onto
% the subject's part for the area (no side), and the condition is dropped
% because the part now says it.
if any(strcmp(options.Mode, {'all', 'sites'}))
    for i = 1:n
        if removeMask(i); continue; end
        s = structs{i};
        [k, area] = siteCondition(s);
        if k == 0; continue; end
        report.site_conditions_seen = report.site_conditions_seen + 1;
        if ~isAnatomical(area)
            report.site_conditions_not_uberon = report.site_conditions_not_uberon + 1;
            continue;
        end
        subject = S.aboutId(s);
        [ok, why, onSlice] = movableSubject(idx, subject);
        if ~ok
            report.(why) = report.(why) + 1;
            continue;
        end
        [partId, idx, newBodies, report, nonUberon] = findOrMintPart(idx, ...
            subject, area, [], s, report, nonUberon);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
            if onSlice
                report.parts_minted_on_slices = report.parts_minted_on_slices + 1;
            end
        end
        s = dropCondition(s, k);
        structs{i} = S.setAbout(s, partId);
        report.site_conditions_retargeted = report.site_conditions_retargeted + 1;
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

    % each located instrument's region and side, decided once
    planOf = containers.Map('KeyType', 'char', 'ValueType', 'any');
    xs = locOf.keys;
    for q = 1:numel(xs)
        p = instrumentPlan(locOf(xs{q}));
        planOf(xs{q}) = p;
        report.(['instruments_' p.kind]) = report.(['instruments_' p.kind]) + 1;
    end

    for i = 1:n
        if removeMask(i); continue; end
        s = structs{i};
        d = S.direction(s);
        if ~any(strcmp(d, {'observation', 'manipulation'}))
            continue;
        end
        instr = S.edge(s, 'instrument_id');
        if isempty(instr) || ~isKey(planOf, instr)
            continue;
        end
        report.statements_with_located_instrument = ...
            report.statements_with_located_instrument + 1;
        p = planOf(instr);
        switch p.kind
            case 'several_areas'
                report.left_instrument_has_several_areas = ...
                    report.left_instrument_has_several_areas + 1;
                continue;
            case 'several_sides'
                report.left_instrument_has_several_sides = ...
                    report.left_instrument_has_several_sides + 1;
                continue;
            case 'no_region'
                report.left_instrument_has_no_region = ...
                    report.left_instrument_has_no_region + 1;
                continue;
        end
        [ok, why, onSlice] = movableSubject(idx, S.aboutId(s));
        if ~ok
            report.(why) = report.(why) + 1;
            continue;
        end
        [partId, idx, newBodies, report, nonUberon] = findOrMintPart(idx, ...
            S.aboutId(s), p.area, p.side, s, report, nonUberon);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
            if onSlice
                report.parts_minted_on_slices = report.parts_minted_on_slices + 1;
            end
        end
        structs{i} = S.setAbout(s, partId);
        if strcmp(d, 'observation')
            report.observations_retargeted = report.observations_retargeted + 1;
        else
            report.manipulations_retargeted = report.manipulations_retargeted + 1;
        end
        if onSlice
            report.statements_retargeted_onto_slice_parts = ...
                report.statements_retargeted_onto_slice_parts + 1;
        end
        if ~isempty(p.side)
            report.laterality_folded = report.laterality_folded + 1;
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
        [ok, why, onSlice] = movableSubject(idx, S.aboutId(s));
        if ~ok
            report.(why) = report.(why) + 1;
            continue;
        end
        [partId, idx, newBodies, report, nonUberon] = findOrMintPart(idx, ...
            S.aboutId(s), t, [], s, report, nonUberon);
        if ~isempty(newBodies)
            partBodies = [partBodies, newBodies]; %#ok<AGROW>
            if onSlice
                report.parts_minted_on_slices = report.parts_minted_on_slices + 1;
            end
        end
        structs{i} = S.setAbout(s, partId);
        report.label_observations_retargeted = report.label_observations_retargeted + 1;
        if onSlice
            report.statements_retargeted_onto_slice_parts = ...
                report.statements_retargeted_onto_slice_parts + 1;
        end
        changed = true;
    end
end

report = finishReport(report, nonUberon);
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
    'site_conditions_seen',                  0, ...
    'site_conditions_not_uberon',            0, ...
    'site_conditions_retargeted',            0, ...
    'sites_laterality_folded',               0, ...
    'sites_several_areas',                   0, ...
    'sites_several_sides',                   0, ...
    'located_instruments',                   0, ...
    'instruments_one_area',                  0, ...
    'instruments_area_with_laterality',      0, ...
    'instruments_laterality_only',           0, ...
    'instruments_several_areas',             0, ...
    'instruments_several_sides',             0, ...
    'instruments_no_region',                 0, ...
    'statements_with_located_instrument',    0, ...
    'observations_retargeted',               0, ...
    'manipulations_retargeted',              0, ...
    'laterality_folded',                     0, ...
    'statements_retargeted_onto_slice_parts', 0, ...
    'label_observations_seen',               0, ...
    'label_observations_anatomical',         0, ...
    'label_observations_retargeted',         0, ...
    'left_instrument_has_several_areas',     0, ...
    'left_instrument_has_several_sides',     0, ...
    'left_instrument_has_no_region',         0, ...
    'left_side_without_region',              0, ...
    'left_about_a_region_part',              0, ...
    'left_about_a_tissue_part_of_nothing',   0, ...
    'left_about_a_device',                   0, ...
    'left_about_an_element',                 0, ...
    'left_about_another_entity_type',        0, ...
    'left_subject_not_in_batch',             0, ...
    'left_subject_not_an_entity',            0, ...
    'left_no_subject',                       0, ...
    'anatomy_terms_inspected',               0, ...
    'anatomy_terms_uberon',                  0, ...
    'anatomy_terms_non_uberon',              0, ...
    'anatomy_non_uberon',                    struct('node', {}, 'name', {}, 'count', {}), ...
    'parts_minted',                          0, ...
    'parts_minted_on_slices',                0, ...
    'laterality_assertions_minted',          0, ...
    'documents_minted',                      0, ...
    'documents_removed',                     0);
end

function r = finishReport(r, nonUberon)
%FINISHREPORT The non-UBERON anatomy terms, by term, most frequent first.
ks = nonUberon.keys;
list = struct('node', {}, 'name', {}, 'count', {});
for k = 1:numel(ks)
    list(end+1) = nonUberon(ks{k}); %#ok<AGROW>
end
if ~isempty(list)
    [~, o] = sort(-[list.count]);
    list = list(o);
end
r.anatomy_non_uberon = list;
end

function [r, nonUberon] = countAnatomy(r, nonUberon, t)
%COUNTANATOMY One region term resolved to a part (decision "b": the part's
%   anatomy term must be UBERON; a non-UBERON term is kept as written and
%   listed here, not mapped).
r.anatomy_terms_inspected = r.anatomy_terms_inspected + 1;
if isAnatomical(t)
    r.anatomy_terms_uberon = r.anatomy_terms_uberon + 1;
    return;
end
r.anatomy_terms_non_uberon = r.anatomy_terms_non_uberon + 1;
node = ''; name = '';
if isfield(t, 'node'); node = strtrim(char(t.node)); end
if isfield(t, 'name'); name = strtrim(char(t.name)); end
key = [node '|' name];
if isKey(nonUberon, key)
    e = nonUberon(key);
    e.count = e.count + 1;
else
    e = struct('node', node, 'name', name, 'count', 1);
end
nonUberon(key) = e;
end

% ===================== laterality ======================================

function tab = lateralityTable()
%LATERALITYTABLE The location terms that are LATERALITY, keyed by node
%   (case-folded), each from its ontology entry, not its label:
%     side       'left' | 'right'
%     structure  true when the term also names a region (a hemisphere), so a
%                probe whose only location it is records from that region
%   UBERON:0002812 left cerebral hemisphere  = cerebral hemisphere and
%       (BSPO:0000120 in_left_side_of some brain)
%   UBERON:0002813 right cerebral hemisphere = cerebral hemisphere and
%       (BSPO:0000121 in_right_side_of some brain)
%   NCIT:C32955 / C33472 Left / Right Cerebral Hemisphere (is_a NCIT:C12351
%       Cerebral Hemisphere)
%   NCIT:C25229 / C25228 Left / Right (is_a NCIT:C73706 Spatial Qualifier)
%   Widening this table is a vocabulary call; a node missing here is an area.
persistent T
if isempty(T)
    T = containers.Map('KeyType', 'char', 'ValueType', 'any');
    T('uberon:0002812') = struct('side', 'left',  'structure', true);
    T('uberon:0002813') = struct('side', 'right', 'structure', true);
    T('ncit:c32955')    = struct('side', 'left',  'structure', true);
    T('ncit:c33472')    = struct('side', 'right', 'structure', true);
    T('ncit:c25229')    = struct('side', 'left',  'structure', false);
    T('ncit:c25228')    = struct('side', 'right', 'structure', false);
end
tab = T;
end

function [lat, tf] = lateralityOf(t)
lat = struct('side', '', 'structure', false);
tf = false;
node = '';
if isstruct(t) && isfield(t, 'node'); node = lower(strtrim(char(t.node))); end
if isempty(node); return; end
T = lateralityTable();
if isKey(T, node)
    lat = T(node);
    tf = true;
end
end

function p = instrumentPlan(m)
%INSTRUMENTPLAN Read one instrument's locations as AREAS and SIDES.
%   kind: one_area | area_with_laterality | laterality_only | several_areas |
%   several_sides | no_region; area / side the terms to use.
vals = m.values;
areas = {}; sides = {}; sideNames = {};
for k = 1:numel(vals)
    t = vals{k}.term;
    [lat, isSide] = lateralityOf(t);
    if isSide
        sides{end+1} = struct('term', t, 'lat', lat); %#ok<AGROW>
        sideNames{end+1} = lat.side; %#ok<AGROW>
    else
        areas{end+1} = t; %#ok<AGROW>
    end
end
p = struct('kind', '', 'area', [], 'side', []);
nSides = numel(unique(sideNames));
if numel(areas) > 1
    p.kind = 'several_areas';
elseif nSides > 1
    p.kind = 'several_sides';
elseif numel(areas) == 1 && isempty(sides)
    p.kind = 'one_area';
    p.area = areas{1};
elseif numel(areas) == 1
    p.kind = 'area_with_laterality';
    p.area = areas{1};
    p.side = sides{1}.term;
elseif numel(sides) == 1 && sides{1}.lat.structure
    % the hemisphere is the only location: it is the region
    p.kind = 'laterality_only';
    p.area = sides{1}.term;
else
    p.kind = 'no_region';
end
end

function g = siteGroupKey(s)
S = ndi.migrate.internal.etaShape;
a = firstAnchor(s);
x = S.aboutId(s);
g = '';
if ~isempty(a) && ~isempty(x)
    g = [a '|' x];
end
end

function p = sitePlan(structs, members, removeMask)
%SITEPLAN The site observations of one (anchor, subject) group: fold its side
%   onto its area when they are exactly ONE area and ONE side.
areas = []; sides = []; sideNames = {};
for k = members
    if removeMask(k); continue; end
    [lat, isSide] = lateralityOf(siteValue(structs{k}));
    if isSide
        sides(end+1) = k; %#ok<AGROW>
        sideNames{end+1} = lat.side; %#ok<AGROW>
    else
        areas(end+1) = k; %#ok<AGROW>
    end
end
nSides = numel(unique(sideNames));
p = struct('fold', numel(areas) == 1 && nSides == 1 && numel(sides) == 1, ...
    'sides', sides, 'severalAreas', numel(areas) > 1, ...
    'severalSides', nSides > 1);
end

% ===================== predicates ======================================

function tf = isSiteObservation(s)
S = ndi.migrate.internal.etaShape;
tf = S.isStatement(s, 'observation', 'term') ...
    && S.isVariable(s, 'anatomical location');
end

function [k, area] = siteCondition(s)
%SITECONDITION The index of S's anatomic-site condition and its term (0, []
%   when none): an entry of `statement.conditions` whose variable is
%   NCIT:C13717 (by node; by the registered or the older label when the node
%   is empty) and that carries a term.
k = 0;
area = [];
if ~(isfield(s, 'statement') && isstruct(s.statement) && isfield(s.statement, 'conditions'))
    return;
end
c = s.statement.conditions;
want = ndi.migrate.internal.etaShape.anatomicalLocationVariable();
for j = 1:numel(c)
    if iscell(c); e = c{j}; else; e = c(j); end
    if ~isstruct(e) || ~isfield(e, 'variable') || ~isstruct(e.variable); continue; end
    v = ndi.migrate.internal.etaShape.asTerm(e.variable);
    if ~isempty(strtrim(v.node))
        hit = strcmpi(strtrim(v.node), want.node);
    else
        hit = any(strcmpi(strtrim(v.name), {want.name, 'anatomical location'}));
    end
    if ~hit || ~isfield(e, 'term'); continue; end
    t = e.term;
    if isstruct(t) && isfield(t, 'value') && ~isfield(t, 'node'); t = t(1).value; end
    if ~isstruct(t); continue; end
    k = j;
    area = ndi.migrate.internal.etaShape.asTerm(t);
    return;
end
end

function s = dropCondition(s, k)
%DROPCONDITION S without its K-th condition (the field goes when none is left).
c = s.statement.conditions;
c(k) = [];
if isempty(c)
    s.statement = rmfield(s.statement, 'conditions');
else
    s.statement.conditions = c;
end
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

function [ok, why, onSlice] = movableSubject(idx, subject)
%MOVABLESUBJECT May a statement about SUBJECT move onto a region part of it?
%   A subject (an organism; a pre-#88 `subject` that is not a v1 element),
%   or a SLICE: a
%   `tissue` entity `part_of` something that is not itself a region part
%   (sliceTetanus's slices; decision "a", animal -> slice -> region).
ok = false;
onSlice = false;
why = '';
if isempty(subject)
    why = 'left_no_subject';
elseif ~isKey(idx.byId, subject)
    why = 'left_subject_not_in_batch';
else
    e = idx.byId(subject);
    if ~ndi.migrate.internal.etaShape.isEntity(e)
        why = 'left_subject_not_an_entity';
    elseif isKey(idx.elements, subject)
        % a v1 element (a probe, a sorted unit): the migrators assert its
        % `element type`; a unit recorded by a located probe is not the
        % specimen, and a region part of a unit is not decided
        why = 'left_about_an_element';
    elseif isRegionPart(idx, subject, e)
        why = 'left_about_a_region_part';
    elseif isTissue(e)
        if isKey(idx.parentOf, subject)
            ok = true;
            onSlice = true;
        else
            why = 'left_about_a_tissue_part_of_nothing';
        end
    elseif strcmp(ndi.migrate.internal.etaShape.entityType(e), 'device')
        why = 'left_about_a_device';
    elseif ~any(strcmp(ndi.migrate.internal.etaShape.entityType(e), {'organism', ''}))
        % a cell, a culture, a group, ...: "a region of a SUBJECT" names an
        % organism ('' is the pre-#88 `subject` class, which has no type)
        why = 'left_about_another_entity_type';
    else
        ok = true;
    end
end
end

function tf = isTissue(e)
S = ndi.migrate.internal.etaShape;
tf = (strcmp(S.className(e), 'entity') && S.isEntity(e, {'tissue'})) ...
    || startsWith(baseField(e, 'name', ''), 'migrated_part_');
end

function tf = isRegionPart(idx, id, e)
% a tissue carrying an `anatomical structure` kind (every part this pass
% makes), or a pre-#88 Path-S part (named migrated_part_*)
tf = isKey(idx.kindOf, id) || startsWith(baseField(e, 'name', ''), 'migrated_part_');
end

% ===================== the part index ==================================

function idx = indexBatch(structs)
%INDEXBATCH id -> body, child -> part_of parent, and (parent|region[|side])
%   -> part for every part already in the batch: a tissue entity `part_of`
%   an entity AND carrying an `anatomical structure` kind assertion (a slice
%   has none, so a slice is never taken for a region part), keyed by its
%   `Laterality` assertion too when it has one.
S = ndi.migrate.internal.etaShape;
idx.byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
idx.parts = containers.Map('KeyType', 'char', 'ValueType', 'char');
idx.parentOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
idx.kindOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
idx.elements = containers.Map('KeyType', 'char', 'ValueType', 'logical');
sideOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(structs)
    s = structs{k};
    id = baseField(s, 'id', '');
    if ~isempty(id); idx.byId(id) = s; end
    if strcmp(S.className(s), 'directed_relation') && strcmp(S.relationName(s), 'part_of')
        [ch, pa] = S.relationEnds(s);
        if ~isempty(ch) && ~isempty(pa); idx.parentOf(ch) = pa; end
    elseif S.isStatement(s, 'assertion', 'term')
        v = S.variable(s).name;
        isKind = S.isVariable(s, 'anatomical structure');
        a = S.aboutId(s);
        % a v1 element: its `element type` assertion, or, where DID-matlab
        % PR #304 no longer writes it ([element type is a device kind term],
        % [element types batch 1] .. [element types batch 4]), a device
        % kind that rebuilds exactly one v1 type (ndi.vintage.elementTypeOfKind);
        % or its `ndi element class` assertion, which every migrated element
        % has, and which is all a sorted unit keeps once DID-matlab drops its
        % `element type` assertion ([cell spellings are one meaning])
        if ~isempty(a) && (strcmp(v, 'element type') || ...
                strcmp(v, ndi.vintage.elementLabel('class')) || ...
                (ndi.vintage.isEquipmentTypeVariable(S.variable(s)) && ...
                 ~isempty(ndi.vintage.elementTypeOfKind(S.termValue(s).node))))
            idx.elements(a) = true;
        end
        k2 = regionKey(S.termValue(s));
        if isempty(k2) || isempty(a); continue; end
        if isKind
            idx.kindOf(a) = k2;
        elseif strcmp(v, LATERALITY_VARIABLE().name)
            sideOf(a) = k2;
        end
    end
end
ps = idx.kindOf.keys;
for i = 1:numel(ps)
    p = ps{i};
    if ~isKey(idx.parentOf, p) || ~isKey(idx.byId, p) || ~isTissue(idx.byId(p))
        continue;
    end
    side = '';
    if isKey(sideOf, p); side = sideOf(p); end
    key = partKey(idx.parentOf(p), idx.kindOf(p), side);
    if ~isKey(idx.parts, key)
        idx.parts(key) = p;
    end
end
end

function key = partKey(parentId, areaKey, sideKey)
key = [parentId '|' areaKey];
if ~isempty(sideKey)
    key = [key '|side:' sideKey];
end
end

function [partId, idx, bodies, r, nonUberon] = findOrMintPart(idx, parentId, ...
    areaTerm, sideTerm, source, r, nonUberon)
bodies = {};
[r, nonUberon] = countAnatomy(r, nonUberon, areaTerm);
sideKey = '';
if ~isempty(sideTerm); sideKey = regionKey(sideTerm); end
key = partKey(parentId, regionKey(areaTerm), sideKey);
if isKey(idx.parts, key)
    partId = idx.parts(key);
    return;
end
p = mintPart(parentId, areaTerm, sideTerm, source);
partId = p.entity.base.id;
idx.parts(key) = partId;
idx.byId(partId) = p.entity;
idx.parentOf(partId) = parentId;
idx.kindOf(partId) = regionKey(areaTerm);
bodies = {p.entity, p.assertion};
if ~isempty(p.laterality)
    bodies{end+1} = p.laterality;
    r.laterality_assertions_minted = r.laterality_assertions_minted + 1;
end
bodies{end+1} = p.relation;
r.parts_minted = r.parts_minted + 1;
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

function v = LATERALITY_VARIABLE()
%LATERALITY_VARIABLE The variable of a part's laterality assertion: NCIT's
%   `Laterality` ("referring to a side of the body or of a structure"). T19:
%   no laterality variable is used in an NDI dataset, so an existing ontology
%   term; its did-schema term registry row is requested, not yet registered.
v = struct('node', 'NCIT:C25185', 'name', 'Laterality');
end

function parts = mintPart(parentId, siteTerm, sideTerm, source)
%MINTPART Build the part entity, its anatomical-kind term assertion, its
%   laterality term assertion (when SIDETERM is given), and the part_of
%   relation. The part is an `entity` of type `tissue` ("part of an organism:
%   a slice, a biopsy, a region", binding_registry_meta.json
%   entity_type_bindings), identity only; the anatomical term is its kind (an
%   assertion, D9), not a field, and is written as the source wrote it (never
%   mapped). PARENTID is the subject, or the slice the statement was about.
%   SOURCE (the statement that called for the part) supplies the session and
%   datestamp.
S = ndi.migrate.internal.etaShape;
sessionId = ndi.v2.sessionIdOf(source);
ds = baseField(source, 'creation_timestamp', '');
if isempty(ds)
    ds = baseField(source, 'datestamp', '');
end
common = {'SessionId', sessionId, 'Datestamp', ds};
partName = safeName(siteTerm);
if ~isempty(sideTerm)
    partName = [partName '_' safeName(sideTerm)];
end
partId = did.ido.unique_id();

% local_identifier is REQUIRED on a tissue entity. Compose parent+part; trim
% any degenerate leading/trailing underscores (an empty parentId would leave
% one), and fall back to the document id if somehow empty -- the same
% guarantee the DID-side jEnsureLocalId gives.
lid = regexprep([shortId(parentId) '_' partName], '^_+|_+$', '');
if isempty(lid); lid = partId; end
ent = S.entity('tissue', struct('local_identifier', lid), 'Id', partId, common{:});

assertion = S.statement('assertion', 'term', partId, ...
    S.anatomicalStructureVariable(), siteTerm, common{:});

laterality = [];
if ~isempty(sideTerm)
    laterality = S.statement('assertion', 'term', partId, ...
        LATERALITY_VARIABLE(), S.asTerm(sideTerm), common{:});
end

relation = S.relation(partId, parentId, ndi.v2.vocabTerm('relation', 'part_of'), common{:});

parts = struct('entity', ent, 'assertion', assertion, 'relation', relation);
parts.laterality = laterality;
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
