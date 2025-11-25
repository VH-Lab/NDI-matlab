function documents = downloadDocumentCollection(datasetId, documentIds, options)
% DOWNLOAD_DOCUMENT_COLLECTION - Download documents using bulk download with chunking.
%
%   documents = ndi.cloud.download.downloadDocumentCollection(datasetId, documentIds, options)
%   downloads a collection of documents from a specified dataset.
%
%   To improve performance and avoid server errors with large requests, this
%   function automatically splits the list of document IDs into smaller chunks
%   (default size: 2000) and performs a separate download for each chunk.
%
% INPUTS:
%    datasetId    - (1,1) string
%                   Unique identifier for the dataset from which documents are
%                   to be downloaded.
%
%    documentIds  - (1,:) string, optional
%                   Array of **cloud API document identifiers** to download.
%                   Default is an empty string (""), which triggers a download of
%                   ALL documents in the dataset.
%
%                   **Performance Note:** If you intend to download all documents
%                   and already have the list of document IDs (e.g., from a
%                   previous call), it is more efficient to pass that list
%                   directly to avoid an extra API call to fetch the list again.
%
%    options.Timeout - (1,1) double, optional
%                   The timeout in seconds for the websave download operation.
%                   Default is 20.
%
%    options.ChunkSize - (1,1) double, optional
%                   The maximum number of document IDs to request in a single
%                   bulk download operation. Default is 2000.
%
% OUTPUTS:
%    documents    - Cell
%                   A cell array of the resulting ndi.document objects.
%
% EXAMPLE:
%    % Download all documents from a dataset (will fetch ID list first)
%    docs = ndi.cloud.download.downloadDocumentCollection("dataset123");
%
%    % Download a specific list of documents with a larger chunk size
%    my_ids = ["id_abc", "id_def", ...];
%    docs = ndi.cloud.download.downloadDocumentCollection("dataset456", my_ids, ChunkSize=5000);
%
% See also: ndi.cloud.api.documents.getBulkDownloadURL, ndi.cloud.api.documents.listDatasetDocumentsAll

    arguments
        datasetId (1,1) string
        documentIds (1,:) string = "" % Default: Will download all documents
        options.Timeout = 20 % Default timeout increased to 20 seconds
        options.ChunkSize = 2000 % Default chunk size
    end

    % If user requests all documents, fetch the full list of IDs first.
    if isempty(documentIds) || (isscalar(documentIds) && documentIds == "")
        disp('No document IDs provided; fetching all document IDs from the server...');
        id_map = ndi.cloud.sync.internal.listRemoteDocumentIds(datasetId);
        documentIds = id_map.apiId;
        if isempty(documentIds)
            documents = {}; % Return empty if dataset has no documents
            return;
        end
    end

    % Split the documentIds into chunks for processing
    numDocs = numel(documentIds);
    numChunks = ceil(numDocs / options.ChunkSize);
    documentChunks = cell(1, numChunks);
    for i = 1:numChunks
        startIndex = (i-1) * options.ChunkSize + 1;
        endIndex = min(i * options.ChunkSize, numDocs);
        documentChunks{i} = documentIds(startIndex:endIndex);
    end

    all_document_structs = [];
    fprintf('Beginning download of %d documents in %d chunk(s).\n', numDocs, numChunks);

    for c = 1:numel(documentChunks)
        chunk_doc_ids = documentChunks{c};
        fprintf('  Processing chunk %d of %d (%d documents)...\n', c, numChunks, numel(chunk_doc_ids));

        [success, downloadUrl, api_reply] = ndi.cloud.api.documents.getBulkDownloadURL(datasetId, "cloudDocumentIDs", chunk_doc_ids);
        if ~success
            err_msg = 'Unknown error';
            if isa(api_reply, 'matlab.net.http.ResponseMessage')
                fprintf('Raw API Response Body:\n%s\n', api_reply.Body.Data);
                try
                    err_data = jsondecode(api_reply.Body.Data);
                    if isfield(err_data, 'message')
                        err_msg = err_data.message;
                    else
                        err_msg = 'No message field in API response body.';
                    end
                catch
                    err_msg = 'Could not decode JSON from API response body.';
                end
            elseif isstruct(api_reply) && isfield(api_reply, 'message')
                err_msg = api_reply.message;
            end
            error(['Failed to get bulk download URL: ' err_msg]);
        end
        tempZipFilepath = [tempname, '.zip'];
        zipfileCleanupObj = onCleanup(@() deleteIfExists(tempZipFilepath));

        isFinished = false;
        t1 = tic;
        % The download URL may not be immediately ready. Retry until timeout.
        while ~isFinished && toc(t1) < options.Timeout
            try
                websave(tempZipFilepath, downloadUrl);
                isFinished = true;
            catch ME
                pause(1) % Wait a second before retrying
            end
        end

        if ~isFinished
            error('NDI:Cloud:DocumentDownloadFailed', ...
                ['Download failed for chunk %d with message:\n %s\n. If this persists, ', ...
                'consider increasing the Timeout value.'], c, ME.message);
        end

        % Unzip and process documents from the current chunk
        unzippedFiles = unzip(tempZipFilepath,fileparts(tempZipFilepath));
        jsonFile = unzippedFiles{1};
        jsonFileCleanupObj = onCleanup(@() deleteIfExists(jsonFile));

        jsonString = fileread(jsonFile);
        jsonRehydrated = ndi.util.rehydrateJSONNanNull(jsonString);
        documentStructs = jsondecode(jsonRehydrated);

        if isempty(all_document_structs)
            all_document_structs = documentStructs;
        else
            % Use a temporary variable to handle both struct array and cell array cases
            tempStructs = all_document_structs;
            if isstruct(tempStructs), tempStructs = num2cell(tempStructs); end
            if isstruct(documentStructs), documentStructs = num2cell(documentStructs); end
            all_document_structs = [tempStructs; documentStructs];
        end

        % Clean up temporary files for this chunk
        clear zipfileCleanupObj jsonFileCleanupObj;
    end

    fprintf('Download complete. Converting %d structs to NDI documents...\n', numel(all_document_structs));
    documents = ndi.cloud.download.internal.structsToNdiDocuments(all_document_structs);
    fprintf('Processing complete.\n');
end

function deleteIfExists(filePath)
    if isfile(filePath)
        delete(filePath)
    end
end