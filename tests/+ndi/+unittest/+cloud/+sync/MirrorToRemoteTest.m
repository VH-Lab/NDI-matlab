classdef MirrorToRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorToRemoteTest Test for ndi.cloud.sync.mirrorToRemote

    properties
        Narrative (1,:) string
    end

    methods(Test)

        function testMirrorToRemote(testCase)
            testCase.Narrative = "Begin MirrorToRemoteTest: testMirrorToRemote";
            narrative = testCase.Narrative;

            % 1. Initial State: Local has doc1, remote has doc2
            narrative(end+1) = "SETUP: Creating local document 'local_doc_1'.";
            doc1 = ndi.document('base', 'base.name', 'local_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            narrative(end+1) = "SETUP: Creating remote document 'remote_doc_2'.";
            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id', testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            narrative(end+1) = "Preparing to call ndi.cloud.sync.mirrorToRemote.";
            [success, msg, report] = ndi.cloud.sync.mirrorToRemote(testCase.localDataset,"Verbose",true);

            narrative(end+1) = "Called ndi.cloud.sync.mirrorToRemote.";

            % Create a result struct to mimic API response body for the report
            resultStruct = struct('msg', msg, 'report', report);

            narrative(end+1) = "Testing: Verifying mirrorToRemote was successful.";
            mirror_message = ndi.unittest.cloud.APIMessage(narrative, success, resultStruct, [], []);
            testCase.verifyTrue(success, mirror_message);
            testCase.verifyEmpty(msg, mirror_message);

            % Check report
            narrative(end+1) = "Testing: Verifying report has 'uploaded_document_ids'.";
            msg_report = ndi.unittest.cloud.APIMessage(narrative, success, resultStruct, [], []);
            testCase.verifyTrue(isfield(report, 'uploaded_document_ids'), msg_report);

            narrative(end+1) = "Testing: Verifying report has 'deleted_remote_document_ids'.";
            msg_report = ndi.unittest.cloud.APIMessage(narrative, success, resultStruct, [], []);
            testCase.verifyTrue(isfield(report, 'deleted_remote_document_ids'), msg_report);

            % Verify specific IDs
            narrative(end+1) = "Testing: Verifying local doc ID was uploaded.";
            msg_ids = ndi.unittest.cloud.APIMessage(narrative, success, resultStruct, [], []);
            if isfield(report, 'uploaded_document_ids')
                 testCase.verifyTrue(any(strcmp(report.uploaded_document_ids, doc1.id())), msg_ids);
            end

            narrative(end+1) = "Testing: Verifying remote doc ID was deleted.";
            msg_ids = ndi.unittest.cloud.APIMessage(narrative, success, resultStruct, [], []);
             if isfield(report, 'deleted_remote_document_ids')
                testCase.verifyTrue(any(strcmp(report.deleted_remote_document_ids, doc2.id())), msg_ids);
            end

            % 3. Verify
            % Remote should now have doc1
            narrative(end+1) = "Verifying state: Calling listDatasetDocumentsAll to check remote state.";
            [success_list, remote_docs, apiResponse, apiURL] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);

            narrative(end+1) = "Testing: Verifying listDatasetDocumentsAll was successful.";
            list_message = ndi.unittest.cloud.APIMessage(narrative, success_list, remote_docs, apiResponse, apiURL);
            testCase.verifyEqual(logical(success_list), true, list_message);

            found_local_doc_1 = false;
            found_remote_doc_2 = false;
            if success_list
                for i=1:numel(remote_docs)
                    if strcmp(remote_docs(i).name,'local_doc_1')
                        found_local_doc_1 = true;
                    elseif strcmp(remote_docs(i).name,'remote_doc_2')
                        found_remote_doc_2 = true;
                    end
                end
            end

            narrative(end+1) = "Testing: Verifying 'local_doc_1' is present on remote.";
            msg_check = ndi.unittest.cloud.APIMessage(narrative, success_list, remote_docs, apiResponse, apiURL);
            testCase.verifyTrue(found_local_doc_1, msg_check);

            narrative(end+1) = "Testing: Verifying 'remote_doc_2' is NOT present on remote.";
            msg_check = ndi.unittest.cloud.APIMessage(narrative, success_list, remote_docs, apiResponse, apiURL);
            testCase.verifyFalse(found_remote_doc_2, msg_check);

            narrative(end+1) = "MirrorToRemoteTest completed.";
            testCase.Narrative = narrative;
        end

    end
end
