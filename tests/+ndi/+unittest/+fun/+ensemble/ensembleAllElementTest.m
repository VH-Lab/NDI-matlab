classdef ensembleAllElementTest < matlab.unittest.TestCase
    % ENSEMBLEALLELEMENTTEST - Tests for ndi.fun.ensemble.allElement / allNTrodes
    %
    % Builds a probe (n-trode) with one UTC epoch and spiking neurons built on it,
    % then checks that ndi.fun.ensemble.allElement builds an ndi.element.ensemble
    % with an ensemble for the epoch and honors IfExists (skip / error / replace),
    % and that allNTrodes runs. Like ensembleElementTest, these exercise the
    % extraction path (readtimeseries).

    properties
        Session
        TempDir
        Probe
    end

    methods (TestMethodSetup)
        function setupSession(testCase)
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            S = ndi.session.dir('ensemble_allelement_test', testCase.TempDir);

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

        function testBuildsEnsembleElement(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.allElement(S, testCase.Probe);
            testCase.verifyClass(ens, 'ndi.element.ensemble');
            docs = ndi.fun.ensemble.findExisting(S, ens, 'epochid', 'epoch_1');
            testCase.verifyEqual(numel(docs), 1, 'One ensemble map doc for the epoch.');
        end

        function testSkip(testCase)
            S = testCase.Session;
            ndi.fun.ensemble.allElement(S, testCase.Probe);
            ndi.fun.ensemble.allElement(S, testCase.Probe); % default 'skip'
            all = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(all), 1, 'Skip should not duplicate the ensemble.');
        end

        function testError(testCase)
            S = testCase.Session;
            ndi.fun.ensemble.allElement(S, testCase.Probe);
            testCase.verifyError(@() ndi.fun.ensemble.allElement(S, testCase.Probe, ...
                'IfExists', 'error'), 'ndi:ensemble:allElement:exists');
        end

        function testReplace(testCase)
            S = testCase.Session;
            ens = ndi.fun.ensemble.allElement(S, testCase.Probe);
            d1 = ndi.fun.ensemble.findExisting(S, ens, 'epochid', 'epoch_1');
            firstId = d1{1}.id();

            ndi.fun.ensemble.allElement(S, testCase.Probe, 'IfExists', 'replace');
            d2 = ndi.fun.ensemble.findExisting(S, ens, 'epochid', 'epoch_1');
            testCase.verifyEqual(numel(d2), 1, 'Still exactly one ensemble after replace.');
            testCase.verifyNotEqual(d2{1}.id(), firstId, ...
                'Replace should produce a new map document.');

            all = S.database_search(ndi.query('','isa','ensemble',''));
            testCase.verifyEqual(numel(all), 1, 'No leftover ensemble documents.');
        end

        function testAllNTrodesRuns(testCase)
            % The probe is not registered through a daq system, so getprobes
            % returns no n-trodes; allNTrodes should return empty.
            S = testCase.Session;
            ens = ndi.fun.ensemble.allNTrodes(S);
            testCase.verifyEmpty(ens, 'With no getprobes n-trodes, the result is empty.');
        end

    end
end
