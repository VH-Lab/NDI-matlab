classdef ensembleTest < matlab.unittest.TestCase
    % ENSEMBLETEST - Unit tests for ndi.fun.ensemble.create and ndi.fun.ensemble.read
    %
    % Builds a small ndi.session in a temp directory with a subject, a probe
    % 'element' document, and several spiking-neuron 'element' documents built
    % on that probe (mirroring how a spike sorter would populate a session).
    % It then exercises ndi.fun.ensemble.create to build and store an 'ensemble'
    % document and ndi.fun.ensemble.read to read it back, verifying that the
    % activity array, neuron names, neuron ids, owning element id, dependencies,
    % and metadata all round-trip through the database.

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
            testCase.Session = ndi.session.dir('ensemble_test', testCase.TempDir);
            S = testCase.Session;

            % a subject for the elements to depend on
            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            testCase.SubjectId = subdoc.id();

            % a probe element that the ensemble will belong to
            probe = ndi.document('element', 'base.session_id', S.id(), ...
                'element.ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
                'element.name', 'ctx_probe', 'element.reference', 1, ...
                'element.type', 'n-trode', 'element.direct', 1);
            probe = probe.set_dependency_value('subject_id', testCase.SubjectId);
            S.database_add(probe);
            testCase.ProbeId = probe.id();

            % a set of spiking-neuron elements built on the probe
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

        function testCreateReadRoundTrip(testCase)
            % A 2-D spike-time ensemble round-trips through the database.
            S = testCase.Session;

            % 4 neurons x up-to-5 spikes; neuron 4 has no spikes
            E = sparse(4,5);
            E(1,1:3) = [0.10 0.22 0.51];
            E(2,1:2) = [0.15 0.40];
            E(3,1:5) = [0.05 0.11 0.27 0.33 0.62];

            ndi.fun.ensemble.create(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, E, ...
                'epochid', 'epoch_1', 'ensemble_name', 'test ensemble', ...
                'value_type', 'spiketimes', ...
                'value_description', 'time of n-th spike of neuron i', ...
                'clocktype', 'dev_local_time', 'add_to_database', true);

            docs = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(docs), 1, 'Exactly one ensemble document should exist.');

            [activity, nids, nnames, element_id, info] = ndi.fun.ensemble.read(S, docs{1});

            testCase.verifyTrue(issparse(activity), 'A 2-D activity array should read back as sparse.');
            testCase.verifyEqual(full(activity), full(E), 'Activity matrix should round-trip exactly.');
            testCase.verifyEqual(nids, testCase.NeuronIds, 'Neuron ids should round-trip in order.');
            testCase.verifyEqual(nnames, testCase.NeuronNames, 'Neuron names should round-trip in order.');
            testCase.verifyEqual(element_id, testCase.ProbeId, 'element_id should be the probe id.');
            testCase.verifyEqual(info.num_neurons, 4, 'num_neurons should be 4.');
            testCase.verifyEqual(info.num_dimensions, 2, 'num_dimensions should be 2.');
            testCase.verifyEqual(info.value_type, 'spiketimes');
            testCase.verifyEqual(info.clocktype, 'dev_local_time');
            testCase.verifyEqual(info.ensemble_name, 'test ensemble');
            testCase.verifyEqual(docs{1}.document_properties.epochid.epochid, 'epoch_1', ...
                'The epoch id should be stored.');
        end

        function testDependenciesRecorded(testCase)
            % The owning element and every neuron are recorded as dependencies.
            S = testCase.Session;
            E = sparse([1 2],[1 1],[0.2 0.3],4,1);
            ndi.fun.ensemble.create(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, E, 'add_to_database', true);

            d = S.database_search(ndi.query('','isa','ensemble',''));
            d = d{1};
            testCase.verifyEqual(d.dependency_value('element_id'), testCase.ProbeId, ...
                'element_id dependency should be the probe.');
            nid = d.dependency_value_n('neuron_id');
            testCase.verifyEqual(nid(:).', testCase.NeuronIds, ...
                'All neuron_id_# dependencies should be present, in order.');
        end

        function testAcceptsElementObject(testCase)
            % create() accepts an object with an id() method for the owning element.
            S = testCase.Session;
            probeObj = ndi.element(S, 'ctx_probe_obj', 2, 'n-trode', [], 1, testCase.SubjectId);
            E = sparse([1],[1],[0.2],4,1);
            ndi.fun.ensemble.create(S, probeObj, ...
                testCase.NeuronIds, testCase.NeuronNames, E, 'add_to_database', true);
            d = S.database_search(ndi.query('','isa','ensemble',''));
            [~, ~, ~, element_id] = ndi.fun.ensemble.read(S, d{1});
            testCase.verifyEqual(element_id, probeObj.id(), ...
                'An element object should be resolved to its document id.');
        end

        function testNotAddedByDefault(testCase)
            % Without add_to_database, nothing is written to the database, but the
            % files are registered on the returned document.
            S = testCase.Session;
            E = sparse([1],[1],[0.2],4,5);
            doc = ndi.fun.ensemble.create(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, E);

            docs = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(docs), 0, ...
                'Without add_to_database, the document should not be in the database.');
            fl = doc.current_file_list();
            testCase.verifyTrue(ismember('ensemble_activity.ndisparse', fl), ...
                'The activity binary file should be registered.');
            testCase.verifyTrue(ismember('neuron_names.txt', fl), ...
                'The neuron names text file should be registered.');
        end

        function testNDActivityRoundTrip(testCase)
            % An N-dimensional (COO struct) activity array round-trips.
            S = testCase.Session;
            subs = [1 1 1; 2 1 2; 3 2 1]; % 1-based, neuron x trial x spike
            vals = [0.10; 0.25; 0.40];
            sz = [4 2 3];
            activityIn = struct('subs', subs, 'vals', vals, 'size', sz);

            ndi.fun.ensemble.create(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames, activityIn, ...
                'value_type', 'spiketimes', 'add_to_database', true);

            d = S.database_search(ndi.query('','isa','ensemble',''));
            [activity, ~, ~, ~, info] = ndi.fun.ensemble.read(S, d{1});
            testCase.verifyEqual(info.num_dimensions, 3, 'num_dimensions should be 3.');
            testCase.verifyTrue(isstruct(activity), 'A 3-D ensemble should read back as a struct.');
            testCase.verifyEqual(activity.size, sz);
            testCase.verifyEqual(sortrows([activity.subs activity.vals]), ...
                sortrows([subs vals]), 'N-D subscripts/values should round-trip.');
        end

        function testNameCountMismatchErrors(testCase)
            % A mismatch between neuron ids and names is an error.
            S = testCase.Session;
            E = sparse(4,2);
            testCase.verifyError(@() ndi.fun.ensemble.create(S, testCase.ProbeId, ...
                testCase.NeuronIds, testCase.NeuronNames(1:2), E), ...
                'ndi:ensemble:create:nameCountMismatch');
        end

    end
end
