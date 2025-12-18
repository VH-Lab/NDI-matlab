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
        doSubmitTests = false;
    end

    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
        Narrative (1,:) string % Stores the narrative for each test
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

    methods (TestMethodSetup)
        % This now runs BEFORE EACH test method, creating a fresh dataset every time.
        function setupNewDataset(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);
            
            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);
            
            if ~b
                setup_narrative = "TestMethodSetup: Failed to create temporary dataset " + unique_name;
                msg = ndi.unittest.cloud.APIMessage(setup_narrative, b, cloudDatasetID, resp, url);
                testCase.fatalAssertTrue(b, "Failed to create dataset in TestMethodSetup. " + msg);
            end
            testCase.DatasetID = cloudDatasetID;
        end
    end

    methods (Access = private)
        % This is now a private helper method, not a teardown method.
        function deleteDatasetAfterTest(testCase)
            if ~ismissing(testCase.DatasetID)
                narrative = testCase.Narrative; % Make a local copy
                narrative(end+1) = "TEARDOWN: Deleting temporary dataset ID: " + testCase.DatasetID;
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID);
                if ~b
                    msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_del, resp_del, url_del);
                    % Use assert instead of verify in teardown to ensure it's noted
                    testCase.assertTrue(b, "Failed to delete dataset in TestMethodTeardown. " + msg);
                end
            end
        end
    end

    methods (Test)
        function testCreateDeleteDataset(testCase)
            % This test verifies the fundamental dataset lifecycle: creation and deletion.
            
            testCase.Narrative = "Begin DatasetsTest: testCreateDeleteDataset";
            narrative = testCase.Narrative;
            
            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;
            
            % --- 2. Delete the created dataset ---
            
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.deleteDataset with the new ID.";
            [b_delete, answer_delete, apiResponse_delete, apiURL_delete] = ndi.cloud.api.datasets.deleteDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_delete);
            
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            delete_message = ndi.unittest.cloud.APIMessage(narrative, b_delete, answer_delete, apiResponse_delete, apiURL_delete);
            testCase.verifyTrue(b_delete, delete_message);
            
            narrative(end+1) = "Dataset deleted successfully.";
            testCase.Narrative = narrative;
        end

        function testGetBranches(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies that we can retrieve the branches for a newly created dataset.
            testCase.Narrative = "Begin DatasetsTest: testGetBranches";
            narrative = testCase.Narrative;
            
            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;
            
            % --- 2. Get the branches for the new dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getBranches for the new dataset.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getBranches(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            % --- Build the message just before the assertion that uses it ---
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(b_get, get_message_success);
            
            % --- Build the next message just before the next assertion ---
            narrative(end+1) = "Testing: Verifying the returned answer is empty for a new dataset.";
            get_message_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(isempty(answer_get), get_message_content);
            
            narrative(end+1) = "getBranches test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testListDatasets(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies that we can list all datasets and find a newly created one.
            testCase.Narrative = "Begin DatasetsTest: testListDatasets";
            narrative = testCase.Narrative;
            
            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;
            
            % --- 2. List all datasets ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.listDatasets.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.listDatasets();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(b_get, get_message_success);
            
            narrative(end+1) = "Testing: Verifying the returned answer is a cell array.";
            get_message_type = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(iscell(answer_get), get_message_type);
            
            % --- 3. Verify the new dataset is in the list ---
            if ~isempty(answer_get)
                if ~isstruct(answer_get{1}) || ~isfield(answer_get{1}, 'id')
                    % Fallback safe check to avoid crash if structure is unexpected
                    narrative(end+1) = "FAILURE: List items are not structs with 'id'.";
                    get_message_badstruct = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
                    testCase.assertTrue(false, get_message_badstruct);
                end
                all_ids = cellfun(@(x) x.id, answer_get, 'UniformOutput', false);
            else
                all_ids = {};
            end
            
            narrative(end+1) = "Testing: Verifying the newly created dataset is in the list.";
            get_message_find = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(any(strcmp(all_ids, cloudDatasetID)), get_message_find);
            
            narrative(end+1) = "listDatasets test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testGetPublished(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies that we can successfully call the getPublished endpoint.
            testCase.Narrative = "Begin DatasetsTest: testGetPublished";
            narrative = testCase.Narrative;
            
            % --- 1. Call the getPublished API endpoint ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getPublished.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getPublished();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            % --- 2. Verify the call and the response structure ---
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(b_get, get_message_success);
            
            narrative(end+1) = "Testing: Verifying the returned answer is a struct (it may be empty if no datasets are published).";
            get_message_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(isstruct(answer_get), get_message_content);
            
            narrative(end+1) = "getPublished test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testGetUnpublished(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies that we can successfully call the getUnpublished endpoint.
            testCase.Narrative = "Begin DatasetsTest: testGetUnpublished";
            narrative = testCase.Narrative;
            
            % --- 1. Call the getUnpublished API endpoint ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getUnpublished.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getUnpublished();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            % --- 2. Verify the call and the response structure ---
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(b_get, get_message_success);
            
            narrative(end+1) = "Testing: Verifying the returned answer is a struct (it may be empty if no datasets are unpublished).";
            get_message_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.verifyTrue(isstruct(answer_get), get_message_content);
            
            narrative(end+1) = "getUnpublished test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testUpdateDataset(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies that a dataset's metadata can be updated.
            testCase.Narrative = "Begin DatasetsTest: testUpdateDataset";
            narrative = testCase.Narrative;
            
            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;
            
            % --- 2. Update the dataset's name ---
            newName = ['UPDATED_' char(java.util.UUID.randomUUID().toString())];
            updateStruct = struct('name', newName);
            
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.updateDataset with new name: " + newName;
            [b_update, answer_update, apiResponse_update, apiURL_update] = ndi.cloud.api.datasets.updateDataset(cloudDatasetID, updateStruct);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_update);
            
            narrative(end+1) = "Testing: Verifying the update API call was successful (APICallSuccessFlag should be true).";
            update_message = ndi.unittest.cloud.APIMessage(narrative, b_update, answer_update, apiResponse_update, apiURL_update);
            % Use assert so we stop if update fails
            testCase.assertTrue(b_update, update_message);
            
            % --- 3. Verify the change by re-fetching the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.getDataset to verify the update.";
            [b_get, answer_get, apiResponse_get, apiURL_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_get);
            
            narrative(end+1) = "Testing: Verifying the verification API call was successful (APICallSuccessFlag should be true).";
            get_message_success = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);
            testCase.assertTrue(b_get, get_message_success);
            
            narrative(end+1) = "Testing: Verifying the dataset name was updated correctly.";
            get_message_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, apiResponse_get, apiURL_get);

            % Robust check to prevent crash if field is missing
            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + get_message_content);
            testCase.assertTrue(isfield(answer_get, 'name'), "Response is missing 'name' field. " + get_message_content);

            testCase.verifyEqual(answer_get.name, newName, get_message_content);
            
            narrative(end+1) = "updateDataset test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testPublicationLifecycle(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies the full dataset publication workflow: submit -> publish -> unpublish.
            testCase.Narrative = "Begin DatasetsTest: testPublicationLifecycle";
            narrative = testCase.Narrative;
            
            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;
            
            if testCase.doSubmitTests
                % --- 2. Submit the dataset ---
                narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.submitDataset.";
                [b_submit, answer_submit, apiResponse_submit, apiURL_submit] = ndi.cloud.api.datasets.submitDataset(cloudDatasetID);
                narrative(end+1) = "Attempted to call API with URL " + string(apiURL_submit);
                
                narrative(end+1) = "Testing: Verifying the submit API call was successful (APICallSuccessFlag should be true).";
                submit_message = ndi.unittest.cloud.APIMessage(narrative, b_submit, answer_submit, apiResponse_submit, apiURL_submit);
                testCase.assertTrue(b_submit, submit_message);
                narrative(end+1) = "Dataset submitted successfully.";
    
                % --- 2.5 Verify submission status ---
                narrative(end+1) = "Preparing to get dataset info to verify submission status.";
                [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
                msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
                testCase.assertTrue(b_get, "Failed to get dataset to verify submission status. " + msg_get_content);

                narrative(end+1) = "Testing: Verifying the 'isSubmitted' flag is true.";
                % Regenerate message with updated narrative
                msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

                testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
                testCase.assertTrue(isfield(answer_get, 'isSubmitted'), "Response is missing 'isSubmitted' field. " + msg_get_content);

                testCase.verifyTrue(answer_get.isSubmitted, msg_get_content);
                narrative(end+1) = "Dataset 'isSubmitted' flag is correctly true.";
            end
            
            % --- 3. Publish the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.publishDataset.";
            [b_publish, answer_publish, apiResponse_publish, apiURL_publish] = ndi.cloud.api.datasets.publishDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_publish);
            
            narrative(end+1) = "Testing: Verifying the publish API call was successful (APICallSuccessFlag should be true).";
            publish_message = ndi.unittest.cloud.APIMessage(narrative, b_publish, answer_publish, apiResponse_publish, apiURL_publish);
            testCase.assertTrue(b_publish, publish_message);
            narrative(end+1) = "Dataset published successfully.";

            % --- 3.5 Verify publication status ---
            narrative(end+1) = "Preparing to get dataset info to verify publication status.";
            [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
            testCase.assertTrue(b_get, "Failed to get dataset to verify publication status. " + msg_get_content);

            narrative(end+1) = "Testing: Verifying the 'isPublished' flag is true.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
            testCase.assertTrue(isfield(answer_get, 'isPublished'), "Response is missing 'isPublished' field. " + msg_get_content);

            testCase.verifyTrue(answer_get.isPublished, msg_get_content);
            narrative(end+1) = "Dataset 'isPublished' flag is correctly true.";
            
            % --- 4. Unpublish the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.unpublishDataset.";
            [b_unpublish, answer_unpublish, apiResponse_unpublish, apiURL_unpublish] = ndi.cloud.api.datasets.unpublishDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_unpublish);
            
            narrative(end+1) = "Testing: Verifying the unpublish API call was successful (APICallSuccessFlag should be true).";
            unpublish_message = ndi.unittest.cloud.APIMessage(narrative, b_unpublish, answer_unpublish, apiResponse_unpublish, apiURL_unpublish);
            testCase.assertTrue(b_unpublish, unpublish_message);
            narrative(end+1) = "Dataset unpublished successfully.";

            % --- 4.5 Verify un-publication status ---
            narrative(end+1) = "Preparing to get dataset info to verify un-publication status.";
            [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
            testCase.assertTrue(b_get, "Failed to get dataset to verify un-publication status. " + msg_get_content);

            narrative(end+1) = "Testing: Verifying the 'isPublished' flag is false.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
            testCase.assertTrue(isfield(answer_get, 'isPublished'), "Response is missing 'isPublished' field. " + msg_get_content);

            testCase.verifyFalse(answer_get.isPublished, msg_get_content);
            narrative(end+1) = "Dataset 'isPublished' flag is correctly false.";

            if testCase.doSubmitTests
                % --- 5. Set isSubmitted to false ---
                narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.updateDataset to set isSubmitted to false.";
                updateStruct = struct('isSubmitted', false);
                [b_update, answer_update, apiResponse_update, apiURL_update] = ndi.cloud.api.datasets.updateDataset(cloudDatasetID, updateStruct);
                narrative(end+1) = "Attempted to call API with URL " + string(apiURL_update);
    
                narrative(end+1) = "Testing: Verifying the update API call was successful (APICallSuccessFlag should be true).";
                update_message = ndi.unittest.cloud.APIMessage(narrative, b_update, answer_update, apiResponse_update, apiURL_update);
                testCase.assertTrue(b_update, update_message);
                narrative(end+1) = "Dataset 'isSubmitted' flag set to false successfully.";
    
                % --- 5.5 Verify isSubmitted status ---
                narrative(end+1) = "Preparing to get dataset info to verify isSubmitted status is false.";
                [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
                msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
                testCase.assertTrue(b_get, "Failed to get dataset to verify isSubmitted status. " + msg_get_content);

                narrative(end+1) = "Testing: Verifying the 'isSubmitted' flag is false.";
                msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

                testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
                testCase.assertTrue(isfield(answer_get, 'isSubmitted'), "Response is missing 'isSubmitted' field. " + msg_get_content);

                testCase.verifyFalse(answer_get.isSubmitted, msg_get_content);
                narrative(end+1) = "Dataset 'isSubmitted' flag is correctly false.";
            end

            narrative(end+1) = "Publication lifecycle test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testPublicationLifecycleSubmitOnly(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies the dataset submission workflow.
            testCase.Narrative = "Begin DatasetsTest: testPublicationLifecycleSubmitOnly";
            narrative = testCase.Narrative;
            
            if ~testCase.doSubmitTests
                % do not run this test
                return;
            end

            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;

            % --- 2. Submit the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.submitDataset.";
            [b_submit, answer_submit, apiResponse_submit, apiURL_submit] = ndi.cloud.api.datasets.submitDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_submit);

            narrative(end+1) = "Testing: Verifying the submit API call was successful (APICallSuccessFlag should be true).";
            submit_message = ndi.unittest.cloud.APIMessage(narrative, b_submit, answer_submit, apiResponse_submit, apiURL_submit);
            testCase.assertTrue(b_submit, submit_message);
            narrative(end+1) = "Dataset submitted successfully.";

            % --- 2.5 Verify submission status ---
            narrative(end+1) = "Preparing to get dataset info to verify submission status.";
            [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
            testCase.assertTrue(b_get, "Failed to get dataset to verify submission status. " + msg_get_content);

            narrative(end+1) = "Testing: Verifying the 'isSubmitted' flag is true.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
            testCase.assertTrue(isfield(answer_get, 'isSubmitted'), "Response is missing 'isSubmitted' field. " + msg_get_content);

            testCase.verifyTrue(answer_get.isSubmitted, msg_get_content);
            narrative(end+1) = "Dataset 'isSubmitted' flag is correctly true.";

            % --- 5. Set isSubmitted to false ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.updateDataset to set isSubmitted to false.";
            updateStruct = struct('isSubmitted', false);
            [b_update, answer_update, apiResponse_update, apiURL_update] = ndi.cloud.api.datasets.updateDataset(cloudDatasetID, updateStruct);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_update);

            narrative(end+1) = "Testing: Verifying the update API call was successful (APICallSuccessFlag should be true).";
            update_message = ndi.unittest.cloud.APIMessage(narrative, b_update, answer_update, apiResponse_update, apiURL_update);
            testCase.assertTrue(b_update, update_message);
            narrative(end+1) = "Dataset 'isSubmitted' flag set to false successfully.";

            % --- 5.5 Verify isSubmitted status ---
            narrative(end+1) = "Preparing to get dataset info to verify isSubmitted status is false.";
            [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
            testCase.assertTrue(b_get, "Failed to get dataset to verify isSubmitted status. " + msg_get_content);

            narrative(end+1) = "Testing: Verifying the 'isSubmitted' flag is false.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
            testCase.assertTrue(isfield(answer_get, 'isSubmitted'), "Response is missing 'isSubmitted' field. " + msg_get_content);

            testCase.verifyFalse(answer_get.isSubmitted, msg_get_content);
            narrative(end+1) = "Dataset 'isSubmitted' flag is correctly false.";

            narrative(end+1) = "Submit-only lifecycle test completed successfully.";
            testCase.Narrative = narrative;
        end

        function testPublicationLifecyclePubOnly(testCase)
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
            % This test verifies the dataset publication workflow without submission.
            testCase.Narrative = "Begin DatasetsTest: testPublicationLifecyclePubOnly";
            narrative = testCase.Narrative;

            % --- 1. Use the dataset created in the TestMethodSetup ---
            cloudDatasetID = testCase.DatasetID;
            narrative(end+1) = "SETUP: Using temporary dataset with ID: " + cloudDatasetID;

            % --- 3. Publish the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.publishDataset.";
            [b_publish, answer_publish, apiResponse_publish, apiURL_publish] = ndi.cloud.api.datasets.publishDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_publish);

            narrative(end+1) = "Testing: Verifying the publish API call was successful (APICallSuccessFlag should be true).";
            publish_message = ndi.unittest.cloud.APIMessage(narrative, b_publish, answer_publish, apiResponse_publish, apiURL_publish);
            testCase.assertTrue(b_publish, publish_message);
            narrative(end+1) = "Dataset published successfully.";

            % --- 3.5 Verify publication status ---
            narrative(end+1) = "Preparing to get dataset info to verify publication status.";
            [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
            testCase.assertTrue(b_get, "Failed to get dataset to verify publication status. " + msg_get_content);

            narrative(end+1) = "Testing: Verifying the 'isPublished' flag is true.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
            testCase.assertTrue(isfield(answer_get, 'isPublished'), "Response is missing 'isPublished' field. " + msg_get_content);

            testCase.verifyTrue(answer_get.isPublished, msg_get_content);
            narrative(end+1) = "Dataset 'isPublished' flag is correctly true.";

            % --- 4. Unpublish the dataset ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.datasets.unpublishDataset.";
            [b_unpublish, answer_unpublish, apiResponse_unpublish, apiURL_unpublish] = ndi.cloud.api.datasets.unpublishDataset(cloudDatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_unpublish);

            narrative(end+1) = "Testing: Verifying the unpublish API call was successful (APICallSuccessFlag should be true).";
            unpublish_message = ndi.unittest.cloud.APIMessage(narrative, b_unpublish, answer_unpublish, apiResponse_unpublish, apiURL_unpublish);
            testCase.assertTrue(b_unpublish, unpublish_message);
            narrative(end+1) = "Dataset unpublished successfully.";

            % --- 4.5 Verify un-publication status ---
            narrative(end+1) = "Preparing to get dataset info to verify un-publication status.";
            [b_get, answer_get, resp_get, url_get] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);
            testCase.assertTrue(b_get, "Failed to get dataset to verify un-publication status. " + msg_get_content);

            narrative(end+1) = "Testing: Verifying the 'isPublished' flag is false.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, answer_get, resp_get, url_get);

            testCase.assertTrue(isstruct(answer_get), "Response must be a struct. " + msg_get_content);
            testCase.assertTrue(isfield(answer_get, 'isPublished'), "Response is missing 'isPublished' field. " + msg_get_content);

            testCase.verifyFalse(answer_get.isPublished, msg_get_content);
            narrative(end+1) = "Dataset 'isPublished' flag is correctly false.";

            narrative(end+1) = "Publish-only lifecycle test completed successfully.";
            testCase.Narrative = narrative;
        end
    end
end
