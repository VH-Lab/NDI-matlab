classdef TestSliceTetanus < matlab.unittest.TestCase
%TESTSLICETETANUS ndi.migrate.internal.sliceTetanus on REAL Dab documents.
%
%   The v1 side is verbatim Dab corpus documents (dab_slice_tetanus_v1.json,
%   224 documents read out of Dab.zip): two animals, three bath stimulators,
%   their patch probes, every stimulus_bath / epoch-time / epochfiles /
%   approach document on those stimulators, the two tetanus treatments and the
%   animals' openMINDS records. It holds both hard cases:
%
%     sd_rat_AVPCre_221122_BNSTIII_SCN   two slices, `_a` and `_b`, each
%                                        tetanized separately (one run each)
%     sd_rat_AVPCre_221202_BNSTI_SCN     one stimulator, two runs: Dec 02, and
%                                        Nov 28, whose files sit in a `Nov 28
%                                        2022` folder nested in `Dec 02 2022`
%
%   The migrated side is built here in the did-schema #88 shapes the real
%   passes emit (stimulusBathToBath + epochAnchorFold: a `manipulation` with
%   the `formulation` kind and a `value_id` edge (a bath is not a dose, Jess
%   Haley 2026-10-21), the stimulus_bath id, the stimulator as instrument,
%   anchored by a `relative_time_reference` to the epoch entity;
%   resolveEpochProbemap: per-epoch term manipulations / voltage observations;
%   the treatment migrator + Path S: a term manipulation on a `tissue` part
%   entity; subjectStrainAssembly: the animal `instance_of` its strain;
%   openminds_stimulus: a passthrough). testThePreEightyEightSpellingGivesTheSamePlan
%   feeds the pre-#88 spelling of the same documents. The whole pipeline is
%   proven on the corpus by TestMigrateLocalEtaDab.
%
%   Decided by Jess Haley, 2026-10-21 (dabrowska/V2_decisions.md).

    properties
        V1
        Migrated
        EpochIndex
        Plan
        Report
    end

    methods (TestClassSetup)
        function build(testCase)
            here = fileparts(mfilename('fullpath'));
            raw = jsondecode(fileread(fullfile(here, 'dab_slice_tetanus_v1.json')));
            if isstruct(raw); raw = num2cell(raw); end
            testCase.V1 = raw(:)';
            [testCase.Migrated, testCase.EpochIndex] = simulateMigrated(testCase.V1, false);
            [testCase.Plan, testCase.Report] = ndi.migrate.internal.sliceTetanus( ...
                testCase.V1, testCase.Migrated, testCase.EpochIndex);
        end
    end

    methods (Test)
        function testDenominators(testCase)
            r = testCase.Report;
            verifyEqual(testCase, r.v1_documents_read, 224);
            verifyEqual(testCase, r.approach_labels, 49);
            verifyEqual(testCase, r.stimulus_bath_documents, 49);
            verifyEqual(testCase, r.stimulators, 3);
            verifyEqual(testCase, r.slice_bath_stimulators, 3);
        end

        function testOneSlicePerStimulatorAndRunAndANewAnimalForTheNestedDay(testCase)
            r = testCase.Report;
            verifyEqual(testCase, r.slices, 4, '221122 _a, _b; 221202 _a Dec 02; and the Nov 28 slice');
            verifyEqual(testCase, r.new_animals, 1);
            verifyEqual(testCase, r.epochs_on_a_nested_date, 11);
            animal = mintedEntities(testCase.Plan, 'organism');
            verifyNumElements(testCase, animal, 1);
            verifyEqual(testCase, animal{1}.entity.local_identifier, ...
                'sd_rat_AVPCre_221128_BNSTI_SCN@dabrowska-lab.rosalindfranklin.edu');
            dec02 = '';
            for k = 1:numel(testCase.V1)
                b = testCase.V1{k};
                if strcmp(b.document_class.class_name, 'subject') && ...
                        strcmp(b.subject.local_identifier, ...
                        'sd_rat_AVPCre_221202_BNSTI_SCN@dabrowska-lab.rosalindfranklin.edu')
                    dec02 = b.base.id;
                end
            end
            % #88: the animal's strain is its instance_of relation
            nStrain = 0;
            for k = 1:numel(testCase.Migrated)
                b = testCase.Migrated{k};
                if strcmp(b.document_class.class_name, 'directed_relation') ...
                        && ndi.v2.vocabIs('relation', b.directed_relation.relation, 'instance_of') ...
                        && strcmp(dep(b, 'child_id'), dec02)
                    nStrain = nStrain + 1;
                end
            end
            verifyGreaterThan(testCase, nStrain, 0);
            verifyEqual(testCase, r.new_animal_strain_assertions_copied, nStrain);
            copied = mintedRelations(testCase.Plan, 'instance_of');
            verifyNumElements(testCase, copied, nStrain);
            verifyEqual(testCase, dep(copied{1}, 'child_id'), animal{1}.base.id);

            slices = mintedEntities(testCase.Plan, 'tissue');
            lids = sort(cellfun(@(s) s.entity.local_identifier, slices, 'UniformOutput', false));
            verifyEqual(testCase, lids, sort({ ...
                'sd_rat_AVPCre_221122_BNSTIII_SCN_a@dabrowska-lab.rosalindfranklin.edu', ...
                'sd_rat_AVPCre_221122_BNSTIII_SCN_b@dabrowska-lab.rosalindfranklin.edu', ...
                'sd_rat_AVPCre_221202_BNSTI_SCN_a@dabrowska-lab.rosalindfranklin.edu', ...
                'sd_rat_AVPCre_221128_BNSTI_SCN_a@dabrowska-lab.rosalindfranklin.edu'}));
            rels = mintedRelations(testCase.Plan, 'part_of');
            verifyNumElements(testCase, rels, 4);
            novSlice = slices{strcmp(cellfun(@(s) s.entity.local_identifier, slices, ...
                'UniformOutput', false), ...
                'sd_rat_AVPCre_221128_BNSTI_SCN_a@dabrowska-lab.rosalindfranklin.edu')};
            rel = rels{cellfun(@(x) strcmp(dep(x, 'child_id'), novSlice.base.id), rels)};
            verifyEqual(testCase, dep(rel, 'parent_id'), animal{1}.base.id, ...
                'the Nov 28 slice is part_of the new animal');
        end

        function testEveryBathAndRecordingStatementMovesToItsSlice(testCase)
            r = testCase.Report;
            verifyEqual(testCase, r.epoch_statements_examined, 196, ...
                '49 baths + 49 probemap stimulator rows + 98 recording rows');
            verifyEqual(testCase, [r.epoch_statements_matched r.epoch_statements_unmatched], [196 0]);
            sliceIds = cellfun(@(s) s.base.id, mintedEntities(testCase.Plan, 'tissue'), ...
                'UniformOutput', false);
            for k = 1:numel(testCase.Plan.replaced)
                s = testCase.Plan.replaced{k};
                if strcmp(s.document_class.class_name, 'directed_relation')
                    verifyTrue(testCase, any(strcmp(dep(s, 'parent_id'), sliceIds)));
                else
                    verifyTrue(testCase, any(strcmp(dep(s, 'entity_id'), sliceIds)));
                end
            end
        end

        function testOneTetanusPerRunWithItsRegionAndFolderProtocol(testCase)
            r = testCase.Report;
            verifyEqual(testCase, r.tetanus_manipulations, 4);
            verifyEqual(testCase, [r.tetanus_with_target_region r.tetanus_without_target_region], [3 1], ...
                'the Nov 28 animal has no treatment record');
            verifyEqual(testCase, [r.tetanus_with_parameters r.tetanus_without_parameters], [2 2], ...
                '221202 (both runs) sits under TLS 10 Hz 20 s; 221122 under plain TLS');
            ms = tetanusManipulations(testCase.Plan);
            verifyNumElements(testCase, ms, 4);
            nParam = 0;
            for k = 1:numel(ms)
                m = ms{k};
                verifyEqual(testCase, {m.document_class.superclasses.class_name}, ...
                    {'interaction', 'statement', 'base', 'term', 'value', 'data'});
                verifyEqual(testCase, m.interaction.method.term.name, 'optogenetic tetanus stimulation');
                verifyEqual(testCase, m.interaction.method.term.node, 'EMPTY:0000358');
                verifyEqual(testCase, m.term.value.node, 'EMPTY:0000358');
                verifyNotEmpty(testCase, dep(m, 'instrument_id'));
                if isfield(m.statement, 'conditions')
                    c = m.statement.conditions;
                    verifyEqual(testCase, c.variable.node, 'EMPTY:0000074');
                    verifyTrue(testCase, startsWith(c.term.node, 'UBERON:'));
                end
                if isfield(m.interaction.method, 'parameters')
                    nParam = nParam + 1;
                    p = m.interaction.method.parameters;
                    verifyNumElements(testCase, p, 2, ...
                        'method.parameters is an entry list on did-schema #88');
                    verifyEqual(testCase, {p(1).variable.name, p(2).variable.name}, ...
                        {'frequency', 'duration'});
                    verifyEqual(testCase, [p(1).quantity.value p(2).quantity.value], [10 20]);
                    verifyEqual(testCase, {p(1).quantity.source_value, p(2).quantity.source_value}, ...
                        {'10', '20'});
                    verifyEqual(testCase, p(1).unit.node, 'om:hertz');
                    verifyEqual(testCase, p(2).unit.node, 'om:second-Time');
                end
            end
            verifyEqual(testCase, nParam, 2);
        end

        function testTheWindowIsRelativeToTheLastBeforeEpoch(testCase)
            ms = tetanusManipulations(testCase.Plan);
            refs = mintedOfClass(testCase.Plan, 'relative_time_reference');
            verifyNumElements(testCase, refs, 4);
            for k = 1:numel(ms)
                ref = refs{cellfun(@(x) strcmp(x.base.id, dep(ms{k}, 'time_reference_id')), refs)};
                v = ref.relative_time_reference.value;
                ndi.unittest.migrate.verifyClock(testCase, v.clock, 'exp_global_time');   % by node [clock terms get nodes]
                verifyGreaterThan(testCase, v.start.seconds, 0);
                verifyGreaterThan(testCase, v.duration.seconds, 0);
                verifyLessThan(testCase, v.duration.seconds, 10 * 60);
                verifyTrue(testCase, any(strcmp(dep(ref, 'referent_id'), ...
                    {testCase.EpochIndex.epoch_document_id})));
            end
        end

        function testMintedBodiesValidateAgainstTheSchema(testCase)
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; no schema to validate against.');
            end
            bodies = testCase.Plan.minted;
            sub = did2.convert.v1_to_v2(bodies, 'Validate', true, ...
                'TargetVersion', 'V_eta', 'Verbose', false);
            msg = '';
            for k = 1:numel(sub.quarantine)
                msg = sprintf('%s\n  %s: %s', msg, sub.quarantine(k).class_name, sub.quarantine(k).reason);
            end
            verifyEmpty(testCase, sub.quarantine, ['minted bodies quarantined:' msg]);
            verifyNumElements(testCase, sub.migrated, numel(bodies));
        end

        function testEveryLabelRebuildsAndIsDropped(testCase)
            r = testCase.Report;
            verifyEqual(testCase, [r.labels_rebuilt r.labels_not_rebuilt], [49 0]);
            verifyEqual(testCase, r.approach_labels_removed, 49);
        end

        function testThePerAnimalTreatmentIsSuperseded(testCase)
            r = testCase.Report;
            verifyEqual(testCase, r.treatment_manipulations_found, 2);
            verifyEqual(testCase, r.treatment_manipulations_superseded, 2);
            verifyEqual(testCase, r.treatment_part_subjects_superseded, 2);
            verifyEqual(testCase, r.treatment_anchors_removed, 2);
            verifyEqual(testCase, r.removals_withheld_still_referenced, 0);
        end

        function testNothingRemovedIsStillReferenced(testCase)
            removed = containers.Map(testCase.Plan.removed, ...
                num2cell(true(1, numel(testCase.Plan.removed))));
            kept = [testCase.Migrated, testCase.Plan.minted];
            for k = 1:numel(kept)
                b = kept{k};
                if isKey(removed, b.base.id); continue; end
                for e = 1:numel(b.depends_on)
                    verifyFalse(testCase, isKey(removed, b.depends_on(e).value), ...
                        sprintf('%s still points at a removed document', b.base.id));
                end
            end
        end

        function testThePreEightyEightSpellingGivesTheSamePlan(testCase)
            % pass-1 output in the pre-#88 spelling (subject, term_assertion +
            % strain_id, subject_id, time_reference_1, relative_reference,
            % child / parent) is read the same way: every count matches
            [mig, idx] = simulateMigrated(testCase.V1, true);
            [plan, r] = ndi.migrate.internal.sliceTetanus(testCase.V1, mig, idx);
            r0 = testCase.Report;
            for f = {'slices', 'new_animals', 'new_animal_strain_assertions_copied', ...
                    'epoch_statements_examined', 'epoch_statements_matched', ...
                    'tetanus_manipulations', 'tetanus_with_target_region', ...
                    'tetanus_with_parameters', 'labels_rebuilt', ...
                    'approach_labels_removed', 'treatment_manipulations_superseded', ...
                    'treatment_part_subjects_superseded', 'treatment_anchors_removed', ...
                    'documents_minted', 'documents_reattributed', 'documents_removed'}
                verifyEqual(testCase, r.(f{1}), r0.(f{1}), f{1});
            end
            verifyNumElements(testCase, tetanusManipulations(plan), 4);
        end

        function testRegionPartsLeaveTheSliceMatchingUnchanged(testCase)
            % Region parts (Jess Haley, 2026-10-21): the Dabrowska baths are
            % the generic 'bath' (NCIm:C0179246), so they target the whole
            % slice/prep and sliceTetanus matches exactly as before. Every
            % patch probe is located in BNST (Dab's 404 probe_location
            % documents all say UBERON:0001880), as ndi.migrate.local runs it:
            % Path S 'sites' -> sliceTetanus -> Path S 'located'.
            mig = testCase.Migrated;
            probes = {};
            for k = 1:numel(mig)
                if strcmp(mig{k}.document_class.class_name, 'observation')
                    probes{end+1} = dep(mig{k}, 'instrument_id'); %#ok<AGROW>
                end
            end
            probes = unique(probes);
            verifyNotEmpty(testCase, probes);
            for k = 1:numel(probes)
                mig = [mig, probeLocation(probes{k}, k)]; %#ok<AGROW>
            end

            [k1, m1, ch1, r1] = ndi.migrate.internal.pathSPromotion(mig, 'Mode', 'sites');
            verifyFalse(testCase, ch1, 'a generic bath carries no site to promote');
            verifyEmpty(testCase, m1);
            verifyEqual(testCase, r1.site_observations_not_co_anchored, numel(probes));

            [plan, r] = ndi.migrate.internal.sliceTetanus(testCase.V1, k1, testCase.EpochIndex);
            r0 = testCase.Report;
            for f = {'slices', 'new_animals', 'epoch_statements_examined', ...
                    'epoch_statements_matched', 'epoch_statements_unmatched', ...
                    'unanchored_statements_matched', 'tetanus_manipulations', ...
                    'tetanus_with_target_region', 'labels_rebuilt', ...
                    'treatment_manipulations_superseded', ...
                    'treatment_part_subjects_superseded', 'documents_reattributed'}
                verifyEqual(testCase, r.(f{1}), r0.(f{1}), f{1});
            end

            % after the slices (Jess Haley, 2026-10-21, "a"): every recording
            % points at the BNST part OF ITS SLICE, and the slice is part of
            % the animal (animal -> slice -> region). One part per slice and
            % region, shared by every recording on that slice; the slice
            % sliceTetanus minted is reused, never a second one.
            after = applyPlan(k1, plan);
            sliceOf = containers.Map();      % recording id -> slice it was on
            slices = mintedEntities(plan, 'tissue');
            sliceIds = cellfun(@(b) b.base.id, slices, 'UniformOutput', false);
            for k = 1:numel(after)
                b = after{k};
                if strcmp(b.document_class.class_name, 'observation') ...
                        && any(strcmp(dep(b, 'entity_id'), sliceIds))
                    sliceOf(b.base.id) = dep(b, 'entity_id');
                end
            end
            verifyEqual(testCase, double(sliceOf.Count), 98);
            [k2, m2, ch2, r2] = ndi.migrate.internal.pathSPromotion(after, 'Mode', 'located');
            verifyTrue(testCase, ch2);
            verifyEqual(testCase, r2.located_instruments, numel(probes));
            verifyEqual(testCase, r2.instruments_one_area, numel(probes));
            verifyEqual(testCase, r2.statements_with_located_instrument, 98);
            verifyEqual(testCase, r2.statements_retargeted_onto_slice_parts, 98);
            verifyEqual(testCase, r2.observations_retargeted, 98);
            verifyEqual(testCase, r2.left_about_a_region_part, 0);
            verifyEqual(testCase, r2.left_about_a_tissue_part_of_nothing, 0);
            usedSlices = unique(sliceOf.values);
            verifyEqual(testCase, r2.parts_minted, numel(usedSlices), ...
                'one BNST part per slice, not one per recording');
            verifyEqual(testCase, r2.parts_minted_on_slices, numel(usedSlices));
            verifyEqual(testCase, [r2.anatomy_terms_inspected r2.anatomy_terms_uberon ...
                r2.anatomy_terms_non_uberon], [98 98 0]);
            % no new slice: the only tissue entities minted are the region parts
            parentOf = containers.Map();
            for k = 1:numel(m2)
                if strcmp(m2{k}.document_class.class_name, 'directed_relation')
                    parentOf(dep(m2{k}, 'child_id')) = dep(m2{k}, 'parent_id');
                end
            end
            ids = sliceOf.keys;
            for k = 1:numel(ids)
                rec = [];
                for j = 1:numel(k2)
                    if strcmp(k2{j}.base.id, ids{k}); rec = k2{j}; break; end
                end
                part = dep(rec, 'entity_id');
                verifyTrue(testCase, isKey(parentOf, part), ids{k});
                verifyEqual(testCase, parentOf(part), sliceOf(ids{k}), ...
                    'the region part is part of the slice the recording was on');
            end
            % the bath stays on the slice: same chain
            for k = 1:numel(k2)
                b = k2{k};
                if strcmp(b.document_class.class_name, 'manipulation') ...
                        && isfield(b, 'formulation')
                    verifyFalse(testCase, isKey(parentOf, dep(b, 'entity_id')));
                end
            end
            verifyEqual(testCase, numel(k2), numel(after));
        end
    end
