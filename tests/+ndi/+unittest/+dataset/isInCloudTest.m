classdef isInCloudTest < matlab.unittest.TestCase
% isInCloudTest - Offline tests for ndi.dataset/isInCloud.
%
%   Verifies that a dataset reports itself "in the cloud" exactly when its
%   database holds a 'dataset_remote' document. Runs fully offline: it builds
%   a local ndi.dataset.dir in a temp folder and adds the linking document
%   directly, with no NDI Cloud network access.

    properties
        testDir
    end

    methods (TestMethodSetup)
        function createTestEnvironment(testCase)
            testCase.testDir = char(tempname);
            if ~isfolder(testCase.testDir)
                mkdir(testCase.testDir);
            end
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            if ~isempty(testCase.testDir) && isfolder(testCase.testDir)
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods (Test)
        function testFreshDatasetNotInCloud(testCase)
            ds = ndi.dataset.dir('notCloudYet', testCase.testDir);
            [b, cloudId] = ds.isInCloud();
            testCase.verifyFalse(b, ...
                'A dataset with no dataset_remote document is not in the cloud.');
            testCase.verifyEqual(cloudId, '');
        end

        function testDatasetWithRemoteDocIsInCloud(testCase)
            ds = ndi.dataset.dir('cloudLinked', testCase.testDir);

            % Add a dataset_remote document by hand (this is what an upload
            % would create), then confirm the dataset reports it is in the cloud.
            remoteId = 'test-cloud-dataset-id-12345';
            doc = ndi.document('dataset_remote', ...
                'base.session_id', ds.id, ...
                'dataset_remote', struct( ...
                    'dataset_id', remoteId, ...
                    'organization_id', 'test-org-id'));
            ds.database_add(doc);

            [b, cloudId] = ds.isInCloud();
            testCase.verifyTrue(b, ...
                'A dataset with a dataset_remote document is in the cloud.');
            testCase.verifyEqual(cloudId, remoteId);
            testCase.verifyClass(cloudId, 'char');
        end
    end
end
