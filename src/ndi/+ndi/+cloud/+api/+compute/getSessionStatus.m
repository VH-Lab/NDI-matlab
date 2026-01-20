function [b, answer, apiResponse, apiURL] = getSessionStatus(sessionId)
%GETSESSIONSTATUS User-facing wrapper to get the status of a compute session.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.getSessionStatus(SESSIONID)
%
%   Retrieves the status/details of a compute session.
%
%   Inputs:
%       sessionId - The ID of the compute session.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The session details struct on success, or an error struct/message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.compute.GetSessionStatus

    arguments
        sessionId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.compute.GetSessionStatus(...
        'sessionId', sessionId);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
