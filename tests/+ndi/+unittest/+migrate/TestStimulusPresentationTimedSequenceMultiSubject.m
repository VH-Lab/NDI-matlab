classdef TestStimulusPresentationTimedSequenceMultiSubject < matlab.unittest.TestCase
%TESTSTIMULUSPRESENTATIONTIMEDSEQUENCEMULTISUBJECT Unit tests for the
%   MULTI-SUBJECT (storage_mode: reference) branch of
%   ndi.migrate.internal.stimulusPresentationToTimedSequence.
%
%   The single-subject shape is covered by
%   TestStimulusPresentationTimedSequence. This file covers only the fork the
%   signed model (DID-schema V_eta_stimulus_model_plan.md, worked example
%   :73-88) calls for when a presentation resolves to N>1 responding animals:
%   ONE shared standalone `timed_sequence` body-of-record + N
%   `timed_sequence_manipulation` leaves, one per subject, each referencing the
%   body-of-record via `timed_sequence_id` (storage_mode='reference') instead of
%   inline `presented_id_#` edges.
%
%   NO v1 corpus carries a multi-subject presentation (on 20211116 all 11
%   resolve to exactly one subject), so this branch is a MODEL-COMPLETENESS
%   build and these unit tests are its only exercise. Pure struct assembly: no
%   database, no schema cache, no toolbox. Fixtures are the same real-20211116
%   shapes the single-subject file uses, extended to two responding elements.
%
%   Run with:
%     runtests('ndi.unittest.migrate.TestStimulusPresentationTimedSequenceMultiSubject')

    methods (Test)

        % ================= the signed multi-subject shape ================

        function testTwoSubjectsGiveOneTimedSequenceAndTwoManipulations(testCase)
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);

            all = allBodies(m, gratings, extra);
            seqs   = ofClass(all, 'timed_sequence');
            manips = ofClass(all, 'timed_sequence_manipulation');

            % EXACTLY one shared body-of-record, TWO per-subject manipulations.
            testCase.verifyEqual(numel(seqs), 1);
            testCase.verifyEqual(numel(manips), 2);
        end

        function testTheBodyOfRecordKeepsThePreservedPresentationId(testCase)
            % "the v1 stimulus_presentation id is preserved on the
            % body-of-record it becomes (the timed_sequence)" -- so the fan-in
            % (stimulus_response_scalar.stimulus_presentation_id,
            % hartley_calc.stimulus_presentation_id,
            % control_designation.timed_sequence_id) resolves to it.
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all  = allBodies(m, gratings, extra);
            seq  = ofClass(all, 'timed_sequence');
            testCase.verifyEqual(seq{1}.base.id, 'pres_multi');
        end

        function testBothManipulationsReferenceTheOneTimedSequence(testCase)
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all    = allBodies(m, gratings, extra);
            seq    = ofClass(all, 'timed_sequence');
            manips = ofClass(all, 'timed_sequence_manipulation');
            seqId  = seq{1}.base.id;
            for k = 1:numel(manips)
                testCase.verifyEqual(depValue(manips{k}, 'timed_sequence_id'), ...
                    seqId);
                % reference mode carries NO inline presented_id_# edges -- the
                % config docs are shared through the body-of-record.
                testCase.verifyEmpty(depValue(manips{k}, 'presented_id_1'));
                testCase.verifyEqual(manips{k}.subject_statement.storage_mode, ...
                    'reference');
            end
        end

        function testTheTwoManipulationsCarryDistinctSubjectIds(testCase)
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all    = allBodies(m, gratings, extra);
            manips = ofClass(all, 'timed_sequence_manipulation');
            sids   = cellfun(@(x) depValue(x, 'subject_id'), manips, ...
                'UniformOutput', false);
            testCase.verifyEqual(sort(sids), {'animal_1', 'animal_2'});
            testCase.verifyEqual(numel(unique(sids)), 2);
        end

        function testEveryMintedBodyHasAUniqueBaseId(testCase)
            % The sqlite PRIMARY KEY guard: `documents(id TEXT PRIMARY KEY)`.
            % TestStimulusPassGating protects against the OLD co-emission; this
            % protects against the new fork minting two bodies on one id.
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all = allBodies(m, gratings, extra);
            ids = cellfun(@(x) x.base.id, all, 'UniformOutput', false);
            testCase.verifyEqual(numel(ids), numel(unique(ids)), ...
                'two minted bodies share a base.id -- the sqlite PRIMARY KEY');
        end

        function testTheGratingsAreMintedOnceAndSharedNotDuplicated(testCase)
            % Three distinct gratings + the blank -> 4 standalone visual_grating
            % docs, minted ONCE regardless of subject count and referenced by
            % the single body-of-record. Nothing about the stimuli duplicates
            % per subject.
            [~, gratings, ~, ~, report, extra] = emit2(testCase);
            testCase.verifyEqual(numel(gratings), 4);
            for k = 1:numel(gratings)
                testCase.verifyEqual(gratings{k}.document_class.class_name, ...
                    'visual_grating');
            end
            testCase.verifyEqual(report.distinct_gratings, 4);
            testCase.verifyEqual(report.subjects_resolved, 2);

            % the body-of-record carries presented_id_1..N to those 4 gratings
            all = allBodies([], gratings, extra);
            seq = ofClass(all, 'timed_sequence');
            for k = 1:4
                testCase.verifyEqual(depValue(seq{1}, sprintf('presented_id_%d', k)), ...
                    gratings{k}.base.id);
            end
            testCase.verifyEmpty(depValue(seq{1}, 'presented_id_5'));
        end

        function testEveryManipulationCarriesTheRequiredPlaylist(testCase)
            % timed_sequence_manipulation is-a timed_sequence, `value` is
            % mustBeNonEmpty, and ensureClassBlocks materialises the block on
            % every leaf -- so each reference manipulation still carries
            % value.presentation_order (an empty one quarantines). It equals the
            % body-of-record's playlist.
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all    = allBodies(m, gratings, extra);
            seq    = ofClass(all, 'timed_sequence');
            manips = ofClass(all, 'timed_sequence_manipulation');
            playlist = seq{1}.timed_sequence.value.presentation_order;
            testCase.verifyEqual(playlist, [1 4 2 4 3 1]);
            for k = 1:numel(manips)
                testCase.verifyEqual( ...
                    manips{k}.timed_sequence.value.presentation_order, playlist);
            end
        end

        % ================= required edges, no empty edges ================

        function testNoEdgeIsEmittedWithAnEmptyValueAnywhere(testCase)
            % The invented-empty-edge discipline, on every body the fork emits.
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all = allBodies(m, gratings, extra);
            for k = 1:numel(all)
                verifyNoEmptyEdges(testCase, all{k});
            end
        end

        function testTheStimulatorBecomesInstrumentIdOnEveryManipulation(testCase)
            % T7: the stimulator is the interaction's instrument; every
            % per-subject manip carries it.
            [m, gratings, ~, ~, ~, extra] = emit2(testCase);
            all    = allBodies(m, gratings, extra);
            manips = ofClass(all, 'timed_sequence_manipulation');
            for k = 1:numel(manips)
                testCase.verifyEqual(depValue(manips{k}, 'instrument_id'), ...
                    '4126943ebaa51186_40d4b41387c4b1a3');
            end
        end

        % ================= the single-subject path is untouched ==========

        function testSingleSubjectStillReturnsNoExtraBodies(testCase)
            % Regression: the 6th output stays {} on the single-subject path,
            % whose primary manip keeps the presentation id inline (as before).
            pres = presentationBody('pres_solo', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            bodies = { pres, ...
                responseScalar('resp_1', 'pres_solo', 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, ~, extra] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence( ...
                    pres, r, 'V_eta');
            testCase.verifyEmpty(extra);
            testCase.verifyEqual(m.base.id, 'pres_solo');
            testCase.verifyEqual(m.subject_statement.storage_mode, 'inline');
        end

    end
end

% ===================== driver =============================================

function [manipBody, gratingBodies, bodyDoc, records, report, extraBodies] = ...
        emit2(~)
%EMIT2 Run the assembler with TWO responding animals in scope. Two
%   `stimulus_response_scalar` bodies name the same presentation but different
%   responding elements, so bodyResolver.subjectsForPresentation returns two
%   distinct subject_ids and the multi-subject branch fires. Same four-stimulus
%   presentation the single-subject file's leading test uses.
stimuli = { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5), ...
            gratingStim(90, 0.04, 0.5), blankStim() };
pres = presentationBody('pres_multi', [1 4 2 4 3 1], stimuli);
bodies = { pres, ...
    responseScalar('resp_1', 'pres_multi', 'elem_1'), ...
    responseScalar('resp_2', 'pres_multi', 'elem_2'), ...
    docBody('element', 'elem_1', {'subject_id', 'animal_1'}), ...
    docBody('element', 'elem_2', {'subject_id', 'animal_2'}) };
r = ndi.migrate.internal.bodyResolver(bodies);
[manipBody, gratingBodies, bodyDoc, records, report, extraBodies] = ...
    ndi.migrate.internal.stimulusPresentationToTimedSequence(pres, r, 'V_eta');
end

function all = allBodies(manipBody, gratingBodies, extraBodies)
%ALLBODIES Every document the decomposition minted, as one cell -- the primary
%   manip, the shared gratings, and the multi-subject overflow.
all = {};
if ~isempty(manipBody)
    all{end+1} = manipBody;
end
for k = 1:numel(gratingBodies)
    all{end+1} = gratingBodies{k}; %#ok<AGROW>
end
for k = 1:numel(extraBodies)
    all{end+1} = extraBodies{k}; %#ok<AGROW>
end
end

function hits = ofClass(bodies, className)
%OFCLASS The bodies whose concrete class_name is EXACTLY className (so
%   'timed_sequence' does not sweep in 'timed_sequence_manipulation').
hits = {};
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        hits{end+1} = bodies{k}; %#ok<AGROW>
    end
end
end

function verifyNoEmptyEdges(testCase, body)
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
% Transcribed to match the single-subject file's fixtures so the two exercise
% the same shapes.

function b = presentationBody(id, order, stimuli)
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
s = struct('parameters', struct( ...
    'BG', [127.5 127.5 127.5], 'dist', 1, 'values', [127.5 127.5 127.5], ...
    'rect', [0 0 1 1], 'angle', 0, 'pixSize', [1 1], 'N', 1, 'fps', 0.5, ...
    'randState', [0.8301061479240671 0.6704957765200832 0.08449867537860833], ...
    'dispprefs', {{'BGpretime', 0, 'BGposttime', 3}}, ...
    'isblank', 1));
end

function b = responseScalar(id, presentationId, elementId)
%RESPONSESCALAR A `stimulus_response_scalar` body carrying the v1 template's OWN
%   superclass declaration -- that declaration is what bodyResolver reads.
b = docBody('stimulus_response_scalar', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
b.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
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
