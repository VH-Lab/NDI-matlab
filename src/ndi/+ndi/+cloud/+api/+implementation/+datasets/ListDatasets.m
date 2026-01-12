classdef ListDatasets < ndi.cloud.api.call
%LISTDATASETS Implementation class for listing datasets in an organization.

    methods
        function this = ListDatasets(args)
            %LISTDATASETS Creates a new ListDatasets API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.ListDatasets(...)
            %
            %   Optional Inputs (Name-Value Pairs):
            %       'cloudOrganizationID' - The ID of the organization. If not
            %           provided, the environment variable NDI_CLOUD_ORGANIZATION_ID
            %           will be used.
            %
            arguments
                args.cloudOrganizationID (1,1) string = missing
            end
            
            this.cloudOrganizationID = args.cloudOrganizationID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list datasets.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - The datasets struct on success, or error message on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %
            
            % Initialize outputs
            b = false;
            answer = {};

            [token, org_id_env] = ndi.cloud.authenticate();
            
            organization_id = this.cloudOrganizationID;
            if ismissing(organization_id)
                organization_id = org_id_env;
            end
            
            apiURL = ndi.cloud.api.url('list_datasets', 'organization_id', organization_id);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;
                if isfield(apiResponse.Body.Data, 'datasets') && ~isempty(apiResponse.Body.Data.datasets)
                    answer = apiResponse.Body.Data.datasets;
                end
            else
                answer = {};
            end
        end
    end
end

