classdef CreateDataset < ndi.cloud.api.call
    %CREATEDATASET Implements the API call to create a new dataset.

    properties
        datasetInfoStruct % The struct defining the new dataset
    end

    methods
        function this = CreateDataset(args)
            %CREATEDATASET Creates a new CreateDataset API call object.
            %
            %   Inputs (Name-Value Pairs):
            %       'datasetInfoStruct'   - The struct defining the new dataset.
            %       'cloudOrganizationID' - (required) The ID of the
            %           organization in which to create the dataset. See
            %           ndi.cloud.internal.chooseOrganization.
            arguments
                args.datasetInfoStruct (1,1) struct
                args.cloudOrganizationID (1,1) string = missing
            end

            if ismissing(args.cloudOrganizationID) || strlength(args.cloudOrganizationID) == 0
                error('NDI:Cloud:OrganizationRequired', ...
                    'CreateDataset requires a cloudOrganizationID; see ndi.cloud.internal.chooseOrganization.');
            end
            
            this.datasetInfoStruct = args.datasetInfoStruct;
            this.cloudOrganizationID = args.cloudOrganizationID;
            this.endpointName = "create_dataset";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to create a new dataset.
            
            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(this.datasetInfoStruct);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            
            auth_token = ndi.cloud.authenticate();
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiURL = ndi.cloud.api.url(this.endpointName, 'organization_id', this.cloudOrganizationID);
            
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


