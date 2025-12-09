classdef datasetDemo < matlab.unittest.TestCase
    properties
        ndiDatasetToUpload
        ndiDatasetDownloaded
        cloudDatasetId
        localSession
    end

    methods (TestMethodSetup)
        function setupDataset(testCase)
            % Create a dataset with an ingested session
            [testCase.ndiDatasetToUpload, testCase.localSession] = ndi.unittest.dataset.buildDataset.sessionWithIngestedDocsAndFiles();
        end
    end

    methods (TestMethodTeardown)
        function teardownDataset(testCase)
            % Clean up local dataset
            if ~isempty(testCase.ndiDatasetToUpload)
                path = testCase.ndiDatasetToUpload.path;
                if isfolder(path)
                    rmdir(path, 's');
                end
            end
            % Clean up downloaded dataset
            if ~isempty(testCase.ndiDatasetDownloaded)
                path = testCase.ndiDatasetDownloaded.path;
                if isfolder(path)
                    rmdir(path, 's');
                end
            end
            % Delete remote dataset
            if ~isempty(testCase.cloudDatasetId)
                try
                    ndi.cloud.api.datasets.deleteDataset(testCase.cloudDatasetId);
                catch ME
                    warning('Could not delete remote dataset %s: %s', testCase.cloudDatasetId, ME.message);
                end
            end
        end
    end

    methods (Test)
        function uploadDownloadThenSync(testCase)
            % Step 2: Upload
            % Pass options as name-value pairs.
            % User requested 'SyncFiles', false for upload.
            [success, testCase.cloudDatasetId, message] = ndi.cloud.uploadDataset(testCase.ndiDatasetToUpload, ...
                'Verbose', true, ...
                'SyncFiles', false, ...
                'uploadAsNew', true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName', 'Dataset sync test');

            testCase.verifyTrue(success, ['Upload failed: ' message]);
            testCase.verifyTrue(strlength(testCase.cloudDatasetId) > 0, 'Cloud Dataset ID should not be empty');

            % Step 3: Download
            tempFolder = tempname;
            mkdir(tempFolder);

            pause(10); % let the upload settle

            % downloadDataset takes name-value pairs for syncOptions.
            testCase.ndiDatasetDownloaded = ndi.cloud.downloadDataset(testCase.cloudDatasetId, tempFolder, ...
                'Verbose', true, 'SyncFiles', false);

            % Step 4: Add files to downloaded dataset session
            [~, id_list] = testCase.ndiDatasetDownloaded.session_list();
            testCase.verifyNotEmpty(id_list, 'Downloaded dataset should have sessions');

            % Open the session. Since it's ingested, this returns a session object pointing to the dataset directory.
            session = testCase.ndiDatasetDownloaded.open_session(id_list{1});

            for i = 101:105
                ndi.unittest.session.buildSession.addDocsWithFiles(session, i);
            end

            % Step 5: Sync downloaded -> cloud
            % twoWaySync(ndiDataset, syncOptions)
            [success, msg, report] = ndi.cloud.sync.twoWaySync(testCase.ndiDatasetDownloaded, ...
                'Verbose', true, 'SyncFiles', false);
            testCase.verifyTrue(success, ['Sync downloaded->cloud failed: ' msg]);
            testCase.verifyTrue(numel(report.uploaded_document_ids) >= 5, 'Should have uploaded at least 5 documents');

            % Step 6: Sync local -> cloud (to get the new files)
            [success, msg, report] = ndi.cloud.sync.twoWaySync(testCase.ndiDatasetToUpload, ...
                'Verbose', true, 'SyncFiles', false);
            testCase.verifyTrue(success, ['Sync local->cloud failed: ' msg]);
            testCase.verifyTrue(numel(report.downloaded_document_ids) >= 5, 'Should have downloaded at least 5 documents');

            % Step 7: Compare datasets using ndi.fun.dataset.diff
            diffReport = ndi.fun.dataset.diff(testCase.ndiDatasetToUpload, testCase.ndiDatasetDownloaded, 'verbose', true);

            testCase.verifyEmpty(diffReport.mismatchedDocuments, 'Found mismatched documents between datasets.');
            testCase.verifyEmpty(diffReport.fileDifferences, 'Found file differences between datasets.');

            % Verify that the specific documents (101-105) are present in both (not exclusive to one)
            % We get the IDs of the documents of interest from the downloaded dataset (where we created them)
            for i = 101:105
                docname = sprintf('doc_%d', i);
                q = ndi.query('base.name', 'exact_string', docname);
                docs = testCase.ndiDatasetDownloaded.database_search(q);
                testCase.verifyNotEmpty(docs, ['Document ' docname ' must exist in the downloaded dataset']);
                if ~isempty(docs)
                     docId = docs{1}.id();
                     testCase.verifyFalse(ismember(docId, diffReport.documentsInAOnly), ...
                         ['Document ' docname ' (' docId ') should not be in dataset A only']);
                     testCase.verifyFalse(ismember(docId, diffReport.documentsInBOnly), ...
                         ['Document ' docname ' (' docId ') should not be in dataset B only']);
                end
            end
        end

        function testSequentialAddSession(testCase)
            % Sequentially adds 3 sessions to a remote dataset and checks their presence.

            % 1. Upload initial dataset to create remote dataset
            [success, testCase.cloudDatasetId, message] = ndi.cloud.uploadDataset(testCase.ndiDatasetToUpload, ...
                'Verbose', true, ...
                'SyncFiles', false, ...
                'uploadAsNew', true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName', 'Sequential Session Add Test');
            testCase.verifyTrue(success, ['Initial upload failed: ' message]);

            % 2. Create 3 new sessions
            numSessions = 3;
            sessions = cell(1, numSessions);

            for i = 1:numSessions
                % Create a temporary session
                % We use buildSession to create distinct sessions (with distinct refs if needed, but buildSession might reuse)
                % ndi.unittest.session.buildSession.withDocsAndFiles creates a session.
                % But we want to reuse the class but new instances.
                % The static method creates a temp folder.

                % We need to create independent sessions.
                % ndi.unittest.session.buildSession is a TestCase class, but has static methods.
                % sessionWithIngestedDocsAndFiles creates a dataset. We just want a session.
                % There isn't a direct "create session with docs" static method in buildSession that returns JUST a session object
                % without it being part of the test class lifecycle easily?
                % Ah, `ndi.unittest.session.buildSession.withDocsAndFiles` is not in memory explicitly as a pure static generator?
                % Memory said: "The static method `ndi.unittest.session.buildSession.withDocsAndFiles` generates a temporary `ndi.session.dir` containing `demoNDI` documents...".
                % So yes, we can use it.

                % However, `withDocsAndFiles` might return a session that is already "ingested" in its own directory?
                % `addSessionToRemoteDataset` requires an ingested session.
                % So we need to make sure `ingest` is called.

                % Note: `buildSession` usually creates a session but `ingest` must be manually called?
                % Memory: "The session object created by `ndi.unittest.session.buildSession` is initialized but not ingested; the `ingest` method must be manually called".

                % We need a way to manage the temp folders for cleanup.
                % Since `withDocsAndFiles` creates a temp dir, we should track it.
                % But `withDocsAndFiles` returns `session`. `session.path` is the dir.

                S = ndi.unittest.session.buildSession.withDocsAndFiles();
                S.ingest();
                sessions{i} = S;

                % Modify reference to be unique
                % S.reference is read-only? No, SetAccess=protected.
                % We can't easily change reference.
                % But S has a unique ID. That should be enough.

                % 3. Add session to remote dataset
                % We provide the local dataset `testCase.ndiDatasetToUpload` to sync back.
                [success, msg] = ndi.cloud.addSessionToRemoteDataset(testCase.cloudDatasetId, S, 'ndiDataset', testCase.ndiDatasetToUpload);
                testCase.verifyTrue(success, ['Failed to add session ' int2str(i) ': ' msg]);

                % Cleanup the temp session folder (we don't need it after upload)
                % Wait, if we delete it, `addSessionToRemoteDataset` might need it during upload?
                % Yes, it uploads S docs.
                % We can delete it after.

                % Verify presence in local dataset (since we synced)
                [~, id_list] = testCase.ndiDatasetToUpload.session_list();
                testCase.verifyTrue(ismember(S.id(), id_list), ['Session ' int2str(i) ' not found in local dataset after sync']);

                % Verify remote presence (optional, but good)
                % We can list remote documents.
            end

            % 4. Verify all 3 are in the dataset
            % We can check `testCase.ndiDatasetToUpload` session list.
            [~, id_list] = testCase.ndiDatasetToUpload.session_list();
            for i = 1:numSessions
                testCase.verifyTrue(ismember(sessions{i}.id(), id_list), ['Session ' int2str(i) ' missing from final check']);
            end

            % Cleanup temp sessions
            for i = 1:numSessions
                if isfolder(sessions{i}.path)
                    rmdir(sessions{i}.path, 's');
                end
            end
        end
    end
end
