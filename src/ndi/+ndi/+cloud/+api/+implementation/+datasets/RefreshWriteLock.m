classdef RefreshWriteLock < ndi.cloud.api.call
%REFRESHWRITELOCK Implementation class for refreshing a dataset write lock.

    methods
        function this = RefreshWriteLock(args)
            arguments
                args.cloudDatasetID (1,1) string
            end
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('refresh_write_lock', ...
                'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.PATCH;

            body = matlab.net.http.MessageBody('');

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

            originalWarnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningResetObj = onCleanup(@() warning(originalWarnState));

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
