classdef TestStimulusPresentationTimedSequence < matlab.unittest.TestCase
%TESTSTIMULUSPRESENTATIONTIMEDSEQUENCE Unit tests for
%   ndi.migrate.internal.stimulusPresentationToTimedSequence -- the emitter for
%   the SIGNED stimulus model (DID-schema V_eta_stimulus_model_plan.md :224 and
%   the 2026-08-17 reconciliation at the end of that file). Pure struct
%   assembly: no database, no schema, no toolbox.
%
%   THE FIXTURES ARE TRANSCRIBED FROM REAL 20211116 DOCUMENTS, not from a
%   DID-side schema and not from the v1 template. That matters twice over here:
%
%     * the template declares `stimulus_presentation.presentation_time` inline
%       and the WRITER stopped writing it (`+ndi/+app/+stimulus/decoder.m:132`
%       comments it out and calls `add_file('presentation_time.bin', ...)`
%       instead), so 11 of 11 real documents have block keys
%       {presentation_order, stimuli} and nothing else. The pre-existing
%       TestStimulusPresentation fixture builds an inline `presentation_time`,
%       which no production document has carried for years.
%     * the real `stimuli` list arrives in THREE different MATLAB shapes out of
%       jsondecode -- a scalar struct (one stimulus: 10 of the 11 documents), a
%       cell (225 stimuli whose parameter key sets differ: 1 document), and a
%       struct array (uniform key sets) -- and each is exercised below.
%
%   Run with:
%     runtests('ndi.unittest.migrate.TestStimulusPresentationTimedSequence')

    methods (Test)

        % ================= the signed shape ==============================

        function testSequenceOfGratingsBecomesOneTimedSequenceManipulation(testCase)
            % Four stimuli (three gratings + the blank), six trials with
            % repeats -- the 225-stimulus oridir run in miniature.
            stimuli = { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5), ...
                        gratingStim(90, 0.04, 0.5), blankStim() };
            pres = presentationBody('pres_1', [1 4 2 4 3 1], stimuli);
            [m, gratings, body, records, report] = emit(testCase, pres);

            % ONE manipulation, N grating documents.
            testCase.verifyEqual(m.document_class.class_name, ...
                'timed_sequence_manipulation');
            testCase.verifyEqual(numel(gratings), 4);
            testCase.verifyEqual(report.stimuli_read, 4);
            testCase.verifyEqual(report.distinct_gratings, 4);
            testCase.verifyEqual(report.trials, 6);
            testCase.verifyEqual(report.blank_gratings, 1);

            % each grating is a STANDALONE document of the data_type
            for k = 1:numel(gratings)
                testCase.verifyEqual(gratings{k}.document_class.class_name, ...
                    'visual_grating');
                testCase.verifyTrue(isfield(gratings{k}.visual_grating, 'value'));
            end

            % THE EIGHT TYPED FIELDS, populated -- the point of the change.
            % The flattening pass writes no visual_grating block at all and
            % puts these in an untyped numeric matrix instead.
            v = gratings{2}.visual_grating.value;
            testCase.verifyEqual(sort(fieldnames(v)), sort({'angle'; ...
                'spatial_frequency'; 'temporal_frequency'; 'contrast'; ...
                'size'; 'position'; 'duration'; 'is_blank'}));
            testCase.verifyEqual(v.angle, 45);
            testCase.verifyEqual(v.spatial_frequency, 0.04);
            testCase.verifyEqual(v.temporal_frequency, 0.5);
            testCase.verifyEqual(v.contrast, 1);
            testCase.verifyFalse(v.is_blank);
            testCase.verifyTrue(gratings{4}.visual_grating.value.is_blank);

            % presented_id_1..N, one per DISTINCT grating, each populated.
            for k = 1:4
                testCase.verifyEqual(depValue(m, sprintf('presented_id_%d', k)), ...
                    gratings{k}.base.id);
            end

            % the playlist INDEXES those references, in trial order
            testCase.verifyEqual(m.timed_sequence.value.presentation_order, ...
                [1 4 2 4 3 1]);

            % no timing in a real-shaped document -> no body, and the report
            % says which of "no timing" / "not looked at" it is
            testCase.verifyEmpty(body);
            testCase.verifyEmpty(records);
            testCase.verifyEqual(report.trials_with_timing, 0);
        end

        function testTheV1IdIsPreservedOnTheManipulation(testCase)
            % "decomposed around its preserved id, not dissolved". On 20211116
            % there are 494 inbound edges onto the 11 presentation ids
            % (stimulus_response_scalar 273, hartley_calc 210,
            % control_stimulus_ids 11); every one of them dangles if this
            % moves.
            pres = presentationBody('4126943ebbdf85c2_c0d0b567f5cca85b', ...
                [1 2], { gratingStim(0, 0.04, 0.5), gratingStim(90, 0.04, 0.5) });
            m = emit(testCase, pres);
            testCase.verifyEqual(m.base.id, '4126943ebbdf85c2_c0d0b567f5cca85b');

            % and the NEW documents get NEW ids -- nothing in v1 references an
            % individual stimulus, so reusing the presentation id on one of
            % them would be a second claim on it.
            [~, gratings] = emit(testCase, pres);
            for k = 1:numel(gratings)
                testCase.verifyNotEqual(gratings{k}.base.id, m.base.id);
            end
        end

        function testDuplicateStimuliDedupeToOneGratingDocument(testCase)
            % "deduped by content": two identical parameter sets are ONE
            % document, and the playlist remaps onto the distinct set. v1
            % indexes `stimuli`, the signed encoding indexes `presented_id`;
            % those differ the moment anything dedups, so this pins the remap.
            same = gratingStim(45, 0.04, 0.5);
            pres = presentationBody('pres_dedup', [1 2 3 2], ...
                { same, same, gratingStim(90, 0.04, 0.5) });
            [m, gratings, ~, ~, report] = emit(testCase, pres);

            testCase.verifyEqual(report.stimuli_read, 3);
            testCase.verifyEqual(report.distinct_gratings, 2);
            testCase.verifyEqual(numel(gratings), 2);
            % v1 order [1 2 3 2] over {A A B} -> distinct {A B} -> [1 1 2 1]
            testCase.verifyEqual(m.timed_sequence.value.presentation_order, ...
                [1 1 2 1]);
            testCase.verifyEmpty(depValue(m, 'presented_id_3'));
        end

        function testDedupIgnoresFieldsTheGratingValueDoesNotModel(testCase)
            % Two stimuli identical in the eight typed fields but differing in
            % `nCycles` (which the value does not carry) are one document. If
            % that is ever wrong it is wrong because the VALUE is missing a
            % field, not because the dedup is -- and this test is where that
            % shows up.
            a = gratingStim(45, 0.04, 0.5); a.parameters.nCycles = 1;
            b = gratingStim(45, 0.04, 0.5); b.parameters.nCycles = 64;
            pres = presentationBody('pres_ncycles', [1 2], {a, b});
            [~, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 2);
            testCase.verifyEqual(report.distinct_gratings, 1);
            testCase.verifyEqual(numel(gratings), 1);
        end

        % ================= required fields and edges =====================

        function testEveryRequiredEdgeAndFieldIsPopulatedNonEmpty(testCase)
            % RequiredDependencies (#37) is ARMED BY DEFAULT, so an unfillable
            % required edge QUARANTINES rather than passing through. The
            % required set for timed_sequence_manipulation is subject_id
            % (subject_statement) and base id / session_id /
            % creation_timestamp; timed_sequence.value is mustBeNonEmpty too.
            pres = presentationBody('pres_req', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            [m, gratings] = emit(testCase, pres);

            testCase.verifyNotEmpty(depValue(m, 'subject_id'));
            testCase.verifyNotEmpty(m.base.id);
            testCase.verifyNotEmpty(m.base.session_id);
            testCase.verifyNotEmpty(m.base.creation_timestamp);
            testCase.verifyNotEmpty(m.subject_statement.variable.name);
            testCase.verifyNotEmpty(fieldnames(m.timed_sequence.value));

            for k = 1:numel(gratings)
                testCase.verifyNotEmpty(gratings{k}.base.id);
                testCase.verifyNotEmpty(gratings{k}.base.session_id);
                testCase.verifyNotEmpty(gratings{k}.base.creation_timestamp);
            end

            % AND NO EDGE IS EMITTED WITH AN EMPTY VALUE anywhere. That is the
            % invented-empty-edge pattern: +did2/+validate/references.m:90
            % skips an empty edge, so it validates clean while reading as a
            % recorded fact.
            verifyNoEmptyEdges(testCase, m);
            for k = 1:numel(gratings)
                verifyNoEmptyEdges(testCase, gratings{k});
            end
        end

        function testTheStimulatorBecomesInstrumentIdAndIsOmittedWhenAbsent(testCase)
            % T7: the stimulator is the INSTRUMENT of the interaction; v1
            % `stimulus_element_id` is its source. `instrument_id` is OPTIONAL
            % (subject_interaction declares it mustBeNonEmpty false), so a
            % presentation without one asserts nothing rather than emitting a
            % blank edge.
            pres = presentationBody('pres_instr', 1, { gratingStim(0, 0.04, 0.5) });
            m = emit(testCase, pres);
            testCase.verifyEqual(depValue(m, 'instrument_id'), ...
                '4126943ebaa51186_40d4b41387c4b1a3');

            pres.depends_on = struct('name', {}, 'value', {});
            [m2, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(depValue(m2, 'instrument_id'));
            testCase.verifyFalse(report.instrument_resolved);
            verifyNoEmptyEdges(testCase, m2);
        end

        function testAnIncompleteBaseIsRefusedRatherThanQuarantined(testCase)
            % base declares id / session_id / creation_timestamp mustBeNonEmpty.
            % A passthrough is non-gating; a quarantine is not.
            pres = presentationBody('pres_nodate', 1, { gratingStim(0, 0.04, 0.5) });
            pres.base.datestamp = '';
            [m, gratings, body, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(gratings);
            testCase.verifyEmpty(body);
            testCase.verifyNotEmpty(report.reason);
        end

        % ================= timing / the body tier ========================

        function testRealCorpusShapeCarriesNoInlineTimingSoNoBodyIsEmitted(testCase)
            % 11 of 11 20211116 documents look like this: the block has
            % presentation_order + stimuli and nothing else, and the times are
            % in the attached presentation_time.bin, which a struct-level batch
            % pass does not open. Emitting an axis of zeros here would be the
            % `silentLoss` defect -- "nobody looked" rendered as a measurement.
            pres = presentationBody('pres_notime', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            testCase.verifyFalse(isfield(pres.stimulus_presentation, 'presentation_time'));
            testCase.verifyEqual(pres.files.file_list, {'presentation_time.bin'});

            [m, ~, body, records, report] = emit(testCase, pres);
            testCase.verifyNotEmpty(m);          % the manipulation still lands
            testCase.verifyEmpty(body);
            testCase.verifyEmpty(records);
            testCase.verifyEqual(report.trials_with_timing, 0);
            testCase.verifyEqual(m.subject_statement.storage_mode, 'inline');
        end

        function testInlineTimingProducesAnIrregularTimeAxisOnASampledBody(testCase)
            % The deprecated inline form the reader still accepts
            % (decoder.m:154 "old way"). When the times really are there, the
            % per-trial onsets become an irregular time axis on a sampled_body
            % -- revision 2 of the signed plan.
            pres = presentationBody('pres_timed', [1 2 1], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            pres.stimulus_presentation.presentation_time = ...
                [trialTime(0, 4) trialTime(5, 9) trialTime(10, 14)];

            [m, ~, body, records, report] = emit(testCase, pres);
            testCase.verifyEqual(report.trials_with_timing, 3);
            testCase.verifyNotEmpty(body);
            testCase.verifyEqual(body.document_class.class_name, 'sampled_body');

            % `statement` is mustBeNonEmpty on data_body and points back at the
            % manipulation, i.e. at the PRESERVED presentation id.
            testCase.verifyEqual(depValue(body, 'statement'), 'pres_timed');
            testCase.verifyEqual(depValue(body, 'statement'), m.base.id);

            % ONE axis, because the payload is one duration per trial. The
            % schema reads the list POSITIONALLY -- axes[k] IS array dimension
            % k -- so a spurious second entry would assert a dimension that
            % does not exist.
            ax = body.sampled_body.axes;
            testCase.verifyEqual(numel(ax), 1);
            testCase.verifyEqual(ax(1).variable.name, 'time');
            testCase.verifyFalse(ax(1).regular);
            testCase.verifyEqual(ax(1).n, 3);
            testCase.verifyEqual(ax(1).values.values, [0 5 10]);
            testCase.verifyEqual(ax(1).source_unit, 's');

            % every declared axis sub-field is present, in a fixed order, so
            % `[a, b]` concatenation on a future multi-axis body cannot throw
            testCase.verifyEqual(fieldnames(ax(1)), {'variable'; 'unit'; ...
                'source_unit'; 'approximate'; 'n'; 'regular'; 'origin'; ...
                'spacing'; 'values'; 'labels'});

            % storage_mode says where the samples live; datum_type is on the
            % STATEMENT (signed data_body sec.5), not on the body
            testCase.verifyEqual(m.subject_statement.storage_mode, 'body');
            testCase.verifyEqual(m.subject_statement.datum_type, 'float64');
            testCase.verifyEqual(m.subject_statement.source_datum_type, 'double');
            testCase.verifyFalse(isfield(body.sampled_body, 'datum'));
            testCase.verifyFalse(isfield(body.sampled_body, 'summary'));
            testCase.verifyFalse(isfield(body.sampled_body, 'sample_time'));

            % the payload the caller serialises: one duration per trial
            testCase.verifyEqual(records, [4; 4; 4]);
        end

        function testPartialTimingEmitsNoBodyAtAll(testCase)
            % All-or-nothing: a half-filled time axis would have to invent the
            % rest, and 0 / NaN / carry-forward all read as measurements.
            pres = presentationBody('pres_partial', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            half = trialTime(5, 9);
            half.offset = [];
            pres.stimulus_presentation.presentation_time = [trialTime(0, 4) half];
            [~, ~, body, records, report] = emit(testCase, pres);
            testCase.verifyEmpty(body);
            testCase.verifyEmpty(records);
            testCase.verifyEqual(report.trials_with_timing, 1);
        end

        % ================= scope and refusals ============================

        function testHartleyGeneratorPresentationIsRefusedNotMappedToZeros(testCase)
            % The shape 10 of the 11 20211116 presentations actually have: ONE
            % stimulus whose parameters are the white-noise GENERATOR's (M,
            % K_absmax, L_absmax, sfmax, randState), with presentation_order
            % the scalar 1. It enumerates no basis functions, and it carries
            % no angle / sFrequency / tFrequency -- so
            % gratingValueFromParameters would return a grating at 0 deg,
            % 0 cyc/deg, 0 Hz and every field would look measured.
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            [m, gratings, body, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(gratings);
            testCase.verifyEmpty(body);
            testCase.verifyEqual(report.stimuli_read, 1);
            testCase.verifyEqual(report.non_grating_stimuli, 1);
            testCase.verifyEqual(report.stimulus_kinds.hartleystim, 1);
            testCase.verifySubstring(report.reason, 'hartleystim');
        end

        % ====== the NewStim class recogniser (Jess Haley, 2026-10-21) =====
        % Every fixture below is a parameter shape counted in the six-corpus
        % stimulus census (2026-10-21), with values from the census ranges.

        function testASineGratingIsImageType2AndFolds(testCase)
            pres = presentationBody('pres_sine', [1 2], ...
                { gratingStim(0, 0.04, 0.5), blankStim() });
            [m, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyNotEmpty(m);
            testCase.verifyEqual(numel(gratings), 2);
            testCase.verifyEqual(report.stimulus_kinds.grating, 1);
            testCase.verifyEqual(report.stimulus_kinds.blank, 1);
            testCase.verifyEqual(report.non_grating_stimuli, 0);
        end

        function testASquareGratingIsImageType1AndFolds(testCase)
            % Dab: periodicstim imageType 1, animType 4 (1,812 stimuli).
            sq = gratingStim(90, 0.1, 2);
            sq.parameters.imageType = 1;
            pres = presentationBody('pres_square', [1 2], { sq, blankStim() });
            [m, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyNotEmpty(m);
            testCase.verifyEqual(numel(gratings), 2);
            testCase.verifyEqual(report.stimulus_kinds.grating, 1);
        end

        function testPeriodicstimImageType0BarsAreRefused(testCase)
            % Dab: imageType 0 (a uniform field) in an oriented thin window,
            % stepped by lineoffset -- flashed bars (17,260 stimuli). Its
            % sFrequency has no effect, so it is not a grating.
            pres = presentationBody('pres_bars', [1 2], { barStim(0), blankStim() });
            [m, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(gratings);
            testCase.verifyEqual(report.stimulus_kinds.periodicstim_bars, 1);
            testCase.verifyEqual(report.stimulus_kinds.blank, 1);
            testCase.verifyEqual(report.non_grating_stimuli, 1);
            testCase.verifySubstring(report.reason, 'periodicstim imageType 0');
        end

        function testStochasticGridNoiseIsRefusedDespiteItsAngle(testCase)
            % Soph: 57 presentations of 20 noise stimuli each, every one
            % carrying `angle = 0` (the grid's rotation). The old key test
            % passed them as gratings at 0 cyc/deg.
            pres = presentationBody('pres_noise', [1 2 3], ...
                { noiseStim(1), noiseStim(2), noiseStim(3) });
            [m, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.stochasticgridstim, 3);
            testCase.verifyEqual(report.stimulus_kinds.grating, 0);
            testCase.verifySubstring(report.reason, 'stochasticgridstim');
        end

        function testBlinkingstimIsRefused(testCase)
            % Dab: 129 presentations, one blinkingstim each.
            pres = presentationBody('pres_blink', 1, blinkingStim());
            [m, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.blinkingstim, 1);
            testCase.verifySubstring(report.reason, 'blinkingstim');
        end

        function testShapemoviestimIsRefusedWithAngleOrDisparity(testCase)
            % Dab: 37 presentations label the movie with `angle` (passed by
            % the old key test) and 43 with `disparity`.
            pres = presentationBody('pres_shape', [1 2 3], ...
                { shapeMovieStim('angle', 22.5), shapeMovieStim('disparity', -400), ...
                  blankStim() });
            [m, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.shapemoviestim, 2);
            testCase.verifyEqual(report.stimulus_kinds.blank, 1);
            testCase.verifySubstring(report.reason, 'shapemoviestim');
        end

        function testAnUnrecognisedParameterSetIsRefused(testCase)
            % The positive rule: a set no class's required fields describe is
            % never a grating, even when it carries angle / sFrequency /
            % tFrequency (which the old key test accepted).
            loose = struct('parameters', struct('angle', 45, ...
                'sFrequency', 0.04, 'tFrequency', 2));
            pres = presentationBody('pres_loose', 1, loose);
            [m, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.unrecognised, 1);
            testCase.verifySubstring(report.reason, 'unrecognised');
        end

        function testAPeriodicstimWithAnotherImageTypeIsRefused(testCase)
            odd = gratingStim(0, 0.04, 0.5);
            odd.parameters.imageType = 5;
            pres = presentationBody('pres_odd', 1, odd);
            [m, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.periodicstim_other, 1);
        end

        function testKindsAreCountedEvenWhenNoAnimalResolves(testCase)
            % The per-kind breakdown is taken before the animal is resolved,
            % so a subject-less presentation still reports what it holds.
            pres = presentationBody('pres_none', [1 2], ...
                { noiseStim(1), blankStim() });
            r = ndi.migrate.internal.bodyResolver({pres});
            [m, ~, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulus_kinds.stochasticgridstim, 1);
            testCase.verifyEqual(report.stimulus_kinds.blank, 1);
            testCase.verifySubstring(report.reason, 'no responding animal');
        end

        function testABlankStimulusIsInScope(testCase)
            % The blank carries `isblank` and an `angle`, so it is typeable and
            % must NOT be swept up by the guard above -- it is one of the 225.
            pres = presentationBody('pres_blank', [1 2], ...
                { gratingStim(0, 0.04, 0.5), blankStim() });
            [~, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEqual(report.non_grating_stimuli, 0);
            testCase.verifyEqual(numel(gratings), 2);
            testCase.verifyTrue(gratings{2}.visual_grating.value.is_blank);
        end

        function testNoRespondingAnimalEmitsNothing(testCase)
            % subject_id is mustBeNonEmpty; with nothing to place the
            % manipulation on, the presentation is left as-is.
            pres = presentationBody('pres_1', 1, { gratingStim(0, 0.04, 0.5) });
            r = ndi.migrate.internal.bodyResolver({pres});
            [m, gratings, body, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(gratings);
            testCase.verifyEmpty(body);
            testCase.verifyEqual(report.subjects_resolved, 0);
            testCase.verifyNotEmpty(report.reason);
        end

        % ======== the stimulator route (Jess Haley, 2026-10-21, PR #1021) ===

        function testNoResponseAndNoEpochElementResolvesViaTheStimulator(testCase)
            % The Dab shape: a recorded epoch with no sorted unit, so no
            % element_epoch, and no stimulus_response. The presentation's own
            % stimulus_element_id -> the stimulator element -> its subject.
            pres = presentationBody('pres_stim', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            bodies = { pres, stimulatorElement(stimulatorIdOf(pres), ...
                'animal_stim', pres.base.session_id), ...
                docBody('subject', 'animal_stim') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, gratings, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyNotEmpty(m);
            testCase.verifyEqual(numel(gratings), 2);
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_stim');
            testCase.verifyEqual(report.animal_source, 'stimulator');
            testCase.verifyEqual(report.subjects_resolved, 0);
            testCase.verifyEqual(report.stimulator_subjects, 1);
            testCase.verifyEqual(report.sibling_subjects, 0);
            testCase.verifyEmpty(report.reason);
            verifyNoEmptyEdges(testCase, m);
        end

        function testADerivedStimulatorElementFollowsUpItsChain(testCase)
            % The element -> subject step is the migration's own
            % subjectOfElement: an element with no subject of its own resolves
            % through underlying_element_id.
            pres = presentationBody('pres_stim_derived', 1, { gratingStim(0, 0.04, 0.5) });
            sid = pres.base.session_id;
            derived = docBody('element', stimulatorIdOf(pres), ...
                {'underlying_element_id', 'probe_1'});
            derived.base.session_id = sid;
            bodies = { pres, derived, stimulatorElement('probe_1', 'animal_stim', sid) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_stim');
            testCase.verifyEqual(report.animal_source, 'stimulator');
        end

        function testTheEpochRouteIsStillPreferredWhenItFindsAnElement(testCase)
            % Fork 1 comes first. The stimulator here names a DIFFERENT
            % subject on purpose, so the test can tell which route won; the
            % stimulator route must not even be consulted.
            pres = presentationBody('pres_epoch', 1, { gratingStim(0, 0.04, 0.5) });
            sid = pres.base.session_id;
            ee = docBody('element_epoch', 'ee_1', {'element_id', 'unit_1'});
            ee.base.session_id = sid;
            ee.epochid = struct('epochid', pres.epochid.epochid);
            bodies = { pres, ee, stimulatorElement('unit_1', 'animal_epoch', sid), ...
                stimulatorElement(stimulatorIdOf(pres), 'animal_stim', sid) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_epoch');
            testCase.verifyEqual(report.animal_source, 'epoch');
            testCase.verifyEqual(report.stimulator_subjects, 0);
        end

        function testTheResponseRouteIsStillPreferredOverTheStimulator(testCase)
            pres = presentationBody('pres_resp', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, responseScalar('resp_1', pres.base.id, 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_resp'}), ...
                stimulatorElement(stimulatorIdOf(pres), 'animal_stim', pres.base.session_id) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_resp');
            testCase.verifyEqual(report.animal_source, 'response');
        end

        function testAStimulatorNamingNoSubjectIsRefused(testCase)
            % The stimulator element is present but carries no subject_id and
            % no underlying element: nothing to attribute, refuse as before.
            pres = presentationBody('pres_nosub', 1, { gratingStim(0, 0.04, 0.5) });
            orphan = docBody('element', stimulatorIdOf(pres));
            orphan.base.session_id = pres.base.session_id;
            r = ndi.migrate.internal.bodyResolver({ pres, orphan });
            [m, gratings, body, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(gratings);
            testCase.verifyEmpty(body);
            testCase.verifyEqual(report.animal_source, 'none');
            testCase.verifyEqual(report.stimulator_subjects, 0);
            testCase.verifySubstring(report.reason, 'stimulator element names no subject');
        end

        function testAStimulatorNamingSeveralSubjectsIsRefused(testCase)
            % Two stimulus_element_id edges reaching two different animals:
            % ambiguous, so refuse rather than pick one.
            pres = presentationBody('pres_two', 1, { gratingStim(0, 0.04, 0.5) });
            sid = pres.base.session_id;
            pres.depends_on(end+1) = struct('name', 'stimulus_element_id', ...
                'value', 'stimulator_2');
            bodies = { pres, ...
                stimulatorElement(stimulatorIdOf(pres), 'animal_a', sid), ...
                stimulatorElement('stimulator_2', 'animal_b', sid) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulator_subjects, 2);
            testCase.verifyEqual(report.animal_source, 'none');
            testCase.verifySubstring(report.reason, 'ambiguous');
        end

        function testAStimulatorInAnotherSessionIsNotFollowed(testCase)
            % Session-scoped like fork 1: a stimulator element stored in a
            % different session is never followed (that is fork 2's risk).
            pres = presentationBody('pres_xsess', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, stimulatorElement(stimulatorIdOf(pres), ...
                'animal_other', 'some_other_session') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, report] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.stimulator_subjects, 0);
            testCase.verifyNotEmpty(report.reason);
        end

        function testAPlaylistIndexOutsideTheStimuliListIsRefused(testCase)
            % Dropping the offending trials would silently shorten the
            % playlist; refusing the document does not.
            pres = presentationBody('pres_oor', [1 7], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            [m, ~, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEmpty(m);
            testCase.verifyEqual(report.trials_out_of_range, 1);
            testCase.verifyNotEmpty(report.reason);
        end

        % ================= the shapes jsondecode really produces =========

        function testScalarStimulusAndScalarOrderAreHandled(testCase)
            % 10 of the 11 real documents decode to a SCALAR struct for
            % `stimuli` and a SCALAR double for `presentation_order`, because
            % jsondecode collapses a lone JSON object and a lone number. A
            % reader that assumed a list would mis-handle the common case.
            pres = presentationBody('pres_scalar', 1, gratingStim(45, 0.04, 0.5));
            testCase.verifyTrue(isstruct(pres.stimulus_presentation.stimuli));
            testCase.verifyTrue(isscalar(pres.stimulus_presentation.stimuli));
            [m, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 1);
            testCase.verifyEqual(numel(gratings), 1);
            testCase.verifyEqual(m.timed_sequence.value.presentation_order, 1);
        end

        function testAHeterogeneousStimuliCellIsHandled(testCase)
            % The 225-stimulus document decodes to a CELL, not a struct array,
            % because the 224 gratings and the 1 blank have different
            % parameter key sets (24 keys vs 11). Measured: 2 distinct key
            % signatures within that one document.
            pres = presentationBody('pres_cell', [1 2], ...
                { gratingStim(0, 0.04, 0.5), blankStim() });
            testCase.verifyTrue(iscell(pres.stimulus_presentation.stimuli));
            [~, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 2);
            testCase.verifyEqual(numel(gratings), 2);
        end

        function testAUniformStimuliStructArrayIsHandled(testCase)
            % When every parameter key set matches, jsondecode returns a struct
            % ARRAY instead. Same input, third shape.
            arr = [gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5)];
            pres = presentationBody('pres_arr', [1 2], arr);
            testCase.verifyTrue(isstruct(pres.stimulus_presentation.stimuli));
            testCase.verifyEqual(numel(pres.stimulus_presentation.stimuli), 2);
            [~, gratings, ~, ~, report] = emit(testCase, pres);
            testCase.verifyEqual(report.stimuli_read, 2);
            testCase.verifyEqual(numel(gratings), 2);
        end

        % ================= the instrument reports its denominator ========

        function testTheReportCarriesItsDenominatorsEvenWhenNothingIsEmitted(testCase)
            % Operating Rule 5. A refusal must print the same SHAPE as a
            % success, so "fell through" is never inferable only by
            % subtracting two other counters.
            expected = {'stimuli_read'; 'non_grating_stimuli'; 'stimulus_kinds'; ...
                'distinct_gratings'; 'blank_gratings'; 'trials'; ...
                'trials_out_of_range'; 'trials_with_timing'; 'timing_source'; ...
                'basis_source'; 'shared_refs'; 'frames'; ...
                'subjects_resolved'; 'sibling_subjects'; 'stimulator_subjects'; ...
                'instrument_resolved'; 'epoch_id'; ...
                'animal_source'; 'reason'};

            pres = presentationBody('pres_1', 1, { gratingStim(0, 0.04, 0.5) });
            r = ndi.migrate.internal.bodyResolver({pres});   % nothing responded
            [~, ~, ~, ~, refused] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
            testCase.verifyEqual(fieldnames(refused), expected);

            [~, ~, ~, ~, ok] = emit(testCase, pres);
            testCase.verifyEqual(fieldnames(ok), expected);
            testCase.verifyEmpty(ok.reason);

            % the v1 epoch string is REPORTED rather than turned into a guessed
            % time anchor -- the clocktype it would need lives in the same
            % unreadable presentation_time.bin as the onsets
            testCase.verifyEqual(ok.epoch_id, 't00001');
        end

        % ================= a canary on the subject link ==================

        function testStimulusResponseScalarNowResolvesTheSubject(testCase)
            % THIS TEST WAS THE INVERSE OF ITSELF UNTIL 2026-08-17, and it is
            % kept rather than deleted because the gap it pinned is the reason
            % this whole path was dead on real data.
            %
            % bodyResolver's subjectsForPresentation matched
            % `strcmp(classNameOf(b), 'stimulus_response')`, and the
            % production writer never mints that class:
            % `+ndi/+app/+stimulus/tuning_response.m` writes
            % `ndi.document('stimulus_response_scalar', ...)` with both
            % `stimulus_presentation_id` and `element_id` on it. Measured over
            % the 20211116 corpus (1220 documents read): 0 named
            % `stimulus_response`, 273 named `stimulus_response_scalar`, all
            % 273 carrying both edges, covering all 11 presentations. So NO
            % emitter could fire, on any presentation, on that corpus.
            %
            % The resolver now reads the IS-A from the document's OWN
            % `document_class.superclasses` -- the v1 template declares
            % `{definition: '$NDIDOCUMENTPATH/stimulus/stimulus_response.json'}`
            % on stimulus_response_scalar -- so this is a widening by
            % declaration, not a second name in a list.
            pres = presentationBody('pres_1', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, ...
                responseScalar('resp_1', 'pres_1', 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});

            % and the emitter now lands on that corpus shape
            [m, gratings] = ndi.migrate.internal.stimulusPresentationToTimedSequence( ...
                pres, r, 'V_eta');
            testCase.verifyEqual(m.document_class.class_name, ...
                'timed_sequence_manipulation');
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_1');
            testCase.verifyEqual(numel(gratings), 1);
        end

        function testADocumentThatIsNotAResponseIsStillNotSweptIn(testCase)
            % The widening is by DECLARED superclass, so a class that merely
            % carries the same two edges does not resolve a subject. Without
            % this the previous test would pass under a `contains('response')`
            % implementation too.
            pres = presentationBody('pres_1', 1, { gratingStim(0, 0.04, 0.5) });
            bodies = { pres, ...
                docBody('stimulus_response_scalar_parameters_basic', 'p_1', ...
                    {'stimulus_presentation_id', 'pres_1'}, {'element_id', 'elem_9'}), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

        % ================= the supplied enumeration (Hartley) ============

        function testASuppliedSequenceReplacesThePlaylistAndTheRefs(testCase)
            % The shape 10 of the 11 20211116 presentations have: a GENERATOR
            % RECIPE that enumerates nothing. Refused on its own (the test
            % above), emitted when the enumeration is supplied from the
            % `hartley_calc` documents.
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            seq = struct('presented_ids', {{'g_a', 'g_b', 'g_c'}}, ...
                'order', [1 3 2 3 1], 'frame_times', [0 0.1 0.2 0.3 0.4]);
            [m, gratings, body, records, report] = emit(testCase, pres, seq);

            testCase.verifyEqual(m.document_class.class_name, ...
                'timed_sequence_manipulation');
            % the refs are the SUPPLIED ones -- nothing is minted here,
            % because the basis is shared across every presentation that plays
            % it and must be minted ONCE by the caller
            testCase.verifyEmpty(gratings);
            testCase.verifyEqual(depValue(m, 'presented_id_1'), 'g_a');
            testCase.verifyEqual(depValue(m, 'presented_id_3'), 'g_c');
            testCase.verifyEmpty(depValue(m, 'presented_id_4'));
            testCase.verifyEqual(m.timed_sequence.value.presentation_order, ...
                [1 3 2 3 1]);
            testCase.verifyEqual(m.base.id, 'pres_hartley');   % id preserved

            % the report says WHERE the basis came from, and both counts
            testCase.verifyEqual(report.basis_source, ...
                'supplied enumeration (hartley_calc)');
            testCase.verifyEqual(report.shared_refs, 3);
            testCase.verifyEqual(report.frames, 5);
            testCase.verifyEqual(report.non_grating_stimuli, 0, ...
                ['the generator guard must not run on the supplied path -- ' ...
                 'it describes the presentation''s own stimuli list']);

            % NO sampled_body: there are no bytes. The frame onsets are the
            % axis and the playlist is inline, so the axis mounts on the
            % STATEMENT and storage_mode stays `inline`.
            testCase.verifyEmpty(body);
            testCase.verifyEmpty(records);
            testCase.verifyEqual(m.subject_statement.storage_mode, 'inline');
            ax = m.subject_statement.axes;
            testCase.verifyEqual(numel(ax), 1);
            testCase.verifyEqual(ax(1).variable.name, 'time');
            testCase.verifyFalse(ax(1).regular);
            testCase.verifyEqual(ax(1).n, 5);
            testCase.verifyEqual(ax(1).source_unit, 's');
            testCase.verifyEqual(ax(1).values.values, [0 0.1 0.2 0.3 0.4]);
            testCase.verifyEqual(report.timing_source, 'frameTimes (hartley_calc)');
            testCase.verifyEqual(report.trials_with_timing, 5);
        end

        function testASuppliedSequenceWithNoFrameTimesEmitsNoAxis(testCase)
            % "Nobody looked" is not "it happened at t=0": an absent
            % frame_times leaves the statement without an axis rather than
            % inventing one.
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());
            seq = struct('presented_ids', {{'g_a', 'g_b'}}, 'order', [1 2 1]);
            [m, ~, ~, ~, report] = emit(testCase, pres, seq);
            testCase.verifyFalse(isfield(m.subject_statement, 'axes'));
            testCase.verifyEqual(report.trials_with_timing, 0);
            testCase.verifyEqual(report.frames, 3);
        end

        function testASuppliedSequenceIsRefusedRatherThanRepaired(testCase)
            % Each of the three ways the two halves can disagree. Every one
            % would otherwise emit a document that VALIDATES while saying
            % something untrue, which is the failure mode the whole
            % invented-empty-edge family belongs to.
            pres = presentationBody('pres_hartley', 1, hartleyGeneratorStim());

            outOfRange = struct('presented_ids', {{'g_a'}}, 'order', [1 2]);
            [m1, ~, ~, ~, r1] = emit(testCase, pres, outOfRange);
            testCase.verifyEmpty(m1);
            testCase.verifyNotEmpty(r1.reason);

            raggedTimes = struct('presented_ids', {{'g_a'}}, 'order', [1 1], ...
                'frame_times', [0 1 2]);
            [m2, ~, ~, ~, r2] = emit(testCase, pres, raggedTimes);
            testCase.verifyEmpty(m2);
            testCase.verifyNotEmpty(r2.reason);

            noRefs = struct('presented_ids', {{}}, 'order', [1 1]);
            [m3, ~, ~, ~, r3] = emit(testCase, pres, noRefs);
            testCase.verifyEmpty(m3);
            testCase.verifyNotEmpty(r3.reason);
        end

    end
end

% ===================== driver =============================================

function [manipBody, gratingBodies, bodyDoc, records, report] = emit(~, pres, sequence)
%EMIT Run the assembler with a responding animal in scope.
%   Uses the real bodyResolver over a `stimulus_response_scalar` body -- the
%   class production actually writes, and the one 273 of the 20211116 corpus's
%   documents carry -- so the assembler is exercised through the production
%   resolution path rather than a stub. The fixture used the bare
%   `stimulus_response` name until 2026-08-17, which no corpus holds; see
%   testStimulusResponseScalarNowResolvesTheSubject.
if nargin < 3
    sequence = [];
end
bodies = { pres, ...
    responseScalar('resp_1', pres.base.id, 'elem_9'), ...
    docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
r = ndi.migrate.internal.bodyResolver(bodies);
[manipBody, gratingBodies, bodyDoc, records, report] = ...
    ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta', ...
        sequence);
end

function b = responseScalar(id, presentationId, elementId)
%RESPONSESCALAR A `stimulus_response_scalar` body carrying the v1 template's
%   OWN superclass declaration -- that declaration is what the resolver reads,
%   so a fixture without it would test a different mechanism.
%   Verbatim from ndi_common/database_documents/stimulus/
%   stimulus_response_scalar.json, and matched by every one of the 273 such
%   documents in the 20211116 corpus.
b = docBody('stimulus_response_scalar', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
b.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
end

function b = stimulatorElement(id, subjectId, sessionId)
%STIMULATORELEMENT A v1 element carrying the animal as its own subject_id, the
%   shape of Dab's `vhvis_spike2` stimulator element, stored in SESSIONID.
b = docBody('element', id, {'subject_id', subjectId});
b.base.session_id = sessionId;
end

function id = stimulatorIdOf(pres)
id = depValue(pres, 'stimulus_element_id');
end

function verifyNoEmptyEdges(testCase, body)
%VERIFYNOEMPTYEDGES No depends_on entry may carry an empty value.
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    testCase.verifyNotEmpty(body.depends_on(k).value, ...
        sprintf('depends_on "%s" was emitted with an empty value', ...
            body.depends_on(k).name));
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
v = '';
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, name); v = b.depends_on(k).value; return; end
end
end
