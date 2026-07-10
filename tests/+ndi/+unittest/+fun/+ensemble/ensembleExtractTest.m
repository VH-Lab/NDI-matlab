classdef ensembleExtractTest < matlab.unittest.TestCase
    % ENSEMBLEEXTRACTTEST - End-to-end tests for ndi.fun.ensemble.load and .create
    %
    % Builds a session with a reference element (a probe) that has one epoch, and
    % several spiking-neuron ndi.element.timeseries objects that carry spike
    % times in that epoch (expressed in a shared global UTC clock). It then
    % verifies that:
    %   * ndi.fun.ensemble.load reads each neuron's spikes for the epoch and
    %     packs them into the correct N-by-Smax matrix, and
    %   * ndi.fun.ensemble.create stores the ensemble, that it reads back, and
    %     that a second create raises the duplicate error unless CheckExisting
    %     is disabled.
    %
    % These tests exercise the extraction path (readtimeseries against a time
    % reference), so they depend on the session's time handling; the neurons and
    % the reference element share a UTC epoch so their times are comparable.

    properties
        Session
        TempDir
        SubjectId
        Probe        % reference element (ndi.element.timeseries)
        NeuronObjs   % cell array of neuron ndi.element.timeseries
        NeuronIds
        NeuronNames
        Spikes       % cell array of spike-time vectors, one per neuron
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            S = ndi.session.dir('ensemble_extract_test', testCase.TempDir);

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            testCase.SubjectId = subdoc.id();

            utc = ndi.time.clocktype('UTC');

            % reference element (a probe) with one epoch
            probe = ndi.element.timeseries(S, 'ctx_probe', 1, 'n-trode', [], 0, ...
                testCase.SubjectId);
            probe = probe.addepoch('epoch_1', utc, [0 100], [], []);
            testCase.Probe = probe;

            % spiking neurons carrying spike times in epoch_1 (UTC)
            testCase.Spikes = { [10 50 90], [20 60], [30 70 80 95], [40] };
            n = numel(testCase.Spikes);
            objs = cell(1,n); ids = cell(1,n); names = cell(1,n);
            for i = 1:n
                e = ndi.element.timeseries(S, sprintf('neuron_%d', i), i, 'spikes', ...
                    [], 0, testCase.SubjectId);
                t = testCase.Spikes{i}(:);
                e = e.addepoch('epoch_1', utc, [0 100], t, ones(size(t)));
                objs{i} = e;
                ids{i} = e.id();
                names{i} = e.elementstring();
            end
            testCase.NeuronObjs = objs;
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

        function testLoadBuildsMatrix(testCase)
            S = testCase.Session;
            [E, nids, nnames] = ndi.fun.ensemble.load(S, testCase.Probe, 'epoch_1', ...
                'clocktype', 'UTC');

            testCase.verifyEqual(size(E,1), numel(testCase.Spikes), ...
                'One row per neuron recorded in the epoch.');
            testCase.verifyEqual(numel(nids), numel(testCase.Spikes));

            % rows come back in database order; match each by neuron id
            for k = 1:numel(nids)
                idx = find(strcmp(nids{k}, testCase.NeuronIds), 1);
                testCase.verifyNotEmpty(idx, 'Returned id should be one of the neurons.');
                v = full(E(k,:));
                v = sort(v(v~=0));
                testCase.verifyEqual(v, sort(testCase.Spikes{idx}), 'AbsTol', 1e-9, ...
                    'Row spike times should match the neuron''s spikes.');
                testCase.verifyEqual(nnames{k}, testCase.NeuronNames{idx}, ...
                    'Neuron name should match.');
            end
        end

        function testCreateStoresAndReads(testCase)
            S = testCase.Session;
            ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1', ...
                'clocktype', 'UTC', 'ensemble_name', 'extract test', ...
                'add_to_database', true);

            docs = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(docs), 1);
            [activity, nids, ~, element_id, info] = ndi.fun.ensemble.read(S, docs{1});
            testCase.verifyEqual(element_id, testCase.Probe.id(), ...
                'element_id should be the probe.');
            testCase.verifyEqual(info.num_neurons, numel(testCase.Spikes));
            testCase.verifyEqual(size(activity,1), numel(testCase.Spikes));
            testCase.verifyEqual(numel(nids), numel(testCase.Spikes));
        end

        function testDuplicateErrorsAndSkip(testCase)
            S = testCase.Session;
            ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1', ...
                'clocktype', 'UTC', 'add_to_database', true);

            % a second identical create should error
            testCase.verifyError(@() ndi.fun.ensemble.create(S, testCase.Probe, ...
                'epoch_1', 'clocktype', 'UTC', 'add_to_database', true), ...
                'ndi:ensemble:create:exists');

            % ... unless the check is disabled
            ndi.fun.ensemble.create(S, testCase.Probe, 'epoch_1', ...
                'clocktype', 'UTC', 'add_to_database', true, 'CheckExisting', false);
            docs = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(docs), 2, ...
                'CheckExisting=false should allow a second copy.');
        end

    end
end
