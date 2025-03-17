function documents = download_document_collection(datasetId, documentIds, options)
% download_document_collection - Download collection of documents using bulk download

    arguments
        datasetId (1,1) string
        documentIds (1,:) string
        options.Timeout = 10
    end
    
    downloadUrl = ndi.cloud.api.documents.get_bulk_download_url(datasetId, documentIds);

    tempZipFilepath = [tempname, '.zip'];
    zipfileCleanupObj = onCleanup(@() deleteIfExists(tempZipFilepath));

    isFinished = false;
    t1 = tic;
    while ~isFinished && toc(t1) < options.Timeout
        try
            websave(tempZipFilepath, downloadUrl);
            isFinished = true;
        catch ME
            pause(1)
        end
    end
    
    % Unzip documents and return as structs
    jsonFile = unzip(tempZipFilepath);
    documents = jsondecode(fileread(jsonFile{1}));
end

function deleteIfExists(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end