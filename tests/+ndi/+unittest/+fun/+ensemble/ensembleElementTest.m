classdef ensembleElementTest < matlab.unittest.TestCase
    % ENSEMBLEELEMENTTEST - End-to-end tests for ndi.element.ensemble + create/read
    %
    % Builds a probe (n-trode) with one UTC epoch and several spiking neurons
    % built on it, then uses ndi.fun.ensemble.create to build the ensemble
    % element and verifies:
    %   * readtimeseries returns the spikes as a marked point process
    %     (neuron column index, spike time);
    %   * neuronIds / neuronNames / neurons recover the per-epoch column map;
    %   * spikeMatrix and ndi.fun.ensemble.read reconstruct the neuron-by-spike
    %     matrix;
    %   * a duplicate create errors, and findExisting locates the map document.
    %
    % These exercise the extraction and element read-back paths (readtimeseries),
    % so they depend on the session's time handling; the probe and neurons share
    % a UTC epoch so their times are comparable.

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

        function testReadtimeseriesMarkedPointProcess(testCase)
            ens = ndi.fun.ensemble.create(testCase.Session, testCase.Probe, 'epoch_1');
            [colindex, t] = ens.readtimeseries('epoch_1', -Inf, Inf);
            colindex = round(colindex(:).');
            t = t(:).';

            nTotal = numel([testCase.Spikes{:}]);
            testCase.verifyEqual(numel(t), nTotal, 'All spikes should be returned.');
            testCase.verifyEqual(sort(t), sort([testCase.Spikes{:}]), 'AbsTol', 1e-9, ...
                'The union of spike times should match.');

            % per-column spikes must match the neuron that column maps to
            ids = ens.neuronIds('epoch_1');
            names = ens.neuronNames('epoch_1');
            for c = 1:numel(ids)
                idx = find(strcmp(ids{c}, testCase.NeuronIds), 1);
                testCase.verifyNotEmpty(idx);
                spk = sort(t(colindex==c));
                testCase.verifyEqual(spk, sort(testCase.Spikes{idx}), 'AbsTol', 1e-9, ...
                    'Column spikes should match the mapped neuron.');
                testCase.verifyEqual(names{c}, testCase.NeuronNames{idx}, ...
                    'Column name should match the mapped neuron.');
            end
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

        function testSpikeMatrixAndReadFunction(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1');
            [M, ids] = ens.spikeMatrix('epoch_1');
            testCase.verifyEqual(size(M,1), numel(testCase.Spikes));

            [E, rids, rnames, info] = ndi.fun.ensemble.read(S, ens, 'epoch_1');
            testCase.verifyEqual(full(E), full(M), 'read should match spikeMatrix.');
            testCase.verifyEqual(rids, ids);
            testCase.verifyEqual(numel(rnames), numel(ids));
            testCase.verifyEqual(info.num_neurons, numel(testCase.Spikes));

            for c = 1:numel(ids)
                idx = find(strcmp(ids{c}, testCase.NeuronIds), 1);
                v = sort(nonzeros(M(c,:)).');
                testCase.verifyEqual(v, sort(testCase.Spikes{idx}), 'AbsTol', 1e-9, ...
                    'Row spikes should match the mapped neuron.');
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
