function [b, answer, apiResponse, apiURL] = createSignedURLSetJob(cloudDatasetID, cloudDocumentID, options)
%CREATESIGNEDURLSETJOB Start an async job building a document's signed URL map.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.documents.createSignedURLSetJob(CLOUD_DATASET_ID, CLOUD_DOCUMENT_ID)
%   [...] = ndi.cloud.api.documents.createSignedURLSetJob(..., 'fileSeries', NAME)
%
%   Asks the server to sign every file the document references and write the
%   whole uid -> URL map as one gzipped JSON blob. Returns immediately with a
%   jobId; poll ndi.cloud.api.documents.waitForSignedURLSetJob, then fetch the
%   blob with ndi.cloud.api.documents.getSignedURLSetResult.
%
%   Use this instead of paging when the document references thousands of files.
%
%   Inputs:
%       cloudDatasetID  - The ID of the dataset containing the document.
%       cloudDocumentID - The cloud API document ID.
%
%   Name-Value Pairs:
%       'fileSeries' (string) - Restrict the job to one named file series.
%
%   Outputs:
%       b            - True if the job was accepted.
%       answer       - On success, a struct with jobId, datasetId, documentId,
%                      statusUrl and pollAfterSec. On failure, the error body.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.documents.CreateSignedURLSetJob,
%             ndi.cloud.api.documents.waitForSignedURLSetJob,
%             ndi.cloud.api.documents.getSignedURLSetResult

    arguments
        cloudDatasetID (1,1) string
        cloudDocumentID (1,1) string
        options.fileSeries (1,1) string = ""
    end

    api_call = ndi.cloud.api.implementation.documents.CreateSignedURLSetJob(...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudDocumentID', cloudDocumentID, ...
        'fileSeries', options.fileSeries);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
