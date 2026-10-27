classdef AddOrganizationMember < ndi.cloud.api.call
    %ADDORGANIZATIONMEMBER Implements POST /admin/organizations/{organizationId}/members (admin only).
    %
    %   See also: ndi.cloud.api.admin.addOrganizationMember

    methods
        function this = AddOrganizationMember(args)
            arguments
                args.cloudOrganizationID (1,1) string
                args.cloudUserID (1,1) string
            end

            this.cloudOrganizationID = args.cloudOrganizationID;
            this.cloudUserID = args.cloudUserID;
            this.endpointName = "admin_add_organization_member";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Adds a user to an organization.
            %
            %   Adding a user who is already a member succeeds and changes
            %   nothing. On success (200), ANSWER is the organization with
            %   its updated member list (see GetOrganization.addMemberFields).

            apiURL = ndi.cloud.api.url(this.endpointName, ...
                'organization_id', this.cloudOrganizationID);
            body = struct('userId', this.cloudUserID);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.POST, apiURL, body);
            b = (apiResponse.StatusCode == 200);
            if b
                answer = ndi.cloud.api.implementation.admin.GetOrganization.addMemberFields(answer);
            end
        end
    end
end
