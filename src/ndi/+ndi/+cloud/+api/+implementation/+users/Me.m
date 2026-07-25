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
                % arrays. Each organization is an OrganizationListItem with
                % fields 'id', 'name' and 'canUploadDataset' (see the NDI Cloud
                % API definition of UserWithOrganizations). The raw
                % 'organizations' field is left untouched for callers that want
                % the full structs.
                asChar = @(v) char(string(v));

                answer.organizationID = {};
                answer.organizationName = {};
                answer.organizationCanUploadDataset = {};

                if isfield(answer, 'organizations')
                    orgs = answer.organizations;

                    % Normalize to a cell array of scalar structs so that a
                    % struct array (typical) and a cell array of structs (as
                    % jsondecode sometimes returns) are handled identically.
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
                            answer.organizationID{end+1} = asChar(org.id);
                        end
                        if isfield(org, 'name')
                            answer.organizationName{end+1} = asChar(org.name);
                        end
                        if isfield(org, 'canUploadDataset')
                            answer.organizationCanUploadDataset{end+1} = ...
                                logical(org.canUploadDataset);
                        end
                    end
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
end
