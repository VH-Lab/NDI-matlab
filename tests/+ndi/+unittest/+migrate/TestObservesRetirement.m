classdef TestObservesRetirement < matlab.unittest.TestCase
%TESTOBSERVESRETIREMENT ndi.migrate.internal.observesRetirement, over structs.
%
%   Decided by Jess Haley, 2026-11-17 [observes retires in the second pass]
%   (did-schema did_v2_go_forward_class_audit.md): NDI's second pass retires a
%   stimulator's `observes` relation after it has converted the stimulus
%   presentations into manipulations, where a presentation names the same
%   device as instrument and the same animal as entity.
%
%   THE FIXTURES ARE THE EMITTERS' SHAPES. The `observes` relation is what
%   DID-matlab's +migrators_j/element.m lineageRelation writes (a
%   directed_relation, relation {node '', name 'observes'}, child_id the
%   element, parent_id the subject). A presentation is what
%   ndi.migrate.internal.stimulusPresentationToItem writes: a `manipulation`
%   with value kind `item`, entity_id the animal (or the session's cohort),
%   instrument_id the stimulator. The same function's real output is checked
%   in TestStimulusPresentationItem/testTheStimulatorRouteManipulationRetiresObserves.
%   Pure struct logic, so no DID-matlab converter is needed, only the
%   schema stamp etaShape writes (did2.schema.v2Stamp).

    methods (TestClassSetup)
        function needTheStamp(testCase)
            testCase.assumeFalse(isempty(which('did2.schema.v2Stamp')), ...
                'did2.schema.v2Stamp (DID-matlab V2) is not on the path');
        end
    end

    methods (Static)
        function b = observes(id, child, parent)
            b = ndi.migrate.internal.etaShape.relation(child, parent, ...
                struct('node', '', 'name', 'observes'), 'Id', id, 'SessionId', 's1');
        end

        function b = presentation(id, entity, instrument)
            b = ndi.migrate.internal.etaShape.statement('manipulation', 'item', ...
                entity, struct('node', '', 'name', 'stimulus'), struct('item', [0 1 0]), ...
                'Id', id, 'SessionId', 's1', 'InstrumentId', instrument);
        end

        function b = bath(id, entity, instrument)
            % a manipulation by the stimulator that is not a presentation
            b = ndi.migrate.internal.etaShape.statement('manipulation', 'term', ...
                entity, struct('node', '', 'name', 'stimulator'), ...
                struct('node', '', 'name', 'stimulator'), ...
                'Id', id, 'SessionId', 's1', 'InstrumentId', instrument);
        end
    end

    methods (Test)
        function testAMatchingPresentationRetiresTheRelation(testCase)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.presentation('p2', 'animal', 'stim')});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.documents_inspected, 3);
            testCase.verifyEqual(r.observes_seen, 1);
            testCase.verifyEqual(r.presentation_manipulations, 2);
            testCase.verifyEqual(r.presentation_instruments, 1);
            testCase.verifyEqual(r.observes_retired, 1);
            testCase.verifyEqual(r.observes_kept, 0);
        end

        function testNoPresentationKeepsTheRelation(testCase)
            % a recording probe's, or a stimulator that presented nothing;
            % a bath manipulation by the stimulator is not a presentation
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), ...
                P.bath('b1', 'animal', 'stim')});
            testCase.verifyEmpty(ids);
            testCase.verifyEqual(r.observes_seen, 1);
            testCase.verifyEqual(r.presentation_manipulations, 0);
            testCase.verifyEqual(r.kept_no_presentation, 1);
            testCase.verifyEqual(r.observes_kept, 1);
        end

        function testAPresentationOfAnotherEntityKeepsTheRelation(testCase)
            % a cohort presentation names the session's group, not the animal
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'cohort', 'stim')});
            testCase.verifyEmpty(ids);
            testCase.verifyEqual(r.kept_other_entity, 1);
            testCase.verifyEqual(r.observes_kept, 1);
        end

        function testPresentationsNamingSeveralEntitiesKeepTheRelation(testCase)
            % the reader takes the first presentation's entity, so the
            % relation goes only when every presentation names the animal
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.presentation('p2', 'cohort', 'stim')});
            testCase.verifyEmpty(ids);
            testCase.verifyEqual(r.kept_several_entities, 1);
        end

        function testADeviceObservingTwoParentsKeepsBoth(testCase)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), ...
                P.observes('obs2', 'stim', 'animal2'), ...
                P.presentation('p1', 'animal', 'stim')});
            testCase.verifyEmpty(ids);
            testCase.verifyEqual(r.observes_seen, 2);
            testCase.verifyEqual(r.kept_several_observes, 2);
            testCase.verifyEqual(r.observes_kept, 2);
        end

        function testOnlyTheMatchingDeviceIsRetired(testCase)
            % two stimulators and a recording probe in one batch
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obsA', 'stimA', 'animal'), ...
                P.observes('obsB', 'stimB', 'animal'), ...
                P.observes('obsC', 'probe', 'animal'), ...
                P.presentation('pA', 'animal', 'stimA'), ...
                P.presentation('pB', 'other', 'stimB')});
            testCase.verifyEqual(ids, {'obsA'});
            testCase.verifyEqual(r.observes_seen, 3);
            testCase.verifyEqual(r.observes_retired, 1);
            testCase.verifyEqual(r.kept_other_entity, 1);
            testCase.verifyEqual(r.kept_no_presentation, 1);
            testCase.verifyEqual(r.observes_retired + r.observes_kept, r.observes_seen, ...
                'every relation read is retired or kept');
        end

        function testAnEmptyBatchReportsEveryCounter(testCase)
            [ids, r] = ndi.migrate.internal.observesRetirement({});
            testCase.verifyEmpty(ids);
            for f = {'documents_inspected', 'observes_seen', 'presentation_manipulations', ...
                    'presentation_instruments', 'observes_retired', 'kept_incomplete', ...
                    'kept_several_observes', 'kept_no_presentation', 'kept_other_entity', ...
                    'kept_several_entities', 'observes_kept'}
                testCase.verifyTrue(isfield(r, f{1}), f{1});
                testCase.verifyEqual(r.(f{1}), 0, f{1});
            end
        end
    end
end
