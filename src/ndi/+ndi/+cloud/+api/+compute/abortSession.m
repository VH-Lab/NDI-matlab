function [b, answer, apiResponse, apiURL] = abortSession(sessionId)
%ABORTSESSION User-facing wrapper to abort a compute session.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.abortSession(SESSIONID)
%
%   Aborts a running compute session.
%
%   Inputs:
%       sessionId - The ID of the compute session.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - Empty on success, or an error struct/message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.compute.AbortSession

    arguments
        sessionId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.compute.AbortSession(...
        'sessionId', sessionId);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
