classdef TestPathSPromotion < matlab.unittest.TestCase
%TESTPATHSPROMOTION Unit tests for the V_eta Path-S second pass (pure struct
%   logic; no database, schema, or MATLAB toolbox needed).
%
%   ndi.migrate.internal.pathSPromotion promotes an ATTRIBUTED anatomical locus
%   (a site term observation co-anchored with a manipulation -- the
%   intervention-target pattern) to a Path-S part ENTITY (type `tissue`) + a
%   term ASSERTION of its anatomical kind + a `part_of` `directed_relation`,
%   retargeting the co-anchored manipulation onto the part. A merely-located
%   site (no co-anchored manipulation, e.g. a probe location) is left
%   untouched. Promotion is deduped per (animal, site).
%
%   The fixtures are did-schema #88's shapes (V_eta_entity_composition_plan.md
%   secs. 1 and 4: a statement is a direction plus a value-kind mixin, about
%   its `entity_id`; time references by repeated `time_reference_id`).
%   testPreEightyEightShapeStillResolves feeds the pre-#88 spelling
%   (`term_observation`, `subject_id`, `time_reference_1`).
%
%   HISTORY: the notes below are about the pre-#88 `term_assertion` block,
%   kept because they record why the value is read from the `term` block.
%
%   Run with:  runtests('ndi.unittest.migrate.TestPathSPromotion')
%
%   The fixtures/accessors are LOCAL FUNCTIONS (below the classdef), called
%   unqualified from the Test methods. They were previously static methods called
%   as `TestPathSPromotion.helper(...)`, but that class-qualified reference failed
%   to resolve in the packaged class ("Unable to resolve the name ..."), so the
%   tests never actually ran. Local functions need no class-name resolution.
%
%   STATUS 2026-08-11: `testAttributedSitePromoted` ERRORED on its first real
%   execution (test-eta-migrate.yml run 31463051482, af840428f, and identically
%   on the parent run 31460488423 / e3795c2f7):
%
%       Error ID: 'MATLAB:nonExistentField'
%       Unrecognized field name "term_assertion".
%       Error in .../testAttributedSitePromoted (line 47)
%           testCase.verifyEqual(assertion.term_assertion.value.node, ...
%
%   THE TEST WAS STALE, NOT THE CODE, and it is INVERTED here rather than
%   deleted. `term_assertion` is `subject_assertion` x `term` and declares NO
%   fields of its own -- `value` is inherited from `term`, so it rides the
%   `term` BLOCK. Positive evidence, three ways:
%
%     DID-schema/schemas/V_eta/stable/term_assertion.json
%         superclasses = [subject_assertion, term];  "fields": []
%     DID-schema/schemas/V_eta/stable/term.json
%         declares the `value` (ontology_term) field
%     DID-matlab, every migrator under src/:
%         16 sites write `<body>.term = struct('value', ...)`
%          0 sites write a `term_assertion` block
%         -- including probe_geometry.m:124, which mints a term_assertion
%            document and puts its value on `.term`.
%
%   NDI-matlab commit d03a42bdf ("pathSPromotion: term_assertion pairs with the
%   `term` composite", 2026-07-28) made that move in pathSPromotion.m; this file
%   was written at 6108689dc, before it, and the two commits that touched it
%   since were about static-method resolution. The assertion below now reads
%   `.term.value`, additionally pins the superclass chain the same commit
%   changed, and pins the ABSENCE of a stale `term_assertion` block (an
%   undeclared top-level block quarantines -- the same regression the
%   `subject_relation` assertion further down exists for).

    methods (Test)

        function testAttributedSitePromoted(testCase)
            structs = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyTrue(changed);
            testCase.verifyFalse(anyStatement(kept, 'observation'));
            testCase.verifyTrue(anyClass(minted, 'entity'));
            testCase.verifyTrue(anyClass(minted, 'assertion'));
            testCase.verifyTrue(anyClass(minted, 'directed_relation'));

            part = firstOfClass(minted, 'entity');
            partId = part.base.id;
            testCase.verifyEqual(part.entity.type.name, 'tissue');
            testCase.verifyNotEmpty(part.entity.local_identifier);
            testCase.verifyFalse(isfield(part.base, 'name'));

            dose = firstOfClass(kept, 'manipulation');
            testCase.verifyEqual(depValue(dose, 'entity_id'), partId);
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'child_id'), partId);
            testCase.verifyEqual(depValue(rel, 'parent_id'), 'animal_1');
            testCase.verifyEqual(rel.directed_relation.relation.name, 'part_of');
            testCase.verifyEqual({rel.document_class.superclasses.class_name}, ...
                {'relation', 'base'});

            assertion = firstOfClass(minted, 'assertion');
            testCase.verifyEqual(assertion.term.value.node, 'uberon:0002436');
            testCase.verifyEqual(assertion.statement.variable.name, 'anatomical structure');
            testCase.verifyEqual(depValue(assertion, 'entity_id'), partId);
            testCase.verifyEqual({assertion.document_class.superclasses.class_name}, ...
                {'statement', 'base', 'term', 'value', 'data'});
            testCase.verifyFalse(isfield(assertion, 'subject_statement'));
        end

        function testPreEightyEightShapeStillResolves(testCase)
            % pass-1 output from a pre-#88 DID-matlab, read the same way;
            % the minted documents are #88 regardless
            structs = pre88(treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex'));
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyTrue(changed);
            part = firstOfClass(minted, 'entity');
            dose = firstOfClass(kept, 'dose_manipulation');
            testCase.verifyEqual(depValue(dose, 'subject_id'), part.base.id);
            assertion = firstOfClass(minted, 'assertion');
            testCase.verifyEqual(assertion.term.value.node, 'uberon:0002436');
            testCase.verifyEqual(assertion.term.value.name, ...
                'primary visual cortex');
        end

        function testPreCompositeSiteBlockStillResolves(testCase)
            structs = withPreCompositeSite(pre88(treatmentWithSite('anch_1', ...
                'animal_1', 'uberon:0002436', 'primary visual cortex')));
            [~, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyTrue(changed);
            assertion = firstOfClass(minted, 'assertion');
            testCase.verifyEqual(assertion.term.value.node, 'uberon:0002436');
        end

        function testMerelyLocatedSiteUntouched(testCase)
            structs = probeWithSite('anch_2', 'probe_9', ...
                'uberon:0000955', 'brain');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);

            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(numel(kept), numel(structs));
            testCase.verifyTrue(anyStatement(kept, 'observation'));
        end

        function testDedupPerAnimalSite(testCase)
            a = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            b = treatmentWithSite('anch_3', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            [~, minted, ~] = ndi.migrate.internal.pathSPromotion([a, b]);
            testCase.verifyEqual(countClass(minted, 'entity'), 1);
        end

        function testDistinctSitesGetDistinctParts(testCase)
            a = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'V1');
            b = treatmentWithSite('anch_3', 'animal_1', ...
                'uberon:0001950', 'neocortex');
            [~, minted, ~] = ndi.migrate.internal.pathSPromotion([a, b]);
            testCase.verifyEqual(countClass(minted, 'entity'), 2);
        end


        % ---- REGION PARTS (Jess Haley, 2026-10-21) -------------------------
        % "Any statement about an anatomical region of a subject --
        % manipulation or observation -- targets that region's part entity
        % (one per subject and region, shared, type tissue, part_of the
        % subject). A statement about the whole subject (... the generic
        % 'bath' location NCIm:C0179246) targets the subject."

        function testCompartmentBathTargetsThePart(testCase)
            % a Marder 'upper' compartment bath: a formulation-valued
            % manipulation and its co-anchored anatomical site
            structs = bathWithSite('anch_b', 'prep_1', 'UBERON:8910017', '');
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'sites');
            testCase.verifyTrue(changed);
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(part.entity.type.name, 'tissue');
            bath = firstOfClass(kept, 'manipulation');
            testCase.verifyEqual(depValue(bath, 'entity_id'), part.base.id);
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'parent_id'), 'prep_1');
            testCase.verifyEqual(report.site_observations_promoted, 1);
            testCase.verifyEqual(report.manipulations_retargeted, 1);
        end

        function testGenericBathTargetsTheWholeSubject(testCase)
            % the generic bath carries no site (the assemblers drop it), so
            % nothing is promoted and the bath stays on the subject
            structs = bathWithSite('anch_b', 'animal_1', '', '');
            structs = structs(~cellfun(@(b) strcmp(b.base.id, 'site_anch_b'), structs));
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);
            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(depValue(firstOfClass(kept, 'manipulation'), ...
                'entity_id'), 'animal_1');
        end

        function testProbeLocationRetargetsTheRecording(testCase)
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', ...
                    'bed nucleus of stria terminalis (BNST)'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyTrue(changed);
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(part.entity.type.name, 'tissue');
            rec = byId(kept, 'rec_1');
            testCase.verifyEqual(depValue(rec, 'entity_id'), part.base.id);
            testCase.verifyEqual(depValue(rec, 'instrument_id'), 'probe_1');
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'parent_id'), 'animal_1');
            kind = firstOfClass(minted, 'assertion');
            testCase.verifyEqual(kind.term.value.node, 'UBERON:0001880');
            % the probe's own location stays: it is a fact about the probe
            testCase.verifyNotEmpty(byId(kept, 'site_anch_p'));
            testCase.verifyEqual(depValue(byId(kept, 'site_anch_p'), 'entity_id'), 'probe_1');
            testCase.verifyEqual(report.observations_retargeted, 1);
            testCase.verifyEqual(report.located_instruments, 1);
        end

        function testInjectionAndRecordingShareOnePart(testCase)
            % an injection into BNST and a recording from a probe in BNST, on
            % one animal: ONE part entity, both statements on it -- in one
            % call, and in the two calls ndi.migrate.local makes
            structs = [{organism('animal_1'), device('probe_1')}, ...
                treatmentWithSite('anch_t', 'animal_1', 'uberon:0001880', ''), ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', 'BNST'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];

            [kept, minted] = ndi.migrate.internal.pathSPromotion(structs);
            testCase.verifyEqual(countClass(minted, 'entity'), 1);
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'manip_anch_t'), 'entity_id'), part.base.id);
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), part.base.id);

            [k1, m1] = ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'sites');
            [k2, m2, ~, r2] = ndi.migrate.internal.pathSPromotion([k1, m1], 'Mode', 'located');
            testCase.verifyEqual(countClass([m1, m2], 'entity'), 1, ...
                'the late pass finds the part the early pass made');
            testCase.verifyEqual(r2.parts_found_existing, 1);
            part = firstOfClass(m1, 'entity');
            testCase.verifyEqual(depValue(byId(k2, 'manip_anch_t'), 'entity_id'), part.base.id);
            testCase.verifyEqual(depValue(byId(k2, 'rec_1'), 'entity_id'), part.base.id);
        end

        function testAProbeWithSeveralLocationsIsLeftAndCounted(testCase)
            % Soph / 20211116: V1 AND a hemisphere on one probe -- which region
            % the recording is from is not decided here
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), 'animal_1');
            testCase.verifyEqual(report.left_instrument_has_several_locations, 1);
        end

        function testARecordingOnASliceStaysOnTheSlice(testCase)
            % sliceTetanus moved it onto a slice (a tissue with no anatomical
            % kind): a region part of a slice is not decided
            structs = [{organism('animal_1'), device('probe_1'), tissue('slice_a')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', 'BNST'), ...
                recording('rec_1', 'slice_a', 'probe_1', 'anch_r')];
            [kept, ~, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), 'slice_a');
            testCase.verifyEqual(report.left_about_a_tissue, 1);
        end

        function testAnAnatomicalLabelTargetsThePart(testCase)
            lbl = labelObs('lbl_1', 'animal_1', 'UBERON:0002436', 'anch_l');
            other = labelObs('lbl_2', 'animal_1', 'EMPTY:0000131', 'anch_l');
            structs = [{organism('animal_1'), lbl, other}, {makeAnchor('anch_l')}];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyTrue(changed);
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'lbl_1'), 'entity_id'), part.base.id);
            testCase.verifyEqual(depValue(byId(kept, 'lbl_2'), 'entity_id'), 'animal_1');
            testCase.verifyEqual([report.label_observations_seen ...
                report.label_observations_anatomical report.label_observations_retargeted], [2 1 1]);
        end

    end
