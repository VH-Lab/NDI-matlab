function [b, answer, apiResponse, apiURL] = startSession(pipelineId, inputParameters)
%STARTSESSION User-facing wrapper to start a new compute session.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.startSession(PIPELINEID, INPUTPARAMETERS)
%
%   Starts a new compute session for the specified pipeline.
%
%   Inputs:
%       pipelineId      - The ID of the pipeline to start.
%       inputParameters - (Optional) Structure containing input parameters. Defaults to empty struct.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The response struct on success, or an error struct/message on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.implementation.compute.StartSession

    arguments
        pipelineId (1,1) string
        inputParameters (1,1) struct = struct()
    end

    api_call = ndi.cloud.api.implementation.compute.StartSession(...
        'pipelineId', pipelineId, 'inputParameters', inputParameters);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
