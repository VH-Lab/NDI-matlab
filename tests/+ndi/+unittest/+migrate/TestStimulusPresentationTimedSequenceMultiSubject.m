classdef TestStimulusPresentationTimedSequenceMultiSubject < matlab.unittest.TestCase
%TESTSTIMULUSPRESENTATIONTIMEDSEQUENCEMULTISUBJECT A presentation that
%   resolves to SEVERAL animals in its session, in
%   ndi.migrate.internal.stimulusPresentationToTimedSequence.
%
%   INVERTED 2026-10-21 (Jess Haley). This file pinned the storage_mode
%   `reference` shape: one shared `timed_sequence` plus N per-animal
%   manipulations. That shape is retired. The decided shape is ONE cohort
%   entity per session (each animal member_of it) and ONE manipulation of the
%   cohort with `distributive` true. The did-schema this pass writes
%   (v_eta-pre73, pinned by the NDI e2e workflows) has no
%   subject_statement.distributive, so the cohort shape cannot be written: the
%   presentation is left as v1, with a reason, and counted. No N copies.
%
%   Pure struct assembly: no database, no schema cache, no toolbox.
%
%   Run with:
%     runtests('ndi.unittest.migrate.TestStimulusPresentationTimedSequenceMultiSubject')

    methods (Test)

        function testSeveralAnimalsArePassedThroughNotCopied(testCase)
            [m, gratings, bodyDoc, ~, report, extra] = emit2(testCase);
            testCase.verifyEmpty(m, 'no manipulation: the presentation stays v1');
            testCase.verifyEmpty(extra, 'no per-animal copies');
            testCase.verifyEmpty(gratings, 'nothing is minted for a passed-through presentation');
            testCase.verifyEmpty(bodyDoc);
            testCase.verifyEqual(report.subjects_resolved, 2);
        end

        function testTheAnimalCountAndReasonAreReported(testCase)
            [~, ~, ~, ~, report] = emit2(testCase);
            testCase.verifyEqual(report.several_animals, 2, ...
                'the counter carries how many animals the presentation names');
            testCase.verifySubstring(report.reason, 'several animals');
            testCase.verifySubstring(report.reason, 'distributive');
        end

        function testOneAnimalIsNotCountedAsSeveral(testCase)
            pres = presentationBody('pres_solo', [1 2], ...
                { gratingStim(0, 0.04, 0.5), gratingStim(45, 0.04, 0.5) });
            bodies = { pres, ...
                responseScalar('resp_1', 'pres_solo', 'elem_9'), ...
                docBody('element', 'elem_9', {'subject_id', 'animal_1'}) };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, ~, ~, ~, report, extra] = ...
                ndi.migrate.internal.stimulusPresentationToTimedSequence( ...
                    pres, r, 'V_eta');
            testCase.verifyEqual(report.several_animals, 0);
            testCase.verifyEmpty(extra);
            testCase.verifyEqual(m.base.id, 'pres_solo');
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_1', ...
                'a single-animal presentation still names its animal');
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
