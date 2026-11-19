function [b, report] = uploadDocumentCollection(datasetId, documentList, options)
% UPLOAD_DOCUMENT_COLLECTION - Upload a collection of documents using bulk or serial upload.
%
%   [b, report] = ndi.cloud.upload.uploadDocumentCollection(datasetId, documentList, options)
%   performs an upload of documents to a specified dataset. The method (batch vs. serial)
%   and batch size can be controlled.
%
%   By default, it uses a bulk upload process. It creates ZIP archives from the
%   document list, retrieves bulk upload URLs, and uploads the ZIP files to the cloud.
%   Each ZIP holds at most 'maxDocumentChunk' documents and at most
%   'maxDocumentBytes' bytes of document JSON, whichever limit is reached first.
%
%   If the environment variable 'NDI_CLOUD_UPLOAD_NO_ZIP' is set to 'true',
%   the documents are uploaded one at a time via a slower serial process.
%
% INPUTS:
%   datasetId      - (1,1) string
%                    The unique identifier for the target NDI Cloud dataset.
%
%   documentList   - (1,:) cell
%                    A cell array of ndi.document objects to be uploaded.
%
%   options.maxDocumentChunk - (1,1) double
%                    The maximum number of documents to include in a single ZIP
%                    archive for batch uploads. Defaults to the preference
%                    Cloud.Upload.Max_Document_Batch_Count (see ndi.preferences).
%
%   options.maxDocumentBytes - (1,1) double
%                    The maximum size, in bytes of encoded JSON, of the
%                    documents in a single ZIP archive for batch uploads. A
%                    single document larger than this is sent in a ZIP of its
%                    own. Defaults to the preference
%                    Cloud.Upload.Max_Document_Batch_Size (50 MB). The server
%                    ingests each ZIP in a Lambda with limited scratch disk, so
%                    one very large JSON file can fail to ingest at all.
%
%   options.onlyUploadMissing - (1,1) logical
%                    If true (default), documents whose ids the dataset
%                    already lists are skipped.
%
%   options.waitForIngestion - (1,1) logical
%                    If true (default), a batch upload does not return until
%                    the server lists the uploaded documents, or until
%                    options.ingestionTimeout elapses. A batch upload returns
%                    once each zip is stored, before the server has ingested
%                    it, so without this a listing made straight afterwards
%                    can miss documents. Serial uploads are not affected.
%                    If the server lists NONE of the stored documents when
%                    the wait ends, the server-side ingestion is treated as
%                    failed: every stored batch is marked 'failure', B is
%                    false, and a NDI:Cloud:Upload:IngestionFailed warning is
%                    issued. (Running the upload again with onlyUploadMissing
%                    sends only what the server still lacks.)
%
%   options.ingestionTimeout - (1,1) double
%                    Seconds to wait for ingestion. Default 300. On a timeout
%                    the function warns (NDI:Cloud:Upload:IngestionTimeout)
%                    and still returns B according to the upload itself,
%                    unless no document at all was ingested (see above).
%
% OUTPUTS:
%   b              - (1,1) logical
%                    A boolean that is true if the entire upload operation
%                    succeeded and false otherwise.
%
%   report         - (1,1) struct
%                    A structure containing a report of the upload operation.
%                    It will have the following fields:
%                    'uploadType': 'batch' or 'serial'.
%                    'manifest': For 'batch' type, a cell array where each entry
%                                is a cell array of document IDs in that batch.
%                                For 'serial' type, this is a cell array of
%                                individual document IDs.
%                    'status': A cell array with 'success' or 'failure' for
%                              each corresponding entry in the manifest.
%                    'ingestion': Present when a batch upload waited for
%                                 ingestion; the ANSWER struct of
%                                 ndi.cloud.api.documents.waitForDocumentCount
%                                 (state, count, expectedCount, elapsed),
%                                 plus countBefore. state is 'failed' when
%                                 the server ingested none of the documents.
%
% EXAMPLE:
%   % Upload a collection of documents in chunks of 100
%   docs = {doc_obj1, doc_obj2, ..., doc_obj250};
%   [success, uploadReport] = ndi.cloud.upload.uploadDocumentCollection("dataset123", docs, maxDocumentChunk=100);
%
% See also:
%   ndi.cloud.api.documents.get_bulk_upload_url
%   ndi.cloud.upload.internal.zip_documents_for_upload
%   ndi.cloud.api.documents.waitForDocumentCount

    arguments
        datasetId (1,1) string
        documentList (1,:) cell
        options.maxDocumentChunk (1,1) double {mustBePositive} = ndi.preferences.get('Cloud.Upload.Max_Document_Batch_Count')
        options.maxDocumentBytes (1,1) double {mustBePositive} = ndi.preferences.get('Cloud.Upload.Max_Document_Batch_Size')
        options.onlyUploadMissing (1,1) logical = true
        options.waitForIngestion (1,1) logical = true
        options.ingestionTimeout (1,1) double {mustBePositive} = 300
    end
    assert(~isempty(documentList), 'List of documents was empty.')

    % --- Pre-processing Step ---
    if options.onlyUploadMissing
        total_local_docs = numel(documentList);
        [success, remoteDocs] = ndi.cloud.api.documents.listDatasetDocumentsAll(datasetId);
        if ~success
            error(['Could not list remote documents to determine which to upload: ' remoteDocs.message]);
        end
        num_remote_docs = numel(remoteDocs);
        remoteDocNdiIds = string({remoteDocs.ndiId});
        localDocNdiIds = string(cellfun(@(x) x.document_properties.base.id, documentList, 'UniformOutput', false));

        [~, keepIndexes] = setdiff(localDocNdiIds, remoteDocNdiIds);
        documentList = documentList(keepIndexes);

        fprintf('Total documents: %d. %d already in cloud. %d remain to be transmitted.\n', ...
            total_local_docs, num_remote_docs, numel(documentList));
    end

    if isempty(documentList)
        b = true;
        report.uploadType = 'none';
        report.manifest = {};
        report.status = {};
        return;
    end

    disp('Uploading dataset documents...');

    % Extract document IDs for the report manifest
    docIds = cellfun(@(x) x.id(), documentList, 'UniformOutput', false);

    ndiCloudUploadNoZipEnvironment = getenv('NDI_CLOUD_UPLOAD_NO_ZIP');
    if isempty(ndiCloudUploadNoZipEnvironment)
       ndiCloudUploadNoZipEnvironment = "false";
    end

    % Initialize progress bar
    app = ndi.gui.component.ProgressBarWindow('NDI tasks');
    uuid = did.ido.unique_id();
    app.addBar('Label','Uploading documents','tag',uuid,'Auto',true);

    % --- Main Logic ---
    if strcmpi(char(ndiCloudUploadNoZipEnvironment),'true')
        % SERIAL UPLOAD
        report.uploadType = 'serial';
        report.manifest = cell(1, numel(documentList));
        report.status = cell(1, numel(documentList));

        for i=1:numel(documentList)
            report.manifest{i} = docIds{i};
            try
                % For serial upload, encode just the document properties.
                % addDocument's success flag must be read: AddDocument.execute
                % swallows exceptions internally (returns ok=false without
                % rethrowing), so the surrounding try/catch alone can never see
                % a failed upload and every status would be recorded 'success'.
                docProperties = documentList{i}.document_properties;
                [ok, ~] = ndi.cloud.api.documents.addDocument(datasetId, ...
                    did.datastructures.jsonencodenan(docProperties));
                if ok
                    report.status{i} = 'success';
                else
                    report.status{i} = 'failure';
                end
            catch ME
                % Keep the catch for genuinely thrown errors, but say what
                % happened. Recording 'failure' and discarding the reason is
                % how the unqualified jsonencodenan call above survived: it
                % could never resolve, so every document on this path failed,
                % and the report said only that they had failed.
                report.status{i} = 'failure';
                warning('NDI:Cloud:Upload:DocumentUploadFailed', ...
                    'Upload of document %s failed: %s', ...
                    string(docIds{i}), ME.message);
            end
            app.updateBar(uuid, i / numel(documentList));
        end

    else
        % BATCH (ZIP) UPLOAD
        report.uploadType = 'batch';
        report.manifest = {};
        report.status = {};

        % The server's count before this upload, so the ingestion wait
        % below knows what count to expect. NaN skips the wait.
        countBefore = NaN;
        if options.waitForIngestion
            try
                [okCount, countAnswer] = ndi.cloud.api.documents.documentCount(datasetId);
                if okCount && isnumeric(countAnswer) && isscalar(countAnswer)
                    countBefore = double(countAnswer);
                end
            catch
            end
        end

        docCount = numel(documentList);

        % Encode each document once, both to size the batches and to
        % write the zips. Batches end at maxDocumentChunk documents or
        % maxDocumentBytes of JSON, whichever comes first. (Character
        % count is used as the byte size; it is exact for ASCII JSON.)
        documentJson = cellfun(@(x) did.datastructures.jsonencodenan(x.document_properties), ...
            documentList, 'UniformOutput', false);
        documentSizes = cellfun(@numel, documentJson);
        batchRanges = ndi.cloud.upload.internal.documentBatchRanges(...
            documentSizes, options.maxDocumentChunk, options.maxDocumentBytes);
        if numel(batchRanges) > 1
            fprintf('Sending %d documents (%.1f MB of JSON) in %d batches.\n', ...
                docCount, sum(documentSizes)/1e6, numel(batchRanges));
        end

        for k = 1:numel(batchRanges)
            batchIndexes = batchRanges{k};
            endIndex = batchIndexes(end);
            
            % Pass the chunk of ndi.document objects directly
            chunkDocs = documentList(batchIndexes);
            
            zipFilePath = ''; % Initialize to ensure it's in scope for cleanup
            idManifest = {};
            
            try
                % Create zip file for the current chunk
                [zipFilePath, idManifest] = ...
                    ndi.cloud.upload.internal.zip_documents_for_upload(chunkDocs, datasetId, ...
                    'DocumentJson', documentJson(batchIndexes));
                
                % Get upload URL and perform upload
                [success, uploadUrl] = ndi.cloud.api.documents.getBulkUploadURL(datasetId);
                if ~success
                    error(['Failed to get bulk upload URL: ' uploadUrl.message]);
                end
                [batchUploadSucces] = ndi.cloud.api.files.putFiles(uploadUrl, zipFilePath);
                if ~batchUploadSucces
                    error('Failed to actually upload');
                end
                
                % If we reached here, the upload was successful
                report.manifest{end+1} = idManifest;
                report.status{end+1} = 'success';
                delete(zipFilePath); % Clean up the file
                
            catch ME
                % The upload failed
                warning('NDI:Cloud:Upload:BatchUploadFailed', ...
                    'Upload of document batch %d of %d failed: %s', ...
                    k, numel(batchRanges), ME.message);
                if isempty(idManifest) % if zipping failed before manifest was created
                    idManifest = cellfun(@(x) x.id(), chunkDocs, 'UniformOutput', false);
                end
                report.manifest{end+1} = idManifest; % Still log the manifest
                report.status{end+1} = 'failure';
                % Clean up the file if it was created before the error
                if isfile(zipFilePath)
                    delete(zipFilePath);
                end
            end
            app.updateBar(uuid, endIndex / docCount);
        end
    end
    
    % Close progress bar window upon completion
    delete(app);

    % A stored zip is not yet an ingested one, and bulk document uploads
    % have no job to wait on, so wait for the server's document count to
    % take in every document from the batches that were stored. The server
    % adds a new document for each one uploaded, even one whose id it
    % already lists, so the count grows by exactly that many.
    if strcmp(report.uploadType, 'batch') && ~isnan(countBefore)
        numStored = sum(cellfun(@numel, report.manifest(strcmp(report.status, 'success'))));
        if numStored > 0
            expectedCount = countBefore + numStored;
            fprintf('Waiting for the server to list %d uploaded documents...\n', numStored);
            try
                [ingested, report.ingestion] = ndi.cloud.api.documents.waitForDocumentCount(...
                    datasetId, expectedCount, 'timeout', options.ingestionTimeout);
            catch ME
                ingested = false;
                report.ingestion = struct('state', 'error', 'count', NaN, ...
                    'expectedCount', expectedCount, 'elapsed', NaN, 'message', ME.message);
            end
            report.ingestion.countBefore = countBefore;
            if ~ingested && isfinite(report.ingestion.count) && report.ingestion.count <= countBefore
                % The server stored the zips but listed none of their
                % documents by the deadline: its ingestion failed (or has
                % not started at all). Report the upload as failed so
                % callers (e.g. sync) do not record these documents as
                % present; uploading again sends only what is missing.
                report.ingestion.state = 'failed';
                storedBatches = strcmp(report.status, 'success');
                report.status(storedBatches) = {'failure'};
                warning('NDI:Cloud:Upload:IngestionFailed', ...
                    ['Dataset %s still lists %g documents %.0f s after %d documents were ' ...
                    'uploaded in %d batch(es): the server ingested none of them. The ' ...
                    'server-side ingestion failed or is badly delayed; the upload is ' ...
                    'reported as failed. Run the upload again later (only missing ' ...
                    'documents are sent), and if it fails again ask an NDI Cloud ' ...
                    'administrator to check the bulk document upload logs.'], ...
                    datasetId, report.ingestion.count, report.ingestion.elapsed, ...
                    numStored, nnz(storedBatches));
            elseif ~ingested
                warning('NDI:Cloud:Upload:IngestionTimeout', ...
                    ['Dataset %s lists %g of the %d documents expected after this upload ' ...
                    '(state: %s). The upload succeeded; the server may still be ' ...
                    'ingesting the rest.'], ...
                    datasetId, report.ingestion.count, expectedCount, report.ingestion.state);
            end
        end
    end

    % Determine overall success from the report
    b = ~any(strcmp(report.status, 'failure'));
end