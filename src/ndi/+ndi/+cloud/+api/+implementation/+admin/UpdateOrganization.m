classdef UpdateOrganization < ndi.cloud.api.call
    %UPDATEORGANIZATION Implements PATCH /admin/organizations/{organizationId} (admin only).
    %
    %   Sends UPDATES as the JSON body as-is. The server accepts the fields
    %   'name' (non-empty string) and 'canUploadDataset' (logical), and
    %   answers 400 if neither is present.
    %
    %   See also: ndi.cloud.api.admin.updateOrganization

    properties
        updates (1,1) struct
    end

    methods
        function this = UpdateOrganization(args)
            arguments
                args.cloudOrganizationID (1,1) string
                args.updates (1,1) struct
            end

            this.cloudOrganizationID = args.cloudOrganizationID;
            this.updates = args.updates;
            this.endpointName = "admin_update_organization";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Updates an organization.
            %
            %   On success (200), ANSWER is the updated organization struct.

            apiURL = ndi.cloud.api.url(this.endpointName, ...
                'organization_id', this.cloudOrganizationID);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.PATCH, apiURL, this.updates);
            b = (apiResponse.StatusCode == 200);
        end
    end
end