end


function s = bathWithSite(anchorId, subjectId, siteNode, siteName)
bath = struct();
bath.document_class = dc('manipulation', ...
    {'interaction', 'statement', 'base', 'formulation', 'value', 'data'});
bath.depends_on = [dep('entity_id', subjectId), dep('instrument_id', 'stim_1'), ...
    dep('time_reference_id', anchorId), dep('value_id', 'form_1')];
bath.base = base('bath_1');
bath.statement = struct('variable', term('CHEBI:6904', 'muscimol'));
site = siteObs(anchorId, subjectId, siteNode, siteName, ['site_' anchorId]);
s = {bath, site, makeAnchor(anchorId)};
end

function s = recording(id, subjectId, probeId, anchorId)
r = struct();
r.document_class = dc('observation', ...
    {'interaction', 'statement', 'base', 'voltage', 'value', 'data'});
r.depends_on = [dep('entity_id', subjectId), dep('instrument_id', probeId), ...
    dep('time_reference_id', anchorId)];
r.base = base(id);
r.statement = struct('variable', term('', 'voltage'));
s = {r, makeAnchor(anchorId)};
end

function o = labelObs(id, subjectId, node, anchorId)
o = struct();
o.document_class = dc('observation', ...
    {'interaction', 'statement', 'base', 'term', 'value', 'data'});
