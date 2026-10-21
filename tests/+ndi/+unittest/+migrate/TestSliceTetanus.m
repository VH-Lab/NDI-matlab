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
%   The migrated side is built here in the shapes the real passes emit
%   (stimulusBathToBath + epochAnchorFold: a dose_manipulation with the
%   stimulus_bath id, the stimulator as instrument, anchored to the epoch;
%   resolveEpochProbemap: per-epoch term_manipulation / observations; the
%   treatment migrator + Path S: a term_manipulation on a part-subject;
%   openminds_stimulus: a passthrough; element: `observes`). The whole
%   pipeline is proven on the corpus by TestMigrateLocalEtaDab.
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
            [testCase.Migrated, testCase.EpochIndex] = simulateMigrated(testCase.V1);
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
            animal = mintedNamed(testCase.Plan, 'migrated_nested_date_animal');
            verifyNumElements(testCase, animal, 1);
            verifyEqual(testCase, animal{1}.subject.local_identifier, ...
                'sd_rat_AVPCre_221128_BNSTI_SCN@dabrowska-lab.rosalindfranklin.edu');
            % every strain assertion the Dec 02 animal carries is copied, and
            % nothing else (species and sex are lab-wide, not folder facts)
            dec02 = '';
            for k = 1:numel(testCase.V1)
                b = testCase.V1{k};
                if strcmp(b.document_class.class_name, 'subject') && ...
                        strcmp(b.subject.local_identifier, ...
                        'sd_rat_AVPCre_221202_BNSTI_SCN@dabrowska-lab.rosalindfranklin.edu')
                    dec02 = b.base.id;
                end
            end
            nStrain = 0;
            for k = 1:numel(testCase.Migrated)
                b = testCase.Migrated{k};
                if strcmp(b.document_class.class_name, 'term_assertion') ...
                        && strcmp(dep(b, 'subject_id'), dec02) && ~isempty(dep(b, 'strain_id'))
                    nStrain = nStrain + 1;
                end
            end
            verifyGreaterThan(testCase, nStrain, 0);
            verifyEqual(testCase, r.new_animal_strain_assertions_copied, nStrain);
            slices = mintedNamed(testCase.Plan, 'migrated_slice');
            lids = sort(cellfun(@(s) s.subject.local_identifier, slices, 'UniformOutput', false));
            verifyEqual(testCase, lids, sort({ ...
                'sd_rat_AVPCre_221122_BNSTIII_SCN_a@dabrowska-lab.rosalindfranklin.edu', ...
                'sd_rat_AVPCre_221122_BNSTIII_SCN_b@dabrowska-lab.rosalindfranklin.edu', ...
                'sd_rat_AVPCre_221202_BNSTI_SCN_a@dabrowska-lab.rosalindfranklin.edu', ...
                'sd_rat_AVPCre_221128_BNSTI_SCN_a@dabrowska-lab.rosalindfranklin.edu'}));
            rels = mintedNamed(testCase.Plan, 'migrated_slice_part_of');
            verifyNumElements(testCase, rels, 4);
            novSlice = slices{strcmp(cellfun(@(s) s.subject.local_identifier, slices, ...
                'UniformOutput', false), ...
                'sd_rat_AVPCre_221128_BNSTI_SCN_a@dabrowska-lab.rosalindfranklin.edu')};
            rel = rels{cellfun(@(x) strcmp(dep(x, 'child'), novSlice.base.id), rels)};
            verifyEqual(testCase, dep(rel, 'parent'), animal{1}.base.id, ...
                'the Nov 28 slice is part_of the new animal');
        end

        function testEveryBathAndRecordingStatementMovesToItsSlice(testCase)
            r = testCase.Report;
            verifyEqual(testCase, r.epoch_statements_examined, 196, ...
                '49 baths + 49 probemap stimulator rows + 98 recording rows');
            verifyEqual(testCase, [r.epoch_statements_matched r.epoch_statements_unmatched], [196 0]);
            verifyEqual(testCase, [r.element_relations_matched r.element_relations_ambiguous], [6 3], ...
                'the 221202 elements recorded both animals, so their observes stays on the animal');
            sliceIds = cellfun(@(s) s.base.id, mintedNamed(testCase.Plan, 'migrated_slice'), ...
                'UniformOutput', false);
            for k = 1:numel(testCase.Plan.replaced)
                s = testCase.Plan.replaced{k};
                if strcmp(s.document_class.class_name, 'directed_relation')
                    verifyTrue(testCase, any(strcmp(dep(s, 'parent'), sliceIds)));
                else
                    verifyTrue(testCase, any(strcmp(dep(s, 'subject_id'), sliceIds)));
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
            ms = mintedNamed(testCase.Plan, 'migrated_tetanus_manipulation');
            for k = 1:numel(ms)
                m = ms{k};
                verifyEqual(testCase, m.subject_interaction.method.name, 'optogenetic tetanus stimulation');
                verifyNotEmpty(testCase, dep(m, 'instrument_id'));
                if isfield(m.subject_statement, 'conditions')
                    c = m.subject_statement.conditions;
                    verifyEqual(testCase, c.variable.node, 'EMPTY:0000074');
                    verifyTrue(testCase, startsWith(c.term.value.node, 'UBERON:'));
                end
                if isfield(m.subject_interaction, 'method_parameters')
                    p = m.subject_interaction.method_parameters;
                    verifyEqual(testCase, {p.source_unit}, {'Hz', 's'});
                    verifyEqual(testCase, [p(1).quantity.value p(2).quantity.value], [10 20]);
                    verifyEqual(testCase, {p(1).quantity.source_value, p(2).quantity.source_value}, {'10', '20'});
                    verifyEqual(testCase, p(2).unit.node, 'om:second-Time');
                end
            end
        end

        function testTheWindowIsRelativeToTheLastBeforeEpoch(testCase)
            % The Nov 28 run, from the v1 times: last before epoch
            % 17:01:06-17:02:38, first after 17:05:07.
            ms = mintedNamed(testCase.Plan, 'migrated_tetanus_manipulation');
            refs = mintedNamed(testCase.Plan, 'migrated_tetanus_window');
            verifyNumElements(testCase, refs, 4);
            for k = 1:numel(ms)
                ref = refs{cellfun(@(x) strcmp(x.base.id, dep(ms{k}, 'time_reference_1')), refs)};
                v = ref.relative_reference.value;
                verifyEqual(testCase, v.clock.name, 'exp_global_time');
                verifyGreaterThan(testCase, v.start.seconds, 0);
                verifyGreaterThan(testCase, v.duration.seconds, 0);
                verifyLessThan(testCase, v.duration.seconds, 10 * 60);
                verifyTrue(testCase, any(strcmp(dep(ref, 'relative_to'), ...
                    {testCase.EpochIndex.epoch_document_id})));
            end
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
    end