end

function b = probeLocation(probeId, n)
% a pass-1 probe_location: a site term observation ABOUT the probe, anchored
% to the session (migrators_j.probe_location)
a = sprintf('ploc_anchor_%03d', n);
b = body('observation', sprintf('ploc_%03d', n), 'sess', ...
    [struct('name', 'entity_id', 'value', probeId), ...
     struct('name', 'time_reference_id', 'value', a)]);
b.document_class.superclasses = struct('class_name', ...
    {'interaction', 'statement', 'base', 'term', 'value', 'data'}, 'class_version', '1.0.0');
b.statement = struct('variable', struct('node', '', 'name', 'anatomical location'));
b.term = struct('value', struct('node', 'UBERON:0001880', ...
    'name', 'bed nucleus of stria terminalis (BNST)'));
r = body('relative_time_reference', a, 'sess', ...
    struct('name', 'referent_id', 'value', 'sessiondoc'));
b = {b, r};
end

function out = applyPlan(M, plan)
% what ndi.migrate.local's resolveSliceTetanus does with a plan that folded
removed = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(plan.removed); removed(plan.removed{k}) = true; end
replaced = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(plan.replaced); replaced(plan.replaced{k}.base.id) = plan.replaced{k}; end
out = {};
for k = 1:numel(M)
    id = M{k}.base.id;
    if isKey(removed, id); continue; end
    if isKey(replaced, id); out{end+1} = replaced(id); else; out{end+1} = M{k}; end %#ok<AGROW>