o.depends_on = [dep('entity_id', subjectId), dep('time_reference_id', anchorId)];
o.base = base(id);
o.statement = struct('variable', term('', 'label'));
o.term = struct('value', term(node, ''));
end

function e = organism(id)
e = entityOf(id, 'organism');
end

function e = device(id)
e = entityOf(id, 'device');
end

function e = tissue(id)
e = entityOf(id, 'tissue');
end

function e = entityOf(id, type)
e = struct();
e.document_class = dc('entity', {'base'});
e.depends_on = struct('name', {}, 'value', {});
e.base = base(id);
e.entity = struct('type', term('', type), 'local_identifier', id);
end

function b = byId(bodies, id)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, id)
        b = bodies{k}; return;
    end
end
end


function s = treatmentWithSite(anchorId, animalId, siteNode, siteName)
manip = struct();
manip.document_class = dc('manipulation', ...
    {'interaction', 'statement', 'base', 'dose', 'value', 'data'});
manip.depends_on = [dep('entity_id', animalId), ...
    dep('time_reference_id', anchorId)];
manip.base = base(['manip_' anchorId]);
manip.statement = struct('variable', term('chebi:1', 'muscimol'));
manip.interaction = struct('method', struct('term', term('', 'injection')));
manip.dose = struct('value', struct());

