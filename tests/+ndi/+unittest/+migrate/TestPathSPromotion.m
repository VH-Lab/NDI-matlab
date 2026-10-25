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
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', part.entity.type, 'tissue'));
            testCase.verifyNotEmpty(part.entity.local_identifier);
            testCase.verifyFalse(isfield(part.base, 'name'));

            dose = firstOfClass(kept, 'manipulation');
            testCase.verifyEqual(depValue(dose, 'entity_id'), partId);
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'child_id'), partId);
            testCase.verifyEqual(depValue(rel, 'parent_id'), 'animal_1');
            testCase.verifyTrue(ndi.v2.vocabIs('relation', rel.directed_relation.relation, 'part_of'));
            testCase.verifyEqual({rel.document_class.superclasses.class_name}, ...
                {'relation', 'base'});

            assertion = firstOfClass(minted, 'assertion');
            testCase.verifyEqual(assertion.term.value.node, 'uberon:0002436');
            % the registered variable (did-schema #88 term registry), not the
            % label-only form older documents carry
            testCase.verifyEqual(assertion.statement.variable.node, 'UBERON:0000061');
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

        function testRegisteredSiteVariableIsPromotedToo(testCase)
            % A site written with the registered variable NCIT:C13717 "Anatomic
            % Site" is promoted exactly as the label-only 'anatomical location'
            % of older documents is (the fixture's default form).
            structs = treatmentWithSite('anch_1', 'animal_1', ...
                'uberon:0002436', 'primary visual cortex');
            structs{2}.statement.variable = term('NCIT:C13717', 'Anatomic Site');
            [kept, minted, changed] = ndi.migrate.internal.pathSPromotion(structs);
            testCase.verifyTrue(changed);
            testCase.verifyFalse(anyStatement(kept, 'observation'));
            testCase.verifyTrue(anyClass(minted, 'entity'));
            % the node decides, whatever the label says
            structs{2}.statement.variable = term('ncit:c13717', '');
            [~, ~, changed] = ndi.migrate.internal.pathSPromotion(structs);
            testCase.verifyTrue(changed, 'the node alone, in another case, must match');
            % a different node with the old label is NOT a site
            structs{2}.statement.variable = term('NCIT:C25185', 'anatomical location');
            [~, ~, changed] = ndi.migrate.internal.pathSPromotion(structs);
            testCase.verifyFalse(changed, 'a node other than C13717 is not the site variable');
        end

        function testASiteConditionMovesTheObservationOntoItsPart(testCase)
            % DID-matlab #218's ontology_image raster: ONE intensity
            % observation of the subject naming its area as a condition
            % {NCIT:C13717 "Anatomic Site", UBERON term}. The observation
            % moves onto the subject's part for that area (no side) and the
            % condition is dropped.
            obs = conditionObs('img_1', 'animal_1', 'uberon:0002436', 'primary visual cortex');
            structs = {organism('animal_1'), obs, makeAnchor('img_anchor')};
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'sites');
            testCase.verifyTrue(changed);
            testCase.verifyEqual(report.site_conditions_seen, 1);
            testCase.verifyEqual(report.site_conditions_retargeted, 1);
            part = firstOfClass(minted, 'entity');
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', part.entity.type, 'tissue'));
            moved = byId(kept, 'img_1');
            testCase.verifyEqual(depValue(moved, 'entity_id'), part.base.id);
            testCase.verifyFalse(isfield(moved.statement, 'conditions'), ...
                'the anatomic-site condition must be dropped once the part says it');
            kinds = assertionsAbout(minted, part.base.id);
            testCase.verifyEqual(numel(kinds), 1, 'no laterality: the area only');
            testCase.verifyEqual(kinds{1}.term.value.node, 'uberon:0002436');
            % a second observation of the same area reuses the part
            obs2 = conditionObs('img_2', 'animal_1', 'UBERON:0002436', 'primary visual cortex');
            [kept2, minted2] = ndi.migrate.internal.pathSPromotion( ...
                [kept, minted, {obs2}], 'Mode', 'sites');
            testCase.verifyEmpty(minted2, 'the existing part is reused');
            testCase.verifyEqual(depValue(byId(kept2, 'img_2'), 'entity_id'), part.base.id);
        end

        function testASiteConditionThatIsNotUberonOrNotAboutAnOrganismStays(testCase)
            % only a UBERON area is a region; other conditions stay
            obs = conditionObs('img_1', 'animal_1', 'CL:0000540', 'neuron');
            [kept, ~, changed, report] = ndi.migrate.internal.pathSPromotion( ...
                {organism('animal_1'), obs, makeAnchor('img_anchor')}, 'Mode', 'sites');
            testCase.verifyFalse(changed);
            testCase.verifyEqual(report.site_conditions_not_uberon, 1);
            testCase.verifyTrue(isfield(byId(kept, 'img_1').statement, 'conditions'));
            % about a device: not moved, counted
            obs = conditionObs('img_1', 'probe_1', 'uberon:0002436', 'primary visual cortex');
            [~, ~, changed, report] = ndi.migrate.internal.pathSPromotion( ...
                {device('probe_1'), obs, makeAnchor('img_anchor')}, 'Mode', 'sites');
            testCase.verifyFalse(changed);
            testCase.verifyEqual(report.left_about_a_device, 1);
            % a non-area node rides on a plain label variable {name: 'ontology
            % node'} (DID-matlab #218; [non-area image node] is NOT decided, so
            % no ontology term); it stays on the subject
            obs = conditionObs('img_1', 'animal_1', 'CL:0000540', 'neuron');
            obs.statement.conditions(1).variable = term('', 'ontology node');
            [kept, ~, changed, report] = ndi.migrate.internal.pathSPromotion( ...
                {organism('animal_1'), obs, makeAnchor('img_anchor')}, 'Mode', 'sites');
            testCase.verifyFalse(changed);
            testCase.verifyEqual(report.site_conditions_seen, 0);
            testCase.verifyEqual(depValue(byId(kept, 'img_1'), 'entity_id'), 'animal_1');
            % a condition with another variable is not a site
            obs = conditionObs('img_1', 'animal_1', 'uberon:0002436', 'primary visual cortex');
            obs.statement.conditions(1).variable = term('NCIT:C25185', 'Laterality');
            [~, ~, changed] = ndi.migrate.internal.pathSPromotion( ...
                {organism('animal_1'), obs, makeAnchor('img_anchor')}, 'Mode', 'sites');
            testCase.verifyFalse(changed);
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
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', part.entity.type, 'tissue'));
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
            testCase.verifyTrue(ndi.v2.vocabIs('entity_type', part.entity.type, 'tissue'));
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

        % ---- LATERALITY (Jess Haley, 2026-10-21, "a") ---------------------
        % "When a v1 probe/element records several location terms, e.g. a
        % brain area plus a hemisphere, the migrator makes ONE part entity for
        % the area, and states the laterality on that part as a term
        % assertion. It does NOT make a separate part entity per location
        % term." The fixtures are the writer's shape: vhlab-contrast-matlab
        % sophie_add_treatment_info.m writes TWO probe_location documents per
        % probe, {UBERON:0002436, 'primary visual cortex'} and
        % {UBERON:0002812, 'left cerebral hemisphere'} (or 0002813 right), and
        % migrators_j.probe_location turns each into its own anchored site
        % observation about the probe.

        function testAreaPlusHemisphereIsOnePartWithLaterality(testCase)
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyTrue(changed);
            testCase.verifyEqual(countClass(minted, 'entity'), 1, ...
                'one part for the area, not one per location term');
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), part.base.id);
            kinds = assertionsAbout(minted, part.base.id);
            testCase.verifyEqual(numel(kinds), 2);
            v = cellfun(@(x) x.statement.variable.name, kinds, 'UniformOutput', false);
            kind = kinds{strcmp(v, 'anatomical structure')};
            lat = kinds{strcmp(v, 'Laterality')};
            testCase.verifyEqual(kind.term.value.node, 'UBERON:0002436');
            testCase.verifyEqual(kind.statement.variable.node, 'UBERON:0000061');
            testCase.verifyEqual(lat.statement.variable.node, 'NCIT:C25185');
            % the side is kept as the writer wrote it
            testCase.verifyEqual(lat.term.value.node, 'UBERON:0002812');
            testCase.verifyEqual(lat.term.value.name, 'left cerebral hemisphere');
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'parent_id'), 'animal_1');
            % both probe_location facts stay on the probe
            testCase.verifyNotEmpty(byId(kept, 'site_anch_p'));
            testCase.verifyNotEmpty(byId(kept, 'site_anch_q'));
            testCase.verifyEqual([report.located_instruments ...
                report.instruments_area_with_laterality report.laterality_folded ...
                report.laterality_assertions_minted report.parts_minted], [1 1 1 1 1]);
            % the laterality term is not an anatomy term for the UBERON rule
            testCase.verifyEqual([report.anatomy_terms_inspected ...
                report.anatomy_terms_uberon report.anatomy_terms_non_uberon], [1 1 0]);
        end

        function testLeftAndRightProbesOnOneAnimalAreTwoParts(testCase)
            % Soph: 17 of 32 animals carry a left-V1 AND a right-V1 probe. One
            % part per (animal, area, side): never one V1 part with both sides
            structs = [{organism('animal_1'), device('probe_L'), device('probe_R')}, ...
                probeWithSite('a1', 'probe_L', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('a2', 'probe_L', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                probeWithSite('a3', 'probe_R', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('a4', 'probe_R', 'UBERON:0002813', 'right cerebral hemisphere'), ...
                recording('rec_L', 'animal_1', 'probe_L', 'anch_r'), ...
                recording('rec_L2', 'animal_1', 'probe_L', 'anch_r2'), ...
                recording('rec_R', 'animal_1', 'probe_R', 'anch_r3')];
            [kept, minted, ~, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyEqual(countClass(minted, 'entity'), 2);
            pL = depValue(byId(kept, 'rec_L'), 'entity_id');
            testCase.verifyEqual(depValue(byId(kept, 'rec_L2'), 'entity_id'), pL);
            pR = depValue(byId(kept, 'rec_R'), 'entity_id');
            testCase.verifyNotEqual(pL, pR);
            testCase.verifyEqual(sideOf(minted, pL), 'UBERON:0002812');
            testCase.verifyEqual(sideOf(minted, pR), 'UBERON:0002813');
            testCase.verifyEqual(report.laterality_folded, 3);
            % a second pass finds both parts by (animal, area, side)
            [~, m2, ~, r2] = ndi.migrate.internal.pathSPromotion([kept, minted], 'Mode', 'located');
            testCase.verifyEmpty(m2);
            testCase.verifyEqual(r2.parts_found_existing, 2);
        end

        function testSeveralAreasAreLeftAndCounted(testCase)
            % not laterality: two AREAS on one probe -- left as before, counted
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0001950', 'neocortex'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), 'animal_1');
            testCase.verifyEqual(report.instruments_several_areas, 1);
            testCase.verifyEqual(report.left_instrument_has_several_areas, 1);
        end

        function testLateralityIsReadFromTheNodeNotTheLabel(testCase)
            % a label that says "left" on a node not in the laterality table is
            % an AREA: two areas, left and counted
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0001950', 'left neocortex'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [~, ~, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEqual(report.instruments_several_areas, 1);
        end

        function testAHemisphereAloneIsTheRegion(testCase)
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [kept, minted, ~, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), part.base.id);
            kinds = assertionsAbout(minted, part.base.id);
            testCase.verifyEqual(numel(kinds), 1);
            testCase.verifyEqual(kinds{1}.term.value.node, 'UBERON:0002812');
            testCase.verifyEqual(report.instruments_laterality_only, 1);
            testCase.verifyEqual(report.laterality_assertions_minted, 0);
        end

        function testABareSideIsNoRegion(testCase)
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_q', 'probe_1', 'NCIT:C25229', 'Left'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), 'animal_1');
            testCase.verifyEqual(report.left_instrument_has_no_region, 1);
        end

        function testBothSidesOnOneProbeAreLeftAndCounted(testCase)
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('a1', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('a2', 'probe_1', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                probeWithSite('a3', 'probe_1', 'UBERON:0002813', 'right cerebral hemisphere'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [~, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.left_instrument_has_several_sides, 1);
        end

        function testAManipulationAndAnObservationShareTheSidedPart(testCase)
            % manipulations and observations treat their subjects the same: a
            % stimulation through the located probe lands on the same part
            stim = recording('stim_1', 'animal_1', 'probe_1', 'anch_s');
            stim{1}.document_class = dc('manipulation', ...
                {'interaction', 'statement', 'base', 'current', 'value', 'data'});
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r'), stim];
            [kept, minted, ~, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyEqual(countClass(minted, 'entity'), 1);
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), part.base.id);
            testCase.verifyEqual(depValue(byId(kept, 'stim_1'), 'entity_id'), part.base.id);
            testCase.verifyEqual([report.observations_retargeted ...
                report.manipulations_retargeted report.laterality_folded], [1 1 2]);
        end

        function testSitesFoldTheSideOntoTheAreaPart(testCase)
            % 'sites': one source document wrote an area AND a side for an
            % injection (same anchor, same animal) -- one part, laterality
            % asserted on it, both site observations superseded
            s = treatmentWithSite('anch_1', 'animal_1', 'UBERON:0002812', ...
                'left cerebral hemisphere');
            s{end+1} = siteObs('anch_1', 'animal_1', 'UBERON:0002436', ...
                'primary visual cortex', 'site_anch_1_area');
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(s, 'Mode', 'sites');
            testCase.verifyTrue(changed);
            testCase.verifyEqual(countClass(minted, 'entity'), 1);
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'manip_anch_1'), 'entity_id'), part.base.id);
            testCase.verifyEmpty(byId(kept, 'site_anch_1'));
            testCase.verifyEmpty(byId(kept, 'site_anch_1_area'));
            testCase.verifyEqual(sideOf(minted, part.base.id), 'UBERON:0002812');
            testCase.verifyEqual([report.site_observations_promoted ...
                report.sites_laterality_folded report.laterality_assertions_minted], [1 1 1]);
        end

        function testSortedUnitsOfALocatedProbeAreNotMoved(testCase)
            % 20211116: the located n-trode `leftcortex` (V1 + left cerebral
            % hemisphere) has 21 sorted `spikes` units (underlying_element_id
            % the probe). Each unit is migrated as an entity with an `element
            % type` kind assertion; an observation about a unit taken with the
            % probe is not about the specimen, so no region part is made for
            % it (CI run 39658733813 minted 22 parts there, one per unit).
            u1 = entityOf('unit_1', 'cell'); u2 = entityOf('unit_2', '');
            u2.document_class = dc('subject', {'base'});    % pre-#88 element
            structs = [{organism('animal_1'), device('probe_1'), u1, u2, ...
                elementType('unit_1', 'spikes'), elementType('unit_2', 'spikes'), ...
                elementType('probe_1', 'n-trode')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0002436', 'primary visual cortex'), ...
                probeWithSite('anch_q', 'probe_1', 'UBERON:0002812', 'left cerebral hemisphere'), ...
                recording('rec_u1', 'unit_1', 'probe_1', 'anch_r1'), ...
                recording('rec_u2', 'unit_2', 'probe_1', 'anch_r2'), ...
                recording('rec_a', 'animal_1', 'probe_1', 'anch_r3')];
            [kept, minted, ~, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyEqual(countClass(minted, 'entity'), 1, ...
                'one part, for the animal; none per unit');
            testCase.verifyEqual(depValue(byId(kept, 'rec_u1'), 'entity_id'), 'unit_1');
            testCase.verifyEqual(depValue(byId(kept, 'rec_u2'), 'entity_id'), 'unit_2');
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'rec_a'), 'entity_id'), part.base.id);
            testCase.verifyEqual(report.left_about_an_element, 2);
        end

        function testACellOrCultureIsNotARegionParent(testCase)
            structs = [{entityOf('cell_1', 'cell'), entityOf('cult_1', 'culture'), ...
                device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', 'BNST'), ...
                recording('rec_1', 'cell_1', 'probe_1', 'anch_r'), ...
                recording('rec_2', 'cult_1', 'probe_1', 'anch_r2')];
            [~, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.left_about_another_entity_type, 2);
        end

        % ---- SLICES (Jess Haley, 2026-10-21, "a") --------------------------
        % "The recording observation points at a BNST part entity that is a
        % part of the SLICE, and the slice is a part of the animal (animal ->
        % slice -> region)." Dabrowska's writer (doImport.m step 6) gives
        % every patch probe one probe_location, {UBERON:0001880, 'bed nucleus
        % of stria terminalis (BNST)'}; sliceTetanus makes the slice.

        function testARecordingOnASliceTargetsTheSlicesRegionPart(testCase)
            structs = [{organism('animal_1'), device('probe_1'), device('probe_2'), ...
                tissue('slice_a'), partOf('slice_a', 'animal_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', ...
                    'bed nucleus of stria terminalis (BNST)'), ...
                probeWithSite('anch_p2', 'probe_2', 'UBERON:0001880', ...
                    'bed nucleus of stria terminalis (BNST)'), ...
                recording('rec_1', 'slice_a', 'probe_1', 'anch_r'), ...
                recording('rec_2', 'slice_a', 'probe_2', 'anch_r2')];
            [kept, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyTrue(changed);
            testCase.verifyEqual(countClass(minted, 'entity'), 1, ...
                'one region part per slice, shared by its recordings');
            part = firstOfClass(minted, 'entity');
            testCase.verifyEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), part.base.id);
            testCase.verifyEqual(depValue(byId(kept, 'rec_2'), 'entity_id'), part.base.id);
            rel = firstOfClass(minted, 'directed_relation');
            testCase.verifyEqual(depValue(rel, 'child_id'), part.base.id);
            testCase.verifyEqual(depValue(rel, 'parent_id'), 'slice_a');
            testCase.verifyEqual([report.statements_retargeted_onto_slice_parts ...
                report.parts_minted_on_slices], [2 1]);
        end

        function testASliceRegionIsNotTheAnimalRegion(testCase)
            % a recording on the slice and one still on the animal: two BNST
            % parts, one under each
            structs = [{organism('animal_1'), device('probe_1'), ...
                tissue('slice_a'), partOf('slice_a', 'animal_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', 'BNST'), ...
                recording('rec_1', 'slice_a', 'probe_1', 'anch_r'), ...
                recording('rec_2', 'animal_1', 'probe_1', 'anch_r2')];
            [kept, minted] = ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyEqual(countClass(minted, 'entity'), 2);
            testCase.verifyNotEqual(depValue(byId(kept, 'rec_1'), 'entity_id'), ...
                depValue(byId(kept, 'rec_2'), 'entity_id'));
        end

        function testARecordingOnARegionPartOrALooseTissueIsLeft(testCase)
            structs = [{organism('animal_1'), device('probe_1'), tissue('loose')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', 'BNST'), ...
                recording('rec_1', 'loose', 'probe_1', 'anch_r')];
            [~, ~, changed, report] = ...
                ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            testCase.verifyFalse(changed);
            testCase.verifyEqual(report.left_about_a_tissue_part_of_nothing, 1);

            % already on a region part: a second pass leaves it there
            structs = [{organism('animal_1'), device('probe_1')}, ...
                probeWithSite('anch_p', 'probe_1', 'UBERON:0001880', 'BNST'), ...
                recording('rec_1', 'animal_1', 'probe_1', 'anch_r')];
            [k1, m1] = ndi.migrate.internal.pathSPromotion(structs, 'Mode', 'located');
            [~, m2, ch2, r2] = ndi.migrate.internal.pathSPromotion([k1, m1], 'Mode', 'located');
            testCase.verifyFalse(ch2);
            testCase.verifyEmpty(m2);
            testCase.verifyEqual(r2.left_about_a_region_part, 1);
        end

        % ---- UBERON (Jess Haley, 2026-10-21, "b") --------------------------
        % "A region part entity's anatomy term must be UBERON. A non-UBERON
        % anatomy term is NOT mapped: it is kept as written, counted and
        % reported." Dabrowska's optogenetic target (doImport.m step 7,
        % `anatomy(optoLocation)`) is UBERON:0001930 / 0002034 / 0001929.

        function testDabrowskaOptoTargetIsUberon(testCase)
            s = treatmentWithSite('anch_1', 'animal_1', 'UBERON:0002034', '');
            [~, ~, ~, report] = ndi.migrate.internal.pathSPromotion(s, 'Mode', 'sites');
            testCase.verifyEqual([report.anatomy_terms_inspected ...
                report.anatomy_terms_uberon report.anatomy_terms_non_uberon], [1 1 0]);
            testCase.verifyEmpty(report.anatomy_non_uberon);
        end

        function testANonUberonAnatomyTermIsKeptAndReported(testCase)
            a = treatmentWithSite('anch_1', 'animal_1', 'WBbt:0005735', 'nerve ring');
            b = treatmentWithSite('anch_2', 'animal_2', 'WBbt:0005735', 'nerve ring');
            c = treatmentWithSite('anch_3', 'animal_1', '', 'dorsal horn');
            [~, minted, changed, report] = ...
                ndi.migrate.internal.pathSPromotion([a, b, c], 'Mode', 'sites');
            testCase.verifyTrue(changed);
            kinds = {};
            for k = 1:numel(minted)
                if strcmp(minted{k}.document_class.class_name, 'assertion')
                    kinds{end+1} = minted{k}.term.value; %#ok<AGROW>
                end
            end
            testCase.verifyEqual(numel(kinds), 3);
            % kept as written: no mapping to an UBERON node
            testCase.verifyEqual(kinds{1}.node, 'WBbt:0005735');
            testCase.verifyEqual(kinds{1}.name, 'nerve ring');
            testCase.verifyEqual([report.anatomy_terms_inspected ...
                report.anatomy_terms_uberon report.anatomy_terms_non_uberon], [3 0 3]);
            list = report.anatomy_non_uberon;
            testCase.verifyEqual(numel(list), 2);
            testCase.verifyEqual(list(1).node, 'WBbt:0005735');
            testCase.verifyEqual(list(1).count, 2);
            testCase.verifyEqual(list(2).name, 'dorsal horn');
            testCase.verifyEqual(list(2).count, 1);
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

function r = partOf(childId, parentId)
r = struct();
r.document_class = dc('directed_relation', {'relation', 'base'});
r.depends_on = [dep('child_id', childId), dep('parent_id', parentId)];
r.base = base(['rel_' childId]);
r.directed_relation = struct('relation', term('BFO:0000050', 'part_of'));
end

function out = assertionsAbout(bodies, id)
out = {};
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, 'assertion') ...
            && strcmp(depValue(bodies{k}, 'entity_id'), id)
        out{end+1} = bodies{k}; %#ok<AGROW>
    end
end
end

function node = sideOf(bodies, partId)
node = '';
a = assertionsAbout(bodies, partId);
for k = 1:numel(a)
    if strcmp(a{k}.statement.variable.name, 'Laterality')
        node = a{k}.term.value.node;
    end
end
end

function a = elementType(entityId, type)
% the kind assertion migrators_j.element writes about every v1 element
a = struct();
a.document_class = dc('assertion', {'statement', 'base', 'term', 'value', 'data'});
a.depends_on = dep('entity_id', entityId);
a.base = base(['etype_' entityId]);
a.statement = struct('variable', term('', 'element type'));
a.term = struct('value', term('', type));
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
    'superclasses', sc, 'schema_version', 'did_v2');
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

function o = conditionObs(id, subjectId, node, name)
% an intensity observation of SUBJECTID naming its area as a condition, as
% DID-matlab #218's ontology_image raster writes it
o = struct();
o.document_class = dc('observation', ...
    {'interaction', 'statement', 'base', 'intensity', 'value', 'data'});
o.depends_on = [dep('entity_id', subjectId), dep('time_reference_id', 'img_anchor')];
o.base = base(id);
o.statement = struct('variable', term('NCIT:C221750', 'Imaging Signal Intensity'), ...
    'conditions', struct('variable', term('NCIT:C13717', 'Anatomic Site'), ...
        'term', term(node, name)));
o.value = struct('data_body', true);
end
