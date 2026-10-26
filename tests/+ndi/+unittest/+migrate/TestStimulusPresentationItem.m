classdef TestStimulusPresentationItem < matlab.unittest.TestCase
%TESTSTIMULUSPRESENTATIONITEM Unit tests for
%   ndi.migrate.internal.stimulusPresentationToItem -- the stimulus fold in
%   the did-schema #88 shape: one standalone `method` document per distinct
%   stimulus (V_eta_method_plan.md, TEAM-SIGN-OFF [method] 2026-10-21) and
%   one `manipulation` (value kind `item`) whose `item` value is the playlist into them
%   (`item` replaces `timed_sequence`, V_eta_study_plan.md).
%
%   The documents are built with did2.build, so these tests need DID-matlab
%   V2 and a did-schema #88 set on DID_SCHEMA_PATH (the fast assembler
%   workflow provides both). No database, no session.
%
%   THE FIXTURES ARE TRANSCRIBED FROM REAL 20211116 DOCUMENTS, not from a
%   DID-side schema: 11 of 11 real documents carry block keys
%   {presentation_order, stimuli} and no inline `presentation_time` (the writer
%   moved it to presentation_time.bin, decoder.m:132), and the `stimuli` list
%   arrives in three MATLAB shapes out of jsondecode (scalar struct, cell,
%   struct array). Each is exercised below.
%
%   Run with:
%     runtests('ndi.unittest.migrate.TestStimulusPresentationItem')

    methods (TestClassSetup)
        function needTheV2Builder(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.statement')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(fullfile(schemaPath, 'item.json')) && ...
                isfile(fullfile(schemaPath, 'method.json')), ...
                'DID_SCHEMA_PATH does not hold did-schema #88 (`item`, `method`)');
        end
    end

    methods (Test)

        % ================= the generic stage: nothing unplaced ==============

        function testTheGenericStageLeavesAGratingPresentationAsV1(testCase)
            % [generic stage is lossless] / [partly placed is carried as v1]
            % (Jess Haley, 2026-10-25, audit item 4): gratingRecipe writes five
            % of a periodicstim's parameters, so by default (the generic
            % stage) a grating presentation is REFUSED -- left as it is for the
            % end of ndi.migrate.local to carry as v1 -- with the fields named.
            % The tests below drive the recipes with 'LeaveUnplaced', false.
            stimuli = { gratingStim(0, 0.04, 0.5), blankStim() };
            pres = presentationBody('pres_g', [1 2], stimuli);
            bodies = { pres, ...
                responseScalar('resp_1', pres.base.id, 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, methods, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r);
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(methods);
            testCase.verifyTrue(startsWith(report.reason, 'unplaced (carried as v1)'), report.reason);
            testCase.verifyTrue(any(strcmp(report.unplaced_fields, 'parameters.chromhigh')));
            testCase.verifyTrue(any(strcmp(report.unplaced_fields, 'parameters.BG')), ...
                'a blank''s parameters are written nowhere either');
            % a presentation whose every parameter is an entry is still folded
            pres2 = presentationBody('pres_n', [1 2], { noiseStim(1), noiseStim(2) });
            bodies2 = { pres2, ...
                responseScalar('resp_2', pres2.base.id, 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r2 = ndi.migrate.internal.bodyResolver(bodies2);
            [m2, ~, report2] = ndi.migrate.internal.stimulusPresentationToItem(pres2, r2);
            testCase.verifyNotEmpty(m2, report2.reason);
            testCase.verifyEmpty(report2.unplaced_fields);
        end

        % ================= the #88 shape ===================================

        function testSequenceOfGratingsBecomesOneItemManipulation(testCase)
            % Four stimuli (three gratings + the blank), six trials with
            % repeats -- the 225-stimulus oridir run in miniature.
            stimuli = { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5), ...
                        gratingStim(90, 0.04, 0.5), blankStim() };
            pres = presentationBody('pres_1', [1 4 2 4 3 1], stimuli);
            [m, methods, report] = emit(testCase, pres);

            testCase.verifyTrue(isItemManipulation(m), ...
                'a `manipulation` listing the `item` value kind');
            testCase.verifyEqual(numel(methods), 4);
            testCase.verifyEqual(report.stimuli_read, 4);
            testCase.verifyEqual(report.distinct_stimuli, 4);
            testCase.verifyEqual(report.trials, 6);
            testCase.verifyEqual(report.blank_stimuli, 1);

            % each stimulus is a STANDALONE `method` document {term, parameters}
            for k = 1:numel(methods)
                testCase.verifyEqual(methods{k}.document_class.class_name, 'method');
            end
            testCase.verifyEqual(methods{2}.method.term.name, 'drifting sinusoidal grating');
            testCase.verifyEqual(methodParam(methods{2}, 'orientation'), 45);
            testCase.verifyEqual(methodParam(methods{2}, 'spatial frequency'), 0.04);
            testCase.verifyEqual(methodParam(methods{2}, 'temporal frequency'), 0.5);
            testCase.verifyEqual(methodParam(methods{2}, 'contrast'), 1);
            testCase.verifyEqual(methods{4}.method.term.name, 'blank screen');

            % item_id names the distinct methods, in order
            testCase.verifyEqual(depValues(m, 'item_id'), ...
                cellfun(@(d) d.base.id, methods, 'UniformOutput', false));

            % the playlist INDEXES those, 0-based (T14), in trial order
            testCase.verifyEqual(m.item.value.item(:)', [0 3 1 3 2 0]);
            % the blank is NOT made the control: [control as covariate] (Jess
            % Haley, 2026-10-22) takes the control from a v1 control record,
            % and this presentation has none -> no control covariate, and
            % item.value.control_item is gone (data_body plan AMENDMENT 6)
            testCase.verifyFalse(isfield(m.item.value, 'control_item'));
            testCase.verifyEmpty(covariateOf(m, 'control condition'));

            % ONE dimension: a presentation per trial
            d = dimensionsOf(m);
            testCase.verifyNumElements(d, 1);
            % Decided by Jess Haley, 2026-10-22 [presentation dimension term]
            testCase.verifyEqual(termName(d{1}.term), 'presentation of stimulus');
            testCase.verifyEqual(char(d{1}.term.node), 'OBI:0000807');
            testCase.verifyEqual(double(d{1}.n), 6);
            % no timing in a real-shaped document -> no onset or offset
            % covariate, and no item.value.offset
            testCase.verifyEmpty(covariateOf(m, 'onset time'));
            testCase.verifyEmpty(covariateOf(m, 'offset time'));
            testCase.verifyFalse(isfield(m.item.value, 'offset'));
            testCase.verifyFalse(isfield(m, 'data') && isfield(m.data, 'keys'), ...
                '`keys` is gone (data_body plan AMENDMENT 6)');
            testCase.verifyEqual(report.trials_with_timing, 0);
        end

        function testTheV1IdIsPreservedOnTheManipulation(testCase)
            % "decomposed around its preserved id, not dissolved": 494 inbound
            % edges onto the 11 presentation ids of 20211116.
            pres = presentationBody('4126943ebbdf85c2_c0d0b567f5cca85b', ...
                [1 2], { gratingStim(0, 0.04, 0.5), gratingStim(90, 0.04, 0.5) });
            [m, methods] = emit(testCase, pres);
            testCase.verifyEqual(m.base.id, '4126943ebbdf85c2_c0d0b567f5cca85b');
            for k = 1:numel(methods)
                testCase.verifyNotEqual(methods{k}.base.id, m.base.id);
            end
        end

        function testDuplicateStimuliDedupeToOneMethodDocument(testCase)
            same = gratingStim(45, 0.04, 0.5);
            pres = presentationBody('pres_dedup', [1 2 3 2], ...
                { same, same, gratingStim(90, 0.04, 0.5) });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(report.distinct_stimuli, 2);
            testCase.verifyEqual(numel(methods), 2);
            % v1 order [1 2 3 2] over {A A B} -> distinct {A B} -> [0 0 1 0]
            testCase.verifyEqual(m.item.value.item(:)', [0 0 1 0]);
            testCase.verifyEqual(numel(depValues(m, 'item_id')), 2);
            testCase.verifyFalse(isfield(m.item.value, 'control_item'));
            testCase.verifyEmpty(covariateOf(m, 'control condition'), ...
                'no control record, so no control covariate');
        end

        function testDedupIgnoresFieldsTheRecipeDoesNotCarry(testCase)
            a = gratingStim(45, 0.04, 0.5); a.parameters.nCycles = 1;
            b = gratingStim(45, 0.04, 0.5); b.parameters.nCycles = 64;
            pres = presentationBody('pres_ncycles', [1 2], {a, b});
            [~, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(report.distinct_stimuli, 1);
            testCase.verifyEqual(numel(methods), 1);
        end

        % ================= edges ===========================================

        function testTheEntityTheMethodAndTheTimeMarker(testCase)
            pres = presentationBody('pres_req', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            m = emit(testCase, pres);
            testCase.verifyEqual(depValue(m, 'entity_id'), 'animal_1');
            testCase.verifyEqual(m.statement.variable.name, 'visual stimulus');
            testCase.verifyEqual(m.interaction.method.term.name, 'visual stimulation');
            % the time reference is minted by the pass ("during the session");
            % here the manipulation carries the transient marker on its own id
            testCase.verifyEmpty(depValues(m, 'time_reference_id'));
            testCase.verifyEqual(depValue(m, ...
                did2.convert.mintSessionDuring('marker')), 'pres_req');
            testCase.verifyFalse(isfield(m.statement, 'distributive') ...
                && isequal(m.statement.distributive, true), ...
                'a single-animal manipulation is not distributive');
            verifyNoEmptyEdges(testCase, m);
        end

        % ============ [presentation app is software] =======================

        function testTheAppBecomesASoftwareEntityOnSoftwareId(testCase)
            % Decided by Jess Haley, 2026-10-26 [presentation app is software]
            % (rule R1): the v1 `app` block, which this fold used to drop,
            % is a `software` entity (name, NAME@VERSION, url) with a text
            % version assertion, referenced by the manipulation's software_id.
            % 20211116's values.
            pres = withApp(presentationBody('pres_app', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) }));
            [m, ~, report, sw] = emit(testCase, pres);
            testCase.verifyNumElements(sw, 2, 'the entity and its version assertion');
            e = sw{1};
            testCase.verifyEqual(e.document_class.class_name, 'entity');
            testCase.verifyEqual(e.entity.name, 'ndi_app_stimulus_decoder');
            testCase.verifyEqual(e.entity.local_identifier, ...
                'ndi_app_stimulus_decoder@fa67d45d0d957ce9ab3bb2e272a6799f02333996');
            testCase.verifySubstring(jsonencode(e.entity.global_identifier), ...
                'https://github.com/VH-lab/NDI-matlab');
            testCase.verifyEqual(sw{2}.document_class.class_name, 'assertion');
            testCase.verifyEqual(depValue(sw{2}, 'entity_id'), e.base.id);
            testCase.verifySubstring(jsonencode(sw{2}), ...
                'fa67d45d0d957ce9ab3bb2e272a6799f02333996');
            testCase.verifyEqual(depValue(m, 'software_id'), e.base.id);
            testCase.verifyEqual(report.software_minted, 1);
            testCase.verifyTrue(report.software_referenced);
            testCase.verifyEqual(report.software_unreferenced, 0);
            % the run environment: `manipulation` declares no
            % operating_system_id / interpreter_id on did-schema main, so it
            % is not written, and the report names what was not
            testCase.verifyEmpty(depValues(m, 'operating_system_id'));
            testCase.verifyEmpty(depValues(m, 'interpreter_id'));
            testCase.verifyEqual(report.app_environment_not_written, ...
                {'app.os', 'app.os_version', 'app.interpreter', 'app.interpreter_version'});
            verifyNoEmptyEdges(testCase, m);
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            for k = 1:numel(sw)
                testCase.verifyWarningFree(@() cache.validateDocument(sw{k}), ...
                    'a software document does not validate');
            end
        end

        function testTheRenamedAppSpellingIsReadToo(testCase)
            % did2.convert.universalRenames writes app_name / app_version
            pres = presentationBody('pres_app2', 1, { gratingStim(0, 0.04, 0.5) });
            pres.app = struct('app_name', 'ndi_app_stimulus_decoder', ...
                'app_version', 'abc', 'url', '');
            [m, ~, report, sw] = emit(testCase, pres);
            testCase.verifyEqual(sw{1}.entity.local_identifier, 'ndi_app_stimulus_decoder@abc');
            testCase.verifyEqual(depValue(m, 'software_id'), sw{1}.base.id);
            testCase.verifyEmpty(report.app_environment_not_written);
        end

        function testNoAppGivesNoSoftware(testCase)
            pres = presentationBody('pres_noapp', 1, { gratingStim(0, 0.04, 0.5) });
            [m, ~, report, sw] = emit(testCase, pres);
            testCase.verifyEmpty(sw);
            testCase.verifyEmpty(depValues(m, 'software_id'));
            testCase.verifyEqual(report.software_minted, 0);
            testCase.verifyFalse(report.software_referenced);
            % a nameless app block names no program: no entity
            pres.app = struct('name', '', 'version', '1', 'os', 'MACA64');
            [m, ~, report, sw] = emit(testCase, pres);
            testCase.verifyEmpty(sw);
            testCase.verifyEmpty(depValues(m, 'software_id'));
            testCase.verifyEqual(report.app_environment_not_written, {'app.os'});
        end

        function testAStandaloneItemsSoftwareIsMintedUnreferenced(testCase)
            % an item has no software_id edge
            pres = withApp(presentationBody('pres_sa', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) }));
            r = ndi.migrate.internal.bodyResolver({pres});
            [d, ~, report, sw] = ndi.migrate.internal.stimulusPresentationToItem( ...
                pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyTrue(report.standalone);
            testCase.verifyEmpty(depValues(d, 'software_id'));
            testCase.verifyNumElements(sw, 2);
            testCase.verifyFalse(report.software_referenced);
            testCase.verifyEqual(report.software_unreferenced, 1);
        end

        function testTheStimulatorBecomesInstrumentIdAndIsOmittedWhenAbsent(testCase)
            pres = presentationBody('pres_instr', 1, { gratingStim(0, 0.04, 0.5) });
            m = emit(testCase, pres);
            testCase.verifyEqual(depValue(m, 'instrument_id'), ...
                '4126943ebaa51186_40d4b41387c4b1a3');
            pres.depends_on = struct('name', {}, 'value', {});
            [m2, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(depValue(m2, 'instrument_id'));
            testCase.verifyFalse(report.instrument_resolved);
            verifyNoEmptyEdges(testCase, m2);
        end

        function testAnIncompleteBaseIsRefusedRatherThanQuarantined(testCase)
            pres = presentationBody('pres_nodate', 1, { gratingStim(0, 0.04, 0.5) });
            pres.base.datestamp = '';
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(methods);
            testCase.verifyNotEmpty(report.reason);
        end

        % ================= timing ==========================================

        function testInlineTimingIsOnsetAndOffsetTimeCovariates(testCase)
            % The deprecated inline form (decoder.m:154 "old way"): with every
            % trial timed, the onsets are the `onset time` covariate and the
            % ends the `offset time` covariate along the presentation
            % dimension (data_body plan AMENDMENT 6, Decided by Jess Haley,
            % 2026-10-22 [onset time]). No body: the values are inline.
            pres = presentationBody('pres_timed', [1 2 1], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            pres.stimulus_presentation.presentation_time = ...
                [trialTime(0, 4) trialTime(5, 9) trialTime(10, 14)];
            [m, ~, report] = emit(testCase, pres);
            testCase.verifyEqual(report.trials_with_timing, 3);
            d = dimensionsOf(m);
            testCase.verifyNumElements(d, 1);
            testCase.verifyEqual(double(d{1}.n), 3);
            on = covariateOf(m, 'onset time');
            testCase.verifyEqual(double(on.along(:)'), 0);
            testCase.verifyEqual(on.quantity.value(:)', [0 5 10]);
            testCase.verifyEqual(termName(on.unit), 'second');
            off = covariateOf(m, 'offset time');
            testCase.verifyEqual(double(off.along(:)'), 0);
            testCase.verifyEqual(off.quantity.value(:)', [4 9 14]);
            testCase.verifyFalse(isfield(m.item.value, 'offset'), ...
                'item.value.offset is gone (AMENDMENT 6)');
        end

        function testTimesComeFromPresentationTimeBin(testCase)
            % Decided by Jess Haley, 2026-10-22 [presentation times from the
            % file]: the onsets and offsets are read from the v1
            % presentation_time.bin, written here by the v1 writer's own
            % function (ndi.database.fun.write_presentation_time_structure,
            % as +ndi/+app/+stimulus/decoder.m calls it), and the file stays
            % attached as the raw source.
            pres = presentationBody('pres_bin', [1 2 1], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            f = writePresentationTimeFile(testCase, [10.5 12.5 14.5], [11.5 13.5 15.5]);
            [m, ~, report] = emit(testCase, pres, [], 'PresentationTimeFile', f);
            testCase.verifyEqual(report.timing_source, 'presentation_time.bin');
            testCase.verifyEqual(report.timing_file, 'read');
            testCase.verifyEqual(report.timing_file_entries, 3);
            testCase.verifyEqual(report.timing_clocktype, 'dev_local_time');
            testCase.verifyEqual(report.trials_with_timing, 3);
            on = covariateOf(m, 'onset time');
            testCase.verifyEqual(char(on.variable.node), 'EMPTY:0000368');
            testCase.verifyEqual(double(on.along(:)'), 0);
            testCase.verifyEqual(on.quantity.value(:)', [10.5 12.5 14.5]);
            testCase.verifyEqual(termName(on.unit), 'second');
            off = covariateOf(m, 'offset time');
            testCase.verifyEqual(char(off.variable.node), 'EMPTY:0000369');
            testCase.verifyEqual(off.quantity.value(:)', [11.5 13.5 15.5]);
            % the raw source stays attached
            testCase.verifyTrue(isfield(m, 'files'), 'the files block was dropped');
            testCase.verifyEqual(m.files, pres.files);
            testCase.verifyEqual(report.files_attached, 1);
        end

        function testTheFileWinsOverTheInlineBlock(testCase)
            pres = presentationBody('pres_both', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            pres.stimulus_presentation.presentation_time = [trialTime(0, 4) trialTime(5, 9)];
            f = writePresentationTimeFile(testCase, [100 200], [101 201]);
            [m, ~, report] = emit(testCase, pres, [], 'PresentationTimeFile', f);
            testCase.verifyEqual(report.timing_source, 'presentation_time.bin');
            on = covariateOf(m, 'onset time');
            testCase.verifyEqual(on.quantity.value(:)', [100 200]);
        end

        function testAFileOfTheWrongLengthFallsBackToInline(testCase)
            pres = presentationBody('pres_short', [1 2 1], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            pres.stimulus_presentation.presentation_time = ...
                [trialTime(0, 4) trialTime(5, 9) trialTime(10, 14)];
            f = writePresentationTimeFile(testCase, [100 200], [101 201]);
            [m, ~, report] = emit(testCase, pres, [], 'PresentationTimeFile', f);
            testCase.verifyEqual(report.timing_file, '2 entr(ies) for 3 trial(s)');
            testCase.verifyEqual(report.timing_source, 'inline (deprecated writer form)');
            on = covariateOf(m, 'onset time');
            testCase.verifyEqual(on.quantity.value(:)', [0 5 10]);
        end

        function testAFileThatIsNotHereGivesNoTimesButStaysAttached(testCase)
            pres = presentationBody('pres_gone', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            [m, ~, report] = emit(testCase, pres, [], 'PresentationTimeFile', ...
                fullfile(tempname, 'presentation_time.bin'));
            testCase.verifyEqual(report.timing_file, 'not on this computer');
            testCase.verifyEqual(report.timing_source, 'none');
            testCase.verifyEmpty(covariateOf(m, 'onset time'));
            testCase.verifyEmpty(covariateOf(m, 'offset time'));
            testCase.verifyEqual(m.files, pres.files, 'still the raw source');
            % and with no path at all, the caller's status is reported
            [~, ~, r2] = emit(testCase, pres, [], 'PresentationTimeFileStatus', ...
                'not on this computer');
            testCase.verifyEqual(r2.timing_file, 'not on this computer');
            [~, ~, r3] = emit(testCase, pres);
            testCase.verifyEqual(r3.timing_file, 'declared, not located');
        end

        function testNaNOffsetsInTheFileWriteOnsetsOnly(testCase)
            pres = presentationBody('pres_nanoff', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            f = writePresentationTimeFile(testCase, [1 2], [1.5 NaN]);
            [m, ~, report] = emit(testCase, pres, [], 'PresentationTimeFile', f);
            testCase.verifyEqual(report.timing_source, 'presentation_time.bin');
            testCase.verifyEqual(covariateOf(m, 'onset time').quantity.value(:)', [1 2]);
            testCase.verifyEmpty(covariateOf(m, 'offset time'));
        end

        function testANaNOnsetInTheFileIsNotUsed(testCase)
            pres = presentationBody('pres_nanon', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            f = writePresentationTimeFile(testCase, [NaN 2], [1.5 2.5]);
            [m, ~, report] = emit(testCase, pres, [], 'PresentationTimeFile', f);
            testCase.verifyEqual(report.timing_file, 'an onset is not a finite number');
            testCase.verifyEqual(report.timing_source, 'none');
            testCase.verifyEmpty(covariateOf(m, 'onset time'));
        end

        function testTheFileIsNotReadOnAFrameSequence(testCase)
            % On the SEQUENCE path the dimension is frames, not trials: the
            % per-trial file times do not index it.
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            seq = struct('item_ids', {{'g_a', 'g_b'}}, 'order', [1 2 1], ...
                'frame_times', [0 0.1 0.2], 'duration', 0.1);
            f = writePresentationTimeFile(testCase, 5, 6);
            [m, ~, report] = emit(testCase, pres, seq, 'PresentationTimeFile', f);
            testCase.verifyEqual(report.timing_file, 'not used: the dimension is frames');
            testCase.verifyEqual(report.timing_source, 'frameTimes (hartley_calc)');
            testCase.verifyEqual(covariateOf(m, 'onset time').quantity.value(:)', ...
                [0 0.1 0.2], 'AbsTol', 1e-12);
            testCase.verifyEqual(m.files, pres.files, 'the file stays attached');
        end

        function testPartialTimingWritesNoTimeCovariates(testCase)
            pres = presentationBody('pres_partial', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            half = trialTime(5, 9);
            half.offset = [];
            pres.stimulus_presentation.presentation_time = [trialTime(0, 4) half];
            [m, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(covariateOf(m, 'onset time'));
            testCase.verifyEmpty(covariateOf(m, 'offset time'));
            testCase.verifyNumElements(dimensionsOf(m), 1, ...
                'the presentation dimension is there with or without times');
            testCase.verifyFalse(isfield(m.item.value, 'offset'));
            testCase.verifyEqual(report.trials_with_timing, 1);
        end

        % ================= the grating guard ===============================

        function testHartleyWithoutEnumerationIsOneHartleyStimulusMethod(testCase)
            % Decided by Jess Haley, 2026-10-22 [Hartley without enumeration]:
            % no hartley_calc -> one method, term "Hartley stimulus", its raw v1
            % parameters as entries (nothing mapped to zeros, nothing refused),
            % and the presentation's notes says the gratings are not listed.
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyTrue(isItemManipulation(m));
            testCase.verifyEmpty(report.reason);
            testCase.verifyEqual(report.stimulus_kinds.hartleystim, 1);
            testCase.verifyTrue(report.hartley_without_enumeration);
            testCase.verifyEqual(numel(methods), 1);
            testCase.verifyEqual(methods{1}.method.term.name, 'Hartley stimulus');
            testCase.verifyEqual(methodParam(methods{1}, 'M'), 200);
            testCase.verifyEqual(methodParam(methods{1}, 'K_absmax'), 20);
            testCase.verifySubstring(m.statement.notes, 'not listed in the source');
            testCase.verifyFalse(isfield(methods{1}, 'notes') ...
                || (isfield(methods{1}, 'method') && isfield(methods{1}.method, 'notes')), ...
                'the method document carries no note');
        end

        function testASquareGratingIsImageType1AndFolds(testCase)
            sq = gratingStim(90, 0.1, 2);
            sq.parameters.imageType = 1;
            pres = presentationBody('pres_square', [1 2], { sq, blankStim() });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyNotEmpty(m);
            testCase.verifyEqual(numel(methods), 2);
            testCase.verifyEqual(report.stimulus_kinds.grating, 1);
            testCase.verifyEqual(methods{1}.method.term.name, 'drifting square-wave grating');
        end

        % ================= every kind is a method ==========================
        % Decided by Jess Haley, 2026-10-21 [non-grating stimuli as methods]
        % (V_eta_method_plan.md): a non-grating visual stimulus migrates the
        % same way as a grating -- one `method` per distinct stimulus, its term
        % naming the kind, every v1 parameter an entry. No new class.

        function testPeriodicstimImageType0BarsFoldAsFlashedBarMethods(testCase)
            % Decided by Jess Haley, 2026-10-22 [flashed bar]: imageType 0 in a
            % narrow oriented rectangle (7 px here) is a "flashed bar".
            pres = presentationBody('pres_bars', [1 2 3 1], ...
                { barStim(-196), barStim(-189), blankStim() });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyTrue(isItemManipulation(m));
            testCase.verifyEmpty(report.reason);
            testCase.verifyEqual(report.stimulus_kinds.periodicstim_bars, 2);
            testCase.verifyEqual(report.non_grating_stimuli, 2);
            testCase.verifyEqual(numel(methods), 3);
            testCase.verifyEqual(methods{1}.document_class.class_name, 'method');
            testCase.verifyEqual(methods{1}.method.term.name, 'flashed bar');
            testCase.verifyEqual(methods{1}.method.term.node, 'EMPTY:0000366');
            testCase.verifyEqual(report.flashed_bars, 2);
            testCase.verifyEqual(report.uniform_fields_kept, 0);
            testCase.verifyEqual(methodParam(methods{1}, 'line offset'), -196);
            testCase.verifyEqual(methodParam(methods{2}, 'line offset'), -189);
            testCase.verifyEqual(methodParam(methods{1}, 'image type'), 0);
            testCase.verifyEqual(methodParam(methods{1}, 'window shape'), 2);
            testCase.verifyEqual(methodParam(methods{1}, 'stimulus rectangle'), ...
                [-57 336 743 343]);
            testCase.verifyEqual(methods{3}.method.term.name, 'blank screen');
            testCase.verifyEqual(m.item.value.item(:)', [0 1 2 0]);
            testCase.verifyFalse(isfield(m.item.value, 'control_item'));
            testCase.verifyEmpty(covariateOf(m, 'control condition'), ...
                'a blank is not a control without a v1 control record');
        end

        function testAWideImageType0FieldKeepsUniformLuminanceAndIsCounted(testCase)
            % [flashed bar]: short side > 50 px is not a bar
            wide = barStim(-196);
            wide.parameters.rect = [0 0 800 600];
            pres = presentationBody('pres_field', [1 2], { wide, blankStim() });
            [~, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(methods{1}.method.term.name, 'uniform luminance field');
            testCase.verifyEqual(report.uniform_fields_kept, 1);
            testCase.verifyEqual(report.flashed_bars, 0);
        end

        function testAShapeMoviePresentationCarriesTheNote(testCase)
            % Decided by Jess Haley, 2026-10-22 [shape movie note]: the
            % presentation's statement.notes; the method carries none
            pres = presentationBody('pres_shape', [1 2], ...
                { shapeMovieStim('angle', 0), blankStim() });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyTrue(report.shape_movie_note);
            testCase.verifyEqual(m.statement.notes, ['The shape movies in this ' ...
                'presentation are recorded by their settings only (NewStim ' ...
                'shapemoviestim SMSparams); the shapes drawn on each frame ' ...
                '(nframemovies) are not in the v1 record.']);
            testCase.verifyFalse(isfield(methods{1}.method, 'notes'));
            % and a presentation without one has no note
            [m2, ~, report2] = emit(testCase, presentationBody('pres_g', [1 2], ...
                { gratingStim(0, 0.04, 0.5), blankStim() }));
            testCase.verifyFalse(report2.shape_movie_note);
            testCase.verifyTrue(~isfield(m2.statement, 'notes') || isempty(m2.statement.notes));
        end

        function testStochasticGridNoiseFoldsAsDenseNoiseMethods(testCase)
            pres = presentationBody('pres_noise', [1 2 3 1], ...
                { noiseStim(1), noiseStim(2), noiseStim(3) });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyTrue(isItemManipulation(m));
            testCase.verifyEmpty(report.reason);
            testCase.verifyEqual(report.stimulus_kinds.stochasticgridstim, 3);
            testCase.verifyEqual(numel(methods), 3, 'only randState differs: 3 distinct');
            d = methods{1};
            testCase.verifyEqual(d.method.term.name, 'dense noise');
            testCase.verifyEqual(methodParam(d, 'colour palette'), [0 0 0; 255 255 255]);
            testCase.verifyEqual(methodParam(d, 'colour weights'), [1 1]);
            testCase.verifyEqual(methodParam(d, 'background colour'), [128 128 128]);
            testCase.verifyEqual(methodParam(d, 'grid square size'), [50 50]);
            testCase.verifyEqual(methodParam(d, 'frame count'), 100);
            testCase.verifyEqual(methodParam(d, 'frame rate'), 15);
            testCase.verifyEqual(methodParam(d, 'grid rotation'), 0);
            testCase.verifyEqual(methodParam(d, 'bit depth'), 8);
            seed = paramEntry(d, 'Random Seed');
            testCase.verifyEqual(seed.variable.node, 'NCIT:C64220');
            testCase.verifyEqual(size(seed.matrix), [3 1], 'randState is a column');
            testCase.verifyEqual(paramEntry(d, 'colour palette').unit.node, 'NCIT:C75765');
            testCase.verifyEqual(paramEntry(d, 'frame rate').unit.node, 'om:hertz');
            testCase.verifyNotEmpty(paramEntry(d, 'background duration before stimulus'));
            testCase.verifyEqual(m.item.value.item(:)', [0 1 2 0]);
        end

        function testBlinkingstimFoldsAsSparseNoiseMethod(testCase)
            pres = presentationBody('pres_blink', 1, blinkingStim());
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyTrue(isItemManipulation(m));
            testCase.verifyEqual(report.stimulus_kinds.blinkingstim, 1);
            testCase.verifyEqual(numel(methods), 1);
            d = methods{1};
            testCase.verifyEqual(d.method.term.name, 'sparse noise');
            testCase.verifyEqual(methodParam(d, 'square colour'), [0 0 0]);
            testCase.verifyEqual(methodParam(d, 'random order'), 1);
            testCase.verifyEqual(methodParam(d, 'repetitions'), 30);
            testCase.verifyEqual(methodParam(d, 'background pause'), 0);
            testCase.verifyEqual(paramEntry(d, 'background pause').unit.node, 'EMPTY:0000260');
            testCase.verifyEqual(methodParam(d, 'stimulus rectangle'), [200 100 600 500]);
        end

        function testShapemoviestimFoldsAsShapeMovieMethods(testCase)
            pres = presentationBody('pres_shape', [1 2 3 2], ...
                { shapeMovieStim('angle', 0), shapeMovieStim('disparity', -40), blankStim() });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyTrue(isItemManipulation(m));
            testCase.verifyEqual(report.stimulus_kinds.shapemoviestim, 2);
            testCase.verifyEqual(numel(methods), 3);
            testCase.verifyEqual(methods{1}.method.term.name, 'shape movie');
            testCase.verifyEqual(methodParam(methods{1}, 'angle'), 0);
            testCase.verifyEqual(methodParam(methods{2}, 'disparity'), -40);
            testCase.verifyEmpty(paramEntry(methods{2}, 'angle'));
            testCase.verifyEqual(methodParam(methods{2}, 'frame count'), 160);
            testCase.verifyEqual(methodParam(methods{2}, 'inter-stimulus interval'), 0.01);
            testCase.verifyEqual(methodParam(methods{2}, 'stimulus rectangle'), [0 0 800 600]);
            testCase.verifyFalse(isfield(m.item.value, 'control_item'));
            testCase.verifyEmpty(covariateOf(m, 'control condition'), ...
                'a blank is not a control without a v1 control record');
        end

        function testAMixedPlaylistNamesEachStimulusKind(testCase)
            % The method plan's problem 2: one sequence interleaving a grating,
            % a bar, noise and a blank -- each its own method, by its own term.
            pres = presentationBody('pres_mix', [1 2 3 4], ...
                { gratingStim(0, 0.04, 0.5), barStim(-196), noiseStim(1), blankStim() });
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyNotEmpty(m);
            testCase.verifyEmpty(report.reason);
            terms = cellfun(@(d) d.method.term.name, methods, 'UniformOutput', false);
            testCase.verifyEqual(terms, {'drifting sinusoidal grating', ...
                'flashed bar', 'dense noise', 'blank screen'});
        end

        function testAnUnrecognisedParameterSetIsRefused(testCase)
            loose = struct('parameters', struct('angle', 45, ...
                'sFrequency', 0.04, 'tFrequency', 2));
            pres = presentationBody('pres_loose', 1, loose);
            [m, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.unrecognised, 1);
        end

        function testKindsAreCountedEvenWhenNoAnimalResolves(testCase)
            pres = presentationBody('pres_none', [1 2], { noiseStim(1), blankStim() });
            r = ndi.migrate.internal.bodyResolver({pres});
            [m, methods, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyNotEmpty(m, 'noise folds; with no subject, as a standalone item');
            testCase.verifyEqual(m.document_class.class_name, 'item');
            testCase.verifyEqual(numel(methods), 2);
            testCase.verifyEqual(report.stimulus_kinds.stochasticgridstim, 1);
            testCase.verifyEqual(report.stimulus_kinds.blank, 1);
            testCase.verifyTrue(report.standalone);
            testCase.verifySubstring(report.no_subject_reason, 'no responding animal');
        end

        % ================= the stimulator route ============================

        function testNoResponseAndNoEpochElementResolvesViaTheStimulator(testCase)
            pres = presentationBody('pres_stim', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            bodies = { pres, stimulatorElement(stimulatorIdOf(pres), ...
                'animal_stim', pres.base.session_id), docBody('subject', 'animal_stim') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, methods, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyNotEmpty(m);
            testCase.verifyEqual(numel(methods), 2);
            testCase.verifyEqual(depValue(m, 'entity_id'), 'animal_stim');
            testCase.verifyEqual(report.animal_source, 'stimulator');
            testCase.verifyEqual(report.stimulator_subjects, 1);
            testCase.verifyEmpty(report.reason);
        end

        function testTheEpochRouteIsStillPreferredWhenItFindsAnElement(testCase)
            pres = presentationBody('pres_epoch', 1, { gratingStim(0, 0.04, 0.5) });
            sid = pres.base.session_id;
            ee = docBody('element_epoch', 'ee_1', {'element_id', 'unit_1'});
            ee.base.session_id = sid;
            ee.epochid = struct('epochid', pres.epochid.epochid);
            bodies = { pres, ee, stimulatorElement('unit_1', 'animal_epoch', sid), ...
                stimulatorElement(stimulatorIdOf(pres), 'animal_stim', sid) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyEqual(depValue(m, 'entity_id'), 'animal_epoch');
            testCase.verifyEqual(report.animal_source, 'epoch');
            testCase.verifyEqual(report.stimulator_subjects, 0);
        end

        function testTheResponseRouteIsStillPreferredOverTheStimulator(testCase)
            pres = presentationBody('pres_resp', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, responseScalar('resp_1', pres.base.id, 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_resp'}), ...
                stimulatorElement(stimulatorIdOf(pres), 'animal_stim', pres.base.session_id) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyEqual(depValue(m, 'entity_id'), 'animal_resp');
            testCase.verifyEqual(report.animal_source, 'response');
        end

        function testAStimulatorNamingNoSubjectGivesAStandaloneItem(testCase)
            % No response, no element in the epoch, and the stimulator names
            % no animal: decided by Jess Haley, 2026-10-21 ("a"), a standalone
            % `item`, id preserved, no manipulation and no subject claim.
            pres = presentationBody('pres_nosub', [1 2 1], ...
                { gratingStim(0, 0.04, 0.5), blankStim() });
            orphan = docBody('element', stimulatorIdOf(pres));
            orphan.base.session_id = pres.base.session_id;
            r = ndi.migrate.internal.bodyResolver({ pres, orphan });
            [d, methods, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyTrue(report.standalone);
            testCase.verifyEqual(report.animal_source, 'none');
            testCase.verifySubstring(report.no_subject_reason, ...
                'stimulator element names no subject');
            testCase.verifyEmpty(report.reason, 'a standalone item is not a refusal');
            testCase.verifyEqual(d.document_class.class_name, 'item');
            testCase.verifyEqual(d.base.id, 'pres_nosub');
            testCase.verifyEqual(numel(methods), 2);
            testCase.verifyEqual(depValues(d, 'item_id'), ...
                cellfun(@(x) x.base.id, methods, 'UniformOutput', false));
            testCase.verifyEqual(d.item.value.item(:)', [0 1 0]);
            testCase.verifyFalse(isfield(d.item.value, 'control_item'));
            dd = dimensionsOf(d);
            testCase.verifyNumElements(dd, 1);
            testCase.verifyEqual(double(dd{1}.n), 3);
            for gone = {'entity_id', 'instrument_id', 'time_reference_id', ...
                    did2.convert.mintSessionDuring('marker')}
                testCase.verifyEmpty(depValues(d, gone{1}), ...
                    sprintf('a standalone item carries no %s', gone{1}));
            end
            verifyNoEmptyEdges(testCase, d);
        end

        function testTheStandaloneItemValidates(testCase)
            pres = presentationBody('pres_valid', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            r = ndi.migrate.internal.bodyResolver({pres});
            [d, ~, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyTrue(report.standalone);
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            testCase.verifyWarningFree(@() cache.validateDocument(d), ...
                'the standalone item does not validate against did-schema #88');
        end

        function testEveryKindsMethodDocumentValidates(testCase)
            % [non-grating stimuli as methods]: the method documents of every
            % kind (matrix, count, text and term-struct entries included)
            % validate against did-schema #88's `method`.
            pres = presentationBody('pres_kinds', 1:6, ...
                { gratingStim(0, 0.04, 0.5), barStim(-196), noiseStim(1), ...
                  blinkingStim(), shapeMovieStim('disparity', -40), blankStim() });
            [~, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(numel(methods), 6);
            testCase.verifyEmpty(report.reason);
            cache = did2.schema.cache.shared();
            restore = ndi.migrate.internal.termRegistryOff(); %#ok<NASGU>
            for k = 1:numel(methods)
                testCase.verifyWarningFree(@() cache.validateDocument(methods{k}), ...
                    sprintf('the %s method does not validate against did-schema #88', ...
                        methods{k}.method.term.name));
            end
        end

        function testElementsThatResolveToNoSubjectAreStillRefused(testCase)
            % Outside the decision: the epoch DOES record an element, it just
            % names no subject. Still left as v1, with its reason.
            pres = presentationBody('pres_nosubj_el', 1, { gratingStim(0, 0.04, 0.5) });
            sid = pres.base.session_id;
            ee = docBody('element_epoch', 'ee_1', {'element_id', 'unit_1'});
            ee.base.session_id = sid;
            ee.epochid = struct('epochid', pres.epochid.epochid);
            el = docBody('element', 'unit_1');
            el.base.session_id = sid;
            r = ndi.migrate.internal.bodyResolver({ pres, ee, el });
            [m, ~, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyEmpty(m);
            testCase.verifyFalse(report.standalone);
            testCase.verifySubstring(report.reason, 'resolve to no subject');
        end

        function testStimulatorLinksToDifferentAnimalsAreRefused(testCase)
            % Decision 4 (Jess Haley, 2026-10-21): conflicting records are not
            % a shared event -- refused and listed, NOT folded onto the
            % cohort, even when a cohort is on offer.
            pres = presentationBody('pres_two', 1, { gratingStim(0, 0.04, 0.5) });
            sid = pres.base.session_id;
            pres.depends_on(end+1) = struct('name', 'stimulus_element_id', ...
                'value', 'stimulator_2');
            bodies = { pres, ...
                stimulatorElement(stimulatorIdOf(pres), 'animal_a', sid), ...
                stimulatorElement('stimulator_2', 'animal_b', sid) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, ...
                [], 'CohortIdFor', @(s) 'cohort_x', 'LeaveUnplaced', false);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulator_subjects, 2);
            testCase.verifyEqual(report.several_animals, 2);
            testCase.verifySubstring(report.reason, 'conflicting records');
        end

        function testAStimulatorInAnotherSessionIsNotFollowed(testCase)
            pres = presentationBody('pres_xsess', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, stimulatorElement(stimulatorIdOf(pres), ...
                'animal_other', 'some_other_session') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [d, ~, report] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyEqual(report.stimulator_subjects, 0);
            testCase.verifyTrue(report.standalone, ...
                'never followed into another session, so no subject: a standalone item');
            testCase.verifyEqual(d.document_class.class_name, 'item');
        end

        function testAPlaylistIndexOutsideTheStimuliListIsRefused(testCase)
            pres = presentationBody('pres_oor', [1 7], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            [m, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.trials_out_of_range, 1);
        end

        % ================= the shapes jsondecode really produces ===========

        function testScalarStimulusAndScalarOrderAreHandled(testCase)
            pres = presentationBody('pres_scalar', 1, gratingStim(45, 0.04, 0.5));
            [m, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 1);
            testCase.verifyEqual(numel(methods), 1);
            testCase.verifyEqual(double(m.item.value.item), 0);
        end

        function testAHeterogeneousStimuliCellIsHandled(testCase)
            pres = presentationBody('pres_cell', [1 2], ...
                { gratingStim(0, 0.04, 0.5), blankStim() });
            [~, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 2);
            testCase.verifyEqual(numel(methods), 2);
        end

        function testAUniformStimuliStructArrayIsHandled(testCase)
            arr = [gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5)];
            pres = presentationBody('pres_arr', [1 2], arr);
            [~, methods, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 2);
            testCase.verifyEqual(numel(methods), 2);
        end

        % ================= the report ======================================

        function testTheReportCarriesItsDenominatorsEvenWhenNothingIsEmitted(testCase)
            expected = {'stimuli_read'; 'non_grating_stimuli'; 'stimulus_kinds'; ...
                'distinct_stimuli'; 'blank_stimuli'; 'trials'; ...
                'trials_out_of_range'; 'trials_with_timing'; 'timing_source'; ...
                'timing_file'; 'timing_file_entries'; 'timing_clocktype'; 'files_attached'; ...
                'basis_source'; 'shared_refs'; 'frames'; ...
                'subjects_resolved'; 'sibling_subjects'; 'stimulator_subjects'; ...
                'several_animals'; 'animals'; 'distributive'; ...
                'standalone'; 'no_subject_reason'; ...
                'instrument_resolved'; 'epoch_id'; 'animal_source'; ...
                'trial_positions'; 'control_records'; 'control_records_folded'; ...
                'control_true'; 'control_unfolded_reason'; ...
                'control_method_conflict'; 'control_method_parameters'; ...
                'control_method_not_placed'; 'software_minted'; ...
                'software_referenced'; 'software_unreferenced'; ...
                'app_environment_not_written'; ...
                'flashed_bars'; 'uniform_fields_kept'; ...
                'shape_movie_note'; 'hartley_without_enumeration'; ...
                'notes_not_written_standalone'; 'entity_id'; 'unplaced_fields'; 'reason'};
            pres = presentationBody('pres_1', 1, { gratingStim(0, 0.04, 0.5) });
            pres.base.datestamp = '';    % refused before anything is read
            r = ndi.migrate.internal.bodyResolver({pres});
            [~, ~, refused] = ndi.migrate.internal.stimulusPresentationToItem(pres, r, [], 'LeaveUnplaced', false);
            testCase.verifyEqual(fieldnames(refused), expected);
            pres.base.datestamp = '2025-09-11T12:48:21.932Z';
            [~, ~, ok] = emit(testCase, pres);
            testCase.verifyEqual(fieldnames(ok), expected);
            testCase.verifyEmpty(ok.reason);
            testCase.verifyEqual(ok.epoch_id, 't00001');
            % per trial, its item position
            [m, ~, rep2] = emit(testCase, pres);
            testCase.verifyEqual(rep2.trial_positions(:)', m.item.value.item(:)');
        end

        function testADocumentThatIsNotAResponseIsStillNotSweptIn(testCase)
            pres = presentationBody('pres_1', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, ...
                docBody('stimulus_response_scalar_parameters_basic', 'p_1', ...
                    {'stimulus_presentation_id', 'pres_1'}, {'element_id', 'elem_9'}), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

        % ================= the supplied enumeration (Hartley) ==============

        function testASuppliedSequenceReplacesThePlaylistAndTheRefs(testCase)
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            seq = struct('item_ids', {{'g_a', 'g_b', 'g_c'}}, ...
                'order', [1 3 2 3 1], 'frame_times', [0 0.1 0.2 0.3 0.4], ...
                'duration', 0.1);
            [m, methods, report] = emit(testCase, pres, seq);
            testCase.verifyTrue(isItemManipulation(m));
            testCase.verifyEmpty(methods, 'the shared basis is minted by the caller');
            testCase.verifyEqual(depValues(m, 'item_id'), {'g_a', 'g_b', 'g_c'});
            testCase.verifyEqual(m.item.value.item(:)', [0 2 1 2 0]);
            testCase.verifyEqual(m.base.id, 'pres_hartley');
            testCase.verifyEqual(report.basis_source, 'supplied enumeration (hartley_calc)');
            testCase.verifyEqual(report.shared_refs, 3);
            testCase.verifyEqual(report.frames, 5);
            testCase.verifyEqual(report.non_grating_stimuli, 0);
            d = dimensionsOf(m);
            testCase.verifyNumElements(d, 1);
            testCase.verifyEqual(double(d{1}.n), 5, 'one presentation per frame');
            on = covariateOf(m, 'onset time');
            testCase.verifyEqual(on.quantity.value(:)', [0 0.1 0.2 0.3 0.4], 'AbsTol', 1e-12);
            off = covariateOf(m, 'offset time');
            testCase.verifyEqual(off.quantity.value(:)', [0.1 0.2 0.3 0.4 0.5], 'AbsTol', 1e-12);
            testCase.verifyFalse(isfield(m.item.value, 'offset'));
            testCase.verifyEqual(report.trials_with_timing, 5);
        end

        function testASuppliedSequenceWithNoFrameTimesWritesNoTimeCovariate(testCase)
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            seq = struct('item_ids', {{'g_a', 'g_b'}}, 'order', [1 2 1]);
            [m, ~, report] = emit(testCase, pres, seq);
            testCase.verifyEmpty(covariateOf(m, 'onset time'));
            testCase.verifyEmpty(covariateOf(m, 'offset time'));
            testCase.verifyEqual(report.trials_with_timing, 0);
            testCase.verifyEqual(report.frames, 3);
        end

        function testASuppliedSequenceIsRefusedRatherThanRepaired(testCase)
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            [m1, ~, r1] = emit(testCase, pres, struct('item_ids', {{'g_a'}}, 'order', [1 2]));
            testCase.verifyEmpty(m1); testCase.verifyNotEmpty(r1.reason);
            [m2, ~, r2] = emit(testCase, pres, struct('item_ids', {{'g_a'}}, ...
                'order', [1 1], 'frame_times', [0 1 2]));
            testCase.verifyEmpty(m2); testCase.verifyNotEmpty(r2.reason);
            [m3, ~, r3] = emit(testCase, pres, struct('item_ids', {{}}, 'order', [1 1]));
            testCase.verifyEmpty(m3); testCase.verifyNotEmpty(r3.reason);
        end

    end
end

% ===================== driver =============================================

function [manipBody, methodBodies, report, software] = emit(~, pres, sequence, varargin)
%EMIT Run the assembler with one responding animal in scope, through the real
%   bodyResolver over a `stimulus_response_scalar` body (the class production
%   writes). VARARGIN: further name-value options for the assembler.
if nargin < 3
    sequence = [];
end
bodies = { pres, ...
    responseScalar('resp_1', pres.base.id, 'elem_9'), ...
    docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
r = ndi.migrate.internal.bodyResolver(bodies);
[manipBody, methodBodies, report, software] = ...
    ndi.migrate.internal.stimulusPresentationToItem(pres, r, sequence, varargin{:}, 'LeaveUnplaced', false);
end

function f = writePresentationTimeFile(testCase, onsets, offsets)
%WRITEPRESENTATIONTIMEFILE A presentation_time.bin written by the v1 writer's
%   own function, in the structure +ndi/+app/+stimulus/decoder.m builds (one
%   entry per trial: clocktype, stimopen, onset, offset, stimclose,
%   stimevents). The corpora are document-only, so this is the only way a
%   test sees the bytes.
pt = struct('clocktype', {}, 'stimopen', {}, 'onset', {}, 'offset', {}, ...
    'stimclose', {}, 'stimevents', {});
for k = 1:numel(onsets)
    pt(end+1) = struct('clocktype', 'dev_local_time', 'stimopen', onsets(k) - 0.5, ...
        'onset', onsets(k), 'offset', offsets(k), 'stimclose', offsets(k) + 0.5, ...
        'stimevents', [onsets(k) 1; offsets(k) 2]); %#ok<AGROW>
end
f = [tempname '_presentation_time.bin'];
ndi.database.fun.write_presentation_time_structure(f, pt);
testCase.addTeardown(@() deleteIfThere(f));
end

function deleteIfThere(f)
if isfile(f)
    delete(f);
end
end

function b = responseScalar(id, presentationId, elementId)
b = docBody('stimulus_response_scalar', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
b.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
end

function b = stimulatorElement(id, subjectId, sessionId)
b = docBody('element', id, {'subject_id', subjectId});
b.base.session_id = sessionId;
end

function id = stimulatorIdOf(pres)
id = depValue(pres, 'stimulus_element_id');
end

function verifyNoEmptyEdges(testCase, body)
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    testCase.verifyNotEmpty(depValues(body, body.depends_on(k).name), ...
        sprintf('depends_on "%s" was emitted with an empty value', ...
            body.depends_on(k).name));
    ids = depValues(body, body.depends_on(k).name);
    for j = 1:numel(ids)
        testCase.verifyNotEmpty(ids{j}, sprintf('depends_on "%s" is empty', ...
            body.depends_on(k).name));
    end
end
end

% ===================== fixtures, from real 20211116 documents =============

function b = presentationBody(id, order, stimuli)
%PRESENTATIONBODY The real shape: block = {presentation_order, stimuli}, the
%   times in an attached file, one `stimulus_element_id` dep, an epochid block.
%   Transcribed from 4126943ebbdd014f_40c471eb4e8ea86d.json and siblings.
b = struct();
b.document_class = struct('class_name', 'stimulus_presentation');
b.depends_on = struct('name', {'stimulus_element_id'}, ...
    'value', {'4126943ebaa51186_40d4b41387c4b1a3'});
b.base = struct('id', id, ...
    'session_id', '4126943eba883b79_40dfd8222e0301f0', ...
    'name', '', 'datestamp', '2025-09-11T12:48:21.932Z');
b.epochid = struct('epochid', 't00001');
b.files = struct('file_list', {{'presentation_time.bin'}});
b.stimulus_presentation = struct();
b.stimulus_presentation.presentation_order = order;
b.stimulus_presentation.stimuli = stimuli;
end

function b = withApp(b)
% the v1 app block, as on 20211116's presentations
b.app = struct('name', 'ndi_app_stimulus_decoder', ...
    'version', 'fa67d45d0d957ce9ab3bb2e272a6799f02333996', ...
    'url', 'https://github.com/VH-lab/NDI-matlab', 'os', 'MACA64', ...
    'os_version', '15.6.1', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
end

function s = gratingStim(angle, sFrequency, tFrequency)
%GRATINGSTIM The 24-key periodic-grating parameter set, verbatim from the
%   225-stimulus document (4126943ebbdf85c2_c0d0b567f5cca85b.json, stimuli[0]);
%   only the three varying quantities are arguments.
s = struct('parameters', struct( ...
    'imageType', 2, 'animType', 4, 'flickerType', 0, ...
    'angle', angle, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'sFrequency', sFrequency, 'sPhaseShift', 0, 'distance', 57, ...
    'tFrequency', tFrequency, 'barWidth', 0.5, ...
    'rect', [0 0 800 600], 'nCycles', 1, 'contrast', 1, ...
    'background', 0.5, 'backdrop', 0.5, 'barColor', 1, ...
    'nSmoothPixels', 2, 'fixedDur', 0, 'windowShape', 0, 'loops', 0, ...
    'dispprefs', {{'BGposttime', 3}}, ...
    'phaseSteps', [], 'phaseSequence', []));
end

function s = blankStim()
%BLANKSTIM The 11-key blank, verbatim from stimuli[225] of the same document.
%   `randState` is elided to its first three entries -- the value carries none
%   of it, and its length is not what any assertion here turns on.
s = struct('parameters', struct( ...
    'BG', [127.5 127.5 127.5], 'dist', 1, 'values', [127.5 127.5 127.5], ...
    'rect', [0 0 1 1], 'angle', 0, 'pixSize', [1 1], 'N', 1, 'fps', 0.5, ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'dispprefs', {{'BGpretime', 0, 'BGposttime', 3}}, ...
    'isblank', 1));
end

function s = hartleyGeneratorStim()
%HARTLEYGENERATORSTIM The 16-key white-noise GENERATOR spec, verbatim from
%   4126943ebbdd014f_40c471eb4e8ea86d.json -- the shape 10 of the 11 20211116
%   presentations carry, as their single stimulus. Note what is NOT here:
%   angle, sFrequency, tFrequency.
s = struct('parameters', struct( ...
    'rect', [-7 -138 793 662], 'windowShape', 0, 'distance', 30, ...
    'M', 200, 'K_absmax', 20, 'L_absmax', 20, 'sfmax', 5, 'contrast', 1, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'background', 0.5, 'backdrop', 0.5, 'reps', 1, 'fps', 10, ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'dispprefs', {{'BGposttime', 3}}));
end

function s = barStim(lineoffset)
%BARSTIM periodicstim imageType 0, windowShape 2 (oriented rectangle), a
%   7-pixel-tall rect -- one light bar of Dab's flashed-bar map (census key set
%   "periodicstim + linenumber lineoffset", 17,260 stimuli).
s = gratingStim(0, 0.1, 0);
s.parameters.imageType = 0;
s.parameters.animType = 0;
s.parameters.windowShape = 2;
s.parameters.rect = [-57 336 743 343];
s.parameters.linenumber = 1;
s.parameters.lineoffset = lineoffset;
end

function s = noiseStim(seed)
%NOISESTIM Soph's stochasticgridstim noise: key set {BG N angle dispprefs dist
%   fps pixSize randState rect values}, N 100, pixSize [50 50], rect
%   [0 0 800 600], 2-colour B/W values, angle 0, fps 15; within a
%   presentation only randState varies.
s = struct('parameters', struct( ...
    'BG', [128 128 128], 'N', 100, 'angle', 0, ...
    'dispprefs', {{'BGpretime', 0, 'BGposttime', 0}}, ...
    'dist', [1 1], 'fps', 15, 'pixSize', [50 50], ...
    'randState', [seed 0.6704957765200832 0.08449867537860833], ...
    'rect', [0 0 800 600], 'values', [0 0 0; 255 255 255]));
end

function s = blinkingStim()
%BLINKINGSTIM Dab's blinkingstim: key set {BG bgpause dispprefs fps pixSize
%   randState random rect repeat value}; BG [128 128 128], value [0 0 0],
%   random 1, repeat 30, fps 10, bgpause 0, pixSize [40 40], a 400x400 rect.
s = struct('parameters', struct( ...
    'BG', [128 128 128], 'bgpause', 0, ...
    'dispprefs', {{'BGposttime', 3}}, ...
    'fps', 10, 'pixSize', [40 40], ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'random', 1, 'rect', [200 100 600 500], 'repeat', 30, 'value', [0 0 0]));
end

function s = shapeMovieStim(labelName, labelValue)
%SHAPEMOVIESTIM Dab's shapemoviestim: key set {BG N dispprefs fps isi rect
%   scale} plus the experimenter's label `angle` or `disparity`; BG [0 0 0],
%   N 160, fps 100, isi 0.01, rect [0 0 800 600], scale 1, dispprefs {}.
p = struct('BG', [0 0 0], 'N', 160, 'dispprefs', {{}}, 'fps', 100, ...
    'isi', 0.01, 'rect', [0 0 800 600], 'scale', 1);
p.(labelName) = labelValue;
s = struct('parameters', p);
end

function t = trialTime(onset, offset)
%TRIALTIME One entry of the DEPRECATED inline presentation_time. No production
%   document has carried this since decoder.m moved the structure into
%   presentation_time.bin; it exists here to exercise the body-tier branch.
t = struct('clocktype', 'dev_local_time', 'stimopen', onset, ...
    'onset', onset, 'offset', offset, 'stimclose', offset, 'stimevents', []);
end

function b = docBody(className, id, varargin)
b = struct();
b.document_class = struct('class_name', className);
deps = struct('name', {}, 'value', {});
for k = 1:numel(varargin)
    pair = varargin{k};
    deps(end+1) = struct('name', pair{1}, 'value', pair{2}); %#ok<AGROW>
end
b.depends_on = deps;
b.base = struct('id', id);
end

function v = depValue(b, name)
%DEPVALUE The first edge NAME's id ({name, value} in v1, {name, document_id}
%   from did2.build).
ids = depValues(b, name);
v = '';
if ~isempty(ids); v = ids{1}; end
end

function ids = depValues(b, name)
ids = {};
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~strcmp(d.name, name); continue; end
    if isfield(d, 'document_id'); ids{end+1} = d.document_id; %#ok<AGROW>
    else; ids{end+1} = d.value; end %#ok<AGROW>
end
end

function v = methodParam(doc, variable)
%METHODPARAM The value of a `method` document's parameter VARIABLE: the
%   quantity's value, the matrix, the count, the term's name or the text;
%   [] when absent.
v = [];
e = paramEntry(doc, variable);
if isempty(e); return; end
if isfield(e, 'quantity') && ~isempty(e.quantity); v = e.quantity.value;
elseif isfield(e, 'matrix') && ~isempty(e.matrix); v = e.matrix;
elseif isfield(e, 'count') && ~isempty(e.count); v = e.count;
elseif isfield(e, 'term') && ~isempty(e.term) && ~isempty(e.term.name); v = e.term.name;
elseif isfield(e, 'text') && ~isempty(e.text); v = e.text; end
end

function e = paramEntry(doc, variable)
%PARAMENTRY The entry of a `method` document whose variable's name is VARIABLE.
e = [];
p = doc.method.parameters;
if isstruct(p); p = num2cell(p); end
for k = 1:numel(p)
    if strcmp(p{k}.variable.name, variable)
        e = p{k};
        return;
    end
end
end

function d = dimensionsOf(b)
%DIMENSIONSOF The document's data.dimensions, as a cell (AMENDMENT 6).
d = {};
if isfield(b, 'data') && isfield(b.data, 'dimensions')
    d = ndi.v2.entries(b.data.dimensions);
end
end

function c = covariateOf(b, name)
%COVARIATEOF The document's covariate whose variable's name is NAME, or [].
c = [];
if ~isfield(b, 'data') || ~isfield(b.data, 'covariates'); return; end
cs = ndi.v2.entries(b.data.covariates);
for k = 1:numel(cs)
    if strcmp(termName(cs{k}.variable), name)
        c = cs{k};
        return;
    end
end
end

function n = termName(t)
n = '';
if iscell(t) && ~isempty(t); t = t{1}; end
if isstruct(t) && isfield(t, 'name'); n = char(t(1).name);
elseif ischar(t) || isstring(t); n = char(t); end
end

function tf = isItemManipulation(m)
names = {m.document_class.superclasses.class_name};
tf = strcmp(m.document_class.class_name, 'manipulation') && any(strcmp(names, 'item'));
end
