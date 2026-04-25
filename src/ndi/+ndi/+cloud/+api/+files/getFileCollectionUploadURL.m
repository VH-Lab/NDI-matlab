function [b, answer, apiResponse, apiURL] = getFileCollectionUploadURL(cloudDatasetID)
%GETFILECOLLECTIONUPLOADURL Get a pre-signed URL for uploading a file collection (zip).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getFileCollectionUploadURL(CLOUDDATASETID)
%
%   Retrieves a URL that can be used to PUT a zip archive containing multiple files
%   for a dataset.
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - On success, a struct with fields:
%                        url   - The pre-signed PUT URL for the zip archive.
%                        jobId - Identifier of the server-side extraction job.
%                                Pass it to ndi.cloud.api.files.waitForBulkUpload
%                                (or to ndi.cloud.api.files.putFiles with
%                                'waitForCompletion', true) to wait for the
%                                server to finish extracting the zip before
%                                attempting to download the extracted files.
%                                Empty string if the server did not return a
%                                job id (older server versions).
%                      On failure, the server error payload.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, info] = ndi.cloud.api.files.getFileCollectionUploadURL('d-12345');
%       if success
%           [ok] = ndi.cloud.api.files.putFiles(info.url, 'bundle.zip', ...
%               'jobId', info.jobId, 'waitForCompletion', true);
%       end
%
%   See also: ndi.cloud.api.implementation.files.GetFileCollectionUploadURL,
%             ndi.cloud.api.files.putFiles,
%             ndi.cloud.api.files.waitForBulkUpload

    arguments
        cloudDatasetID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.files.GetFileCollectionUploadURL('cloudDatasetID', cloudDatasetID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

