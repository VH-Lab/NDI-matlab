classdef readIngested < matlab.unittest.TestCase
% readIngested - Test reading an ingested dataset from the cloud
%
%   This test downloads a known dataset from the cloud, opens a session,
%   and verifies that probes can be read with expected values.
%

    properties
        TargetDir
        Dataset
        Session
    end

    properties (Constant)
        CloudDatasetId = '668b0539f13096e04f1feccd';
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = 'Missing NDI Cloud credentials. Skipping cloud-dependent tests.';
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function downloadDataset(testCase)
            testCase.TargetDir = tempdir;

            % Remove any leftover dataset folder from a previous run
            datasetFolder = fullfile(testCase.TargetDir, testCase.CloudDatasetId);
            if isfolder(datasetFolder)
                rmdir(datasetFolder, 's');
            end

            testCase.addTeardown(@() testCase.cleanupTargetDir());

            % Re-authenticate in case token expired during a long test suite
            ndi.cloud.authenticate('InteractionEnabled', 'off');

            testCase.Dataset = ndi.cloud.downloadDataset(testCase.CloudDatasetId, testCase.TargetDir);

            [~, sess_ids] = testCase.Dataset.session_list();
            testCase.fatalAssertNumElements(sess_ids, 1, ...
                'Expected exactly one session in the dataset.');

            testCase.Session = testCase.Dataset.open_session(sess_ids{1});
        end
    end

    methods (Access = private)
        function cleanupTargetDir(testCase)
            if ~isempty(testCase.TargetDir) && isfolder(testCase.TargetDir)
                % TargetDir is tempdir, so do not delete it entirely;
                % the downloaded dataset folder will be cleaned up by the OS.
            end
        end
    end

    methods (Test)
        function testReadCarbonFiberProbe(testCase)
            p_cf = testCase.Session.getprobes('name', 'carbonfiber', 'reference', 1);
            testCase.fatalAssertNumElements(p_cf, 1, ...
                'Expected exactly one carbonfiber probe with reference 1.');

            [d1, t1] = p_cf{1}.readtimeseries(1, 10, 20);

            expected_d1 = [ ...
                55.7700; 253.3050; -43.2900; -9.5550; 30.6150; ...
                23.4000; 16.1850; -51.6750; -1.7550; -14.6250; ...
                -32.7600; 45.6300; -7.2150; 0.9750; -1.7550; 45.0450];

            testCase.verifyEqual(d1(1,:)', expected_d1, 'AbsTol', 0.001, ...
                'First row of carbonfiber timeseries data does not match expected values.');

            testCase.verifyEqual(t1(1), 10.0000, 'AbsTol', 0.001, ...
                'First time value should be 10.');
        end

        function testReadStimulatorProbe(testCase)
            p_st = testCase.Session.getprobes('type', 'stimulator');
            testCase.fatalAssertNotEmpty(p_st, ...
                'Expected at least one stimulator probe.');

            [ds, ts, ~] = p_st{1}.readtimeseries(1, 10, 20);

            testCase.verifyEqual(ds.stimid, 31, ...
                'Stimulus ID should be 31.');

            testCase.verifyEqual(ts.stimon, 15.2590, 'AbsTol', 0.001, ...
                'Stimulus onset time should be 15.2590.');
        end
    end
end