end
out = [out, plan.minted];
end


function [M, idx] = simulateMigrated(v1, pre88)
%SIMULATEMIGRATED The pass-1 + earlier second-pass output for V1, in the
%   did-schema #88 spelling, or the pre-#88 one when PRE88 is true.
M = {}; idx = struct('session_id', {}, 'local_identifier', {}, 'epoch_document_id', {});
epochDoc = containers.Map();
els = containers.Map(); subjByLid = containers.Map(); elByName = containers.Map();
for k = 1:numel(v1)
    b = v1{k};
    switch b.document_class.class_name
        case 'element'
            els(b.base.id) = b;
            elByName([b.base.session_id '|' b.element.name]) = b.base.id;
        case 'subject'
            subjByLid(b.subject.local_identifier) = b.base.id;
    end
end
n = 0;
if pre88
    ABOUT = 'subject_id'; TR = 'time_reference_1'; CHILD = 'child'; PARENT = 'parent';
else
    ABOUT = 'entity_id'; TR = 'time_reference_id'; CHILD = 'child_id'; PARENT = 'parent_id';
end
for k = 1:numel(v1)
    b = v1{k}; s = b.base.session_id;
    switch b.document_class.class_name
        case 'stimulus_bath'
            st = v1dep(b, 'stimulus_element_id');
            a = anchor(s, b.epochid.epochid);
            bathKind = 'formulation';   % a bath is not a dose (Jess Haley, 2026-10-21)
            if pre88; bathKind = 'dose'; end
            M{end+1} = statement('manipulation', bathKind, b.base.id, s, ...
                [struct('name', ABOUT, 'value', v1dep(els(st), 'subject_id')), ...
                 struct('name', 'instrument_id', 'value', st), ...
                 struct('name', TR, 'value', a)]); %#ok<AGROW>
        case 'epochfiles_ingested'
            ep = b.epochfiles_ingested.epoch_id;
            rows = strsplit(strtrim(b.epochfiles_ingested.epochprobemap), newline);
            a = anchor(s, ep);
            for q = 2:numel(rows)
                c = strsplit(rows{q}, sprintf('\t'));
                d = [struct('name', ABOUT, 'value', subjByLid(c{5})), ...
                     struct('name', 'instrument_id', 'value', elByName([s '|' c{1}])), ...
                     struct('name', TR, 'value', a)];
                if strcmp(c{3}, 'stimulator')
                    x = statement('manipulation', 'term', uid(), s, d);
                else
                    x = statement('observation', 'voltage', uid(), s, d);
                end
                M{end+1} = x; %#ok<AGROW>
            end
        case 'openminds_stimulus'
            M{end+1} = body('openminds_stimulus', b.base.id, s, ...
                struct('name', 'stimulus_element_id', 'value', v1dep(b, 'stimulus_element_id'))); %#ok<AGROW>
        case 'treatment'
            animal = v1dep(b, 'subject_id'); sa = uid(); part = uid();
            M{end+1} = sessionAnchor(sa, s); %#ok<AGROW>
            t = statement('manipulation', 'term', b.base.id, s, ...
                [struct('name', ABOUT, 'value', part), struct('name', TR, 'value', sa)]);
            v = struct('variable', struct('node', 'EMPTY:0000074', ...
                'name', 'Optogenetic Tetanus Stimulation'));
            if pre88; t.subject_statement = v; else; t.statement = v; end
            M{end+1} = t; %#ok<AGROW>
            if pre88
                p = body('subject', part, s, struct('name', {}, 'value', {}));
                p.base.name = 'migrated_part_x';
            else
                p = entity(part, s, 'tissue');
            end
            M{end+1} = p; %#ok<AGROW>
            M{end+1} = statement('assertion', 'term', uid(), s, ...
                struct('name', ABOUT, 'value', part)); %#ok<AGROW>
            r = body('directed_relation', uid(), s, ...
                [struct('name', CHILD, 'value', part), struct('name', PARENT, 'value', animal)]);
            r.directed_relation = struct('relation', struct('node', 'BFO:0000050', 'name', 'part_of'));
            M{end+1} = r; %#ok<AGROW>
        case 'element'
            if pre88
                M{end+1} = body('subject', b.base.id, s, struct('name', {}, 'value', {})); %#ok<AGROW>
            else
                M{end+1} = entity(b.base.id, s, 'device'); %#ok<AGROW>
            end
        case 'subject'
            if pre88
                M{end+1} = body('subject', b.base.id, s, struct('name', {}, 'value', {})); %#ok<AGROW>
            else
                M{end+1} = entity(b.base.id, s, 'organism'); %#ok<AGROW>
            end
        case 'openminds_subject'
            if contains(b.openminds.openminds_type, 'Strain')
                if pre88
                    M{end+1} = statement('assertion', 'term', uid(), s, ...
                        [struct('name', ABOUT, 'value', v1dep(b, 'subject_id')), ...
                         struct('name', 'strain_id', 'value', 'strainentity')]); %#ok<AGROW>
                else
                    r = body('directed_relation', uid(), s, ...
                        [struct('name', CHILD, 'value', v1dep(b, 'subject_id')), ...
                         struct('name', PARENT, 'value', 'strainentity')]);
                    r.directed_relation = struct('relation', struct('node', '', 'name', 'instance_of'));
                    M{end+1} = r; %#ok<AGROW>
                end
            end
    end
