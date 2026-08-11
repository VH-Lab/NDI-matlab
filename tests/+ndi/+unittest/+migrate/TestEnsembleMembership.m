classdef TestEnsembleMembership < matlab.unittest.TestCase
%TESTENSEMBLEMEMBERSHIP Unit tests for the V_eta ensemble second pass (pure
%   struct logic; no database, schema, or MATLAB toolbox needed).
%
%   ndi.migrate.internal.ensembleMembership turns each did_v1 `ensemble` MAP
%   document into graph-native membership: a `member_of` `directed_relation`
%   from every constituent neuron-subject to the ensemble group-subject
%   (carrying its column order in `sequence`), plus `derived_from` provenance
%   recording that the combined marked-point-process binary is a rebuildable
%   CACHE of those same neurons.
%
%   The roster comes from the map document's `neuron_id_#` depends_on EDGES --
%   NOT from `neuron_names.txt`. `add_dependency_value_n` appends
%   `neuron_id_1`, `neuron_id_2`, ... in the loop that writes the names
%   (origin/main:+ndi/+element/ensemble.m:274-276), so the suffix index IS the
%   column index; the tests below pin that, including when the depends_on
%   entries arrive out of order.
%
%   The pass ADDS ONLY. Nothing is dropped -- the map document, the
%   `acquisition_epoch` and its bytes all survive, because the
%   verify-before-delete gate has not run on a corpus. testNothingIsEverDropped
%   pins that.
%
%   THE GATE MEASURES TRAINS, NOT SUBJECTS. `neuron_edges_stranded` asks only
%   whether the neuron SUBJECT is present, and migrators_j.element turns an
%   element into a bare `subject` with no data -- so it can read 0 while every
%   spike train is absent, which would license destroying the only copy.
%   testSubjectPresentButTrainAbsentIsNotAClearance pins exactly that case.
%   A train is an acquisition_epoch owned by the neuron and carrying
%   `epoch_binary_data.vhsb`, which is the triple NDI's own readtimeseries
%   searches for (origin/main:+ndi/+element/timeseries.m:56-70); the fixtures
%   below are built to the did_v1 `element_epoch.json` template, not to a
%   V_eta schema.
%
%   Run with:  runtests('ndi.unittest.migrate.TestEnsembleMembership')
%
%   The fixtures/accessors are LOCAL FUNCTIONS (below the classdef), called
%   unqualified from the Test methods -- the same arrangement
%   TestPathSPromotion uses, because a class-qualified static reference fails
%   to resolve in a packaged class.

    methods (Test)

        function testMembershipAndCacheProvenanceMinted(testCase)
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            [~, minted, report] = ndi.migrate.internal.ensembleMembership(structs);

            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(report.member_of_minted, 2);
            testCase.verifyEqual(report.derived_from_minted, 2);

            m = ofRelation(minted, 'member_of');
            testCase.verifyEqual(numel(m), 2);
            % child = the neuron, parent = the ensemble group-subject
            testCase.verifyEqual(depValue(m{1}, 'child'), 'nrn_1');
            testCase.verifyEqual(depValue(m{1}, 'parent'), 'ens_1');
            testCase.verifyEqual(m{1}.directed_relation.relation.node, 'RO:0002350');
            % column order rides on the declared `sequence` ordinal
            testCase.verifyEqual(m{1}.directed_relation.sequence, 1);
            testCase.verifyEqual(m{2}.directed_relation.sequence, 2);

            d = ofRelation(minted, 'derived_from');
            testCase.verifyEqual(numel(d), 2);
            % the cache carrier (the acquisition_epoch holding the combined
            % binary) is DERIVED FROM each neuron -- this set is the
            % verify-before-delete manifest.
            testCase.verifyEqual(depValue(d{1}, 'child'), 'aepoch_epoch_a');
            testCase.verifyEqual(depValue(d{1}, 'parent'), 'nrn_1');
            testCase.verifyEqual(d{1}.directed_relation.relation.node, 'RO:0001000');
            % a derived_from edge is unordered -- no sequence
            testCase.verifyFalse(isfield(d{1}.directed_relation, 'sequence'));
        end

        function testMintedRelationShapeIsVEta(testCase)
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            [~, minted, ~] = ndi.migrate.internal.ensembleMembership(structs);
            rel = minted{1};
            % regression guard copied from Path-S: `subject_relation` was
            % renamed to `relation` in V_eta, and a stale block is an
            % undeclared top-level block that quarantines.
            testCase.verifyFalse(isfield(rel, 'subject_relation'));
            supers = {rel.document_class.superclasses.class_name};
            testCase.verifyTrue(any(strcmp(supers, 'relation')));
            testCase.verifyFalse(any(strcmp(supers, 'subject_relation')));
            testCase.verifyEqual(rel.document_class.class_name, 'directed_relation');
            testCase.verifyEqual(rel.document_class.schema_version, 'V_eta');
            testCase.verifyNotEmpty(rel.base.id);
            testCase.verifyEqual(rel.base.session_id, 'sess_1');
        end

        function testNothingIsEverDropped(testCase)
            % The map document, the acquisition_epoch and the bytes all
            % survive: dropping them is gated on a corpus verify-before-delete
            % that has not run.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            [kept, ~, ~] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(numel(kept), numel(structs));
            testCase.verifyTrue(anyClass(kept, 'ensemble'));
            testCase.verifyTrue(anyClass(kept, 'acquisition_epoch'));
        end

        function testColumnOrderComesFromTheEdgeSuffix(testCase)
            % depends_on order must not matter: `neuron_id_2` listed first
            % still lands in column 2.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            map = firstOfClass(structs, 'ensemble');
            map.depends_on = [dep('element_id', 'ens_1'), ...
                dep('element_epoch_id', 'aepoch_epoch_a'), ...
                dep('neuron_id_2', 'nrn_2'), ...
                dep('neuron_id_1', 'nrn_1')];
            structs = replaceClass(structs, 'ensemble', map);

            [~, minted, ~] = ndi.migrate.internal.ensembleMembership(structs);
            m = ofRelation(minted, 'member_of');
            byChild = containers.Map();
            for k = 1:numel(m)
                byChild(depValue(m{k}, 'child')) = m{k}.directed_relation.sequence;
            end
            testCase.verifyEqual(byChild('nrn_1'), 1);
            testCase.verifyEqual(byChild('nrn_2'), 2);
        end

        function testStrandedNeuronIsCountedAndGetsNoEdge(testCase)
            % A neuron whose train is not in this corpus must NOT get an edge
            % -- that edge would be an orphan, and orphans are the corpus gate.
            % It is counted instead: this is the verify-before-delete
            % instrument.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            structs = dropId(structs, 'nrn_2');

            [~, minted, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.neuron_edges_seen, 2);
            testCase.verifyEqual(report.neuron_edges_resolved, 1);
            testCase.verifyEqual(report.neuron_edges_stranded, 1);
            testCase.verifyEqual(report.stranded_neuron_ids, {'nrn_2'});
            testCase.verifyEqual(report.member_of_minted, 1);
            for k = 1:numel(minted)
                testCase.verifyNotEqual(depValue(minted{k}, 'child'), 'nrn_2');
                testCase.verifyNotEqual(depValue(minted{k}, 'parent'), 'nrn_2');
            end
        end

        function testNoGroupSubjectMintsNothing(testCase)
            % The ensemble ELEMENT becomes a group-SUBJECT with its id
            % preserved. If that subject is absent, `parent` would be an empty
            % or dangling edge -- so nothing is minted for this map.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            structs = dropId(structs, 'ens_1');

            [kept, minted, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(report.ensemble_maps_seen, 1);
            testCase.verifyEqual(report.ensemble_maps_no_group, 1);
            testCase.verifyEqual(numel(kept), numel(structs));
        end

        function testMissingCacheCarrierStillMintsMembership(testCase)
            % Membership does not depend on the binary. With no resolvable
            % acquisition_epoch, member_of is still minted and derived_from is
            % not (no child to point at).
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            structs = dropId(structs, 'aepoch_epoch_a');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.member_of_minted, 1);
            testCase.verifyEqual(report.derived_from_minted, 0);
            testCase.verifyEqual(report.cache_carriers_seen, 1);
            testCase.verifyEqual(report.cache_carriers_resolved, 0);
        end

        function testEdgesAreDedupedWhenTheEpochCannotBeCarried(testCase)
            % Two epochs of the same ensemble with the same roster. Without an
            % epoch slot the two rosters are indistinguishable, so the edges
            % collapse instead of being emitted twice -- and the map documents
            % stay, because they are then the only durable per-epoch record.
            a = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            b = mapOnly('ens_1', 'epoch_b', {'nrn_1', 'nrn_2'});
            structs = [a, b];

            [kept, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.ensemble_maps_seen, 2);
            testCase.verifyEqual(report.member_of_minted, 2);
            testCase.verifyFalse(report.epoch_scope_available);
            testCase.verifyEqual(report.epoch_scoped_edges, 0);
            testCase.verifyEqual(numel(kept), numel(structs));
        end

        function testEpochScopeHookSeparatesEpochs(testCase)
            % When a caller can resolve an epochid string to an `epoch`
            % document (open item #60 -- not built), the edges become
            % epoch-scoped and the two rosters no longer collapse.
            a = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            b = mapOnly('ens_1', 'epoch_b', {'nrn_1', 'nrn_2'});
            structs = [a, b];
            resolver = @(epochStr, sessionId) ['epochdoc_' epochStr];

            [~, minted, report] = ndi.migrate.internal.ensembleMembership( ...
                structs, 'EpochDocumentIdFor', resolver);
            testCase.verifyTrue(report.epoch_scope_available);
            testCase.verifyEqual(report.member_of_minted, 4);
            m = ofRelation(minted, 'member_of');
            scopes = {};
            for k = 1:numel(m)
                scopes{end+1} = depValue(m{k}, 'epoch_id'); %#ok<AGROW>
            end
            testCase.verifyTrue(any(strcmp(scopes, 'epochdoc_epoch_a')));
            testCase.verifyTrue(any(strcmp(scopes, 'epochdoc_epoch_b')));
            testCase.verifyEqual(report.epoch_scoped_edges, ...
                report.member_of_minted + report.derived_from_minted);
        end

        function testEpochScopeIsAbsentNotEmptyByDefault(testCase)
            % Never emit an empty edge: with no resolver there is no `epoch_id`
            % entry at all, rather than one carrying ''.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            [~, minted, ~] = ndi.migrate.internal.ensembleMembership(structs);
            for k = 1:numel(minted)
                names = {minted{k}.depends_on.name};
                testCase.verifyFalse(any(strcmp(names, 'epoch_id')));
                for j = 1:numel(minted{k}.depends_on)
                    testCase.verifyNotEmpty(minted{k}.depends_on(j).value);
                end
            end
        end

        function testReportStatesItsDenominator(testCase)
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.documents_inspected, numel(structs));
            testCase.verifyEqual(report.neuron_edges_seen, ...
                report.neuron_edges_resolved + report.neuron_edges_stranded);
        end

        % ============ verify-before-delete: TRAINS, not subjects ============
        % The gate that licenses dropping the combined marked-point-process
        % bytes. A neuron SUBJECT existing proves nothing about its spike
        % times: migrators_j.element turns an element into a bare `subject`
        % with no data, and the train is a separate acquisition_epoch. These
        % tests pin that the gate asks the data question.

        function testSubjectPresentButTrainAbsentIsNotAClearance(testCase)
            % THE DEFECT THIS BUCKET EXISTS FOR. Both neuron-subjects are
            % present, so neuron_edges_stranded is 0 -- and there is not one
            % per-neuron train in the batch. Dropping the combined binary here
            % would destroy the only copy of every spike time.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);

            testCase.verifyEqual(report.neuron_edges_stranded, 0);
            testCase.verifyEqual(report.neuron_trains_missing_entirely, 2);
            testCase.verifyEqual(sort(report.neurons_missing_train_ids), ...
                {'nrn_1', 'nrn_2'});
            testCase.verifyFalse(report.verify_before_delete_clear);
        end

        function testGateClearsOnlyWhenEveryTrainIsPresent(testCase)
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            structs{end+1} = trainBody('nrn_1', 'epoch_a');
            structs{end+1} = trainBody('nrn_2', 'epoch_a');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.neuron_trains_present_this_epoch, 2);
            testCase.verifyEqual(report.neuron_trains_missing_entirely, 0);
            testCase.verifyEqual(report.neuron_trains_other_epoch_only, 0);
            testCase.verifyEmpty(report.neurons_missing_train_ids);
            testCase.verifyTrue(report.verify_before_delete_clear);
        end

        function testOnePartialTrainBlocksTheGate(testCase)
            % One of two neurons has a train. The gate must NOT clear.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            structs{end+1} = trainBody('nrn_1', 'epoch_a');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.neuron_trains_present_this_epoch, 1);
            testCase.verifyEqual(report.neuron_trains_missing_entirely, 1);
            testCase.verifyEqual(report.neurons_missing_train_ids, {'nrn_2'});
            testCase.verifyFalse(report.verify_before_delete_clear);
        end

        function testTrainUnderAnotherEpochIsItsOwnBucket(testCase)
            % NDI reaches a neuron's epoch through syncgraph.time_convert, so
            % an ensemble's epochid and a neuron's epochid need not be the
            % same string. "has data, filed elsewhere" must not be reported as
            % "has no data" -- nor silently accepted as a clearance.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            structs{end+1} = trainBody('nrn_1', 'a_different_epoch');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.neuron_trains_missing_entirely, 0);
            testCase.verifyEqual(report.neuron_trains_present_this_epoch, 0);
            testCase.verifyEqual(report.neuron_trains_other_epoch_only, 1);
            testCase.verifyFalse(report.verify_before_delete_clear);
        end

        function testEpochDocumentWithNoBytesIsNotATrain(testCase)
            % An acquisition_epoch naming the neuron's epoch but carrying no
            % binary holds no spike times. It is counted as a document seen,
            % NOT as a train.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            structs{end+1} = trainBodyWithoutBytes('nrn_1', 'epoch_a');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.neuron_trains_missing_entirely, 1);
            testCase.verifyFalse(report.verify_before_delete_clear);
            % the ensemble's own carrier has bytes; the neuron's does not
            testCase.verifyEqual(report.train_documents_seen, 2);
            testCase.verifyEqual(report.train_documents_with_binary, 1);
        end

        function testInstrumentReportsItsOwnDenominator(testCase)
            % If train_documents_with_binary were 0 while train_documents_seen
            % was large, every "missing train" would be an artefact of this
            % pass reading the wrong field. Both numbers are published so the
            % two situations are distinguishable from the report alone.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            structs{end+1} = trainBody('nrn_1', 'epoch_a');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.train_documents_seen, 2);
            testCase.verifyEqual(report.train_documents_with_binary, 2);
        end

        function testStrandedSubjectAlsoBlocksTheGate(testCase)
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1', 'nrn_2'});
            structs{end+1} = trainBody('nrn_1', 'epoch_a');
            structs = dropId(structs, 'nrn_2');

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.neuron_edges_stranded, 1);
            testCase.verifyFalse(report.verify_before_delete_clear);
        end

        function testEmptyBatchNeverReadsAsAClearance(testCase)
            % A gate that clears when nothing was inspected is the "all-zero
            % counts read as clean" failure. Absence of findings is not a pass.
            [~, ~, report] = ndi.migrate.internal.ensembleMembership({});
            testCase.verifyFalse(report.verify_before_delete_clear);

            structs = {subjectBody('nrn_1')};
            [~, ~, r2] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyFalse(r2.verify_before_delete_clear);
        end

        % ==================== the other denominators ========================

        function testDistinctEnsemblesAndEpochsAreCountedSeparately(testCase)
            % A map document is PER EPOCH, so ensemble_maps_seen over-counts
            % ensembles. Two epochs of ONE ensemble = 2 maps, 1 ensemble,
            % 2 epochs.
            a = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            b = mapOnly('ens_1', 'epoch_b', {'nrn_1'});
            structs = [a, b];

            [~, ~, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.ensemble_maps_seen, 2);
            testCase.verifyEqual(report.distinct_ensembles_seen, 1);
            testCase.verifyEqual(report.distinct_epochs_seen, 2);
        end

        function testMapWithNoNeuronEdgesIsCountedNotSilentlySkipped(testCase)
            % "Fell through" must be a named number, never something you have
            % to infer by subtracting two others.
            structs = ensembleCorpus('ens_1', 'epoch_a', {'nrn_1'});
            map = firstOfClass(structs, 'ensemble');
            map.depends_on = [dep('element_id', 'ens_1'), ...
                dep('element_epoch_id', 'aepoch_epoch_a')];
            structs = replaceClass(structs, 'ensemble', map);

            [~, minted, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyEqual(report.ensemble_maps_seen, 1);
            testCase.verifyEqual(report.ensemble_maps_used, 0);
            testCase.verifyEqual(report.ensemble_maps_no_neurons, 1);
            testCase.verifyEmpty(minted);
            testCase.verifyFalse(report.verify_before_delete_clear);
        end

        function testEmptyCorpusIsInertAndStillReports(testCase)
            [kept, minted, report] = ndi.migrate.internal.ensembleMembership({});
            testCase.verifyEmpty(kept);
            testCase.verifyEmpty(minted);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.documents_inspected, 0);
        end

        function testCorpusWithNoEnsembleIsUntouched(testCase)
            structs = {subjectBody('nrn_1')};
            [kept, minted, report] = ndi.migrate.internal.ensembleMembership(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEmpty(minted);
            testCase.verifyEqual(numel(kept), 1);
            testCase.verifyEqual(report.ensemble_maps_seen, 0);
        end

    end
end

% ===================== fixtures + accessors (test-only) ====================

function s = ensembleCorpus(ensembleId, epochId, neuronIds)
% A migrated corpus fragment: the ensemble group-subject, one neuron-subject
% per member, the acquisition_epoch that carries the combined binary, and the
% `ensemble` map document that ties them together.
s = {subjectBody(ensembleId)};
for k = 1:numel(neuronIds)
    s{end+1} = subjectBody(neuronIds{k}); %#ok<AGROW>
end
s{end+1} = acquisitionEpochBody(['aepoch_' epochId], epochId, ensembleId);
s{end+1} = mapBody(ensembleId, epochId, neuronIds);
end

function s = mapOnly(ensembleId, epochId, neuronIds)
% A second epoch of the same ensemble: another acquisition_epoch + map, no new
% subjects.
s = {acquisitionEpochBody(['aepoch_' epochId], epochId, ensembleId), ...
     mapBody(ensembleId, epochId, neuronIds)};
end

function b = mapBody(ensembleId, epochId, neuronIds)
b = struct();
b.document_class = dc('ensemble', {'base', 'epochid', 'app'});
deps = [dep('element_id', ensembleId), ...
        dep('element_epoch_id', ['aepoch_' epochId])];
for k = 1:numel(neuronIds)
    deps(end+1) = dep(sprintf('neuron_id_%d', k), neuronIds{k}); %#ok<AGROW>
end
b.depends_on = deps;
b.base = base(['map_' ensembleId '_' epochId]);
b.epochid = struct('epochid', epochId);
b.app = struct('name', 'ndi.element.ensemble');
b.ensemble = struct('ensemble_name', 'V1', 'value_type', 'spiketimes', ...
    'value_description', '', 'num_neurons', numel(neuronIds), ...
    'clocktype', 'dev_local_time');
end

function b = subjectBody(id)
b = struct();
b.document_class = dc('subject', {'entity'});
b.depends_on = struct('name', {}, 'value', {});
b.base = base(id);
b.subject = struct('local_identifier', id, 'description', '');
end

function b = acquisitionEpochBody(id, epochId, elementId)
% The migrated `element_epoch`: element_id + epochid.epochid + the binary.
% Shape taken from the did_v1 template
% (origin/main:src/ndi/ndi_common/database_documents/element_epoch.json --
% depends_on element_id, files.file_list ["epoch_binary_data.vhsb"],
% superclasses base + epochid), which is the document NDI's readtimeseries
% path searches for at +ndi/+element/timeseries.m:56-70.
b = struct();
b.document_class = dc('acquisition_epoch', {'base', 'epochid'});
b.depends_on = dep('element_id', elementId);
b.base = base(id);
b.epochid = struct('epochid', epochId);
b.acquisition_epoch = struct('clocks', struct('clock', 'dev_local_time'));
b.files = struct('file_list', {{'epoch_binary_data.vhsb'}});
end

function b = trainBody(neuronId, epochId)
% A PER-NEURON SPIKE TRAIN: the same acquisition_epoch shape, but owned by
% the neuron rather than by the ensemble. This is the thing the
% verify-before-delete gate must find before the combined bytes may go.
b = acquisitionEpochBody(['train_' neuronId '_' epochId], epochId, neuronId);
end

function b = trainBodyWithoutBytes(neuronId, epochId)
% An epoch document for the neuron that carries NO binary -- it names an
% epoch but holds no spike times, so it is not a train.
b = trainBody(neuronId, epochId);
% NOTE: `struct('file_list', {{}})` would build a 0x0 STRUCT ARRAY -- struct()
% distributes over cell values, and {} has zero elements. Assign the field
% instead, which is the only way to get a 1x1 struct with an empty cell field.
b.files = struct();
b.files.file_list = {};
end

function x = dc(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
x = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function x = dep(name, value)
x = struct('name', name, 'value', value);
end

function x = base(id)
x = struct('id', id, 'session_id', 'sess_1', 'name', 'n', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
end

function out = ofRelation(bodies, relationName)
% every minted directed_relation carrying RELATIONNAME, in mint order
out = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if ~strcmp(b.document_class.class_name, 'directed_relation'); continue; end
    if strcmp(b.directed_relation.relation.name, relationName)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function tf = anyClass(bodies, className)
tf = false;
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        tf = true; return;
    end
end
end

function b = firstOfClass(bodies, className)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        b = bodies{k}; return;
    end
end
end

function bodies = replaceClass(bodies, className, newBody)
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        bodies{k} = newBody; return;
    end
end
end

function bodies = dropId(bodies, id)
out = {};
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, id); continue; end
    out{end+1} = bodies{k}; %#ok<AGROW>
end
bodies = out;
end

function v = depValue(s, name)
v = '';
for k = 1:numel(s.depends_on)
    if strcmp(s.depends_on(k).name, name)
        v = s.depends_on(k).value; return;
    end
end
end