end

% ===================== the migrated side, in the passes' shapes ==========

function [M, idx] = simulateMigrated(v1)
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
for k = 1:numel(v1)
    b = v1{k}; s = b.base.session_id;
    switch b.document_class.class_name
        case 'stimulus_bath'
            st = v1dep(b, 'stimulus_element_id');
            a = anchor(s, b.epochid.epochid);
            M{end+1} = body('dose_manipulation', b.base.id, s, 'migrated_bath', ...
                [struct('name', 'subject_id', 'value', v1dep(els(st), 'subject_id')), ...
                 struct('name', 'instrument_id', 'value', st), ...
                 struct('name', 'time_reference_1', 'value', a)]); %#ok<AGROW>
        case 'epochfiles_ingested'
            ep = b.epochfiles_ingested.epoch_id;
            rows = strsplit(strtrim(b.epochfiles_ingested.epochprobemap), newline);
            a = anchor(s, ep);
            for q = 2:numel(rows)
                c = strsplit(rows{q}, sprintf('\t'));
                d = [struct('name', 'subject_id', 'value', subjByLid(c{5})), ...
                     struct('name', 'instrument_id', 'value', elByName([s '|' c{1}])), ...
                     struct('name', 'time_reference_1', 'value', a)];
                if strcmp(c{3}, 'stimulator')
                    x = body('term_manipulation', uid(), s, 'migrated_probemap_manipulation', d);
                else
                    x = body('voltage_observation', uid(), s, 'migrated_probemap_observation', d);
                end
                M{end+1} = x; %#ok<AGROW>
            end
        case 'openminds_stimulus'
            M{end+1} = body('openminds_stimulus', b.base.id, s, '', ...
                struct('name', 'stimulus_element_id', 'value', v1dep(b, 'stimulus_element_id'))); %#ok<AGROW>
        case 'treatment'
            animal = v1dep(b, 'subject_id'); sa = uid(); part = uid();
            M{end+1} = body('relative_reference', sa, s, 'migrated_session_anchor', ...
                struct('name', 'relative_to', 'value', 'sessiondoc')); %#ok<AGROW>
            t = body('term_manipulation', b.base.id, s, '', ...
                [struct('name', 'subject_id', 'value', part), struct('name', 'time_reference_1', 'value', sa)]);
            t.subject_statement = struct('variable', struct('node', 'EMPTY:0000074', ...
                'name', 'Optogenetic Tetanus Stimulation'));
            M{end+1} = t; %#ok<AGROW>
            M{end+1} = body('subject', part, s, 'migrated_part_x', struct('name', {}, 'value', {})); %#ok<AGROW>
            M{end+1} = body('term_assertion', uid(), s, 'migrated_part_kind', ...
                struct('name', 'subject_id', 'value', part)); %#ok<AGROW>
            r = body('directed_relation', uid(), s, 'migrated_part_of', ...
                [struct('name', 'child', 'value', part), struct('name', 'parent', 'value', animal)]);
            r.directed_relation = struct('relation', struct('node', 'BFO:0000050', 'name', 'part_of'));
            M{end+1} = r; %#ok<AGROW>
        case 'element'
            M{end+1} = body('subject', b.base.id, s, '', struct('name', {}, 'value', {})); %#ok<AGROW>
            r = body('directed_relation', uid(), s, '', ...
                [struct('name', 'child', 'value', b.base.id), ...
                 struct('name', 'parent', 'value', v1dep(b, 'subject_id'))]);
            r.directed_relation = struct('relation', struct('node', '', 'name', 'observes'));
            M{end+1} = r; %#ok<AGROW>
        case 'subject'
            M{end+1} = body('subject', b.base.id, s, '', struct('name', {}, 'value', {})); %#ok<AGROW>
        case 'openminds_subject'
            if contains(b.openminds.openminds_type, 'Strain')
                M{end+1} = body('term_assertion', uid(), s, '', ...
                    [struct('name', 'subject_id', 'value', v1dep(b, 'subject_id')), ...
                     struct('name', 'strain_id', 'value', 'strainentity')]); %#ok<AGROW>
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
            M{end+1} = body('epoch', e, s, '', struct('name', 'session_id', 'value', 'sessiondoc'));
        end
        e = epochDoc(key);
    end
    function a = anchor(s, ep)
        a = uid();
        M{end+1} = body('relative_reference', a, s, 'migrated_probemap_epoch_anchor', ...
            struct('name', 'relative_to', 'value', epoch(s, ep)));
    end
end

function b = body(cls, id, s, name, deps)
b = struct();
b.document_class = struct('class_name', cls, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {}, 'class_version', {}), 'schema_version', 'V_eta');
b.depends_on = deps;
b.base = struct('id', id, 'session_id', s, 'name', name, 'creation_timestamp', 'x');
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

function out = mintedNamed(plan, name)
out = {};
for k = 1:numel(plan.minted)
    if strcmp(plan.minted{k}.base.name, name); out{end+1} = plan.minted{k}; end %#ok<AGROW>
end
end
