function [b, answer, apiResponse, apiURL] = startSession(pipelineId, organizationId, inputParameters)
%STARTSESSION User-facing wrapper to start a new compute session.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.compute.startSession(PIPELINEID, ORGANIZATIONID)
%   [...] = ndi.cloud.api.compute.startSession(PIPELINEID, ORGANIZATIONID, INPUTPARAMETERS)
%
%   Starts a new compute session for the specified pipeline, billed to the
%   specified organization.
%
%   Inputs:
%       pipelineId      - The ID of the pipeline to start.
%       organizationId  - The ID of the organization that owns this compute
%                         session. The backend requires this whenever the
%                         caller is a member of more than one organization,
%                         and rejects the request with HTTP 400 "Organization
%                         ID is required (user has multiple)" if it isn't
%                         supplied. Callers who belong to a single organization
%                         may still be required to pass their id explicitly;
%                         see VH-Lab/NDI-matlab#936 for the rationale.
%       inputParameters - (Optional) Structure containing input parameters.
%                         Defaults to empty struct.
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
        organizationId (1,1) string
        inputParameters (1,1) struct = struct()
    end

    api_call = ndi.cloud.api.implementation.compute.StartSession(...
        'pipelineId', pipelineId, ...
        'organizationId', organizationId, ...
        'inputParameters', inputParameters);

    [b, answer, apiResponse, apiURL] = api_call.execute();

end
