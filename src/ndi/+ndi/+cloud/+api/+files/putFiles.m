function [b, answer, apiResponse, apiURL] = putFiles(preSignedURL, filePath, options)
%PUTFILES Uploads a local file to a given pre-signed URL.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.putFiles(PRESIGNEDURL, FILEPATH, ...)
%
%   Performs an HTTP PUT request to upload the file specified by FILEPATH
%   to the PRESIGNEDURL. This is typically used after obtaining a URL from
%   a function like getFileUploadURL or getFileCollectionUploadURL.
%
%   Inputs:
%       preSignedURL - The pre-signed URL for the upload, obtained from the API.
%       filePath     - The path to the local file to upload.
%
%   Name-Value Pairs:
%       'useCurl' (logical) - If true, the function will use a system call
%                             to the `curl` command-line tool to perform the
%                             upload. Defaults to true so every upload path
%                             stores objects in S3 with consistent headers
%                             (the MATLAB HTTP client can tag objects
%                             differently, producing flaky downloads).
%
%       'jobId' (string)    - The bulk-upload job identifier returned by
%                             ndi.cloud.api.files.getFileCollectionUploadURL.
%                             Only meaningful for bulk (zip) uploads;
%                             ignored for single-file uploads. Defaults to "".
%
%       'waitForCompletion' (logical) - If true, after a successful PUT the
%                             function polls the bulk-upload job via
%                             ndi.cloud.api.files.waitForBulkUpload and only
%                             returns once the server has finished
%                             extracting the zip (or the timeout is hit).
%                             Requires a non-empty jobId. Single-file
%                             uploads have no server-side job to wait on;
%                             the signed PUT returning 200 already means
%                             done. Defaults to false.
%
%       'timeout' (double)  - Overall wait-for-completion deadline, in
%                             seconds. Default 60.
%
%   Outputs:
%       b            - True if the upload succeeded (and, when
%                      waitForCompletion is true, the server-side bulk
%                      extraction job reached state 'complete').
%       answer       - A success message or an error structure from the
%                      server. When waitForCompletion is true, this is the
%                      final bulk-upload status struct.
%       apiResponse  - The full matlab.net.http.ResponseMessage object (or a struct
%                      if using curl). When waitForCompletion is true, this
%                      is the ResponseMessage from the last status poll.
%       apiURL       - The URL that was called. When waitForCompletion is
%                      true, this is the URL of the last status poll.
%
%   Example:
%       % Single-file upload
%       [s, url] = ndi.cloud.api.files.getFileUploadURL('d-123', 'f-abc');
%       if s
%           [s2] = ndi.cloud.api.files.putFiles(url, 'localfile.dat');
%       end
%
%       % Bulk (zip) upload, waiting for server-side extraction to finish
%       [s, info] = ndi.cloud.api.files.getFileCollectionUploadURL('d-123');
%       if s
%           [s2] = ndi.cloud.api.files.putFiles(info.url, 'bundle.zip', ...
%               'jobId', info.jobId, 'waitForCompletion', true);
%       end
%
%   See also: ndi.cloud.api.implementation.files.PutFiles,
%             ndi.cloud.api.files.getFileUploadURL,
%             ndi.cloud.api.files.getFileCollectionUploadURL,
%             ndi.cloud.api.files.waitForBulkUpload
%
    arguments
        preSignedURL (1,1) string
        filePath (1,1) string {mustBeFile}
        options.useCurl (1,1) logical = true
        options.jobId (1,1) string = ""
        options.waitForCompletion (1,1) logical = false
        options.timeout (1,1) double {mustBePositive} = 60
    end
    % 1. Create an instance of the implementation class, passing the options.
    api_call = ndi.cloud.api.implementation.files.PutFiles(...
        'preSignedURL', preSignedURL, ...
        'filePath', filePath, ...
        'useCurl', options.useCurl, ...
        'jobId', options.jobId, ...
        'waitForCompletion', options.waitForCompletion, ...
        'timeout', options.timeout);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