site = siteObs(anchorId, animalId, siteNode, siteName, ['site_' anchorId]);
anchor = makeAnchor(anchorId);
s = {manip, site, anchor};
end

function s = probeWithSite(anchorId, probeId, siteNode, siteName)
site = siteObs(anchorId, probeId, siteNode, siteName, ['site_' anchorId]);
anchor = makeAnchor(anchorId);
s = {site, anchor};
end

function site = siteObs(anchorId, subjectId, siteNode, siteName, baseId)
site = struct();
site.document_class = dc('observation', ...
    {'interaction', 'statement', 'base', 'term', 'value', 'data'});
site.depends_on = [dep('entity_id', subjectId), ...
    dep('time_reference_id', anchorId)];
site.base = base(baseId);
site.statement = struct('variable', term('', 'anatomical location'));
site.term = struct('value', term(siteNode, siteName));
end

function structs = pre88(structs)
%PRE88 The same fixture in the pre-#88 spelling: join-leaf class names,
%   subject_id, time_reference_1, subject_statement.
for k = 1:numel(structs)
    b = structs{k};
    c = b.document_class.class_name;
    sup = {b.document_class.superclasses.class_name};
    if any(strcmp(c, {'observation', 'manipulation'}))
        kind = sup{4};
        b.document_class = dc([kind '_' c], {['subject_' c], kind});
        b.subject_statement = b.statement;
        b = rmfield(b, 'statement');
        for d = 1:numel(b.depends_on)
            if strcmp(b.depends_on(d).name, 'entity_id'); b.depends_on(d).name = 'subject_id'; end
            if strcmp(b.depends_on(d).name, 'time_reference_id'); b.depends_on(d).name = 'time_reference_1'; end
        end
    end
    structs{k} = b;
end
end

function structs = withPreCompositeSite(structs)
for k = 1:numel(structs)
    if strcmp(structs{k}.document_class.class_name, 'term_observation')
        structs{k}.term_observation = struct('value', structs{k}.term.value);
        structs{k} = rmfield(structs{k}, 'term');
    end
end
end

function anchor = makeAnchor(anchorId)
anchor = struct();
anchor.document_class = dc('relative_time_reference', {'time_reference', 'base'});
anchor.depends_on = dep('referent_id', 'session_1');
anchor.base = base(anchorId);
anchor.relative_time_reference = struct('value', ...
    struct('relation', term('', 'during')));
end

function x = dc(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
x = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function x = dep(name, value)
x = struct('name', name, 'value', value);
end

function x = base(id)
x = struct('id', id, 'session_id', 'sess_1', ...
    'creation_timestamp', '2024-01-01T00:00:00.000Z');
end

function x = term(node, name)
x = struct('node', node, 'name', name);
end

function tf = anyClass(bodies, className)
tf = countClass(bodies, className) > 0;
end

function n = countClass(bodies, className)
n = 0;
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        n = n + 1;
    end
end
end

function tf = anyStatement(bodies, direction)
tf = false;
for k = 1:numel(bodies)
    c = bodies{k}.document_class.class_name;
    if strcmp(c, direction) || endsWith(c, ['_' direction])
        tf = true; return;
    end
end
end

function b = firstOfClass(bodies, className)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        b = bodies{k}; return;
    end
end
end

function v = depValue(s, name)
v = '';
for k = 1:numel(s.depends_on)
    if strcmp(s.depends_on(k).name, name)
        v = s.depends_on(k).value; return;
    end
end
end
