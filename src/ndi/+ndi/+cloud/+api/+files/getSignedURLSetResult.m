function [b, answer, apiResponse, apiURL] = getSignedURLSetResult(resultUrl)
%GETSIGNEDURLSETRESULT Download and parse the blob a signed-url-set job produced.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.getSignedURLSetResult(RESULTURL)
%
%   Inputs:
%       resultUrl - The resultUrl reported by a job in state 'ready'.
%
%   Outputs:
%       b            - True if the blob was downloaded and parsed.
%       answer       - On success, a struct with fields:
%                        files       - containers.Map from uid to signed URL
%                        fileCount   - the count the server reported
%                        generatedAt - when the server built the map
%                      On failure, a struct with field 'error'.
%       apiResponse  - Always [] (the download does not go through
%                      matlab.net.http).
%       apiURL       - The result URL that was fetched.
%
%   Example:
%       [ok, job] = ndi.cloud.api.files.createSignedURLSetJob(dsid, docid);
%       [ok, st]  = ndi.cloud.api.files.waitForSignedURLSetJob(job.jobId);
%       [ok, res] = ndi.cloud.api.files.getSignedURLSetResult(st.resultUrl);
%
%   See also: ndi.cloud.api.implementation.files.GetSignedURLSetResult,
%             ndi.cloud.api.files.waitForSignedURLSetJob

    arguments
        resultUrl (1,1) string
    end

    api_call = ndi.cloud.api.implementation.files.GetSignedURLSetResult(...
        'resultUrl', resultUrl);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
