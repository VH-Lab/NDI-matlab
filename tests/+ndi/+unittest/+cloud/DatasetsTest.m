classdef DatasetsTest < matlab.unittest.TestCase
% DatasetsTest - Test suite for the ndi.cloud.api.datasets namespace
%
%   This test class verifies the functionality of the dataset-related API
%   endpoints, ensuring they behave as expected. It follows a narrative-driven
%   approach to provide clear, actionable feedback for both MATLAB and API developers.
%
    properties (Constant)
        % A unique prefix for test datasets to easily identify them.
        DatasetNamePrefix = 'NDI_UNITTEST_DATASET_';
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            % This fatal assertion runs once before any tests in this class.
            % It ensures that the necessary credentials are set as environment variables,
            % preventing the test suite from running if the basic configuration is missing.
            %
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set. This is not an API problem.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set. This is not an API problem.');
        end
    end

    methods (Test)
        function testCreateDeleteDataset(testCase)
            % This test verifies the fundamental dataset lifecycle: creation and deletion.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testCreateDeleteDataset";

            % --- 1. Create a new dataset ---
            
            % Generate a unique name for the dataset to prevent collisions.
            uniqueName = [testCase.DatasetNamePrefix char(java.util.UUID.randomUUID().toString())];
            datasetInfoStruct = struct('name', uniqueName);
            
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.createDataset with name: " + uniqueName;
            [b_create, answer_create, apiResponse_create, apiURL_create] = ndi.cloud.api.datasets.createDataset(datasetInfoStruct);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_create);
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";

            create_message = ndi.unittest.cloud.APIMessage(b_create, answer_create, apiResponse_create, apiURL_create, narrative);
            testCase.verifyTrue(b_create, create_message);

            cloudDatasetID = answer_create;
            % Add a teardown action to ensure this dataset is deleted even if subsequent assertions fail.
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID));

            narrative(end+1) = "Dataset created successfully with ID: " + cloudDatasetID;

            % --- 2. Delete the created dataset ---
            
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.deleteDataset with the new ID.";
            [b_delete, answer_delete, apiResponse_delete, apiURL_delete] = ndi.cloud.api.datasets.deleteDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_delete);
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";

            delete_message = ndi.unittest.cloud.APIMessage(b_delete, answer_delete, apiResponse_delete, apiURL_delete, narrative);
            testCase.verifyTrue(b_delete, delete_message);
            
            narrative(end+1) = "Dataset deleted successfully.";
        end

        function testGetBranches(testCase)
            % This test verifies that we can retrieve the branches for a newly created dataset.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testGetBranches";

            % --- 1. Create a new dataset to test against ---
            uniqueName = [testCase.DatasetNamePrefix char(java.util.UUID.randomUUID().toString())];
            datasetInfoStruct = struct('name', uniqueName);
            
            narrative(end+1) = "SETUP: Creating a temporary dataset named " + uniqueName;
            [b_create, answer_create, ~, ~] = ndi.cloud.api.datasets.createDataset(datasetInfoStruct);
            testCase.verifyTrue(b_create, "SETUP FAILED: Could not create a temporary dataset for the test.");
            
            cloudDatasetID = answer_create;
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID));
            narrative(end+1) = "SETUP: Dataset created successfully with ID: " + cloudDatasetID;

            % --- 2. Get the branches for the new dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getBranches for the new dataset.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getBranches(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            % --- Build the message just before the assertion that uses it ---
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(b_get, get_message_success);

            % --- Build the next message just before the next assertion ---
            narrative(end+1) = "Testing: Verifying the returned answer is empty for a new dataset.";
            get_message_content = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(isempty(answer_get), get_message_content);

            narrative(end+1) = "getBranches test completed successfully.";
        end

        function testListDatasets(testCase)
            % This test verifies that we can list all datasets and find a newly created one.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testListDatasets";

            % --- 1. Create a new dataset to ensure the list is not empty ---
            uniqueName = [testCase.DatasetNamePrefix char(java.util.UUID.randomUUID().toString())];
            datasetInfoStruct = struct('name', uniqueName);
            
            narrative(end+1) = "SETUP: Creating a temporary dataset named " + uniqueName;
            [b_create, cloudDatasetID, ~, ~] = ndi.cloud.api.datasets.createDataset(datasetInfoStruct);
            testCase.verifyTrue(b_create, "SETUP FAILED: Could not create a temporary dataset for the test.");
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID));
            narrative(end+1) = "SETUP: Dataset created successfully with ID: " + cloudDatasetID;

            % --- 2. List all datasets ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.listDatasets.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.listDatasets();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(b_get, get_message_success);

            narrative(end+1) = "Testing: Verifying the returned answer is a cell array.";
            get_message_type = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(iscell(answer_get), get_message_type);

            % --- 3. Verify the new dataset is in the list ---
            if ~isempty(answer_get)
                all_ids = cellfun(@(x) x.id, answer_get, 'UniformOutput', false);
            else
                all_ids = {};
            end
            narrative(end+1) = "Testing: Verifying the newly created dataset is in the list.";
            get_message_find = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(any(strcmp(all_ids, cloudDatasetID)), get_message_find);

            narrative(end+1) = "listDatasets test completed successfully.";
        end

        function testGetPublished(testCase)
            % This test verifies that we can successfully call the getPublished endpoint.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testGetPublished";

            % --- 1. Call the getPublished API endpoint ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getPublished.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getPublished();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            % --- 2. Verify the call and the response structure ---
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(b_get, get_message_success);

            narrative(end+1) = "Testing: Verifying the returned answer is a struct (it may be empty if no datasets are published).";
            get_message_content = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(isstruct(answer_get), get_message_content);

            narrative(end+1) = "getPublished test completed successfully.";
        end

        function testGetUnpublished(testCase)
            % This test verifies that we can successfully call the getUnpublished endpoint.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testGetUnpublished";

            % --- 1. Call the getUnpublished API endpoint ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getUnpublished.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getUnpublished();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            % --- 2. Verify the call and the response structure ---
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(b_get, get_message_success);

            narrative(end+1) = "Testing: Verifying the returned answer is a struct (it may be empty if no datasets are unpublished).";
            get_message_content = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(isstruct(answer_get), get_message_content);

            narrative(end+1) = "getUnpublished test completed successfully.";
        end

        function testUpdateDataset(testCase)
            % This test verifies that a dataset's metadata can be updated.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testUpdateDataset";

            % --- 1. Create a new dataset to test against ---
            uniqueName = [testCase.DatasetNamePrefix char(java.util.UUID.randomUUID().toString())];
            datasetInfoStruct = struct('name', uniqueName);
            
            narrative(end+1) = "SETUP: Creating a temporary dataset named " + uniqueName;
            [b_create, cloudDatasetID, ~, ~] = ndi.cloud.api.datasets.createDataset(datasetInfoStruct);
            testCase.verifyTrue(b_create, "SETUP FAILED: Could not create a temporary dataset for the test.");
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID));
            narrative(end+1) = "SETUP: Dataset created successfully with ID: " + cloudDatasetID;

            % --- 2. Update the dataset's name ---
            newName = ['UPDATED_' uniqueName];
            updateStruct = struct('name', newName);
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.updateDataset with new name: " + newName;
            [b_update, answer_update, apiResponse_update, apiURL_update] = ndi.cloud.api.datasets.updateDataset(cloudDatasetID, updateStruct);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_update);

            narrative(end+1) = "Testing: Verifying the update API call was successful (APICallSuccessFlag should be true).";
            update_message = ndi.unittest.cloud.APIMessage(b_update, answer_update, apiResponse_update, apiURL_update, narrative);
            testCase.verifyTrue(b_update, update_message);

            % --- 3. Verify the change by re-fetching the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getDataset to verify the update.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            narrative(end+1) = "Testing: Verifying the verification API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyTrue(b_get, get_message_success);
            
            narrative(end+1) = "Testing: Verifying the dataset name was updated correctly.";
            get_message_content = ndi.unittest.cloud.APIMessage(b_get, answer_get, apiResponse_get, apiURL_get, narrative);
            testCase.verifyEqual(answer_get.name, newName, get_message_content);

            narrative(end+1) = "updateDataset test completed successfully.";
        end

        function testPublicationLifecycle(testCase)
            % This test verifies the full dataset publication workflow: submit -> publish -> unpublish.
            
            narrative = strings(0,1);
            narrative(end+1) = "Begin DatasetsTest: testPublicationLifecycle";

            % --- 1. Create a new dataset ---
            uniqueName = [testCase.DatasetNamePrefix char(java.util.UUID.randomUUID().toString())];
            datasetInfoStruct = struct('name', uniqueName);
            
            narrative(end+1) = "SETUP: Creating a temporary dataset named " + uniqueName;
            [b_create, cloudDatasetID, ~, ~] = ndi.cloud.api.datasets.createDataset(datasetInfoStruct);
            testCase.verifyTrue(b_create, "SETUP FAILED: Could not create a temporary dataset for the test.");
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID));
            narrative(end+1) = "SETUP: Dataset created successfully with ID: " + cloudDatasetID;

            % --- 2. Submit the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.submitDataset.";
            [b_submit, answer_submit, apiResponse_submit, apiURL_submit] = ndi.cloud.api.datasets.submitDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_submit);
            
            narrative(end+1) = "Testing: Verifying the submit API call was successful (APICallSuccessFlag should be true).";
            submit_message = ndi.unittest.cloud.APIMessage(b_submit, answer_submit, apiResponse_submit, apiURL_submit, narrative);
            testCase.verifyTrue(b_submit, submit_message);
            narrative(end+1) = "Dataset submitted successfully.";

            % --- 3. Publish the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.publishDataset.";
            [b_publish, answer_publish, apiResponse_publish, apiURL_publish] = ndi.cloud.api.datasets.publishDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_publish);

            narrative(end+1) = "Testing: Verifying the publish API call was successful (APICallSuccessFlag should be true).";
            publish_message = ndi.unittest.cloud.APIMessage(b_publish, answer_publish, apiResponse_publish, apiURL_publish, narrative);
            testCase.verifyTrue(b_publish, publish_message);
            narrative(end+1) = "Dataset published successfully.";

            % --- 4. Unpublish the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.unpublishDataset.";
            [b_unpublish, answer_unpublish, apiResponse_unpublish, apiURL_unpublish] = ndi.cloud.api.datasets.unpublishDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_unpublish);

            narrative(end+1) = "Testing: Verifying the unpublish API call was successful (APICallSuccessFlag should be true).";
            unpublish_message = ndi.unittest.cloud.APIMessage(b_unpublish, answer_unpublish, apiResponse_unpublish, apiURL_unpublish, narrative);
            testCase.verifyTrue(b_unpublish, unpublish_message);
            narrative(end+1) = "Dataset unpublished successfully.";
            
            narrative(end+1) = "Publication lifecycle test completed successfully.";
        end
    end
end

