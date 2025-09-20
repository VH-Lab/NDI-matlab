classdef SyncTest < matlab.unittest.TestCase
    properties
        TestDir
        LocalSession
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            % Add mocks to the path
            mockPath = fullfile(nditools.projectdir, 'tests', 'mocks');
            addpath(mockPath);

            % Create a temporary directory for the test NDI session
            testCase.TestDir = tempname;
            mkdir(testCase.TestDir);
        end
    end

    methods (TestClassTeardown)
        function tearDownClass(testCase)
            % Remove mocks from the path
            mockPath = fullfile(nditools.projectdir, 'tests', 'mocks');
            rmpath(mockPath);

            % Remove the temporary directory
            rmdir(testCase.TestDir, 's');
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Clear and recreate the directory for a clean slate
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
            mkdir(testCase.TestDir);

            % Create a new NDI session for each test
            testCase.LocalSession = ndi.session.dir(testCase.TestDir);

            % Clear mock remote datastore
            ndi.cloud.api.documents.listDatasetDocumentsAll('clear');
        end
    end

    methods (TestMethodTeardown)
        function tearDownMethod(testCase)
        end
    end

    methods (Test)
        function testDownloadNew_Simple(testCase)
            % 1. Setup remote state
            remote_docs = [
                struct('ndiId', 'doc1', 'id', 'api_doc1'),
                struct('ndiId', 'doc2', 'id', 'api_doc2')
            ];
            ndi.cloud.api.documents.listDatasetDocumentsAll('set', remote_docs);

            % 2. Call the sync function
            ndi.cloud.sync.downloadNew(testCase.LocalSession);

            % 3. Assertions
            local_docs = testCase.LocalSession.database.search();
            testCase.verifyEqual(numel(local_docs), 2, "Should have downloaded 2 documents");

            local_doc_ids = cellfun(@(x) x.id(), local_docs, 'UniformOutput', false);
            testCase.verifyTrue(all(ismember({'doc1', 'doc2'}, local_doc_ids)), "Downloaded documents should have correct IDs");
        end

        function testDownloadNew_DryRun(testCase)
            % 1. Setup remote state
            remote_docs = [
                struct('ndiId', 'doc1', 'id', 'api_doc1'),
                struct('ndiId', 'doc2', 'id', 'api_doc2')
            ];
            ndi.cloud.api.documents.listDatasetDocumentsAll('set', remote_docs);

            % 2. Call the sync function with DryRun
            ndi.cloud.sync.downloadNew(testCase.LocalSession, 'DryRun', true);

            % 3. Assertions
            local_docs = testCase.LocalSession.database.search();
            testCase.verifyEmpty(local_docs, "No documents should be downloaded in a dry run");
        end

        function testUploadNew_Simple(testCase)
            % 1. Setup local state
            doc1 = ndi.document('ndi_document_id', 'local_doc1');
            doc2 = ndi.document('ndi_document_id', 'local_doc2');
            testCase.LocalSession.database.add(doc1);
            testCase.LocalSession.database.add(doc2);

            % 2. Call sync function
            ndi.cloud.sync.uploadNew(testCase.LocalSession);

            % 3. Assertions
            [~, resp] = ndi.cloud.api.documents.listDatasetDocumentsAll('list');
            remote_docs = resp.documents;
            testCase.verifyEqual(numel(remote_docs), 2, "Should have uploaded 2 documents");

            remote_doc_ids = {remote_docs.ndiId};
            testCase.verifyTrue(all(ismember({'local_doc1', 'local_doc2'}, remote_doc_ids)), "Uploaded documents should have correct IDs");
        end

        function testUploadNew_DryRun(testCase)
            % 1. Setup local state
            doc1 = ndi.document('ndi_document_id', 'local_doc1');
            testCase.LocalSession.database.add(doc1);

            % 2. Call sync function
            ndi.cloud.sync.uploadNew(testCase.LocalSession, 'DryRun', true);

            % 3. Assertions
            [~, resp] = ndi.cloud.api.documents.listDatasetDocumentsAll('list');
            remote_docs = resp.documents;
            testCase.verifyEmpty(remote_docs, "No documents should be uploaded in a dry run");
        end

        function testMirrorFromRemote_Simple(testCase)
            % 1. Setup state
            % Remote has a shared doc and a remote-only doc
            remote_docs = [
                struct('ndiId', 'shared_doc', 'id', 'api_shared'),
                struct('ndiId', 'remote_only_doc', 'id', 'api_remote_only')
            ];
            ndi.cloud.api.documents.listDatasetDocumentsAll('set', remote_docs);

            % Local has a shared doc and a local-only doc
            shared_doc_local = ndi.document('ndi_document_id', 'shared_doc');
            local_only_doc = ndi.document('ndi_document_id', 'local_only_doc');
            testCase.LocalSession.database.add(shared_doc_local);
            testCase.LocalSession.database.add(local_only_doc);

            % 2. Call sync function
            ndi.cloud.sync.mirrorFromRemote(testCase.LocalSession);

            % 3. Assertions
            local_docs = testCase.LocalSession.database.search();
            testCase.verifyEqual(numel(local_docs), 2, "Local session should have 2 documents");

            local_doc_ids = cellfun(@(x) x.id(), local_docs, 'UniformOutput', false);
            testCase.verifyTrue(ismember('shared_doc', local_doc_ids), "Shared document should still exist locally");
            testCase.verifyTrue(ismember('remote_only_doc', local_doc_ids), "Remote-only document should have been downloaded");
            testCase.verifyFalse(ismember('local_only_doc', local_doc_ids), "Local-only document should have been deleted");
        end

        function testMirrorToRemote_Simple(testCase)
            % 1. Setup state
            % Remote has a shared doc and a remote-only doc
            remote_docs = [
                struct('ndiId', 'shared_doc', 'id', 'api_shared'),
                struct('ndiId', 'remote_only_doc', 'id', 'api_remote_only')
            ];
            ndi.cloud.api.documents.listDatasetDocumentsAll('set', remote_docs);

            % Local has a shared doc and a local-only doc
            shared_doc_local = ndi.document('ndi_document_id', 'shared_doc');
            local_only_doc = ndi.document('ndi_document_id', 'local_only_doc');
            testCase.LocalSession.database.add(shared_doc_local);
            testCase.LocalSession.database.add(local_only_doc);

            % 2. Call sync function
            ndi.cloud.sync.mirrorToRemote(testCase.LocalSession);

            % 3. Assertions
            [~, resp] = ndi.cloud.api.documents.listDatasetDocumentsAll('list');
            final_remote_docs = resp.documents;
            testCase.verifyEqual(numel(final_remote_docs), 2, "Remote should have 2 documents");

            remote_doc_ids = {final_remote_docs.ndiId};
            testCase.verifyTrue(ismember('shared_doc', remote_doc_ids), "Shared document should still exist on remote");
            testCase.verifyTrue(ismember('local_only_doc', remote_doc_ids), "Local-only document should have been uploaded");
            testCase.verifyFalse(ismember('remote_only_doc', remote_doc_ids), "Remote-only document should have been deleted");
        end

        function testTwoWaySync_Simple(testCase)
            % 1. Setup state
            % Remote has a shared doc and a remote-only doc
            remote_docs = [
                struct('ndiId', 'shared_doc', 'id', 'api_shared'),
                struct('ndiId', 'remote_only_doc', 'id', 'api_remote_only')
            ];
            ndi.cloud.api.documents.listDatasetDocumentsAll('set', remote_docs);

            % Local has a shared doc and a local-only doc
            shared_doc_local = ndi.document('ndi_document_id', 'shared_doc');
            local_only_doc = ndi.document('ndi_document_id', 'local_only_doc');
            testCase.LocalSession.database.add(shared_doc_local);
            testCase.LocalSession.database.add(local_only_doc);

            % 2. Call sync function
            ndi.cloud.sync.twoWaySync(testCase.LocalSession);

            % 3. Assertions
            % Check local state
            local_docs = testCase.LocalSession.database.search();
            testCase.verifyEqual(numel(local_docs), 3, "Local session should have 3 documents");
            local_doc_ids = cellfun(@(x) x.id(), local_docs, 'UniformOutput', false);
            testCase.verifyTrue(all(ismember({'shared_doc', 'remote_only_doc', 'local_only_doc'}, local_doc_ids)), "Local state is incorrect");

            % Check remote state
            [~, resp] = ndi.cloud.api.documents.listDatasetDocumentsAll('list');
            final_remote_docs = resp.documents;
            testCase.verifyEqual(numel(final_remote_docs), 3, "Remote should have 3 documents");
            remote_doc_ids = {final_remote_docs.ndiId};
            testCase.verifyTrue(all(ismember({'shared_doc', 'remote_only_doc', 'local_only_doc'}, remote_doc_ids)), "Remote state is incorrect");
        end
    end
end
