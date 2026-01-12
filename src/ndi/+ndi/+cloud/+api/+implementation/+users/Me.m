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

                % Process organizations to create organizationID cell array
                if isfield(answer, 'organizations')
                    % Initialize as empty cell array
                    answer.organizationID = {};

                    orgs = answer.organizations;
                    if isstruct(orgs)
                        % If it's a struct array
                        if isfield(orgs, 'id')
                            % Extract IDs
                            for i = 1:numel(orgs)
                                val = orgs(i).id;
                                if isstring(val)
                                    val = char(val);
                                end
                                answer.organizationID{end+1} = val;
                            end
                        end
                    elseif iscell(orgs)
                        % If it's a cell array of structs (e.g. from jsondecode sometimes)
                        for i = 1:numel(orgs)
                            if isfield(orgs{i}, 'id')
                                val = orgs{i}.id;
                                if isstring(val)
                                    val = char(val);
                                end
                                answer.organizationID{end+1} = val;
                            end
                        end
                    end
                else
                    % If no organizations field, ensure organizationID exists as empty cell
                    answer.organizationID = {};
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
