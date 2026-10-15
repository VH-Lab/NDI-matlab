classdef ListUsers < ndi.cloud.api.call
    %LISTUSERS Implements GET /admin/users (admin only).
    %
    %   See also: ndi.cloud.api.admin.listUsers

    properties
        query (1,1) string = ""
    end

    methods
        function this = ListUsers(args)
            arguments
                args.query (1,1) string = ""
                args.page (1,1) double {mustBePositive, mustBeInteger} = 1
                args.pageSize (1,1) double {mustBePositive, mustBeInteger} = 25
            end

            this.query = args.query;
            this.page = args.page;
            this.pageSize = args.pageSize;
            this.endpointName = "admin_list_users";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Lists one page of active users, sorted by email.
            %
            %   On success (200), ANSWER is a struct with fields 'users',
            %   'page', 'limit', 'total' and 'totalPages'.

            apiURL = ndi.cloud.api.url(this.endpointName);
            apiURL = ndi.cloud.api.implementation.admin.addQuery(apiURL, ...
                this.query, this.page, this.pageSize);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.GET, apiURL);
            b = (apiResponse.StatusCode == 200);
        end
    end
end
