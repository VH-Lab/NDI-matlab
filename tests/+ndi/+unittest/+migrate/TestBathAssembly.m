classdef TestBathAssembly < matlab.unittest.TestCase
%TESTBATHASSEMBLY Unit tests for ndi.migrate.internal.stimulusBathToBath (pure
%   struct assembly with a mock resolver; no database, schema, or toolbox needed).
%
%   Under V_eta the bath / pharmacological_manipulation family is retired (D8): a
%   deferred stimulus_bath assembles into a `dose_manipulation` (the delivered
%   substance) on the resolved subject over the stimulator's epoch, mirroring the
%   coarse did2.convert.resolveDeferredBaths.makeBathVeta. Older targets still
%   assemble a `bath`.
%
%   Run with:  runtests('ndi.unittest.migrate.TestBathAssembly')

    methods (Test)

        function testVetaBecomesDoseManipulation(testCase)
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'dev_local_time');
            [dose, timeRef] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');

            % the manipulation is a dose_manipulation on the resolved subject
            testCase.verifyEqual(dose.document_class.class_name, 'dose_manipulation');
            testCase.verifyEqual(dose.base.id, 'bath_1');          % source id preserved
            testCase.verifyEqual(depValue(dose, 'subject_id'), 'animal_1');
            testCase.verifyEqual(dose.subject_statement.storage_mode, 'inline');

            % the primary mixture chemical is the spine identity (variable)
            testCase.verifyEqual(dose.subject_statement.variable.node, 'chebi:6904');
            testCase.verifyEqual(dose.subject_statement.variable.name, 'muscimol');

            % the mixture -> dose formulation chemicals ({substance, amount})
            chems = dose.dose.value.formulation.chemicals;
            testCase.verifyEqual(numel(chems), 1);
            testCase.verifyEqual(chems(1).substance.name, 'muscimol');
            testCase.verifyEqual(chems(1).amount.source_value, 5);

            % the dose depends on the epoch-precise time anchor
            testCase.verifyEqual(timeRef.document_class.class_name, ...
                'epoch_bounded_reference');
            testCase.verifyEqual(depValue(dose, 'time_reference_1'), timeRef.base.id);
            testCase.verifyEqual(timeRef.epoch_bounded_reference.epoch_clock, ...
                'dev_local_time');

            % no retired bath classes leak onto the V_eta path
            testCase.verifyFalse(isfield(dose, 'bath'));
            testCase.verifyFalse(isfield(dose, 'pharmacological_manipulation'));
        end

        function testVetaCarriesTheStimulatorAsInstrument(testCase)
            % T7: the instrument of an interaction is an edge on the
            % interaction. This is what keeps the stimulator's identity when
            % ndi.migrate.internal.epochAnchorFold drops the anchor's
            % `element_id` -- `relative_reference` declares only `relative_to`,
            % so without this edge the fold would LOSE which element's epoch the
            % bath sat in. The stimulator is an element, and migrators_j.element
            % promotes an element to a `subject` with its id PRESERVED.
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'dev_local_time');
            dose = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEqual(depValue(dose, 'instrument_id'), 'stim_1');
        end

        % ---- NO TIMES => NO REFERENCE (V_eta only) ----------------------
        % The signed plan's rule. A reference that cannot name a time is a
        % hollow document: it validates, it is counted, and it says nothing.

        function testVetaEmitsNoAnchorForANoTimeClock(testCase)
            % 'no_time' is NDI's assertion that a thing keeps no time at all
            % (+file/navigator.m:185), never a timeline a time is expressed on.
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'no_time');
            [dose, timeRef] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEmpty(timeRef);
            % time_reference_# is an OPTIONAL dependency, so the absence costs
            % nothing and asserts nothing.
            testCase.verifyEmpty(depValue(dose, 'time_reference_1'));
            testCase.verifyEqual(depValue(dose, 'subject_id'), 'animal_1');
        end

        function testVetaEmitsNoAnchorWhenThereIsNoEpochString(testCase)
            % `epochid.epochid` is mustBeNonEmpty on the V_eta schema, so an
            % empty one is a QUARANTINE today. Declining to mint turns a
            % quarantined document into an honest absence.
            v1 = stimulusBathDoc('stim_1', 't00001');
            v1.epochid = struct('epochid', '');
            r  = mockResolver('animal_1', 'dev_local_time');
            [dose, timeRef] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_eta');
            testCase.verifyEmpty(timeRef);
            testCase.verifyEmpty(depValue(dose, 'time_reference_1'));
        end

        function testTheGuardIsVetaOnlyAndOlderTargetsAreUntouched(testCase)
            % The retirement is a V_eta decision. V_zeta/V_epsilon keep the
            % behaviour they are green with, no_time clock included.
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'no_time');
            [bath, timeRef] = ...
                ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_zeta');
            testCase.verifyNotEmpty(timeRef);
            testCase.verifyEqual(timeRef.document_class.class_name, ...
                'epoch_bounded_reference');
            testCase.verifyEqual(depValue(bath, 'time_reference_1'), ...
                timeRef.base.id);
        end

        function testZetaStillEmitsBath(testCase)
            % the older target is unchanged: a `bath` (pharmacological_manipulation)
            v1 = stimulusBathDoc('stim_1', 't00001');
            r  = mockResolver('animal_1', 'dev_local_time');
            bath = ndi.migrate.internal.stimulusBathToBath(v1, r, 'V_zeta');
            testCase.verifyEqual(bath.document_class.class_name, 'bath');
            testCase.verifyTrue(isfield(bath, 'pharmacological_manipulation'));
        end

    end
end

% ===================== fixtures / helpers =================================

function v1 = stimulusBathDoc(stimId, epochId)
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'base',    'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
v1.base = struct('id', 'bath_1', 'session_id', 'sess_09', ...
    'name', 'bath', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', epochId);
v1.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');
end

function r = mockResolver(subjectId, epochClock)
% the session-aware lookups ndi.migrate.local supplies; fixed values here.
r = struct( ...
    'subjectOfElement',     @(elementId) subjectId, ...
    'epochClockOfElement',  @(elementId, epochId) epochClock);
end

function v = depValue(body, name)
v = '';
for k = 1:numel(body.depends_on)
    if strcmp(body.depends_on(k).name, name)
        v = body.depends_on(k).value;
        return;
    end
end
end
