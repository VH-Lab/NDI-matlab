classdef TestRecordingAttribution < matlab.unittest.TestCase
%TESTRECORDINGATTRIBUTION ndi.migrate.internal.recordingAttribution, over structs.
%
%   The resolver is pure struct logic -- no converter, no schema, no database --
%   so it is tested directly, in milliseconds, rather than only through the PRED
%   corpus. The corpus test proves it runs on real documents; this one proves it
%   REFUSES correctly, which a corpus that happens to contain no ambiguous probe
%   can never show.
%
%   THE FIXTURES ARE BUILT FROM THE TWO EMITTERS' OWN SHAPES, not from the
%   resolver's expectations:
%       element   private/jRecordingObservation.m:211-212
%                 subject_id = the SPECIMEN, instrument_id = the electrode
%       pyraview  migrators_j/pyraview.m
%                 subject_id = element_id (the probe-as-subject), NO instrument
%   A fixture written from the resolver would agree with the resolver about
%   everything including its mistakes.

    methods (Static)
        function b = donor(probeId, specimenId, varNode)
            %DONOR element's shape: an observation that names both.
            if nargin < 3
                varNode = 'NDIC:voltage';
            end
            b = struct();
            b.document_class = struct('class_name', 'voltage_observation', ...
                'class_version', '1.0.0');
            b.depends_on = [ ...
                struct('name', 'subject_id',       'value', specimenId), ...
                struct('name', 'instrument_id',    'value', probeId), ...
                struct('name', 'time_reference_1', 'value', 'tr-1')];
            b.base = struct('id', ['donor-' probeId], 'session_id', 's1', ...
                'name', 'migrated_recording_observation');
            b.subject_statement = struct('variable', ...
                struct('node', varNode, 'name', 'voltage'), ...
                'storage_mode', 'body');
        end

        function b = candidate(probeId, id, varNode)
            %CANDIDATE pyraview's shape: subject is the probe, no instrument.
            if nargin < 2
                id = 'cand-1';
            end
            if nargin < 3
                varNode = '';       % pyraview writes a LABEL, not a term
            end
            b = struct();
            b.document_class = struct('class_name', 'voltage_observation', ...
                'class_version', '1.0.0');
            b.depends_on = [ ...
                struct('name', 'subject_id',       'value', probeId), ...
                struct('name', 'time_reference_1', 'value', 'tr-1')];
            b.base = struct('id', id, 'session_id', 's1', ...
                'name', 'migrated_signal');
            b.subject_statement = struct('variable', ...
                struct('node', varNode, 'name', 'ctx_1'), ...
                'storage_mode', 'body');
        end
    end

    methods (Static)
        function b = probeLocation(probeId, id)
            %PROBELOCATION DID-matlab +migrators_j/probe_location.m's shape on
            %   did-schema #88: an `observation` with value kind `term` about
            %   the probe (entity_id = probe_id), variable NCIT:C13717
            %   "Anatomic Site", the atlas term its value, NO instrument.
            if nargin < 2
                id = 'loc-1';
            end
            sc = {'interaction', 'statement', 'base', 'term', 'value', 'data'};
            b = struct();
            b.document_class = struct('class_name', 'observation', ...
                'class_version', '1.0.0', 'superclasses', ...
                struct('class_name', sc, 'class_version', '1.0.0'));
            b.depends_on = [ ...
                struct('name', 'entity_id',         'value', probeId), ...
                struct('name', 'time_reference_id', 'value', 'tr-1')];
            b.base = struct('id', id, 'session_id', 's1');
            b.statement = struct('variable', ...
                struct('node', 'NCIT:C13717', 'name', 'Anatomic Site'));
            b.term = struct('value', ...
                struct('node', 'UBERON:0001880', 'name', 'bed nucleus of stria terminalis'));
        end

        function b = as88(b)
            %AS88 The same observation in did-schema #88's spelling: the
            %   `observation` direction + the `voltage` kind, `entity_id`,
            %   `time_reference_id`, the variable on the `statement` block.
            sc = {'interaction', 'statement', 'base', 'voltage', 'value', 'data'};
            b.document_class = struct('class_name', 'observation', ...
                'class_version', '1.0.0', 'superclasses', ...
                struct('class_name', sc, 'class_version', '1.0.0'));
            for k = 1:numel(b.depends_on)
                switch b.depends_on(k).name
                    case 'subject_id'
                        b.depends_on(k).name = 'entity_id';
                    case 'time_reference_1'
                        b.depends_on(k).name = 'time_reference_id';
                end
            end
            b.statement = struct('variable', b.subject_statement.variable);
            b = rmfield(b, 'subject_statement');
        end
    end

    methods (Test)

        function aProbeLocationStaysAboutTheProbe(testCase)
            % Jess Haley, 2026-11-26 ("Yes": limit recordingAttribution to
            % recording observations; a probe's location observation stays
            % about the probe). A probe_location term observation has no
            % instrument, and the probe has both an `observes` relation and
            % a recording-observation donor naming its specimen: it is still
            % NOT re-attributed, and it is counted as skipped, by value kind.
            loc = testCase.probeLocation('probe-1');
            structs = {loc, observes('probe-1', 'mouse-7'), ...
                       testCase.as88(testCase.donor('probe-1', 'mouse-7'))};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEmpty(plan);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.observations, 2);
            testCase.verifyEqual(report.donors, 1);
            testCase.verifyEqual(report.without_instrument, 1);
            testCase.verifyEqual(report.candidates, 0);
            testCase.verifyEqual(report.attributed, 0);
            testCase.verifyEqual(report.skipped_not_a_recording, 1);
            testCase.verifyEqual(report.skipped_not_a_recording_by_kind, ...
                struct('term', 1));
            % the input is untouched: still about the probe, no instrument
            testCase.verifyEqual(dep(structs{1}, 'entity_id'), 'probe-1');
            testCase.verifyEmpty(dep(structs{1}, 'instrument_id'));
        end

        function aRecordingBesideAProbeLocationIsStillAttributed(testCase)
            % PRED's case with a probe location beside it: the pyraview
            % recording (value kind voltage) about the probe is attributed to
            % the specimen through the element's `observes`; the probe's
            % location is not, and stays about the probe.
            structs = {testCase.as88(testCase.candidate('probe-1', 'pyr-1')), ...
                       testCase.probeLocation('probe-1', 'loc-1'), ...
                       observes('probe-1', 'mouse-7')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.observations, 2);
            testCase.verifyEqual(report.without_instrument, 2);
            testCase.verifyEqual(report.candidates, 1);
            testCase.verifyEqual(report.skipped_not_a_recording, 1);
            testCase.verifyEqual(report.attributed, 1);
            testCase.verifyEqual(report.attributed_via_observes, 1);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).source_id, 'pyr-1');
            testCase.verifyEqual(dep(plan(1).body, 'entity_id'), 'mouse-7');
            testCase.verifyEqual(dep(plan(1).body, 'instrument_id'), 'probe-1');
        end

        function everyRecordingKindIsACandidateAndNothingElse(testCase)
            % each recording value kind, with no instrument, is a candidate;
            % a kind outside the list (term, text, mass) is skipped
            kinds = {'voltage', 'current', 'time', 'acceleration', ...
                     'temperature', 'intensity', 'term', 'text', 'mass'};
            structs = {observes('probe-1', 'mouse-7')};
            for k = 1:numel(kinds)
                b = testCase.as88(testCase.candidate('probe-1', ['c-' kinds{k}]));
                b.document_class.superclasses(4).class_name = kinds{k};
                structs{end+1} = b; %#ok<AGROW>
            end
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.without_instrument, 9);
            testCase.verifyEqual(report.candidates, 6);
            testCase.verifyEqual(report.attributed, 6);
            testCase.verifyEqual(report.skipped_not_a_recording, 3);
            testCase.verifyEqual(report.skipped_not_a_recording_by_kind, ...
                struct('term', 1, 'text', 1, 'mass', 1));
            testCase.verifyEqual(sort({plan.source_id}), ...
                sort(strcat('c-', kinds(1:6))));
        end

        function theRecordingKindsAreDIDMatlabs(testCase)
            % the list is not this file's: it is the `kinds` DID-matlab's
            % isRecordingObservation reads in did2.convert.epochMint and
            % did2.convert.resolveEpochProbemap (the mixins jRecordingModality
            % and localModality emit). Read from their source, so the lists
            % cannot drift.
            [~, report] = ndi.migrate.internal.recordingAttribution({});
            for f = {'did2.convert.epochMint', 'did2.convert.resolveEpochProbemap'}
                file = which(f{1});
                testCase.assertNotEmpty(file, [f{1} ' is not on the path']);
                text = fileread(file);
                tok = regexp(text, '\nkinds = \{([^}]*)\};', 'tokens');
                testCase.assertNotEmpty(tok, ['no `kinds = {...};` in ' f{1}]);
                for t = 1:numel(tok)
                    theirs = regexp(tok{t}{1}, '''([^'']*)''', 'tokens');
                    theirs = cellfun(@(c) c{1}, theirs, 'UniformOutput', false);
                    testCase.verifyEqual(sort(report.recording_value_kinds), ...
                        sort(theirs), ['the recording value kinds differ from ' f{1}]);
                end
            end
        end

        function withoutEpochFilesTheElementsObservesIsTheDonor(testCase)
            % Decided by Jess Haley, 2026-10-21 [preview attribution without
            % epoch files]: no per-epoch recording observation exists (PRED
            % carries no epoch files), so the element's kept `observes`
            % relation (the probe observes the organism) gives the specimen.
            structs = {testCase.as88(testCase.candidate('probe-1')), ...
                       observes('probe-1', 'mouse-7')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.observes_relations, 1);
            testCase.verifyEqual(report.attributed, 1);
            testCase.verifyEqual(report.attributed_via_observes, 1);
            testCase.verifyEqual(report.refused_no_donor, 0);
            testCase.verifyEqual(dep(plan(1).body, 'entity_id'), 'mouse-7');
            testCase.verifyEqual(dep(plan(1).body, 'instrument_id'), 'probe-1');
        end

        function aRecordingObservationDonorWinsOverObserves(testCase)
            % the per-epoch observation, when there is one, decides
            structs = {testCase.as88(testCase.donor('probe-1', 'mouse-7')), ...
                       testCase.as88(testCase.candidate('probe-1')), ...
                       observes('probe-1', 'mouse-9')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.attributed, 1);
            testCase.verifyEqual(report.attributed_via_observes, 0);
            testCase.verifyEqual(dep(plan(1).body, 'entity_id'), 'mouse-7');
        end

        function aProbeObservingTwoSpecimensIsRefused(testCase)
            structs = {testCase.as88(testCase.candidate('probe-1')), ...
                       observes('probe-1', 'mouse-7'), observes('probe-1', 'mouse-9')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_ambiguous_observes, 1);
            testCase.verifyEqual(report.attributed, 0);
        end

        function aProbeWithNoDonorAndNoObservesIsStillRefused(testCase)
            structs = {testCase.as88(testCase.candidate('probe-1')), ...
                       observes('probe-2', 'mouse-7')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_donor, 1);
        end

        function theEightyEightShapeIsAttributedInItsOwnSpelling(testCase)
            % pass 1 on did-schema #88: the probe moves to instrument_id and
            % the specimen becomes the `entity_id`; no `subject_id` appears
            structs = {testCase.as88(testCase.donor('probe-1', 'mouse-7')), ...
                       testCase.as88(testCase.candidate('probe-1'))};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.observations, 2);
            testCase.verifyEqual(report.attributed, 1);
            testCase.verifyEqual(dep(plan(1).body, 'entity_id'), 'mouse-7');
            testCase.verifyEqual(dep(plan(1).body, 'instrument_id'), 'probe-1');
            testCase.verifyEmpty(dep(plan(1).body, 'subject_id'));
            testCase.verifyEqual(dep(plan(1).body, 'time_reference_id'), 'tr-1');
            % INVERTED 2026-10-25 ([generic stage is lossless], Jess Haley):
            % the candidate's own label 'ctx_1' used to be overwritten by the
            % donor's term; it is a v1 value and is kept
            testCase.verifyEqual(plan(1).body.statement.variable.name, 'ctx_1');
            testCase.verifyEqual(report.variable_carried, 0);
        end

        function theDenominatorIsReportedUnconditionally(testCase)
            % Rule 5, and on the EMPTY input too -- "nothing to do" and "this
            % never ran" must not print the same.
            [~, report] = ndi.migrate.internal.recordingAttribution({});
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyEqual(report.observations, 0);
            testCase.verifyEqual(report.candidates, 0);
            testCase.verifyEqual(report.attributed, 0);
            testCase.verifyEqual(report.without_instrument, 0);
            testCase.verifyEqual(report.skipped_not_a_recording, 0);
            testCase.verifyEqual(report.skipped_not_a_recording_by_kind, struct());
            testCase.verifyFalse(report.changed);
        end

        function theProbeMovesToInstrumentAndTheSpecimenBecomesTheSubject(testCase)
            structs = {testCase.donor('probe-1', 'mouse-7'), ...
                       testCase.candidate('probe-1')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.observations, 2);
            testCase.verifyEqual(report.donors, 1);
            testCase.verifyEqual(report.candidates, 1);
            testCase.verifyEqual(report.attributed, 1);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).specimen_id, 'mouse-7');
            testCase.verifyEqual(plan(1).instrument_id, 'probe-1');
            testCase.verifyEqual(dep(plan(1).body, 'subject_id'), 'mouse-7');
            testCase.verifyEqual(dep(plan(1).body, 'instrument_id'), 'probe-1');
        end

        function theIdIsPreservedSoIncomingEdgesKeepResolving(testCase)
            % base.id PRESERVED is what lets `time_reference_#` and any
            % `derived_from` pointing at this observation survive the swap.
            structs = {testCase.donor('probe-1', 'mouse-7'), ...
                       testCase.candidate('probe-1', 'obs-42')};
            plan = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(plan(1).source_id, 'obs-42');
            testCase.verifyEqual(plan(1).body.base.id, 'obs-42');
        end

        function everythingElseOnTheDocumentIsUntouched(testCase)
            structs = {testCase.donor('probe-1', 'mouse-7'), ...
                       testCase.candidate('probe-1')};
            plan = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(dep(plan(1).body, 'time_reference_1'), 'tr-1');
            testCase.verifyEqual(plan(1).body.subject_statement.storage_mode, ...
                'body');
            testCase.verifyEqual(plan(1).body.base.name, 'migrated_signal');
        end

        function theBodyIsTaggedSoTheConverterShortCircuits(testCase)
            % Without the v2 stamp (schema_version 'did_v2') the caller's v1_to_v2 would try to
            % MIGRATE an already-migrated body instead of validating it.
            structs = {testCase.donor('probe-1', 'mouse-7'), ...
                       testCase.candidate('probe-1')};
            plan = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(plan(1).body.document_class.schema_version, ...
                'did_v2');
        end

        function noDonorMeansREFUSED_notInvented(testCase)
            % THE IMPORTANT REFUSAL. With no signed emitter having attributed
            % this probe, the pass must leave the document alone rather than
            % re-deriving a specimen from somewhere else and disagreeing with
            % the emitter that owns the model.
            structs = {testCase.candidate('probe-unknown')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_donor, 1);
            testCase.verifyEqual(report.attributed, 0);
            testCase.verifyFalse(report.changed);
        end

        function twoSpecimensForOneProbeIsREFUSED_notPickedByOrder(testCase)
            % Should be impossible; if it happens, a refusal with a count is the
            % honest output. Declaration order must never decide a specimen.
            structs = {testCase.donor('probe-1', 'mouse-7'), ...
                       testCase.donor('probe-1', 'mouse-9'), ...
                       testCase.candidate('probe-1')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_ambiguous_probe, 1);
            testCase.verifyEqual(report.ambiguous_probes, {'probe-1'});
        end

        function anObservationThatAlreadyNamesAnInstrumentIsNotACandidate(testCase)
            % element's own document must pass through untouched -- it is the
            % donor, not a thing to re-attribute.
            structs = {testCase.donor('probe-1', 'mouse-7')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.donors, 1);
            testCase.verifyEqual(report.candidates, 0);
        end

        function aSubjectlessObservationIsREFUSED(testCase)
            b = testCase.candidate('probe-1');
            b.depends_on(1).value = '';
            [plan, report] = ndi.migrate.internal.recordingAttribution( ...
                {testCase.donor('probe-1', 'mouse-7'), b});
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_subject, 1);
        end

        function aNonObservationIsIgnoredEntirely(testCase)
            other = struct('document_class', ...
                struct('class_name', 'subject', 'class_version', '1.0.0'), ...
                'base', struct('id', 'x', 'session_id', 's1', 'name', 'n'));
            [~, report] = ndi.migrate.internal.recordingAttribution({other});
            testCase.verifyEqual(report.documents_inspected, 1);
            testCase.verifyEqual(report.observations, 0);
        end

        function aLabelledVariableKeepsItsLabel(testCase)
            % INVERTS anUnresolvedVariableTakesTheDonorsTerm, which asserted the
            % pyraview signal LABEL ('ctx_1', empty node) overwritten by the
            % donor's term. [generic stage is lossless] (Jess Haley,
            % 2026-10-25, audit item 7): the label is a v1 value, so it stays;
            % the observation is still attributed to the specimen.
            structs = {testCase.donor('probe-1', 'mouse-7', 'NDIC:voltage'), ...
                       testCase.candidate('probe-1', 'cand-1', '')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.attributed, 1);
            testCase.verifyEqual(report.variable_carried, 0);
            testCase.verifyEqual(plan(1).body.subject_statement.variable.name, 'ctx_1');
            testCase.verifyEmpty(plan(1).body.subject_statement.variable.node);
        end

        function anEmptyVariableTakesTheDonorsTerm(testCase)
            % nothing to lose: an observation whose variable has neither node
            % nor name takes the donor's term
            c = testCase.candidate('probe-1', 'cand-1', '');
            c.subject_statement.variable.name = '';
            structs = {testCase.donor('probe-1', 'mouse-7', 'NDIC:voltage'), c};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.variable_carried, 1);
            testCase.verifyEqual(plan(1).body.subject_statement.variable.node, ...
                'NDIC:voltage');
        end

        function aPopulatedVariableIsNEVEROverwritten(testCase)
            % The counterpart, and the one that matters: this pass has no
            % standing to decide a vocabulary question. If the candidate already
            % names a term, it keeps it even if the donor disagrees.
            structs = {testCase.donor('probe-1', 'mouse-7', 'NDIC:voltage'), ...
                       testCase.candidate('probe-1', 'cand-1', 'NDIC:current')};
            [plan, report] = ndi.migrate.internal.recordingAttribution(structs);
            testCase.verifyEqual(report.variable_carried, 0);
            testCase.verifyEqual(plan(1).body.subject_statement.variable.node, ...
                'NDIC:current');
        end

    end
end

function value = dep(body, name)
value = '';
for k = 1:numel(body.depends_on)
    if strcmp(body.depends_on(k).name, name)
        value = body.depends_on(k).value;
        return;
    end
end
end

function r = observes(childId, parentId)
% the element's kept v1 `observes` relation, did-schema #88 shape
r = struct();
r.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'relation', 'base'}, 'class_version', '1.0.0'));
r.depends_on = [struct('name', 'child_id', 'value', childId), ...
    struct('name', 'parent_id', 'value', parentId), ...
    struct('name', 'session_id', 'value', 's1')];
r.base = struct('id', ['obs-' childId '-' parentId]);
r.relation = struct();
r.directed_relation = struct('relation', struct('node', '', 'name', 'observes'));
end
