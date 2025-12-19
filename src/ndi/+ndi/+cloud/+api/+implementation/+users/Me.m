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

                % Process organizationID to ensure it is a cell array
                if isfield(answer, 'organizationID')
                    if ischar(answer.organizationID) || (isstring(answer.organizationID) && isscalar(answer.organizationID))
                         answer.organizationID = {char(answer.organizationID)};
                    elseif isstring(answer.organizationID)
                         answer.organizationID = cellstr(answer.organizationID);
                    elseif iscell(answer.organizationID)
                        % Make sure it is a cell array of character vectors (char)
                        for i = 1:numel(answer.organizationID)
                             if isstring(answer.organizationID{i})
                                 answer.organizationID{i} = char(answer.organizationID{i});
                             end
                        end
                    end
                end

                % Ensure id is a character array
                 if isfield(answer, 'id') && isstring(answer.id)
                     answer.id = char(answer.id);
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
