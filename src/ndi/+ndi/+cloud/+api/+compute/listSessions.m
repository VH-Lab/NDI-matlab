function [b, answer, apiResponse, apiURL] = listSessions()
%LISTSESSIONS User-facing wrapper to list all compute sessions for the user.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.listSessions()
%
%   Lists all compute sessions associated with the current user.
%
%   Inputs:
%       None
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The list of sessions on success, or an error struct/message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.compute.ListSessions

    api_call = ndi.cloud.api.implementation.compute.ListSessions();

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
