classdef ListDeletedDatasets < ndi.cloud.api.call
    %LISTDELETEDDATASETS Implements the API call to list soft-deleted datasets.

    properties (Access = protected)
        page
        pageSize
    end

    methods
        function this = ListDeletedDatasets(args)
            %LISTDELETEDDATASETS Creates a new ListDeletedDatasets API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.ListDeletedDatasets('page', 1, 'pageSize', 20)
            %
            arguments
                args.page (1,1) double = 1
                args.pageSize (1,1) double = 20
            end

            this.page = args.page;
            this.pageSize = args.pageSize;
            this.endpointName = "list_deleted_datasets";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list deleted datasets.

            method = matlab.net.http.RequestMethod.GET;

            auth_token = ndi.cloud.authenticate();
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiURL = ndi.cloud.api.url(this.endpointName, 'page', this.page, 'pageSize', this.pageSize);

            apiResponse = request.send(apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
            else
                b = false;
                answer = apiResponse.Body.Data;
            end
        end
    end
end
