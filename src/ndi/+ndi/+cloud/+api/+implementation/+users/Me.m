classdef Me < ndi.cloud.api.call
%ME Implementation class for retrieving current user information.

    methods
        function this = Me()
            %ME Creates a new Me API call object.

            this.endpointName = 'get_current_user';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to retrieve current user information.

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName);

            method = matlab.net.http.RequestMethod.GET;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;

                % Ensure id is a character array
                if isfield(answer, 'id') && isstring(answer.id)
                    answer.id = char(answer.id);
                end

                % Process the organizations list into parallel convenience
                % arrays. The raw 'organizations' field is left untouched for
                % callers that want the full structs.
                answer.organizationID = {};
                answer.organizationName = {};
                answer.organizationCanUploadDataset = {};

                if isfield(answer, 'organizations')
                    [answer.organizationID, answer.organizationName, ...
                        answer.organizationCanUploadDataset] = ...
                        ndi.cloud.api.implementation.users.Me.parseOrganizations(...
                        answer.organizations);
                end
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                elseif isprop(apiResponse.Body, 'Payload')
                     answer = apiResponse.Body.Payload;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end

    methods (Static)
        function [orgID, orgName, orgCanUpload] = parseOrganizations(orgs)
            %PARSEORGANIZATIONS Extract parallel id/name/upload arrays from an
            %   organizations list.
            %
            %   [ORGID, ORGNAME, ORGCANUPLOAD] = parseOrganizations(ORGS)
            %
            %   ORGS is the 'organizations' field returned by the NDI Cloud
            %   /users/me endpoint: an array of OrganizationListItem structs,
            %   each with fields 'id', 'name' and 'canUploadDataset'. It may be
            %   a struct array (typical) or a cell array of scalar structs (as
            %   jsondecode sometimes returns); both are handled identically.
            %
            %   Returns three cell arrays, parallel to one another:
            %       ORGID        - organization IDs (char)
            %       ORGNAME      - organization names (char)
            %       ORGCANUPLOAD - upload permission per organization (logical)

            asChar = @(v) char(string(v));

            orgID = {};
            orgName = {};
            orgCanUpload = {};

            % Normalize to a cell array of scalar structs.
            orgList = {};
            if isstruct(orgs)
                for i = 1:numel(orgs)
                    orgList{end+1} = orgs(i); %#ok<AGROW>
                end
            elseif iscell(orgs)
                orgList = orgs;
            end

            for i = 1:numel(orgList)
                org = orgList{i};
                if ~isstruct(org)
                    continue;
                end
                if isfield(org, 'id')
                    orgID{end+1} = asChar(org.id); %#ok<AGROW>
                end
                if isfield(org, 'name')
                    orgName{end+1} = asChar(org.name); %#ok<AGROW>
                end
                if isfield(org, 'canUploadDataset')
                    orgCanUpload{end+1} = logical(org.canUploadDataset); %#ok<AGROW>
                end
            end
        end
    end
end
