function [b, answer, apiResponse, apiURL] = reassignDatasetOrganization(cloudDatasetID, cloudOrganizationID, reason)
%REASSIGNDATASETORGANIZATION Move a dataset to a different organization (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
%       CLOUDDATASETID, CLOUDORGANIZATIONID, REASON)
%
%   Moves the dataset CLOUDDATASETID into the organization
%   CLOUDORGANIZATIONID. Membership in a dataset's organization is what
%   grants access to it while it is unpublished, so this changes who can
%   see and edit the data. For that reason the server allows it only for
%   accounts with administrator rights (others get B = false and a 403
%   response), requires a REASON, and writes the change, with the old and
%   new organizations and the reason, to its audit log.
%
%   The ordinary metadata update (ndi.cloud.api.datasets.updateDataset)
%   never changes a dataset's organization.
%
%   The server refuses the move (B = false) when:
%       - the dataset is already in that organization (400)
%       - the dataset or the organization does not exist, or the dataset
%         is deleted (404)
%       - the dataset is being published or unpublished, or changed while
%         the move was being made (409)
%
%   Inputs:
%       cloudDatasetID      - The ID of the dataset to move.
%       cloudOrganizationID - The ID of the organization to move it into.
%       reason              - Why the dataset is being moved (non-empty
%                             text, recorded in the audit log).
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the updated dataset struct (as returned
%                     by the admin dataset endpoints). On failure, the
%                     server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   Example:
%       [b, ds] = ndi.cloud.api.datasets.reassignDatasetOrganization( ...
%           datasetId, newOrgId, "Lab merged into the Smith lab organization");
%
%   See also: ndi.cloud.api.datasets.updateDataset,
%             ndi.cloud.api.implementation.datasets.ReassignDatasetOrganization

    arguments
        cloudDatasetID (1,1) string
        cloudOrganizationID (1,1) string
        reason (1,1) string {mustBeNonzeroLengthText}
    end

    if strlength(strtrim(reason)) == 0
        error('NDI:Cloud:Datasets:ReasonRequired', ...
            'A non-blank reason is required to move a dataset to another organization.');
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.datasets.ReassignDatasetOrganization( ...
        'cloudDatasetID', cloudDatasetID, ...
        'cloudOrganizationID', cloudOrganizationID, ...
        'reason', reason);

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
