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

        function multipleSessionSyncTest(testCase)
            % MULTIPLESESSIONSYNCTEST - Test adding sessions and syncing

            % 1. Make a dataset and add 2 ingested sessions with documents.
            % The setup already created a dataset with 1 session. We will add a second one.
            session2 = ndi.unittest.session.buildSession.withDocsAndFiles();
            testCase.addTeardown(@rmdir, session2.path(), 's');

            testCase.ndiDatasetToUpload.add_ingested_session(session2);

            % Verify we have 2 sessions locally
            [~, session_ids] = testCase.ndiDatasetToUpload.session_list();
            testCase.verifyEqual(numel(session_ids), 2, 'Local dataset should have 2 sessions before upload');

            % 2. Upload the dataset
            % Use 'skipMetadataEditorMetadata' as true and 'remoteDatasetName' as 'synctest'.
            [success, testCase.cloudDatasetId, message] = ndi.cloud.uploadDataset(testCase.ndiDatasetToUpload, ...
                'Verbose', true, ...
                'SyncFiles', false, ...
                'uploadAsNew', true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName', 'synctest');

            testCase.verifyTrue(success, ['Upload failed: ' message]);

            % 3. Download the dataset to a new (temporary) location
            tempFolder1 = tempname;
            mkdir(tempFolder1);
            testCase.addTeardown(@rmdir, tempFolder1, 's');

            pause(5); % Allow cloud to settle

            downloadedDataset1 = ndi.cloud.downloadDataset(testCase.cloudDatasetId, tempFolder1, ...
                'Verbose', true, 'SyncFiles', false);

            [~, d1_ids] = downloadedDataset1.session_list();
            testCase.verifyEqual(numel(d1_ids), 2, 'Downloaded dataset 1 should have 2 sessions');

            % 4. Add two more ingested sessions to the local dataset
            session3 = ndi.unittest.session.buildSession.withDocsAndFiles();
            testCase.addTeardown(@rmdir, session3.path(), 's');
            testCase.ndiDatasetToUpload.add_ingested_session(session3);

            session4 = ndi.unittest.session.buildSession.withDocsAndFiles();
            testCase.addTeardown(@rmdir, session4.path(), 's');
            testCase.ndiDatasetToUpload.add_ingested_session(session4);

            % Verify we have 4 sessions locally
            [~, session_ids_local] = testCase.ndiDatasetToUpload.session_list();
            testCase.verifyEqual(numel(session_ids_local), 4, 'Local dataset should have 4 sessions');

            % 5. Run ndi.cloud.sync.twoWaySinc to update the remote dataset
            [success, msg, ~] = ndi.cloud.sync.twoWaySync(testCase.ndiDatasetToUpload, ...
                'Verbose', true, 'SyncFiles', false);
            testCase.verifyTrue(success, ['TwoWaySync failed: ' msg]);

            % 6. Download the dataset to yet another new (temporary) location
            tempFolder2 = tempname;
            mkdir(tempFolder2);
            testCase.addTeardown(@rmdir, tempFolder2, 's');

            pause(5);

            downloadedDataset2 = ndi.cloud.downloadDataset(testCase.cloudDatasetId, tempFolder2, ...
                'Verbose', true, 'SyncFiles', false);

            % 7. Make sure that all sessions are present
            [~, final_session_ids] = downloadedDataset2.session_list();
            testCase.verifyEqual(numel(final_session_ids), 4, 'Final downloaded dataset should have 4 sessions');
        end
    end
end
