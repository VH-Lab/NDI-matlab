classdef CreateOrganization < ndi.cloud.api.call
    %CREATEORGANIZATION Implements POST /admin/organizations (admin only).
    %
    %   See also: ndi.cloud.api.admin.createOrganization

    properties
        name (1,1) string
        canUploadDataset (1,1) logical = false
    end

    methods
        function this = CreateOrganization(args)
            arguments
                args.name (1,1) string
                args.canUploadDataset (1,1) logical = false
            end

            this.name = args.name;
            this.canUploadDataset = args.canUploadDataset;
            this.endpointName = "admin_create_organization";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Creates an organization with no members.
            %
            %   On success (201), ANSWER is the new organization struct.

            apiURL = ndi.cloud.api.url(this.endpointName);
            body = struct('name', this.name, 'canUploadDataset', this.canUploadDataset);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.POST, apiURL, body);
            b = (apiResponse.StatusCode == 201);
        end
    end
end
