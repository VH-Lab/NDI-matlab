function [b, answer, apiResponse, apiURL] = triggerStage(sessionId, stageId)
%TRIGGERSTAGE User-facing wrapper to trigger a stage in a compute session.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.triggerStage(SESSIONID, STAGEID)
%
%   Triggers a specific stage in a compute session.
%
%   Inputs:
%       sessionId - The ID of the compute session.
%       stageId   - The ID of the stage to trigger.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The response struct on success, or an error struct/message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.compute.TriggerStage

    arguments
        sessionId (1,1) string
        stageId (1,1) string
    end

    api_call = ndi.cloud.api.implementation.compute.TriggerStage(...
        'sessionId', sessionId, 'stageId', stageId);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
