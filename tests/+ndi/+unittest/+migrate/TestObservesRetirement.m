classdef TestObservesRetirement < matlab.unittest.TestCase
%TESTOBSERVESRETIREMENT ndi.migrate.internal.observesRetirement, over structs.
%
%   Decided by Jess Haley, 2026-11-26 [no observes relation in v2] (did-schema
%   did_v2_standing_wiring_plan.md): v2 has no `observes` relation; NDI's
%   second pass reads each element's v1 `subject_id` directly (the
%   'ElementSubjects' map, ndi.migrate.internal.v1ElementSubjects), and the
%   animal is the `entity_id` of the observations and manipulations made
%   with the element, or, where none names it, is carried as the element's
%   subject. Any `observes` relation pass 1 still wrote is removed.
%   REWRITTEN 2026-11-27 for that decision: until then each test fed an
%   `observes` relation and asserted which relations were retired or kept;
%   now each feeds the element's v1 subject and asserts whether it is named
%   by a statement or carried, and that the pass-1 relation (where the
%   fixture has one) is removed. Five tests asserted a KEPT relation (several
%   entities, a Stimulator manipulation, a recording observation, a child not
%   converted, two parents); they are inverted, each with a control below.
%
%   The earlier decisions, still the rules for what is carried:
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
%   is checked in TestStimulusPresentationItem/testTheStimulatorRouteManipulationNamesTheSubject.
%   Pure struct logic, so no DID-matlab converter is needed, only the
%   schema stamp etaShape writes (did2.schema.v2Stamp).

    methods (TestClassSetup)
        function needTheStamp(testCase)
            testCase.assumeFalse(isempty(which('did2.schema.v2Stamp')), ...
                'did2.schema.v2Stamp (DID-matlab V2) is not on the path');
        end
    end

    methods (Static)
        function m = subjects(varargin)
            % the v1 element subjects: subjects('stim', 'animal', ...)
            m = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for k = 1:2:numel(varargin)
                m(varargin{k}) = varargin{k+1};
            end
        end

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
        function testAMatchingPresentationNamesTheSubject(testCase)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.presentation('p2', 'animal', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'}, 'the pass-1 `observes` relation is removed');
            testCase.verifyEmpty(carries, 'a presentation names the subject: nothing to carry');
            testCase.verifyEqual(r.documents_inspected, 4);
            testCase.verifyEqual(r.elements_with_v1_subject, 1);
            testCase.verifyEqual(r.elements_converted, 1);
            testCase.verifyEqual(r.presentation_manipulations, 2);
            testCase.verifyEqual(r.presentation_instruments, 1);
            testCase.verifyEqual(r.named_by_presentation, 1);
            testCase.verifyEqual(r.carried, 0);
            testCase.verifyEqual(r.observes_seen, 1);
            testCase.verifyEqual(r.observes_removed, 1);
            testCase.verifyEqual(r.observes_kept, 0);
        end

        function testWithNoObservesRelationTheSubjectIsStillRead(testCase)
            % DID-matlab's first pass writes no `observes` ([no observes
            % relation in v2]): the decision is the same without one
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.presentation('p1', 'animal', 'stim'), ...
                P.element('stim2')}, ...
                'ElementSubjects', P.subjects('stim', 'animal', 'stim2', 'animal'));
            testCase.verifyEmpty(ids, 'no relation to remove');
            testCase.verifyEqual(r.observes_seen, 0);
            testCase.verifyEqual(r.named_by_presentation, 1);
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.element_id, 'stim2');
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testAMatchingBathNamesTheSubject(testCase)
            % [bath manipulation retires observes]: as a presentation
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.bath('b1', 'animal', 'stim'), P.bath('b2', 'animal', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEmpty(carries, 'a bath names the subject: nothing to carry');
            testCase.verifyEqual(r.bath_manipulations, 2);
            testCase.verifyEqual(r.bath_instruments, 1);
            testCase.verifyEqual(r.named_by_bath, 1);
            testCase.verifyEqual(r.named_by_presentation, 0);
            testCase.verifyEqual(r.carried, 0);
        end

        function testManipulationsNamingSeveralEntitiesCarryTheSubject(testCase)
            % INVERTED: the reader takes the first manipulation's entity, so
            % where they name the animal and another entity the subject is
            % carried (read before the manipulations). Until [no observes
            % relation in v2] the relation was KEPT (kept_several_entities,
            % [observes kept on several entities] (1)); v2 has no `observes`
            % to keep. Proposed (not decided): carrying here.
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'animal', 'stim'), ...
                P.presentation('p2', 'cohort', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.carried_several_entities, 1);
            testCase.verifyEqual(r.named_by_presentation, 0);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.subject_id, 'animal');
            [~, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.presentation('p1', 'animal', 'stim'), ...
                P.bath('b1', 'slice2', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(r.carried_several_entities, 1, ...
                'a bath naming another entity beside the presentation''s');
            testCase.assertNumElements(carries, 1);
            [~, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.presentation('p1', 'animal', 'stim'), ...
                P.stimulatorManipulation('m1', 'animal2', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(r.carried_several_entities, 1, ...
                'a Stimulator manipulation naming another entity is read by the reader too');
            testCase.assertNumElements(carries, 1);
            % the control: every manipulation names the animal, nothing carried
            [~, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.presentation('p1', 'animal', 'stim'), ...
                P.bath('b1', 'animal', 'stim'), P.stimulatorManipulation('m1', 'animal', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(r.carried, 0);
            testCase.verifyEqual(r.named_by_presentation, 1);
            testCase.verifyEmpty(carries);
        end

        function testAStimulatorManipulationNamingTheSubjectNamesIt(testCase)
            % INVERTED: a statement names the v1 subject, so nothing is
            % carried ([one-field carry in the migration report]: carried
            % only when no presentation, bath manipulation or Stimulator
            % manipulation names the subject), and the reader reads it from
            % the manipulation (ndi.vintage.subjectNamingManipulations). Until
            % [no observes relation in v2] the relation was KEPT
            % (kept_other_manipulation); it is now removed.
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.stimulatorManipulation('m1', 'animal', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.presentation_manipulations, 0);
            testCase.verifyEqual(r.other_manipulations, 1);
            testCase.verifyEqual(r.named_by_other_manipulation, 1);
            testCase.verifyEqual(r.observes_kept, 0);
        end

        function testAStimulatorNoStatementNamesHasTheSubjectCarried(testCase)
            % [stimulator subject carried as needing information]: a
            % stimulator that presented nothing, with no bath or Stimulator
            % manipulation
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.carried, 1);
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.verifyEqual(r.carried_other_entity, 0);
            testCase.verifyEqual(r.observes_removed, 1);
            testCase.verifyEqual(r.observes_kept, 0);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.element_id, 'stim');
            testCase.verifyEqual(carries.subject_id, 'animal');
            testCase.verifyNotEmpty(carries.reason);
        end

        function testAPresentationOfAnotherEntityHasTheSubjectCarried(testCase)
            % a cohort presentation names the session's group, not the
            % animal: no statement names the v1 subject, so it is carried
            % ([stimulator subject carried as needing information])
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.presentation('p1', 'cohort', 'stim'), ...
                P.stimulatorManipulation('m1', 'cohort', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.carried, 1);
            testCase.verifyEqual(r.carried_other_entity, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testARecordingProbeWithNoObservationHasTheSubjectCarried(testCase)
            % [recording probe subject carried the same way]: a session never
            % ingested, so no recording observation is made with the probe
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('probe'), P.observes('obs1', 'probe', 'animal')}, ...
                'ElementSubjects', P.subjects('probe', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.element_id, 'probe');
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testARecordingProbeWithAnObservationIsNamedByIt(testCase)
            % INVERTED: a probe that records: its recording observations name
            % the subject, so nothing is carried. Until [no observes relation
            % in v2] a relation DID-matlab's resolveEpochProbemap left was
            % KEPT here (kept_observation); it is now removed.
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('probe'), P.observes('obs1', 'probe', 'animal'), ...
                P.recording('o1', 'animal', 'probe')}, ...
                'ElementSubjects', P.subjects('probe', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.observations_with_instrument, 1);
            testCase.verifyEqual(r.named_by_observation, 1);
            testCase.verifyEqual(r.observes_kept, 0);
        end

        function testAnObservationOfAnotherEntityHasTheSubjectCarried(testCase)
            % [recording probe subject carried the same way] (Jess Haley,
            % 2026-11-19, did-schema did_v2_standing_wiring_plan.md) names
            % 20211116's n-trode as a probe with no recording observation; it
            % makes only its sorted units' spike trains (entity the unit,
            % instrument the probe: DID-matlab resolveEpochProbemap SPIKE
            % TRAINS). An observation made with the probe about another
            % entity is not its recording observation, so the subject is
            % carried (e2e run 44489262007)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('probe'), P.observes('obs1', 'probe', 'animal'), ...
                P.recording('o1', 'unit1', 'probe'), P.recording('o2', 'unit2', 'probe')}, ...
                'ElementSubjects', P.subjects('probe', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEqual(r.observations_with_instrument, 2);
            testCase.verifyEqual(r.named_by_observation, 0);
            testCase.verifyEqual(r.carried, 1);
            testCase.verifyEqual(r.carried_other_entity, 1);
            testCase.verifyEqual(r.carried_no_statement, 0);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.element_id, 'probe');
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testAnObservationAttributedThroughTheSubjectIsNotTheProbes(testCase)
            % a pyraview re-attributed through the probe's v1 subject
            % ([preview attribution without epoch files]) is not its
            % recording observation: the subject is carried, and the
            % observation still names it
            P = ndi.unittest.migrate.TestObservesRetirement;
            batch = {P.element('probe'), P.recording('pyr1', 'animal', 'probe')};
            [~, r, carries] = ndi.migrate.internal.observesRetirement(batch, ...
                'ElementSubjects', P.subjects('probe', 'animal'));
            testCase.verifyEmpty(carries, 'without the attribution list the observation names it');
            testCase.verifyEqual(r.named_by_observation, 1);
            [~, r, carries] = ndi.migrate.internal.observesRetirement(batch, ...
                'ElementSubjects', P.subjects('probe', 'animal'), ...
                'AttributedViaSubject', {'pyr1'});
            testCase.verifyEqual(r.observations_attributed_via_subject, 1);
            testCase.verifyEqual(r.carried, 1);
            testCase.assertNumElements(carries, 1);
            testCase.verifyEqual(carries.subject_id, 'animal');
        end

        function testAnElementNotConvertedIsCarriedAsV1(testCase)
            % INVERTED: an element carried whole as v1 keeps its own
            % `subject_id`, so nothing is carried for it and its relation (if
            % pass 1 wrote one) goes. Until [no observes relation in v2] the
            % relation was KEPT (kept_child_not_converted).
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.observes('obs1', 'stim', 'animal'), P.presentation('p1', 'x', 'y')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(ids, {'obs1'});
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.elements_not_converted, 1);
            testCase.verifyEqual(r.elements_converted, 0);
        end

        function testWithoutTheCarryApiNothingIsCarriedAndTheRelationIsKept(testCase)
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.element('stim2'), P.observes('obs2', 'stim2', 'animal'), ...
                P.presentation('p1', 'animal', 'stim2')}, ...
                'ElementSubjects', P.subjects('stim', 'animal', 'stim2', 'animal'), ...
                'CanCarry', false);
            testCase.verifyEqual(ids, {'obs2'}, 'a presentation still names its subject');
            testCase.verifyEmpty(carries);
            testCase.verifyEqual(r.kept_no_carry_api, 1);
            testCase.verifyEqual(r.observes_kept, 1);
        end

        function testARelationWithNoV1SubjectIsKept(testCase)
            % INVERTED from testADeviceObservingTwoParentsKeepsBoth: the
            % subject is the v1 element's, not the relation's. A relation
            % whose child has no v1 subject is kept (removing it could lose
            % its parent); one whose child has, is removed, whatever parent
            % it names
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.observes('obs2', 'stim', 'animal2'), ...
                P.presentation('p1', 'animal', 'stim')});
            testCase.verifyEmpty(ids, 'no v1 subject map: nothing is removed');
            testCase.verifyEqual(r.observes_seen, 2);
            testCase.verifyEqual(r.observes_without_v1_subject, 2);
            testCase.verifyEqual(r.observes_kept, 2);
            [ids, r] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stim'), P.observes('obs1', 'stim', 'animal'), ...
                P.observes('obs2', 'stim', 'animal2'), ...
                P.presentation('p1', 'animal', 'stim')}, ...
                'ElementSubjects', P.subjects('stim', 'animal'));
            testCase.verifyEqual(sort(ids), {'obs1', 'obs2'});
            testCase.verifyEqual(r.observes_kept, 0);
            testCase.verifyEqual(r.named_by_presentation, 1);
        end

        function testEachElementIsDecidedOnItsOwn(testCase)
            % two stimulators and two recording probes in one batch
            P = ndi.unittest.migrate.TestObservesRetirement;
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({ ...
                P.element('stimA'), P.element('stimB'), P.element('probe'), P.element('probe2'), ...
                P.observes('obsA', 'stimA', 'animal'), ...
                P.observes('obsB', 'stimB', 'animal'), ...
                P.presentation('pA', 'animal', 'stimA'), ...
                P.presentation('pB', 'other', 'stimB'), ...
                P.recording('oC', 'animal', 'probe')}, ...
                'ElementSubjects', P.subjects('stimA', 'animal', 'stimB', 'animal', ...
                'probe', 'animal', 'probe2', 'animal'));
            testCase.verifyEqual(sort(ids), {'obsA', 'obsB'});
            testCase.verifyEqual(r.elements_converted, 4);
            testCase.verifyEqual(r.named_by_presentation, 1);
            testCase.verifyEqual(r.named_by_observation, 1);
            testCase.verifyEqual(r.carried, 2);
            testCase.verifyEqual(r.carried_other_entity, 1);
            testCase.verifyEqual(r.carried_no_statement, 1);
            testCase.verifyEqual(sort({carries.element_id}), {'probe2', 'stimB'});
            testCase.verifyEqual(r.named_by_observation + r.named_by_presentation + ...
                r.named_by_bath + r.named_by_other_manipulation + r.carried + ...
                r.kept_no_carry_api, r.elements_converted, ...
                'every converted element is named or carried');
        end

        function testAnEmptyBatchReportsEveryCounter(testCase)
            [ids, r, carries] = ndi.migrate.internal.observesRetirement({});
            testCase.verifyEmpty(ids);
            testCase.verifyEmpty(carries);
            for f = {'documents_inspected', 'elements_with_v1_subject', ...
                    'elements_converted', 'elements_not_converted', 'observes_seen', ...
                    'presentation_manipulations', 'presentation_instruments', ...
                    'bath_manipulations', 'bath_instruments', 'other_manipulations', ...
                    'observations_with_instrument', 'observations_attributed_via_subject', ...
                    'named_by_observation', 'named_by_presentation', 'named_by_bath', ...
                    'named_by_other_manipulation', 'carried', 'carried_several_entities', ...
                    'carried_other_entity', 'carried_no_statement', 'kept_no_carry_api', ...
                    'observes_removed', 'observes_kept', 'observes_without_v1_subject'}
                testCase.verifyTrue(isfield(r, f{1}), f{1});
                testCase.verifyEqual(r.(f{1}), 0, f{1});
            end
        end

        function testTheV1SubjectsAreTheDirectElementsWithASubject(testCase)
            % ndi.migrate.internal.v1ElementSubjects: the elements
            % DID-matlab's element migrator wrote `observes` for (direct,
            % a subject, no underlying element)
            el = @(id, direct, subj, under) jsonencode(struct( ...
                'document_class', struct('class_name', 'element'), ...
                'base', struct('id', id), 'element', struct('direct', direct), ...
                'depends_on', struct('name', {'underlying_element_id', 'subject_id'}, ...
                'value', {under, subj})));
            [m, rep] = ndi.migrate.internal.v1ElementSubjects({ ...
                el('a', 1, 'animal', ''), el('b', 0, 'animal', ''), ...
                el('c', 1, '', ''), el('d', 0, 'animal', 'a'), ...
                el('e', true, 'animal2', ''), el('e', true, 'animal3', ''), ...
                '{"document_class":{"class_name":"subject"},"base":{"id":"animal"}}'});
            testCase.verifyEqual(rep.bodies_read, 7);
            testCase.verifyEqual(rep.elements, 6);
            testCase.verifyEqual(sort(keys(m)), {'a'});
            testCase.verifyEqual(m('a'), 'animal');
            testCase.verifyEqual(rep.not_direct, 1);
            testCase.verifyEqual(rep.no_subject, 1);
            testCase.verifyEqual(rep.with_underlying, 1);
            testCase.verifyEqual(rep.conflicting, 1, 'one id with two subjects is not listed');
        end
    end
end
