classdef CreateDataset < ndi.cloud.api.call
    %CREATEDATASET Implements the API call to create a new dataset.

    properties
        datasetInfoStruct % The struct defining the new dataset
    end

    methods
        function this = CreateDataset(args)
            % The arguments block for name-value pair validation
            arguments
                args.datasetInfoStruct (1,1) struct
            end
            
            this.datasetInfoStruct = args.datasetInfoStruct;
            this.endpointName = "create_dataset";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to create a new dataset.
            
            [~, organization_id] = ndi.cloud.authenticate();
            
            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(this.datasetInfoStruct);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            
            auth_token = ndi.cloud.authenticate();
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiURL = ndi.cloud.api.url(this.endpointName, 'organization_id', organization_id);
            
            apiResponse = request.send(apiURL);
            
            if (apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data.id;
            else
                b = false;
                answer = [];
            end
        end
    end
end


