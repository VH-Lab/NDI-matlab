classdef GetWriteLock < ndi.cloud.api.call
%GETWRITELOCK Implementation class for inspecting a dataset write lock.

    methods
        function this = GetWriteLock(args)
            arguments
                args.cloudDatasetID (1,1) string
            end
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('get_write_lock', ...
                'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.GET;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200
                b = true;
                answer = apiResponse.Body.Data;
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end
end
