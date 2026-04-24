classdef testNdiQuery < matlab.unittest.TestCase
    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_DATASET_NDIQUERY_';
        % A published dataset ID accessible to all users on the NDI cloud.
        % Used by the dataset-scoped ndiquery test.
        cloudDatasetId = '668b0539f13096e04f1feccd';
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

            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b_up, testCase.DatasetID, msg_up] = ndi.cloud.uploadDataset(testCase.Dataset, 'skipMetadataEditorMetadata',true,...
                'remoteDatasetName',unique_name);
            testCase.fatalAssertTrue(b_up, "Failed to upload dataset: " + msg_up);

            testCase.addTeardown(@() testCase.teardownDataset());

            % Allow the cloud's background bulk-document ingest worker to
            % finish indexing the just-uploaded docs before the first query.
            pause(5);

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
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
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
                    % Verify datasetId presence
                    if isfield(docs_result(i), 'datasetId')
                        testCase.verifyNotEmpty(docs_result(i).datasetId, "datasetId is empty for found document.");
                    else
                        % Should be a field
                        testCase.verifyTrue(isfield(docs_result(i), 'datasetId'), "datasetId field missing from document summary.");
                    end
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

        function testQueryAll(testCase)
            testCase.Narrative = "Begin testQueryAll";
            narrative = testCase.Narrative;

            % 1. Create multiple documents to test pagination
            numDocs = 5;
            narrative(end+1) = "Creating " + numDocs + " documents for pagination test.";
            prefix = "queryall_test_" + string(did.ido.unique_id());

            for i = 1:numDocs
                doc_to_add = ndi.document('base', 'base.name', prefix + "_" + i);
                json_doc = jsonencodenan(doc_to_add.document_properties);
                [b_add, ~, ~, ~] = ndi.cloud.api.documents.addDocument(testCase.DatasetID, json_doc);
                testCase.fatalAssertTrue(b_add, "Failed to add document " + i);
            end

            % 2. Construct ndiqueryAll
            % Search for documents containing the prefix
            q = ndi.query('base.name', 'contains_string', prefix);

            % 3. Execute ndiqueryAll with small pageSize to force pagination
            pageSize = 2;
            narrative(end+1) = "Executing ndiqueryAll with pageSize=" + pageSize;
            [b, answer, resp, url] = ndi.cloud.api.documents.ndiqueryAll('private', q, 'pageSize', pageSize);

            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyTrue(b, "ndiqueryAll failed. " + msg);

            % 4. Verify results
            narrative(end+1) = "Verifying results.";
            testCase.verifyEqual(numel(answer), numDocs, "Did not retrieve all documents.");

            % Verify names
            found_count = 0;
            for i = 1:numel(answer)
                name = answer(i).name;
                if contains(name, prefix)
                    found_count = found_count + 1;
                end
            end
            testCase.verifyEqual(found_count, numDocs, "Retrieved documents do not match criteria.");

            testCase.Narrative = narrative;
        end

        function testSearchByDatasetIdScope(testCase)
            % Verify that the new scope form accepts a comma-separated list
            % of dataset ObjectIds and restricts results to those datasets.
            testCase.Narrative = "Begin testSearchByDatasetIdScope";
            narrative = testCase.Narrative;

            cloudDatasetId = testCase.cloudDatasetId;
            narrative(end+1) = "Using cloudDatasetId: " + cloudDatasetId;

            % A broad query — we only care that results come back scoped to
            % the requested dataset, not what they match.
            q = ndi.query('base.id', 'hasfield', '');

            % 1. Single-ID scope — results must be from cloudDatasetId only.
            narrative(end+1) = "Executing ndiquery with single-ID scope.";
            [b, answer, resp, url] = ndi.cloud.api.documents.ndiquery(cloudDatasetId, q);

            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, resp, url);
            testCase.verifyTrue(b, "ndiquery with dataset-ID scope failed. " + msg);

            testCase.verifyTrue(isstruct(answer), "Answer should be a struct.");
            testCase.verifyTrue(isfield(answer, 'documents'), "Answer should have a documents field.");

            docs_result = answer.documents;
            for i = 1:numel(docs_result)
                if isfield(docs_result(i), 'datasetId') && ~isempty(docs_result(i).datasetId)
                    testCase.verifyEqual(string(docs_result(i).datasetId), string(cloudDatasetId), ...
                        "Returned document is not from the scoped dataset.");
                end
            end

            % 2. CSV of two IDs (the accessible one plus a well-formed but
            % unknown-to-us one) — must also succeed and still restrict to
            % the accessible dataset. The server silently drops IDs the
            % caller cannot access.
            bogusButValidId = '000000000000000000000000';
            csvScope = cloudDatasetId + "," + bogusButValidId;
            narrative(end+1) = "Executing ndiquery with CSV-of-IDs scope: " + csvScope;
            [b2, answer2, resp2, url2] = ndi.cloud.api.documents.ndiquery(csvScope, q);

            msg2 = ndi.unittest.cloud.APIMessage(narrative, b2, answer2, resp2, url2);
            testCase.verifyTrue(b2, "ndiquery with CSV-of-IDs scope failed. " + msg2);
            testCase.verifyTrue(isfield(answer2, 'documents'), "Answer should have a documents field.");

            docs_result2 = answer2.documents;
            for i = 1:numel(docs_result2)
                if isfield(docs_result2(i), 'datasetId') && ~isempty(docs_result2(i).datasetId)
                    testCase.verifyEqual(string(docs_result2(i).datasetId), string(cloudDatasetId), ...
                        "CSV-scoped result leaked a dataset beyond the accessible one.");
                end
            end

            % 3. Format-invalid scope must be rejected locally.
            narrative(end+1) = "Verifying client-side rejection of a malformed scope.";
            threw = false;
            try
                ndi.cloud.api.documents.ndiquery("not-a-hex,also-bad", q);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, "Malformed scope should be rejected by client-side validation.");

            testCase.Narrative = narrative;
        end
    end
end
