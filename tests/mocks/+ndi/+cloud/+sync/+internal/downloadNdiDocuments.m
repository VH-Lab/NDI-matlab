function downloadNdiDocuments(cloudDatasetId, cloudApiIds, ndiDataset, syncOptions)
%MOCKDOWNLOADNDIDOCUMENTS Mock for downloading documents
%
% For testing purposes, this function will create dummy document files
% in the local dataset's path to simulate a download. It will also
% add document objects to the dataset's database.

    if syncOptions.Verbose
        fprintf('[Mock] Downloading %d documents...\n', numel(cloudApiIds));
    end

    for i = 1:numel(cloudApiIds)
        % Create a dummy document
        doc = ndi.document('ndi_document_id', cloudApiIds{i});

        % Add a dummy file dependency to test file syncing
        if syncOptions.SyncFiles
            dummy_filename = [doc.id() '_testfile.txt'];
            dummy_filepath = fullfile(ndiDataset.path, dummy_filename);
            fid = fopen(dummy_filepath, 'w');
            fprintf(fid, 'This is a test file for %s', doc.id());
            fclose(fid);

            % This part is tricky, we need to add a file dependency to the doc
            % For now, we'll just simulate the file being there.
        end

        % Add the document to the local dataset's database
        ndiDataset.database.add(doc);
    end
end
