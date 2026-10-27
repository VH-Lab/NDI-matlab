classdef GetUser < ndi.cloud.api.call
    %GETUSER Implements GET /admin/users/{userId} (admin only).
    %
    %   See also: ndi.cloud.api.admin.getUser

    methods
        function this = GetUser(args)
            arguments
                args.cloudUserID (1,1) string
            end

            this.cloudUserID = args.cloudUserID;
            this.endpointName = "admin_get_user";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Retrieves a user, including the organizations they belong to.
            %
            %   On success (200), ANSWER is the user struct plus
            %   'organizationID' and 'organizationName', parallel cell
            %   arrays of char built from its 'organizations' field.

            apiURL = ndi.cloud.api.url(this.endpointName, 'user_id', this.cloudUserID);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.GET, apiURL);
            b = (apiResponse.StatusCode == 200);
            if b
                if isfield(answer, 'id')
                    answer.id = char(string(answer.id));
                end
                orgs = {};
                if isfield(answer, 'organizations')
                    orgs = answer.organizations;
                end
                [answer.organizationID, answer.organizationName] = ...
                    ndi.cloud.api.implementation.users.Me.parseOrganizations(orgs);
            end
        end
    end
end
