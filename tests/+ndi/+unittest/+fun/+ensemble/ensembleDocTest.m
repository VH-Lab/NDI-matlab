classdef ensembleDocTest < matlab.unittest.TestCase
    % ENSEMBLEDOCTEST - Tests for the 'ensemble' document layer
    %
    % Exercises ndi.fun.ensemble.read and ndi.fun.ensemble.findExisting against
    % ensemble documents that are seeded directly into the database (without the
    % extraction path), so these tests do not depend on reading spike time series
    % or on the syncgraph. Verifies that a stored ensemble round-trips through
    % read, and that findExisting matches on element + neuron ids + neuron names
    % (+ epoch) and rejects near-misses.

    properties
        Session
        TempDir
        SubjectId
        ProbeId
        NeuronIds
        NeuronNames
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            testCase.Session = ndi.session.dir('ensemble_doc_test', testCase.TempDir);
            S = testCase.Session;

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            testCase.SubjectId = subdoc.id();

            probe = ndi.document('element', 'base.session_id', S.id(), ...
                'element.ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
                'element.name', 'ctx_probe', 'element.reference', 1, ...
                'element.type', 'n-trode', 'element.direct', 1);
            probe = probe.set_dependency_value('subject_id', testCase.SubjectId);
            S.database_add(probe);
            testCase.ProbeId = probe.id();

            nNeurons = 4;
            ids = cell(1, nNeurons);
            names = cell(1, nNeurons);
            for i = 1:nNeurons
                nm = sprintf('ctx_probe_neuron_%d', i);
                elem = ndi.document('element', 'base.session_id', S.id(), ...
                    'element.ndi_element_class', 'ndi.neuron', ...
                    'element.name', nm, 'element.reference', i, ...
                    'element.type', 'spikes', 'element.direct', 0);
                elem = elem.set_dependency_value('underlying_element_id', testCase.ProbeId);
                elem = elem.set_dependency_value('subject_id', testCase.SubjectId);
                S.database_add(elem);
                ids{i} = elem.id();
                names{i} = nm;
            end
            testCase.NeuronIds = ids;
            testCase.NeuronNames = names;
        end
    end

    methods (TestMethodTeardown)
        function teardownSession(testCase)
            if exist(testCase.TempDir, 'dir')
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)

        function testReadRoundTrip(testCase)
            % A seeded ensemble document reads back exactly.
            E = sparse(4,5);
            E(1,1:3) = [0.10 0.22 0.51];
            E(2,1:2) = [0.15 0.40];
            E(3,1:5) = [0.05 0.11 0.27 0.33 0.62];
            testCase.seedEnsemble(E, testCase.NeuronIds, testCase.NeuronNames, ...
                'epoch_1', 'seed ensemble');

            docs = testCase.Session.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(docs), 1);
            [activity, nids, nnames, element_id, info] = ...
                ndi.fun.ensemble.read(testCase.Session, docs{1});

            testCase.verifyTrue(issparse(activity));
            testCase.verifyEqual(full(activity), full(E), 'Activity should round-trip.');
            testCase.verifyEqual(nids, testCase.NeuronIds);
            testCase.verifyEqual(nnames, testCase.NeuronNames);
            testCase.verifyEqual(element_id, testCase.ProbeId);
            testCase.verifyEqual(info.num_neurons, 4);
            testCase.verifyEqual(docs{1}.document_properties.epochid.epochid, 'epoch_1');
        end

        function testFindExistingMatches(testCase)
            E = sparse([1 2],[1 1],[0.2 0.3],4,1);
            testCase.seedEnsemble(E, testCase.NeuronIds, testCase.NeuronNames, ...
                'epoch_1', 'seed');
            S = testCase.Session;

            found = ndi.fun.ensemble.findExisting(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, 'epochid', 'epoch_1');
            testCase.verifyEqual(numel(found), 1, 'Exact match should be found.');

            % different element -> no match
            none1 = ndi.fun.ensemble.findExisting(S, ndi.ido().id(), ...
                testCase.NeuronIds, testCase.NeuronNames);
            testCase.verifyEmpty(none1, 'A different element should not match.');

            % different neuron ids -> no match
            none2 = ndi.fun.ensemble.findExisting(S, testCase.ProbeId, ...
                testCase.NeuronIds(1:2), testCase.NeuronNames(1:2));
            testCase.verifyEmpty(none2, 'A different neuron set should not match.');

            % different neuron names -> no match
            otherNames = testCase.NeuronNames;
            otherNames{1} = 'renamed';
            none3 = ndi.fun.ensemble.findExisting(S, testCase.ProbeId, ...
                testCase.NeuronIds, otherNames);
            testCase.verifyEmpty(none3, 'Different names should not match.');
        end

        function testFindExistingEpochDistinguishes(testCase)
            % Ensembles built for different epochs are not duplicates.
            E = sparse([1],[1],[0.2],4,1);
            testCase.seedEnsemble(E, testCase.NeuronIds, testCase.NeuronNames, ...
                'epoch_1', 'seed');
            S = testCase.Session;

            same = ndi.fun.ensemble.findExisting(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, 'epochid', 'epoch_1');
            testCase.verifyEqual(numel(same), 1);

            other = ndi.fun.ensemble.findExisting(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, 'epochid', 'epoch_2');
            testCase.verifyEmpty(other, 'A different epoch should not match.');
        end

    end

    methods % helpers
        function seedEnsemble(testCase, activity, neuron_ids, neuron_names, epochid, name)
            % Build and add an 'ensemble' document directly (no extraction).
            S = testCase.Session;
            af = [ndi.file.temp_name() '.ndisparse'];
            ndi.util.writeSparse(af, activity);
            nf = [ndi.file.temp_name() '.txt'];
            fid = fopen(nf, 'w');
            for i = 1:numel(neuron_names)
                fprintf(fid, '%s\n', neuron_names{i});
            end
            fclose(fid);

            doc = S.newdocument('ensemble', ...
                'ensemble.ensemble_name', name, ...
                'ensemble.value_type', 'spiketimes', ...
                'ensemble.value_description', 'seeded', ...
                'ensemble.num_neurons', numel(neuron_ids), ...
                'ensemble.num_dimensions', 2, ...
                'ensemble.clocktype', 'dev_local_time', ...
                'epochid.epochid', epochid);
            doc = doc.set_dependency_value('element_id', testCase.ProbeId);
            for i = 1:numel(neuron_ids)
                doc = doc.add_dependency_value_n('neuron_id', neuron_ids{i});
            end
            doc = doc.add_file('ensemble_activity.ndisparse', af);
            doc = doc.add_file('neuron_names.txt', nf);
            S.database_add(doc);
        end
    end
end
