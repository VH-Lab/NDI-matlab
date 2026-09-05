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

            % Pin this class to prod for the duration of its run: the
            % reference dataset (CloudDatasetId) was published on prod, and
            % on dev its file records return 404 from getFileDetails, which
            % surfaces later as a DID "cannot be accessed" error deep in
            % readtimeseries. Save the previous value so we do not leak
            % 'prod' into any subsequent test class in the same session.
            previousEnv = getenv('CLOUD_API_ENVIRONMENT');

            % Teardown -- run in reverse order of registration, so the
            % order below matters:
            %   (1) restore CLOUD_API_ENVIRONMENT to whatever it was.
            %   (2) BEFORE that, log out the prod token this class cached.
            %       Without (2), the enclosing session is left with a prod
            %       token bound to a restored CLOUD_API_ENVIRONMENT=dev,
            %       and the very next dev-api request 403s with
            %       "Invalid or expired token". Registering the logout
            %       teardown after the env-restore teardown makes the
            %       logout run FIRST (LIFO), so the API call ndi.cloud.logout
            %       makes still goes to the prod endpoint the token was
            %       issued for, not the dev endpoint the caller is about
            %       to switch back to.
            testCase.addTeardown(@() setenv('CLOUD_API_ENVIRONMENT', previousEnv));
            testCase.addTeardown(@() safeLogout());
            setenv('CLOUD_API_ENVIRONMENT', 'prod');

            % Force a fresh login against prod. Without an explicit logout
            % first, authenticate('InteractionEnabled','off') reuses whatever
            % cached token is in scope, and if the previous test was running
            % against dev, that token is a DEV token -- prod rejects it with
            % "Invalid or expired token" on the very next request.
            safeLogout();
            ndi.cloud.authenticate('InteractionEnabled', 'off');

            function safeLogout()
                try
                    ndi.cloud.logout();
                catch
                    % No prior session, network flake in teardown, etc.
                    % Not this test's job to fail on that.
                end
            end

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
