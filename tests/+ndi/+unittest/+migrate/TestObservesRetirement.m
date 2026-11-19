classdef TestObservesRetirement < matlab.unittest.TestCase
%TESTOBSERVESRETIREMENT ndi.migrate.internal.observesRetirement, over structs.
%
%   Decided by Jess Haley, 2026-11-17 [observes retires in the second pass]
%   (did-schema did_v2_go_forward_class_audit.md): NDI's second pass retires a
%   stimulator's `observes` relation after it has converted the stimulus
%   presentations into manipulations, where a presentation names the same
%   device as instrument and the same animal as entity.
%   Decided by Jess Haley, 2026-11-19 [bath manipulation retires observes]
%   (same document): a bath manipulation retires it by the same rule.
%   Decided by Jess Haley, 2026-11-19 [stimulator subject carried as needing
%   information], [one-field carry in the migration report] and [recording
%   probe subject carried the same way] (did-schema
%   did_v2_standing_wiring_plan.md; carry register row carry-172): where no
%   presentation, bath manipulation or Stimulator manipulation names the v1
%   subject (and no recording observation is made with the element), the
%   relation retires and the subject is carried, one CARRIES entry per
%   element (the caller records it with did2.convert.carryElementSubject).
%
%   THE FIXTURES ARE THE EMITTERS' SHAPES. The `observes` relation is what
%   DID-matlab's +migrators_j/element.m lineageRelation writes (a
%   directed_relation, relation {node '', name 'observes'}, child_id the
%   element, parent_id the subject). A presentation is what
%   ndi.migrate.internal.stimulusPresentationToItem writes: a `manipulation`
%   with value kind `item`, entity_id the animal (or the session's cohort),
%   instrument_id the stimulator. A bath is what
%   ndi.migrate.internal.stimulusBathToBath writes: a `manipulation` with
%   value kind `formulation`, entity_id the stimulator's subject,
%   instrument_id the stimulator. A Stimulator manipulation is what
%   DID-matlab's resolveEpochProbemap mkManipulation writes: value kind
%   `term`. A recording observation names the probe as instrument. The
%   element is an `entity` of type device. The same functions' real output
%   is checked in TestStimulusPresentationItem/testTheStimulatorRouteManipulationRetiresObserves.
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

        function b = element(id)
            % the migrated element: an entity of type device, its v1 id kept
            b = ndi.migrate.internal.etaShape.entity('device', ...
                struct('name', id, 'local_identifier', [id ' | 1']), 'Id', id, 'SessionId', 's1');
        end

        function b = presentation(id, entity, instrument)
            b = ndi.migrate.internal.etaShape.statement('manipulation', 'item', ...
                entity, struct('node', '', 'name', 'stimulus'), struct('item', [0 1 0]), ...
                'Id', id, 'SessionId', 's1', 'InstrumentId', instrument);
        end

        function b = bath(id, entity, instrument)
            % a bath (stimulusBathToBath): value kind formulation
            b = ndi.migrate.internal.etaShape.statement('manipulation', 'formulation', ...
                entity, struct('node', '', 'name', 'bath solution'), [], ...
                'Id', id, 'SessionId', 's1', 'InstrumentId', instrument);
        end

        function b = stimulatorManipulation(id, entity, instrument)
            % a per-epoch Stimulator manipulation (resolveEpochProbemap
            % mkManipulation): value kind term, not a presentation or a bath
            b = ndi.migrate.internal.etaShape.statement('manipulation', 'term', ...
                entity, struct('node', '', 'name', 'stimulator'), ...
                struct('node', '', 'name', 'stimulator'), ...
                'Id', id, 'SessionId', 's1', 'InstrumentId', instrument);
        end

        function b = recording(id, entity, instrument)
            % a recording observation made with a probe
            b = ndi.migrate.internal.etaShape.statement('observation', 'voltage', ...
                entity, struct('node', '', 'name', 'voltage'), [], ...
                'Id', id, 'SessionId', 's1', 'InstrumentId', instrument);
        end
    end

    methods (Test)
        function testAMatchingPresentationRetiresTheRelation(testCase)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.presentation('p2', 'animal', 'stim')});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEmpty(carries, 'a presentation names the subject: nothing to carry');
            testCase.verifyEqual(r.documents_inspected, 3);
            testCase.verifyEqual(r.observes_seen, 1);
            testCase.verifyEqual(r.presentation_manipulations, 2);
            testCase.verifyEqual(r.presentation_instruments, 1);
            testCase.verifyEqual(r.observes_retired, 1);
            testCase.verifyEqual(r.retired_by_presentation, 1);
            testCase.verifyEqual(r.observes_kept, 0);
        end

        function testAMatchingBathRetiresTheRelation(testCase)
            % [bath manipulation retires observes]: as a presentation
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.bath('b1', 'animal', 'stim'), P.bath('b2', 'animal', 'stim')});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEmpty(carries, 'a bath names the subject: nothing to carry');
            testCase.verifyEqual(r.bath_manipulations, 2);
            testCase.verifyEqual(r.bath_instruments, 1);
            testCase.verifyEqual(r.retired_by_bath, 1);
            testCase.verifyEqual(r.retired_by_presentation, 0);
            testCase.verifyEqual(r.observes_retired, 1);
            testCase.verifyEqual(r.observes_kept, 0);
        end

        function testPresentationsAndBathsNamingSeveralEntitiesKeepTheRelation(testCase)
            % the reader takes the first presentation's or bath's entity, so
            % the relation goes only when every one of them names the animal
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.presentation('p2', 'cohort', 'stim')});
            testCase.verifyEmpty(ids);
            testCase.verifyEqual(r.kept_several_entities, 1);
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.bath('b1', 'slice2', 'stim')});
            testCase.verifyEmpty(ids, 'a bath naming another entity beside the presentation''s');
            testCase.verifyEqual(r.kept_several_entities, 1);
        end

        function testAStimulatorManipulationNamingTheSubjectKeepsTheRelation(testCase)
            % a statement names the v1 subject, so nothing is carried, and no
            % decision retires `observes` on a Stimulator manipulation in
            % NDI's pass ([one-field carry in the migration report]: carried
            % only when no presentation, bath manipulation or Stimulator
            % manipulation names the subject)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.stimulatorManipulation('m1', 'animal', 'stim')});
            testCase.verifyEmpty(ids);
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.observes_seen, 1);
            testCase.verifyEqual(r.presentation_manipulations, 0);
            testCase.verifyEqual(r.other_manipulations, 1);
            testCase.verifyEqual(r.kept_other_manipulation, 1);
            testCase.verifyEqual(r.observes_kept, 1);
        end

        function testAStimulatorNoStatementNamesRetiresWithTheSubjectCarried(testCase)
            % [stimulator subject carried as needing information]: a
            % stimulator that presented nothing, with no bath or Stimulator
            % manipulation
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal')});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.retired_carried, 1);
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.verifyEqual(r.carried_other_entity, 0);
            testCase.verifyEqual(r.observes_retired, 1);
            testCase.verifyEqual(r.observes_kept, 0);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.element_id, 'stim');
            testCase.verifyEqual(carries.subject_id, 'animal');
            testCase.verifyNotEmpty(carries.reason);
        end

        function testAPresentationOfAnotherEntityRetiresWithTheSubjectCarried(testCase)
            % a cohort presentation names the session's group, not the
            % animal: no presentation names the v1 subject, so it is carried
            % ([stimulator subject carried as needing information]). Before
            % that decision this relation was kept (kept_other_entity).
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'cohort', 'stim'), ...
                P.stimulatorManipulation('m1', 'cohort', 'stim')});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.retired_carried, 1);
            testCase.verifyEqual(r.carried_other_entity, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testARecordingProbeWithNoObservationRetiresWithTheSubjectCarried(testCase)
            % [recording probe subject carried the same way]: a session never
            % ingested, so no recording observation is made with the probe
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('probe'), P.observes('obs1', 'probe', 'animal')});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.element_id, 'probe');
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testARecordingProbeWithAnObservationKeepsTheRelation(testCase)
            % a probe that records: DID-matlab's resolveEpochProbemap retires
            % its `observes` where an observation names the same subject;
            % this pass keeps it either way
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('probe'), P.observes('obs1', 'probe', 'animal'), ...
                P.recording('o1', 'other', 'probe')});
            testCase.verifyEmpty(ids);
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.observations_with_instrument, 1);
            testCase.verifyEqual(r.kept_observation, 1);
        end

        function testAnObservationAttributedThroughObservesIsNotTheProbes(testCase)
            % a pyraview re-attributed through the probe's own `observes`
            % ([preview attribution without epoch files]) is not its
            % recording observation: the relation retires, the subject is
            % carried, and the observation still names it
            P = ndi.unittest.migrate.TestObservesRetirement;
            batch = {P.element('probe'), P.observes('obs1', 'probe', 'animal'), ...
                P.recording('pyr1', 'animal', 'probe')};
            [ids, r] = ndi.migrate.internal.observesRetirement(batch);
            testCase.verifyEmpty(ids, 'without the attribution list the observation keeps it');
            testCase.verifyEqual(r.kept_observation, 1);
            [ids, r, carries] = ndi.migrate.internal.observesRetirement(batch, ...
                'AttributedViaObserves', {'pyr1'});
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.observations_attributed_via_observes, 1);
            testCase.verifyEqual(r.retired_carried, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testAChildThatIsNotAConvertedEntityKeepsTheRelation(testCase)
            % the carried field is collected only for a v2 document
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal')});
            testCase.verifyEmpty(ids);
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.kept_child_not_converted, 1);
        end

        function testWithoutTheCarryApiNothingIsRetiredThatNeedsIt(testCase)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.element('stim2'), P.observes('obs2', 'stim2', 'animal'), ...
                P.presentation('p1', 'animal', 'stim2')}, 'CanCarry', false);
            testCase.verifyEqual(ids, {'obs2'}, 'a presentation still retires its relation');
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.kept_no_carry_api, 1);
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

        function testEachDeviceIsDecidedOnItsOwn(testCase)
            % two stimulators and two recording probes in one batch
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stimA'), P.element('stimB'), P.element('probe'), P.element('probe2'), ...
                P.observes('obsA', 'stimA', 'animal'), ...
                P.observes('obsB', 'stimB', 'animal'), ...
                P.observes('obsC', 'probe', 'animal'), ...
                P.observes('obsD', 'probe2', 'animal'), ...
                P.presentation('pA', 'animal', 'stimA'), ...
                P.presentation('pB', 'other', 'stimB'), ...
                P.recording('oC', 'animal', 'probe')});
            testCase.verifyEqual(sort(ids), {'obsA', 'obsB', 'obsD'});
            testCase.verifyEqual(r.observes_seen, 4);
            testCase.verifyEqual(r.retired_by_presentation, 1);
            testCase.verifyEqual(r.retired_carried, 2);
            testCase.verifyEqual(r.carried_other_entity, 1);
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.verifyEqual(r.kept_observation, 1);
            testCase.verifyEqual(sort({carries.element_id}), {'probe2', 'stimB'});
            testCase.verifyEqual(r.observes_retired + r.observes_kept, r.observes_seen, ...
                'every relation read is retired or kept');
            testCase.verifyEqual(r.observes_retired, ...
                r.retired_by_presentation + r.retired_by_bath + r.retired_carried);
        end

        function testAnEmptyBatchReportsEveryCounter(testCase)
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({});
            testCase.verifyEmpty(ids);
            testCase.verifyEmpty(carries);
            for f = {'documents_inspected', 'observes_seen', 'presentation_manipulations', ...
                    'presentation_instruments', 'bath_manipulations', 'bath_instruments', ...
                    'other_manipulations', 'observations_with_instrument', ...
                    'observations_attributed_via_observes', 'observes_retired', ...
                    'retired_by_presentation', 'retired_by_bath', 'retired_carried', ...
                    'carried_other_entity', 'carried_no_statement', 'kept_incomplete', ...
                    'kept_several_observes', 'kept_several_entities', ...
                    'kept_other_manipulation', 'kept_observation', ...
                    'kept_child_not_converted', 'kept_no_carry_api', 'observes_kept'}
                testCase.verifyTrue(isfield(r, f{1}), f{1});
                testCase.verifyEqual(r.(f{1}), 0, f{1});
            end
        end
    end
end
