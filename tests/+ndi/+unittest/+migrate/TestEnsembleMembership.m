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
%   verify-before-delete gate (0 stranded per-neuron trains) has not run on a
%   corpus. testNothingIsEverDropped pins that, and testStrandedNeuronIsCounted
%   pins the instrument that measures the gate.
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
b = struct();
b.document_class = dc('acquisition_epoch', {'base', 'epochid'});
b.depends_on = dep('element_id', elementId);
b.base = base(id);
b.epochid = struct('epochid', epochId);
b.acquisition_epoch = struct('clocks', struct('clock', 'dev_local_time'));
b.files = struct('file_list', {{'epoch_binary_data.vhsb'}});
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
