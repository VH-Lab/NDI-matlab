classdef emptyDataset < matlab.unittest.TestCase

    properties
        testDir
        cloudDatasetId
    end

    methods(TestMethodSetup)
        function createTestEnvironment(testCase)
            testCase.testDir = char(tempname);
            if ~isfolder(testCase.testDir)
                 mkdir(testCase.testDir);
            end
        end
    end

    methods(TestMethodTeardown)
        function cleanup(testCase)
            if ~isempty(testCase.cloudDatasetId)
                 try
                     ndi.cloud.api.datasets.deleteDataset(testCase.cloudDatasetId);
                 catch ME
                     warning(['Failed to delete remote dataset: ' ME.message]);
                 end
            end
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods(Test)
        function testEmptyUpload(testCase)
            ndiDataset = ndi.dataset.dir(testCase.testDir);

            [success, cloudId, msg] = ndi.cloud.uploadDataset(ndiDataset, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName', 'emptyTest');

            testCase.verifyTrue(success, ['Upload failed with message: ' msg]);
            testCase.verifyNotEmpty(cloudId);

            testCase.cloudDatasetId = cloudId;
        end
    end
end
