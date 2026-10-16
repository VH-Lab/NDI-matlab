classdef RemoveOrganizationMember < ndi.cloud.api.call
    %REMOVEORGANIZATIONMEMBER Implements DELETE /admin/organizations/{organizationId}/members/{userId} (admin only).
    %
    %   See also: ndi.cloud.api.admin.removeOrganizationMember

    methods
        function this = RemoveOrganizationMember(args)
            arguments
                args.cloudOrganizationID (1,1) string
                args.cloudUserID (1,1) string
            end

            this.cloudOrganizationID = args.cloudOrganizationID;
            this.cloudUserID = args.cloudUserID;
            this.endpointName = "admin_remove_organization_member";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Removes a user from an organization.
            %
            %   Removing a user who is not a member succeeds and changes
            %   nothing. On success (200), ANSWER is the organization with
            %   its updated member list (see GetOrganization.addMemberFields).

            apiURL = ndi.cloud.api.url(this.endpointName, ...
                'organization_id', this.cloudOrganizationID, ...
                'user_id', this.cloudUserID);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.DELETE, apiURL);
            b = (apiResponse.StatusCode == 200);
            if b
                answer = ndi.cloud.api.implementation.admin.GetOrganization.addMemberFields(answer);
            end
        end
    end
end
