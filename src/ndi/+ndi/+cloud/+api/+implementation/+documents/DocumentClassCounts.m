classdef DocumentClassCounts < ndi.cloud.api.call
%DOCUMENTCLASSCOUNTS Implementation class for retrieving the document class-name histogram.

    methods
        function this = DocumentClassCounts(args)
            %DOCUMENTCLASSCOUNTS Creates a new DocumentClassCounts API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.DocumentClassCounts('cloudDatasetID', ID)
            %
            arguments
                args.cloudDatasetID (1,1) string
            end

            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get the document class counts.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('document_class_counts', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.GET;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end
