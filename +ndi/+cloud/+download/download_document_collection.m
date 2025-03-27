function documents = download_document_collection(datasetId, documentIds, options)
% DOWNLOAD_DOCUMENT_COLLECTION - Download a collection of documents using bulk download
%
%   documents = ndi.cloud.download.download_document_collection(datasetId) 
%    downloads a collection of documents from a specified dataset using a bulk
%    download mechanism. It retrieves a bulk download URL via the 
%    ndi.cloud.api.documents.get_bulk_download_url API call, downloads the 
%    corresponding ZIP file, and then extracts and decodes the JSON content
%    into a MATLAB struct.
%
% INPUTS:
%    datasetId    - (1,1) string
%                   Unique identifier for the dataset from which documents are 
%                   to be downloaded.
%
%    documentIds  - (1,:) string, optional
%                   Array of document identifiers to download. Default is an empty string (""),
%                   which indicates that all documents in the dataset will be downloaded.
%
% OUTPUTS:
%    documents    - Cell
%                   A cell array of structures representing the downloaded 
%                   documents.
%
% EXAMPLE:
%    % Download all documents from a dataset:
%    docs = ndi.cloud.download.download_document_collection("dataset123");
%
%    % Download specific documents with a custom timeout:
%    docs = ndi.cloud.download.download_document_collection("dataset123", ["doc1", "doc2"]);
%
% See also: ndi.cloud.api.documents.get_bulk_download_url

    arguments
        datasetId (1,1) string
        documentIds (1,:) string = "" % Default: Will download all documents
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