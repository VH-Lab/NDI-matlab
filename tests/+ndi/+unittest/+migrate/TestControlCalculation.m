classdef TestControlCalculation < matlab.unittest.TestCase
%TESTCONTROLCALCULATION ndi.migrate.internal.controlCalculation.
%   Decided by Jess Haley, 2026-10-21 [control record is a calculation]
%   (did-schema V_eta_stimulus_response_model_plan.md): a v1
%   control_stimulus_ids becomes a calculation whose input is the stimulus
%   presentation and whose value names which item is the control.

    methods (TestClassSetup)
        function needsBuilder(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.statement')), ...
                'needs DID-matlab did2.build');
        end
    end

    methods (Test)
        function testAPerTrialControlListBecomesItemPositions(testCase)
            % per-trial item positions [0 1 2 1]; entries name TRIALS 4 and 2
            cs = controlDoc([4 4 2]);
            [c, why] = ndi.migrate.internal.controlCalculation(cs, 'pres_1', ...
                'animal_1', [0 1 2 1], 'sess_1');
            testCase.verifyEmpty(why);
            testCase.verifyEqual(c.document_class.class_name, 'calculation');
            testCase.verifyTrue(any(strcmp({c.document_class.superclasses.class_name}, 'item')));
            testCase.verifyEqual(c.base.id, 'cs_1', 'the v1 id is kept for responses');
            testCase.verifyEqual(c.item.value.item(:)', [1 1 1]);
            testCase.verifyEqual(edgeValue(c, 'input_id'), 'pres_1');
            testCase.verifyEqual(edgeValue(c, 'entity_id'), 'animal_1');
            testCase.verifyEmpty(edgeValue(c, 'time_reference_id'), ...
                'the time reference is the caller''s marker, not a stand-in');
            testCase.verifyEqual(edgeValue(c, did2.convert.mintSessionDuring('marker')), 'cs_1');
            testCase.verifyEqual(c.interaction.method.term.name, 'pseudorandom');
        end

        function testEntriesAreTrialNumbersNotStimulusNumbers(testCase)
            % B's shape: 12 stimuli, 60 trials; entries 11 and 20 name TRIALS
            % (both show stimulus 12, the blank). Read as stimulus numbers 20
            % would be out of range -- the freeze run (39702282413) minted 0 of
            % 1242 that way.
            order = [6 2 10 4 11 3 1 5 9 8 12 7 8 4 9 3 2 6 1 12];
            itemOfStimulus = 0:11;                 % one item per stimulus
            trialPositions = itemOfStimulus(order);
            [c, why] = ndi.migrate.internal.controlCalculation(controlDoc([11 11 20]), ...
                'pres_1', 'animal_1', trialPositions, 'sess_1');
            testCase.verifyEmpty(why);
            testCase.verifyEqual(c.item.value.item(:)', [11 11 11]);
        end

        function testNaNMeansNoControlAndNoCalculation(testCase)
            [c, why] = ndi.migrate.internal.controlCalculation(controlDoc(NaN), ...
                'pres_1', 'animal_1', [0 1], 'sess_1');
            testCase.verifyEmpty(c);
            testCase.verifyEqual(why, 'no control');
            [c, why] = ndi.migrate.internal.controlCalculation(controlDoc([]), ...
                'pres_1', 'animal_1', [0 1], 'sess_1');
            testCase.verifyEmpty(c);
            testCase.verifyEqual(why, 'no control');
        end

        function testRefusalsAreNamed(testCase)
            [c, why] = ndi.migrate.internal.controlCalculation(controlDoc(2), ...
                'pres_1', '', [0 1], 'sess_1');
            testCase.verifyEmpty(c); testCase.verifyEqual(why, 'no subject');
            [c, why] = ndi.migrate.internal.controlCalculation(controlDoc(2), ...
                'pres_1', 'animal_1', [], 'sess_1');
            testCase.verifyEmpty(c); testCase.verifyEqual(why, 'no position map');
            [c, why] = ndi.migrate.internal.controlCalculation(controlDoc([1 9]), ...
                'pres_1', 'animal_1', [0 1], 'sess_1');
            testCase.verifyEmpty(c); testCase.verifyEqual(why, 'unmappable');
        end
    end
end

function d = controlDoc(ids)
d = struct();
d.document_class = struct('class_name', 'control_stimulus_ids', 'class_version', 1);
d.depends_on = struct('name', 'stimulus_presentation_id', 'value', 'pres_1');
d.base = struct('id', 'cs_1', 'session_id', 'sess_1', 'name', '', ...
    'datestamp', '2025-09-11T12:48:55.182Z');
d.control_stimulus_ids = struct('control_stimulus_ids', ids, ...
    'control_stimulus_id_method', struct('method', 'pseudorandom', ...
        'controlid', 'isblank', 'controlid_value', 1));
end

function v = edgeValue(b, name)
v = '';
for k = 1:numel(b.depends_on)
    e = b.depends_on(k);
    if strcmp(e.name, name)
        if isfield(e, 'document_id') && ~isempty(e.document_id); v = e.document_id;
        elseif isfield(e, 'value'); v = e.value; end
        if iscell(v) && ~isempty(v); v = v{1}; end
        return;
    end
end
end
