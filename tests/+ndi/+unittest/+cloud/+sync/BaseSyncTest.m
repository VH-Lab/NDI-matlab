classdef (Abstract) BaseSyncTest < matlab.unittest.TestCase
    %BaseSyncTest Base class for sync tests with common setup/teardown

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_SYNC_';
    end

    properties
        testDir
        localDataset
        cloudDatasetId
    end

    methods(TestMethodSetup)
        function createTestEnvironment(testCase)
            % Create a temporary local directory
            testCase.testDir = char(tempname);
            mkdir(testCase.testDir);

            % Create a unique remote dataset
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);
            [b, cloudDatasetId, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);
            testCase.fatalAssertTrue(b, "Failed to create remote dataset in TestMethodSetup.");
            testCase.cloudDatasetId = cloudDatasetId;

            % Create a local dataset
            testCase.localDataset = ndi.dataset.dir('dref', testCase.testDir);

            % Link the local and remote datasets
            remote_doc = ndi.cloud.internal.createRemoteDatasetDoc(testCase.cloudDatasetId, testCase.localDataset, 'replaceExisting', true);
            testCase.localDataset.database_add(remote_doc);

            % Queue teardown for both local and remote datasets
            testCase.addTeardown(@() testCase.deleteRemoteDataset());
            testCase.addTeardown(@() testCase.deleteLocalDirectory());
        end
    end

    methods (Access = private)
        function deleteRemoteDataset(testCase)
            if ~ismissing(testCase.cloudDatasetId)
                ndi.cloud.api.datasets.deleteDataset(testCase.cloudDatasetId);
            end
        end

        function deleteLocalDirectory(testCase)
            if exist(testCase.testDir, 'dir')
                rmdir(testCase.testDir, 's');
            end
        end
    end

    methods(Access = protected)
        function addDocument(testCase, name, value)
            if nargin < 3, value = ''; end
            doc = testCase.localDataset.newdocument('ndi_document_test', 'test.name', name, 'test.value', value);
            testCase.localDataset.database_add(doc);
        end
    end
end
