classdef ReleaseWriteLock < ndi.cloud.api.call
%RELEASEWRITELOCK Implementation class for releasing a dataset write lock.

    methods
        function this = ReleaseWriteLock(args)
            arguments
                args.cloudDatasetID (1,1) string
            end
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('release_write_lock', ...
                'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.DELETE;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200 || apiResponse.StatusCode == 204
                b = true;
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                end
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
