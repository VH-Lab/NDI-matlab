classdef GetOrganization < ndi.cloud.api.call
    %GETORGANIZATION Implements GET /admin/organizations/{organizationId} (admin only).
    %
    %   See also: ndi.cloud.api.admin.getOrganization

    methods
        function this = GetOrganization(args)
            arguments
                args.cloudOrganizationID (1,1) string
            end

            this.cloudOrganizationID = args.cloudOrganizationID;
            this.endpointName = "admin_get_organization";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Retrieves an organization with its members.
            %
            %   On success (200), ANSWER is the organization struct plus the
            %   convenience fields added by addMemberFields.

            apiURL = ndi.cloud.api.url(this.endpointName, ...
                'organization_id', this.cloudOrganizationID);

            [apiResponse, answer] = ndi.cloud.api.implementation.admin.sendRequest( ...
                matlab.net.http.RequestMethod.GET, apiURL);
            b = (apiResponse.StatusCode == 200);
            if b
                answer = ndi.cloud.api.implementation.admin.GetOrganization.addMemberFields(answer);
            end
        end
    end

    methods (Static)
        function org = addMemberFields(org)
            %ADDMEMBERFIELDS Add parallel member convenience fields to an organization.
            %
            %   ORG = addMemberFields(ORG) adds 'memberID', 'memberName' and
            %   'memberEmail', parallel cell arrays of char built from the
            %   'members' field (each member has 'id', 'name' and 'email').
            %   The raw 'members' field is left untouched.

            asChar = @(v) char(string(v));
            org.memberID = {};
            org.memberName = {};
            org.memberEmail = {};
            if ~isfield(org, 'members')
                return
            end
            members = ndi.cloud.api.implementation.admin.asStructCell(org.members);
            for i = 1:numel(members)
                m = members{i};
                org.memberID{end+1} = asChar(m.id);
                org.memberName{end+1} = asChar(m.name);
                org.memberEmail{end+1} = asChar(m.email);
            end
        end
    end
end
