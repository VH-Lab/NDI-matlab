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
            % Note: syncOptions is 2nd argument, name-value pairs follow.
            % We pass an empty SyncOptions object for defaults, or SyncOptions object if needed.
            % But uploadDataset expects `syncOptions.?ndi.cloud.sync.SyncOptions` which means a value convertible to SyncOptions.
            % However, it's defined as a positional argument.
            syncOptions = ndi.cloud.sync.SyncOptions();
            [success, testCase.cloudDatasetId, message] = ndi.cloud.uploadDataset(testCase.ndiDatasetToUpload, syncOptions, ...
                'uploadAsNew', true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName', 'Dataset sync test');

            testCase.verifyTrue(success, ['Upload failed: ' message]);
            testCase.verifyTrue(strlength(testCase.cloudDatasetId) > 0, 'Cloud Dataset ID should not be empty');

            % Step 3: Download
            tempFolder = tempname;
            mkdir(tempFolder);
            testCase.addTeardown(@() rmdir(tempFolder, 's'));

            % downloadDataset takes syncOptions as 3rd arg (positional).
            % It can be a SyncOptions object or name-value pairs (if implicit conversion works, but it's defined as `.?SyncOptions`).
            % Actually, the definition `syncOptions.?ndi.cloud.sync.SyncOptions` allows passing a struct or name-value args if the constructor supports it?
            % No, usually `.?Class` means "must be of this class or empty".
            % But `downloadDataset` implementation does `syncOptions = ndi.cloud.sync.SyncOptions(syncOptions);`.
            % This implies we can pass what the constructor takes.
            % The constructor of SyncOptions takes name-value pairs.
            % So passing a SyncOptions object is safest.
            syncOptionsDownload = ndi.cloud.sync.SyncOptions('SyncFiles', true);
            testCase.ndiDatasetDownloaded = ndi.cloud.downloadDataset(testCase.cloudDatasetId, tempFolder, syncOptionsDownload);

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
            [success, msg, report] = ndi.cloud.sync.twoWaySync(testCase.ndiDatasetDownloaded, syncOptions);
            testCase.verifyTrue(success, ['Sync downloaded->cloud failed: ' msg]);
            testCase.verifyTrue(numel(report.uploaded_document_ids) >= 5, 'Should have uploaded at least 5 documents');

            % Step 6: Sync local -> cloud (to get the new files)
            [success, msg, report] = ndi.cloud.sync.twoWaySync(testCase.ndiDatasetToUpload, syncOptions);
            testCase.verifyTrue(success, ['Sync local->cloud failed: ' msg]);
            testCase.verifyTrue(numel(report.downloaded_document_ids) >= 5, 'Should have downloaded at least 5 documents');

            % Step 7: Compare documents 101-105
            for i = 101:105
                docname = sprintf('doc_%d', i);
                q = ndi.query('base.name', 'exact_string', docname);

                % Search in downloaded (source of new docs)
                docs_down = testCase.ndiDatasetDownloaded.database_search(q);
                testCase.verifyNotEmpty(docs_down, ['Document ' docname ' should exist in downloaded dataset']);

                % Search in original (uploaded) - should have received them
                docs_up = testCase.ndiDatasetToUpload.database_search(q);
                testCase.verifyNotEmpty(docs_up, ['Document ' docname ' should exist in uploaded dataset after sync']);

                if ~isempty(docs_down) && ~isempty(docs_up)
                     testCase.verifyEqual(docs_down{1}.id(), docs_up{1}.id(), ['IDs should match for ' docname]);

                     % Check file existence in uploaded dataset
                     [exists, path] = testCase.ndiDatasetToUpload.database_existbinarydoc(docs_up{1}, 'filename1.ext');
                     testCase.verifyTrue(exists, ['File should exist for ' docname ' in uploaded dataset']);

                     if exists
                         fid = fopen(path, 'r');
                         content = fread(fid, '*char')';
                         fclose(fid);
                         testCase.verifyEqual(content, docname, ['File content should match for ' docname]);
                     end
                end
            end
        end
    end
end
