classdef ValidateTest < ndi.unittest.cloud.sync.BaseSyncTest
    %ValidateTest Test for ndi.cloud.sync.validate

    properties
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

    methods(Test)

        function testValidation(testCase)
            % Test validation logic
            testCase.Narrative = "Begin ValidateTest: testValidation";
            narrative = testCase.Narrative;

            % 1. Initial State:
            % Local: doc1 (match), doc2 (mismatch), doc3 (local-only)
            % Remote: doc1 (match), doc2 (mismatch), doc4 (remote-only)

            narrative(end+1) = "SETUP: Creating doc1 (match), doc2 (mismatch), doc3 (local-only), doc4 (remote-only)";

            doc1 = ndi.document('base', 'base.name', 'doc1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc1.document_properties));
            doc1_id = doc1.id();

            doc2_local = ndi.document('base', 'base.name', 'doc2','base.session_id', testCase.localDataset.id());
            testCase.localDataset.database_add(doc2_local);
            doc2_id = doc2_local.id();
            
            doc2_remote_struct = doc2_local.document_properties;
            doc2_remote_struct.base.name = 'doc2_remote';
            doc2_remote = ndi.document(doc2_remote_struct);
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2_remote.document_properties));
            
            doc3 = ndi.document('base', 'base.name', 'doc3','base.session_id', testCase.localDataset.id());
            testCase.localDataset.database_add(doc3);
            doc3_id = doc3.id();

            doc4 = ndi.document('base', 'base.name', 'doc4','base.session_id', testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc4.document_properties));
            doc4_id = doc4.id();
            
            % 2. Execute
            narrative(end+1) = "EXECUTE: Calling ndi.cloud.sync.validate";
            report = ndi.cloud.sync.validate(testCase.localDataset,"Verbose",true);

            % 3. Verify
            narrative(end+1) = "VERIFY: Checking report content";

            % We will use the report itself as the 'ResponseBody' for APIMessage context

            msg = ndi.unittest.cloud.APIMessage(narrative, true, report, "N/A", "ndi.cloud.sync.validate");

            testCase.verifyEqual(ismember(doc3_id,report.local_only_ids), true, "doc3 should be local only. " + msg);
            testCase.verifyEqual(ismember(doc4_id,report.remote_only_ids), true, "doc4 should be on remote only. " + msg);
            testCase.verifyEqual(all(ismember({doc1_id,doc2_id},report.common_ids)), true, "doc1 and doc2 should be in both. " + msg);
            testCase.verifyEqual(ismember(doc2_id,report.mismatched_ids), true, "doc2 should be mismatched. " + msg);

            narrative(end+1) = "testValidation completed successfully.";
            testCase.Narrative = narrative;
        end

    end
end
