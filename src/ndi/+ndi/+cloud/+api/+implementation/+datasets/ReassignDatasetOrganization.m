classdef ReassignDatasetOrganization < ndi.cloud.api.call
    %REASSIGNDATASETORGANIZATION Implements POST /admin/datasets/{datasetId}/organization (admin only).
    %
    %   Sends struct('organizationId', ..., 'reason', ...) as the JSON body.
    %   The server answers 403 unless the caller is an administrator.
    %
    %   This class sends REASON as given, without the non-blank check the
    %   user-facing wrapper makes, so that tests can confirm the server
    %   enforces it too.
    %
    %   See also: ndi.cloud.api.datasets.reassignDatasetOrganization

    properties
        reason (1,1) string
    end

    methods
        function this = ReassignDatasetOrganization(args)
            %REASSIGNDATASETORGANIZATION Creates a new ReassignDatasetOrganization API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.ReassignDatasetOrganization( ...
            %      'cloudDatasetID', ID, 'cloudOrganizationID', ORGID, 'reason', REASON)
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudOrganizationID (1,1) string
                args.reason (1,1) string
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudOrganizationID = args.cloudOrganizationID;
            this.reason = args.reason;
            this.endpointName = "admin_reassign_dataset_organization";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to move the dataset.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   On success (200), ANSWER is the updated dataset struct.

            apiURL = ndi.cloud.api.url(this.endpointName, ...
                'dataset_id', this.cloudDatasetID);

            body = struct('organizationId', char(this.cloudOrganizationID), ...
                'reason', char(this.reason));

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.POST, apiURL, body);
            b = (apiResponse.StatusCode == 200);
        end
    end
end
