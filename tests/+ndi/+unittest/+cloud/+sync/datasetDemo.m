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
            testCase.addTeardown(@() rmdir(tempFolder, 's'));

            % downloadDataset takes name-value pairs for syncOptions.
            testCase.ndiDatasetDownloaded = ndi.cloud.downloadDataset(testCase.cloudDatasetId, tempFolder, ...
                'Verbose', true, 'SyncFiles', true);

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
                'Verbose', true, 'SyncFiles', true);
            testCase.verifyTrue(success, ['Sync downloaded->cloud failed: ' msg]);
            testCase.verifyTrue(numel(report.uploaded_document_ids) >= 5, 'Should have uploaded at least 5 documents');

            % Step 6: Sync local -> cloud (to get the new files)
            [success, msg, report] = ndi.cloud.sync.twoWaySync(testCase.ndiDatasetToUpload, ...
                'Verbose', true, 'SyncFiles', true);
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
    end
end
