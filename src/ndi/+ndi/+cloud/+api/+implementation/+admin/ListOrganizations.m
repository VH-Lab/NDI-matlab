classdef ListOrganizations < ndi.cloud.api.call
    %LISTORGANIZATIONS Implements GET /admin/organizations (admin only).
    %
    %   See also: ndi.cloud.api.admin.listOrganizations

    properties
        query (1,1) string = ""
    end

    methods
        function this = ListOrganizations(args)
            arguments
                args.query (1,1) string = ""
                args.page (1,1) double {mustBePositive, mustBeInteger} = 1
                args.pageSize (1,1) double {mustBePositive, mustBeInteger} = 25
            end

            this.query = args.query;
            this.page = args.page;
            this.pageSize = args.pageSize;
            this.endpointName = "admin_list_organizations";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Lists one page of organizations, sorted by name.
            %
            %   On success (200), ANSWER is a struct with fields
            %   'organizations', 'page', 'limit', 'total' and 'totalPages'.

            apiURL = ndi.cloud.api.url(this.endpointName);
            apiURL = ndi.cloud.api.implementation.admin.addQuery(apiURL, ...
                this.query, this.page, this.pageSize);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.GET, apiURL);
            b = (apiResponse.StatusCode == 200);
        end
    end
end
