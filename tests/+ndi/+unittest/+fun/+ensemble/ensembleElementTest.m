classdef ensembleElementTest < matlab.unittest.TestCase
    % ENSEMBLEELEMENTTEST - End-to-end tests for ndi.element.ensemble + create/read
    %
    % Builds a probe (n-trode) with one UTC epoch and several spiking neurons
    % built on it, then uses ndi.fun.ensemble.create to build the ensemble
    % element and verifies:
    %   * create returns an ndi.element.ensemble;
    %   * neuronIds / neurons recover the per-epoch column map;
    %   * a duplicate create errors, and findExisting locates the map document.
    %
    % NOTE: reading the ensemble activity back (readtimeseries / spikeMatrix /
    % ndi.fun.ensemble.read / plot) requires the ensemble element's epoch to be
    % resolvable to dev_local_time through the session's syncgraph. That needs a
    % DAQ-backed session (as in StimulatorTest / OneEpochTest); a bare session
    % with manually added UTC epochs cannot exercise it, so the read-back path is
    % not tested here (it is validated on real, DAQ-backed data).

    properties
        Session
        TempDir
        Probe
        NeuronIds
        NeuronNames
        Spikes
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            S = ndi.session.dir('ensemble_element_test', testCase.TempDir);

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            subjectId = subdoc.id();

            utc = ndi.time.clocktype('UTC');
            probe = ndi.element.timeseries(S, 'ctx_probe', 1, 'n-trode', [], 0, subjectId);
            probe = probe.addepoch('epoch_1', utc, [0 100], [], []);
            testCase.Probe = probe;

            testCase.Spikes = { [10 50 90], [20 60], [30 70 80 95] };
            n = numel(testCase.Spikes);
            ids = cell(1,n); names = cell(1,n);
            for i = 1:n
                e = ndi.element.timeseries(S, sprintf('neuron_%d', i), i, 'spikes', ...
                    probe, 0, subjectId);
                t = testCase.Spikes{i}(:);
                e = e.addepoch('epoch_1', utc, [0 100], t, ones(size(t)));
                ids{i} = e.id();
                names{i} = e.elementstring();
            end
            testCase.NeuronIds = ids;
            testCase.NeuronNames = names;
            testCase.Session = S;
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

        function testCreateReturnsEnsembleElement(testCase)
            ens = ndi.fun.ensemble.create(testCase.Session, testCase.Probe, 'epoch_1');
            testCase.verifyClass(ens, 'ndi.element.ensemble');
        end

        function testNeuronsMethod(testCase)
            ens = ndi.fun.ensemble.create(testCase.Session, testCase.Probe, 'epoch_1');
            ids = ens.neuronIds('epoch_1');
            nrns = ens.neurons('epoch_1');
            testCase.verifyEqual(numel(nrns), numel(ids));
            for c = 1:numel(ids)
                testCase.verifyEqual(nrns{c}.id(), ids{c}, ...
                    'neurons() should return the element for each column id.');
            end
        end

        function testDuplicateErrorsAndFindExisting(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');

            found = ndi.fun.ensemble.findExisting(S, ens, 'epochid', 'epoch_1');
            testCase.verifyEqual(numel(found), 1, 'The map document should be found.');
            none = ndi.fun.ensemble.findExisting(S, ens, 'epochid', 'epoch_2');
            testCase.verifyEmpty(none, 'No ensemble for a different epoch.');

            testCase.verifyError(@() ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1'), ...
                'ndi:ensemble:create:exists');
        end

    end
end
