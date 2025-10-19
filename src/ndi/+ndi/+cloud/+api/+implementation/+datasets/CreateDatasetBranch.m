classdef CreateDatasetBranch < ndi.cloud.api.call
    %CREATEDATASETBRANCH Implements the API call to branch a dataset.

    methods
        function this = CreateDatasetBranch(args)
            % The arguments block for name-value pair validation
            arguments
                args.cloudDatasetID (1,1) string
                args.branchName (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.branchName = args.branchName;
            this.endpointName = "create_dataset_branch";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to create a dataset branch.
            
            json = struct('branchName', this.branchName);
            
            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(json);

            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
            
            auth_token = ndi.cloud.authenticate();
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiURL = ndi.cloud.api.url(this.endpointName, 'dataset_id', this.cloudDatasetID);
            
            apiResponse = request.send(apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
            else
                b = false;
                answer = [];
            end
        end
    end
end


