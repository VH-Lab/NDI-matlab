function [b, answer, apiResponse, apiURL] = finalizeSession(sessionId)
%FINALIZESESSION User-facing wrapper to finalize a compute session.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.finalizeSession(SESSIONID)
%
%   Finalizes a compute session.
%
%   Inputs:
%       sessionId - The ID of the compute session.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The response struct on success, or an error struct/message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.compute.FinalizeSession

    arguments
        sessionId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.compute.FinalizeSession(...
        'sessionId', sessionId);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
