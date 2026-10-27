classdef ListDatasets < ndi.cloud.api.call
%LISTDATASETS Implementation class for listing datasets in an organization.

    methods
        function this = ListDatasets(args)
            %LISTDATASETS Creates a new ListDatasets API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.ListDatasets(...)
            %
            %   Inputs (Name-Value Pairs):
            %       'cloudOrganizationID' - (required) The ID of the
            %           organization. To list across all of the user's
            %           organizations, use ndi.cloud.api.datasets.listDatasets
            %           without an organization.
            %       'page' - The page number to retrieve (default 1).
            %       'pageSize' - The number of datasets per page (default 20).
            %
            arguments
                args.cloudOrganizationID (1,1) string = missing
                args.page (1,1) double = 1
                args.pageSize (1,1) double = 20
            end
            
            if ismissing(args.cloudOrganizationID) || strlength(args.cloudOrganizationID) == 0
                error('NDI:Cloud:OrganizationRequired', ...
                    'ListDatasets requires a cloudOrganizationID.');
            end

            this.cloudOrganizationID = args.cloudOrganizationID;
            this.page = args.page;
            this.pageSize = args.pageSize;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list datasets.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - A struct with fields 'totalNumber', 'page',
            %                      'pageSize', and 'datasets' on success, or
            %                      an error struct on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %
            
            % Initialize outputs
            b = false;
            answer = {};

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('list_datasets', 'organization_id', this.cloudOrganizationID, ...
                'page', this.page, 'page_size', this.pageSize);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;

                % Parse the response body.
                % The API is expected to return:
                % {
                %   "totalNumber": integer,
                %   "page": integer,
                %   "pageSize": integer,
                %   "datasets": [...]
                % }

                if ~isempty(apiResponse.Body.Data)
                    answer = apiResponse.Body.Data;

                    % Ensure 'datasets' field is present and is a cell array (or appropriate type)
                    % If "datasets" is returned as a struct array by MATLAB's automatic JSON parsing,
                    % we might need to convert it or leave it as is depending on downstream expectations.
                    % But users expect a cell array of structs usually?
                    % The previous implementation returned `apiResponse.Body.Data.datasets` which
                    % could be a cell array or struct array.
                    % The user requirements say: "datasets": ["..."]

                    % If datasets is missing, default to empty list/cell
                    if ~isfield(answer, 'datasets')
                        answer.datasets = {};
                    end
                else
                     % Fallback if data is empty but status is 200 (unlikely for this schema)
                    answer = struct('totalNumber', 0, 'page', this.page, 'pageSize', this.pageSize, 'datasets', {{}});
                end
            else
                % On failure, we might want to return the error body or empty
                answer = apiResponse.Body.Data;
            end
        end
    end

end
