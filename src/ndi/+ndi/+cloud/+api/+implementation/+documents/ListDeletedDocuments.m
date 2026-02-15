classdef ListDeletedDocuments < ndi.cloud.api.call
    %LISTDELETEDDOCUMENTS Implements the API call to list soft-deleted documents.

    methods
        function this = ListDeletedDocuments(args)
            %LISTDELETEDDOCUMENTS Creates a new ListDeletedDocuments API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.ListDeletedDocuments('cloudDatasetID', ID, 'page', 1, 'pageSize', 100)
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.page (1,1) double = 1
                args.pageSize (1,1) double = 100
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.page = args.page;
            this.pageSize = args.pageSize;
            this.endpointName = "list_deleted_documents";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to list deleted documents.

            method = matlab.net.http.RequestMethod.GET;

            auth_token = ndi.cloud.authenticate();
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiURL = ndi.cloud.api.url(this.endpointName, 'dataset_id', this.cloudDatasetID, 'page', this.page, 'pageSize', this.pageSize);

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
