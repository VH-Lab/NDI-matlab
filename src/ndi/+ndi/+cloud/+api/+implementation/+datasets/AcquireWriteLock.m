classdef AcquireWriteLock < ndi.cloud.api.call
%ACQUIREWRITELOCK Implementation class for acquiring a dataset write lock.

    properties
        reason       (1,1) string = "did2-migration"
        ttlSeconds   (1,1) double = 0
    end

    methods
        function this = AcquireWriteLock(args)
            %ACQUIREWRITELOCK Creates a new AcquireWriteLock API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.AcquireWriteLock( ...
            %      'cloudDatasetID', ID, 'reason', REASON, 'ttlSeconds', TTL)
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.reason (1,1) string = "did2-migration"
                args.ttlSeconds (1,1) double = 0
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.reason = args.reason;
            this.ttlSeconds = args.ttlSeconds;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('acquire_write_lock', ...
                'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;

            payload = struct('reason', char(this.reason));
            if this.ttlSeconds > 0
                payload.ttlSeconds = this.ttlSeconds;
            end
            body = matlab.net.http.MessageBody(jsonencode(payload));

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201
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
