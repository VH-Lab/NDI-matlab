function [b, answer, apiResponse, apiURL] = advanceSession(sessionId)
%ADVANCESESSION User-facing wrapper to advance a compute session to the next stage.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.advanceSession(SESSIONID)
%
%   Advances a compute session to the next stage
%   (POST /compute/{sessionId}/advance). Advancing past the last stage
%   finalizes the session; there is no separate finalize endpoint.
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
%   See also: ndi.cloud.api.implementation.compute.AdvanceSession

    arguments
        sessionId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.compute.AdvanceSession(...
        'sessionId', sessionId);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
