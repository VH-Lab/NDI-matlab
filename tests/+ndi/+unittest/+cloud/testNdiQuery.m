classdef testNdiQuery < matlab.unittest.TestCase
    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_DATASET_NDIQUERY_';
    end
    properties
        Dataset
        Session
        DatasetID (1,1) string = missing
        Narrative (1,:) string
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, 'NDI_CLOUD_USERNAME not set.');
            testCase.fatalAssertNotEmpty(password, 'NDI_CLOUD_PASSWORD not set.');
        end
    end

    methods (TestMethodSetup)
        function setupDataset(testCase)
            % 1. Create local dataset and session using buildDataset
            [testCase.Dataset, testCase.Session] = ndi.unittest.dataset.buildDataset.sessionWithIngestedDocsAndFiles();

            % 2. Create remote dataset
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);
            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);

            if ~b
                setup_narrative = "TestMethodSetup: Failed to create temporary dataset " + unique_name;
                msg = ndi.unittest.cloud.APIMessage(setup_narrative, b, cloudDatasetID, resp, url);
                testCase.fatalAssertTrue(b, "Failed to create dataset in TestMethodSetup. " + msg);
            end
            testCase.DatasetID = cloudDatasetID;

            % 3. Upload the local dataset to the remote dataset
            % We need to link them first or use uploadDataset with options.
            % uploadDataset takes the local dataset and sync options.
            % We need to tell it to upload to THIS remote dataset.
            % ndi.cloud.uploadDataset checks for existing link.

            % Link manually
            remoteDatasetDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudDatasetID, testCase.Dataset);
            testCase.Dataset.database_add(remoteDatasetDoc);

            % Upload
            % Create sync options
            syncOpts = ndi.cloud.sync.SyncOptions();
            % Upload
            [b_up, id_up, msg_up] = ndi.cloud.uploadDataset(testCase.Dataset, syncOpts);
            testCase.fatalAssertTrue(b_up, "Failed to upload dataset: " + msg_up);

            testCase.addTeardown(@() testCase.teardownDataset());
        end
    end

    methods (Access = private)
        function teardownDataset(testCase)
            % Clean up local
             if ~isempty(testCase.Dataset)
                 path = testCase.Dataset.path;
                 if isfolder(path)
                     rmdir(path, 's');
                 end
             end
             if ~isempty(testCase.Session)
                 path = testCase.Session.path;
                 if isfolder(path)
                     rmdir(path, 's');
                 end
             end

             % Clean up remote
            if ~ismissing(testCase.DatasetID)
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID);
                if ~b
                    warning("Failed to delete dataset " + testCase.DatasetID);
                end
            end
        end
    end

    methods (Test)
        function testSearchByBaseId(testCase)
            testCase.Narrative = "Begin testSearchByBaseId";
            narrative = testCase.Narrative;

            % 1. Get documents from local dataset to know what to search for
            docs = testCase.Dataset.database_search(ndi.query.all());
            testCase.assertGreaterThan(numel(docs), 0, "No documents in local dataset to test with.");

            % Pick a document (e.g. the first one)
            target_doc = docs{1};
            target_id = target_doc.document_properties.base.id;

            narrative(end+1) = "Target Document ID: " + target_id;

            % 2. Construct ndiquery
            % Search for base.id exact_string
            q = ndi.query('base.id', 'exact_string', target_id);

            % 3. Execute ndiquery
            narrative(end+1) = "Executing ndiquery for base.id";
            [b, answer, resp, url] = ndi.cloud.api.documents.ndiquery('private', q);

            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyTrue(b, "ndiquery failed. " + msg);

            % 4. Verify results
            narrative(end+1) = "Verifying results.";
            % We expect at least one result (the doc itself).
            % Note: ndiquery searches ALL datasets accessible to the user if scope is private/all?
            % The swagger says "scope of the search".
            % If we search by unique ID, we should find it.

            found = false;

            testCase.verifyTrue(isstruct(answer), "Answer should be a struct.");
            testCase.verifyTrue(isfield(answer, 'documents'), "Answer should have a documents field.");

            docs_result = answer.documents;

            for i = 1:numel(docs_result)
                if strcmp(docs_result(i).ndiId, target_id)
                    found = true;
                    break;
                end
            end

            testCase.verifyTrue(found, "Target document not found in search results.");

            testCase.Narrative = narrative;
        end

        function testSearchByNonExistentId(testCase)
             q = ndi.query('base.id', 'exact_string', 'non_existent_id_12345');
             [b, answer, resp, url] = ndi.cloud.api.documents.ndiquery('private', q);
             testCase.verifyTrue(b, "ndiquery failed for non-existent ID.");

             testCase.verifyTrue(isstruct(answer), "Answer should be a struct.");
             testCase.verifyTrue(isfield(answer, 'documents'), "Answer should have a documents field.");

             docs_result = answer.documents;

             % Expect empty result? Or just not the id.
             if ~isempty(docs_result)
                 found = false;
                 for i = 1:numel(docs_result)
                    if strcmp(docs_result(i).ndiId, 'non_existent_id_12345')
                        found = true;
                        break;
                    end
                 end
                 testCase.verifyFalse(found, "Found non-existent ID!");
             else
                 testCase.verifyEmpty(docs_result, "Documents list should be empty for non-existent ID");
             end
        end
    end
end