end
    function id = uid()
        n = n + 1; id = sprintf('sim%06d', n);
    end
    function e = epoch(s, ep)
        key = [s '|' ep];
        if ~isKey(epochDoc, key)
            e = uid(); epochDoc(key) = e;
            idx(end+1) = struct('session_id', s, 'local_identifier', ep, 'epoch_document_id', e);
            M{end+1} = entity(e, s, 'epoch');
        end
        e = epochDoc(key);
    end
    function a = anchor(s, ep)
        a = uid();
        e = epoch(s, ep);
        if pre88
            M{end+1} = body('relative_reference', a, s, struct('name', 'relative_to', 'value', e));
        else
            M{end+1} = body('relative_time_reference', a, s, struct('name', 'referent_id', 'value', e));
        end
    end
    function x = sessionAnchor(id, s)
        if pre88
            x = body('relative_reference', id, s, struct('name', 'relative_to', 'value', 'sessiondoc'));
        else
            x = body('relative_time_reference', id, s, struct('name', 'referent_id', 'value', 'sessiondoc'));
        end
    end
    function x = statement(direction, kind, id, s, deps)
        if pre88
            x = body([kind '_' direction], id, s, deps);
        else
            x = body(direction, id, s, deps);
            own = {'interaction', 'statement', 'base'};
            if strcmp(direction, 'assertion'); own = {'statement', 'base'}; end
            x.document_class.superclasses = struct('class_name', ...
                [own, {kind, 'value', 'data'}], 'class_version', '1.0.0');
        end
    end
