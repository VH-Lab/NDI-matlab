classdef ensembleAllNTrodeTest < matlab.unittest.TestCase
    % ENSEMBLEALLNTRODETEST - Tests for ndi.fun.ensemble.allNTrode / allNTrodes
    %
    % Builds an n-trode (ndi.element.timeseries) with one UTC epoch and several
    % spiking neurons built on it, then checks that ndi.fun.ensemble.allNTrode
    % creates an ensemble document for the epoch and honors the IfExists option
    % (skip / error / replace). Also checks that allNTrodes runs over a session's
    % n-trode probes. Like ensembleExtractTest, these exercise the extraction
    % path (readtimeseries), so they depend on the session's time handling.

    properties
        Session
        TempDir
        Probe
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            S = ndi.session.dir('ensemble_allntrode_test', testCase.TempDir);

            subject = ndi.subject('subject1@test', 'test subject');
            subdoc = subject.newdocument();
            S.database_add(subdoc);
            subjectId = subdoc.id();

            utc = ndi.time.clocktype('UTC');
            probe = ndi.element.timeseries(S, 'ctx_probe', 1, 'n-trode', [], 0, subjectId);
            probe = probe.addepoch('epoch_1', utc, [0 100], [], []);

            spikes = { [10 50 90], [20 60], [30 70 95] };
            for i = 1:numel(spikes)
                e = ndi.element.timeseries(S, sprintf('neuron_%d', i), i, 'spikes', ...
                    probe, 0, subjectId);
                t = spikes{i}(:);
                e = e.addepoch('epoch_1', utc, [0 100], t, ones(size(t))); %#ok<NASGU>
            end

            testCase.Probe = probe;
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

        function testCreatesEnsemblePerEpoch(testCase)
            S = testCase.Session;
            docs = ndi.fun.ensemble.allNTrode(S, testCase.Probe);
            testCase.verifyEqual(numel(docs), 1, 'One ensemble for the single epoch.');
            all = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(all), 1);
            testCase.verifyEqual(all{1}.dependency_value('element_id'), testCase.Probe.id());
            testCase.verifyEqual(all{1}.document_properties.epochid.epochid, 'epoch_1');
        end

        function testSkip(testCase)
            S = testCase.Session;
            ndi.fun.ensemble.allNTrode(S, testCase.Probe);
            docs2 = ndi.fun.ensemble.allNTrode(S, testCase.Probe); % default 'skip'
            testCase.verifyEmpty(docs2, 'A second run should create nothing (skip).');
            all = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(all), 1, 'Still only one ensemble after skip.');
        end

        function testError(testCase)
            S = testCase.Session;
            ndi.fun.ensemble.allNTrode(S, testCase.Probe);
            testCase.verifyError(@() ndi.fun.ensemble.allNTrode(S, testCase.Probe, ...
                'IfExists', 'error'), 'ndi:ensemble:allNTrode:exists');
        end

        function testReplace(testCase)
            S = testCase.Session;
            d1 = ndi.fun.ensemble.allNTrode(S, testCase.Probe);
            firstId = d1{1}.id();
            d2 = ndi.fun.ensemble.allNTrode(S, testCase.Probe, 'IfExists', 'replace');
            testCase.verifyEqual(numel(d2), 1, 'Replace should create a new ensemble.');
            all = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(all), 1, 'Still only one ensemble after replace.');
            testCase.verifyNotEqual(all{1}.id(), firstId, ...
                'The existing document should have been replaced by a new one.');
        end

        function testAllNTrodesRuns(testCase)
            % The probe here is not registered through a daq system, so getprobes
            % returns no n-trodes; allNTrodes should simply return empty.
            S = testCase.Session;
            docs = ndi.fun.ensemble.allNTrodes(S);
            testCase.verifyEmpty(docs, 'With no getprobes n-trodes, the result is empty.');
        end

    end
end
