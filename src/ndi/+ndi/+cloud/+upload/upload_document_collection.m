function [b, report] = upload_document_collection(datasetId, documentList, options)
% UPLOAD_DOCUMENT_COLLECTION - Upload a collection of documents using bulk or serial upload.
%
%   [b, report] = ndi.cloud.upload.upload_document_collection(datasetId, documentList, options)
%   performs an upload of documents to a specified dataset. The method (batch vs. serial)
%   and batch size can be controlled.
%
%   By default, it uses a bulk upload process. It creates ZIP archives from the
%   document list, retrieves bulk upload URLs, and uploads the ZIP files to the cloud.
%   This process can be broken into chunks using the 'maxDocumentChunk' option.
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
%                    archive for batch uploads. Defaults to Inf (all documents
%                    in one batch).
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
%
% EXAMPLE:
%   % Upload a collection of documents in chunks of 100
%   docs = {doc_obj1, doc_obj2, ..., doc_obj250};
%   [success, uploadReport] = ndi.cloud.upload.upload_document_collection("dataset123", docs, maxDocumentChunk=100);
%
% See also:
%   ndi.cloud.api.documents.get_bulk_upload_url
%   ndi.cloud.upload.internal.zip_documents_for_upload

    arguments
        datasetId (1,1) string
        documentList (1,:) cell
        options.maxDocumentChunk (1,1) double = Inf
    end
    assert(~isempty(documentList), 'List of documents was empty.')

    % --- Pre-processing Step ---
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
                % For serial upload, encode just the document properties
                docProperties = documentList{i}.document_properties;
                [~,~] = ndi.cloud.api.documents.addDocument(datasetId, jsonencodenan(docProperties));
                report.status{i} = 'success';
            catch
                report.status{i} = 'failure';
            end
            app.updateBar(uuid, i / numel(documentList));
        end

    else
        % BATCH (ZIP) UPLOAD
        report.uploadType = 'batch';
        report.manifest = {};
        report.status = {};
        
        docCount = numel(documentList);
        for i = 1:options.maxDocumentChunk:docCount
            startIndex = i;
            endIndex = min(i + options.maxDocumentChunk - 1, docCount);
            
            % Pass the chunk of ndi.document objects directly
            chunkDocs = documentList(startIndex:endIndex);
            
            zipFilePath = ''; % Initialize to ensure it's in scope for cleanup
            idManifest = {};
            
            try
                % Create zip file for the current chunk
                [zipFilePath, idManifest] = ...
                    ndi.cloud.upload.internal.zip_documents_for_upload(chunkDocs, datasetId);
                
                % Get upload URL and perform upload
                [success, uploadUrl] = ndi.cloud.api.documents.getBulkUploadURL(datasetId);
                if ~success
                    error(['Failed to get bulk upload URL: ' uploadUrl.message]);
                end
                ndi.cloud.api.files.putFiles(uploadUrl, zipFilePath);
                
                % If we reached here, the upload was successful
                report.manifest{end+1} = idManifest;
                report.status{end+1} = 'success';
                delete(zipFilePath); % Clean up the file
                
            catch
                % The upload failed
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
    
    % Determine overall success from the report
    b = ~any(strcmp(report.status, 'failure'));

    % Close progress bar window upon completion
    delete(app);
end