end

function b = entity(id, s, type)
b = body('entity', id, s, struct('name', {}, 'value', {}));
b.document_class.superclasses = struct('class_name', 'base', 'class_version', '1.0.0');
b.entity = struct('type', struct('node', '', 'name', type), 'local_identifier', id);
end

function b = body(cls, id, s, deps)
b = struct();
b.document_class = struct('class_name', cls, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {}, 'class_version', {}), 'schema_version', 'did_v2');
b.depends_on = deps;
b.base = struct('id', id, 'session_id', s, 'name', '', 'creation_timestamp', 'x');
end

function v = v1dep(b, name)
v = '';
d = b.depends_on;
if iscell(d); d = [d{:}]; end
for k = 1:numel(d)
    if strcmp(d(k).name, name) && ischar(d(k).value); v = d(k).value; end
end
end

function v = dep(b, name)
v = '';
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, name); v = b.depends_on(k).value; end
end
end

function out = mintedOfClass(plan, cls)
out = {};
for k = 1:numel(plan.minted)
    if strcmp(plan.minted{k}.document_class.class_name, cls)
        out{end+1} = plan.minted{k}; %#ok<AGROW>
    end
end
end

function out = mintedEntities(plan, type)
out = {};
e = mintedOfClass(plan, 'entity');
for k = 1:numel(e)
    if ndi.v2.vocabIs('entity_type', e{k}.entity.type, type); out{end+1} = e{k}; end %#ok<AGROW>
end
end

function out = mintedRelations(plan, name)
out = {};
r = mintedOfClass(plan, 'directed_relation');
for k = 1:numel(r)
    if ndi.v2.vocabIs('relation', r{k}.directed_relation.relation, name); out{end+1} = r{k}; end %#ok<AGROW>
end
end

function out = tetanusManipulations(plan)
out = {};
m = mintedOfClass(plan, 'manipulation');
for k = 1:numel(m)
    if strcmp(m{k}.statement.variable.node, 'EMPTY:0000358'); out{end+1} = m{k}; end %#ok<AGROW>
end
end
