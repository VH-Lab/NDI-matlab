classdef TestBodyResolver < matlab.unittest.TestCase
%TESTBODYRESOLVER Unit tests for ndi.migrate.internal.bodyResolver (pure struct
%   graph lookups; no database, schema, or MATLAB toolbox needed).
%
%   Focus: subjectsForPresentation -- the animal a stimulus_presentation was shown
%   to, reached through the response link (stimulus_response carries both
%   stimulus_presentation_id and the responding element_id -> its subject). A
%   presentation only names the stimulator, so this is how the V_eta second pass
%   puts the stimulus manipulation on the animal.
%
%   Run with:  runtests('ndi.unittest.migrate.TestBodyResolver')

    methods (Test)

        % ============ the epoch clock, audit batch 2 (b), 2026-11-26 =====

        function testAnEpochWithNoClockRecordHasNoClock(testCase)
            % [one-reading quick answers] Q2 and [no invented values] (Jess
            % Haley, 2026-10-26, did-schema did_v2_go_forward_class_audit.md;
            % built 2026-11-26, audit batch 2 (b)): with no element_epoch
            % and no epochclocktimes for the (element, epoch), the clock is
            % '' and its source 'none' -- not an assumed 'dev_local_time'.
            % The Dab baths are this case: 1,605 of 1,605 (stimulator, epoch)
            % pairs have neither record (Dab.zip, measured 2026-11-26).
            bodies = { element('stimulator_5', 'animal_1'), ...
                elementEpochClock('other_elem', 't00001', 'dev_local_time') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [clock, source] = r.epochClockOfElement('stimulator_5', 't00001');
            testCase.verifyEqual(clock, '');
            testCase.verifyEqual(source, 'none');
            testCase.verifyEqual(r.epochClockOfElement('stimulator_5', 't00001'), '', ...
                'one output: the clock alone, still empty');
        end

        function testAnElementEpochGivesTheClock(testCase)
            % the control: the stimulator's own element_epoch for that epoch
            % gives the clock (and an element_epoch of another epoch does not)
            bodies = { element('stimulator_5', 'animal_1'), ...
                elementEpochClock('stimulator_5', 't00001', 'exp_global_time'), ...
                elementEpochClock('stimulator_5', 't00002', 'dev_local_time') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            [clock, source] = r.epochClockOfElement('stimulator_5', 't00001');
            testCase.verifyEqual(clock, 'exp_global_time');
            testCase.verifyEqual(source, 'element_epoch');
            [clock, source] = r.epochClockOfElement('stimulator_5', 't00003');
            testCase.verifyEqual(clock, '');
            testCase.verifyEqual(source, 'none');
        end

        function testAnEpochclocktimesRecordGivesTheClock(testCase)
            % the second record the resolver reads, favouring dev_local_time
            ect = docBody('epochclocktimes', 'ect_1');
            ect.epochid = struct('epochid', 't00001');
            ect.epochclocktimes = struct('clocktype', 'utc');
            ect2 = ect;
            ect2.base.id = 'ect_2';
            ect2.epochclocktimes.clocktype = 'dev_local_time';
            r = ndi.migrate.internal.bodyResolver({ect});
            [clock, source] = r.epochClockOfElement('stimulator_5', 't00001');
            testCase.verifyEqual(clock, 'utc');
            testCase.verifyEqual(source, 'epochclocktimes');
            r = ndi.migrate.internal.bodyResolver({ect, ect2});
            testCase.verifyEqual(r.epochClockOfElement('stimulator_5', 't00001'), 'dev_local_time');
        end

        function testSubjectViaResponseLink(testCase)
            bodies = { ...
                stimPresentation('pres_1', 'stimulator_5'), ...
                stimResponse('resp_1', 'pres_1', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testDedupMultipleRespondersSameAnimal(testCase)
            % two neurons of the same animal both responded -> one animal subject
            bodies = { ...
                stimResponse('resp_1', 'pres_1', 'elem_9'), ...
                stimResponse('resp_2', 'pres_1', 'elem_10'), ...
                element('elem_9', 'animal_1'), ...
                element('elem_10', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testDerivedElementFollowsUpChain(testCase)
            % a derived responding element (no own subject) resolves via
            % underlying_element_id, exactly like subjectOfElement.
            bodies = { ...
                stimResponse('resp_1', 'pres_1', 'derived_2'), ...
                derivedElement('derived_2', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testNoResponseNoSubject(testCase)
            bodies = { stimPresentation('pres_1', 'stimulator_5') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

        function testUnresolvableElementSkipped(testCase)
            % a response to an element that is not in the body set -> skipped, not error
            bodies = { stimResponse('resp_1', 'pres_1', 'missing_element') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

        % ============ the IS-A widening, 2026-08-17 ======================

        function testASubclassOfStimulusResponseResolves(testCase)
            % THE CASE PRODUCTION ACTUALLY WRITES. The exact-name match this
            % replaced could not fire on real data: measured over the
            % 20211116 corpus (1220 documents read), 0 documents are named
            % `stimulus_response` and 273 are named
            % `stimulus_response_scalar`, all 273 carrying BOTH
            % `stimulus_presentation_id` and `element_id`.
            bodies = { ...
                responseScalar('resp_1', 'pres_1', 'elem_9'), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testTheVetaSpellingOfASuperclassAlsoResolves(testCase)
            % A body set can arrive in either vintage -- v1 superclass entries
            % carry `definition`, V_eta ones carry `class_name` -- so both
            % spellings are read.
            b = docBody('stimulus_response_scalar', 'resp_1', ...
                {'stimulus_presentation_id', 'pres_1'}, {'element_id', 'elem_9'});
            b.document_class.superclasses = ...
                struct('class_name', 'stimulus_response', 'class_version', '1.0.0');
            r = ndi.migrate.internal.bodyResolver({ b, element('elem_9', 'animal_1') });
            testCase.verifyEqual(r.subjectsForPresentation('pres_1'), {'animal_1'});
        end

        function testAnUnrelatedClassWithTheSameEdgesDoesNotResolve(testCase)
            % The widening is by DECLARED superclass, not by name shape or by
            % which edges a document happens to carry. 20211116 holds 273
            % `stimulus_response_scalar_parameters_basic` documents, and they
            % must not be read as responses.
            bodies = { ...
                docBody('stimulus_response_scalar_parameters_basic', 'p_1', ...
                    {'stimulus_presentation_id', 'pres_1'}, ...
                    {'element_id', 'elem_9'}), ...
                element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsForPresentation('pres_1'));
        end

        % ============ the epoch fallback: FORK 1 (own session) ===========

        function testEpochScopedResolvesTheOwnSessionSubject(testCase)
            % FORK 1: a presentation with no response is attributed to the
            % animal recorded in its OWN session's epoch. The sibling resolver
            % must NOT also claim that element -- it belongs to this session.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementEpoch('elem_9', 't5', 'sessA'), ...
                       element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.epochElementCountScoped('pres_1'), 1);
            testCase.verifyEqual(r.subjectsViaEpochScoped('pres_1'), {'animal_1'});
            testCase.verifyEmpty(r.subjectsViaEpochSibling('pres_1'));
        end

        % ============ the epoch fallback: FORK 2 (sibling session) ========

        function testEpochSiblingRecoversWhenTheOwnSessionRecordsNothing(testCase)
            % The own session (sessA)
            % records no element in epoch t5, but the epoch NAME records
            % elem_9 -> animal_1 in a sibling session (sessB). Fork 2 attributes
            % to animal_1; the counters distinguish it from a stimulus-only epoch.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementEpoch('elem_9', 't5', 'sessB'), ...
                       element('elem_9', 'animal_1') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.epochElementCountScoped('pres_1'), 0);
            testCase.verifyEqual(r.epochElementCountUnscoped('pres_1'), 1);
            testCase.verifyEmpty(r.subjectsViaEpochScoped('pres_1'));
            testCase.verifyEqual(r.subjectsViaEpochSibling('pres_1'), {'animal_1'});
        end

        function testEpochSiblingIsAmbiguousAcrossTwoSiblingSubjects(testCase)
            % Two sibling sessions reused the epoch name for DIFFERENT animals.
            % Fork 2 must resolve to both, so the caller refuses (ambiguous),
            % rather than silently attributing to one.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementEpoch('elem_9', 't5', 'sessB'), element('elem_9', 'animal_1'), ...
                       elementEpoch('elem_10', 't5', 'sessC'), element('elem_10', 'animal_2') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(numel(r.subjectsViaEpochSibling('pres_1')), 2);
        end

        function testEpochSiblingElementWithNoSubjectYieldsEmpty(testCase)
            % The sibling epoch records an element that is not in the body set
            % (or carries no subject): the count is non-zero but nothing
            % resolves, so fork 2 attributes nobody and the caller refuses.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementEpoch('missing_elem', 't5', 'sessB') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.epochElementCountUnscoped('pres_1'), 1);
            testCase.verifyEmpty(r.subjectsViaEpochSibling('pres_1'));
        end

        function testEpochSiblingExcludesTheOwnSessionElement(testCase)
            % Both sessions record in the epoch name. Fork 1 attributes the OWN
            % session's animal; fork 2, which only fires when fork 1 found
            % nothing, must exclude the own-session element and see only the
            % sibling -- so the two resolvers never double-count one element.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementEpoch('elem_own', 't5', 'sessA'), element('elem_own', 'animal_own'), ...
                       elementEpoch('elem_sib', 't5', 'sessB'), element('elem_sib', 'animal_sib') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsViaEpochScoped('pres_1'), {'animal_own'});
            testCase.verifyEqual(r.subjectsViaEpochSibling('pres_1'), {'animal_sib'});
        end

        function testAStimulusOnlyEpochHasNoElementAnywhere(testCase)
            % The other half of the 68/0 split: an epoch that records nothing in
            % ANY session. Both counts are 0 and fork 2 finds nobody, so the
            % caller reports a genuinely stimulus-only epoch.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.epochElementCountScoped('pres_1'), 0);
            testCase.verifyEqual(r.epochElementCountUnscoped('pres_1'), 0);
            testCase.verifyEmpty(r.subjectsViaEpochSibling('pres_1'));
        end

        % ======= the stimulator route (Jess Haley, 2026-10-21, PR #1021) ==

        function testStimulatorRouteResolvesTheStimulatorsSubject(testCase)
            % No response and no element_epoch (Dab: a recorded epoch with no
            % sorted unit). presentation -> stimulus_element_id -> the
            % stimulator element -> its subject.
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementInSession('stimulator_5', 'animal_1', 'sessA') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.epochElementCountScoped('pres_1'), 0);
            testCase.verifyEqual(r.subjectsViaStimulator('pres_1'), {'animal_1'});
        end

        function testStimulatorRouteIgnoresAnElementInAnotherSession(testCase)
            bodies = { presentationInEpoch('pres_1', 't5', 'sessA'), ...
                       elementInSession('stimulator_5', 'animal_1', 'sessB') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEmpty(r.subjectsViaStimulator('pres_1'));
        end

        function testStimulatorRouteReturnsEverySubjectItsEdgesReach(testCase)
            % Two stimulus_element_id edges, two animals: both are returned so
            % the caller can refuse as ambiguous.
            pres = presentationInEpoch('pres_1', 't5', 'sessA');
            pres.depends_on(end+1) = struct('name', 'stimulus_element_id', ...
                'value', 'stimulator_6');
            bodies = { pres, ...
                       elementInSession('stimulator_5', 'animal_1', 'sessA'), ...
                       elementInSession('stimulator_6', 'animal_2', 'sessA') };
            r = ndi.migrate.internal.bodyResolver(bodies);
            testCase.verifyEqual(r.subjectsViaStimulator('pres_1'), ...
                {'animal_1', 'animal_2'});
        end

        function testStimulatorRouteEmptyWhenTheElementIsAbsentOrSubjectless(testCase)
            r = ndi.migrate.internal.bodyResolver( ...
                { presentationInEpoch('pres_1', 't5', 'sessA') });
            testCase.verifyEmpty(r.subjectsViaStimulator('pres_1'));

            bare = docBody('element', 'stimulator_5');
            bare.base.session_id = 'sessA';
            r = ndi.migrate.internal.bodyResolver( ...
                { presentationInEpoch('pres_1', 't5', 'sessA'), bare });
            testCase.verifyEmpty(r.subjectsViaStimulator('pres_1'));
        end

    end
end

% ===================== fixtures ===========================================

function b = stimPresentation(id, stimulatorId)
b = docBody('stimulus_presentation', id, {'stimulus_element_id', stimulatorId});
end

function b = stimResponse(id, presentationId, elementId)
b = docBody('stimulus_response', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
end

function b = responseScalar(id, presentationId, elementId)
%RESPONSESCALAR The class production writes, carrying the v1 template's OWN
%   superclass declaration -- verbatim from ndi_common/database_documents/
%   stimulus/stimulus_response_scalar.json, and matched by every one of the
%   273 such documents in the 20211116 corpus. That declaration is what the
%   resolver reads, so a fixture without it would exercise nothing.
b = docBody('stimulus_response_scalar', id, ...
    {'stimulus_presentation_id', presentationId}, {'element_id', elementId});
b.document_class.superclasses = [ ...
    struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
    struct('definition', '$NDIDOCUMENTPATH/stimulus/stimulus_response.json')];
end

function b = element(id, subjectId)
b = docBody('element', id, {'subject_id', subjectId});
end

function b = elementInSession(id, subjectId, sessionId)
b = docBody('element', id, {'subject_id', subjectId});
b.base.session_id = sessionId;
end

function b = derivedElement(id, underlyingId)
% a derived element carries no subject of its own, only underlying_element_id
b = docBody('element', id, {'underlying_element_id', underlyingId});
end

function b = elementEpoch(elementId, epochName, sessionId)
%ELEMENTEPOCH An element_epoch document -- the record that ELEMENTID was
%   recorded in the epoch named EPOCHNAME within session SESSIONID. This is what
%   the epoch->element->subject fallbacks index: elementsByEpoch keys on the
%   bare epoch NAME, elementsBySessionEpoch on '<session_id>|<epoch>'.
b = docBody('element_epoch', ['ee_' elementId '_' sessionId], {'element_id', elementId});
b.base.session_id = sessionId;
b.epochid = struct('epochid', epochName);
end

function b = elementEpochClock(elementId, epochName, clock)
%ELEMENTEPOCHCLOCK An element_epoch of ELEMENTID in EPOCHNAME on clock CLOCK.
b = docBody('element_epoch', ['ee_' elementId '_' epochName], {'element_id', elementId});
b.epochid = struct('epochid', epochName);
b.element_epoch = struct('epoch_clock', clock);
end

function b = presentationInEpoch(id, epochName, sessionId)
%PRESENTATIONINEPOCH A stimulus_presentation carrying the epochid superclass and
%   a session, with NO response linking it to an element -- the shape the epoch
%   fallbacks exist for.
b = docBody('stimulus_presentation', id, {'stimulus_element_id', 'stimulator_5'});
b.base.session_id = sessionId;
b.epochid = struct('epochid', epochName);
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
