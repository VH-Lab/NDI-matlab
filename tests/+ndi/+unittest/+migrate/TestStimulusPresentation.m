classdef TestStimulusPresentation < matlab.unittest.TestCase
%TESTSTIMULUSPRESENTATION Unit tests for
%   ndi.migrate.internal.stimulusPresentationToManipulation (pure struct assembly;
%   no database, schema, or toolbox needed).
%
%   A stimulus_presentation becomes ONE body-backed visual_grating_manipulation on
%   the animal (resolved via the response link), with a sample-per-trial series
%   whose sample times are the trial onsets (sample_time.offsets).
%
%   Run with:  runtests('ndi.unittest.migrate.TestStimulusPresentation')

    methods (Test)

        function testBecomesBodyBackedGratingManipulation(testCase)
            pres = presentationDoc('pres_1');
            bodies = { pres, ...
                stimResponse('resp_1', 'pres_1', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [m, b, records] = ...
                ndi.migrate.internal.stimulusPresentationToManipulation(pres, r, 'V_eta');

            % a body-backed visual_grating_manipulation on the animal
            testCase.verifyEqual(m.document_class.class_name, 'visual_grating_manipulation');
            testCase.verifyEqual(depValue(m, 'subject_id'), 'animal_1');
            testCase.verifyEqual(m.subject_statement.storage_mode, 'body');
            testCase.verifyEqual(m.base.id, 'pres_1');   % source id preserved

            % the sampled_body: onsets ARE the sample times (offsets), record per trial
            testCase.verifyEqual(b.document_class.class_name, 'sampled_body');
            testCase.verifyEqual(depValue(b, 'statement'), 'pres_1');
            testCase.verifyFalse(b.sampled_body.sample_time.regular);
            testCase.verifyEqual(b.sampled_body.sample_time.offsets, [0 5]);
            testCase.verifyEqual(b.sampled_body.sample_time.n, 2);
            testCase.verifyEqual(b.sampled_body.datum.shape, [2 7]);

            % trial records: [angle sf tf contrast size is_blank duration]
            testCase.verifyEqual(size(records), [2 7]);
            testCase.verifyEqual(records(1, 1), 45);   % trial 1 angle
            testCase.verifyEqual(records(2, 1), 90);   % trial 2 angle
            testCase.verifyEqual(records(1, 7), 4);    % trial 1 duration (4 - 0)
            testCase.verifyEqual(records(2, 7), 4);    % trial 2 duration (9 - 5)
        end

        function testBlankTrialKeptAsRow(testCase)
            pres = presentationWithBlank('pres_2');
            bodies = { pres, ...
                stimResponse('resp_1', 'pres_2', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [~, b, records] = ...
                ndi.migrate.internal.stimulusPresentationToManipulation(pres, r, 'V_eta');
            testCase.verifyEqual(b.sampled_body.sample_time.n, 2);   % blank kept
            testCase.verifyEqual(records(2, 6), 1);   % trial 2 is_blank = true
        end

        function testNoResponderReturnsEmpty(testCase)
            pres = presentationDoc('pres_1');
            r = ndi.migrate.internal.bodyResolver({pres});   % no stimulus_response
            [m, b] = ndi.migrate.internal.stimulusPresentationToManipulation(pres, r, 'V_eta');
            testCase.verifyEmpty(m);
            testCase.verifyEmpty(b);
        end

    end
end

% ===================== fixtures ===========================================

function b = presentationDoc(id)
% two grating trials: angle 45 (onset 0) then angle 90 (onset 5), each 4 s
s1 = stim(45); s2 = stim(90);
b = presentationBody(id, [1 2], ...
    [trialTime(0, 4) trialTime(5, 9)], [s1 s2]);
end

function b = presentationWithBlank(id)
s1 = stim(45); s2 = blankStim();
b = presentationBody(id, [1 2], ...
    [trialTime(0, 4) trialTime(5, 9)], [s1 s2]);
end

function b = presentationBody(id, order, times, stimuli)
b = struct();
b.document_class = struct('class_name', 'stimulus_presentation');
b.depends_on = struct('name', {'stimulus_element_id'}, 'value', {'stimulator_5'});
b.base = struct('id', id, 'session_id', 'sess_09', 'name', 'sp', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
b.stimulus_presentation = struct('presentation_order', order, ...
    'presentation_time', times, 'stimuli', stimuli);
end

function s = stim(angle)
s = struct('parameters', struct('angle', angle, 'sFrequency', 0.5, ...
    'tFrequency', 2, 'contrast', 1, 'size', 30, 'isblank', 0));
end

function s = blankStim()
s = struct('parameters', struct('isblank', 1));
end

function t = trialTime(onset, offset)
t = struct('onset', onset, 'offset', offset);
end

function b = stimResponse(id, presentationId, elementId)
b = docBody('stimulus_response', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
end

function b = element(id, subjectId)
b = docBody('element', id, {'subject_id', subjectId});
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
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, name); v = b.depends_on(k).value; return; end
end
end
