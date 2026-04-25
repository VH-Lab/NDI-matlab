classdef ListActiveBulkUploads < ndi.cloud.api.call
%LISTACTIVEBULKUPLOADS Implementation for GET /datasets/{id}/bulk-uploads.
%
%   Returns the bulk upload jobs for a dataset. The server accepts a
%   `state` query parameter to filter by lifecycle state
%   ('active' (default), 'all', 'queued', 'extracting', 'complete',
%   'failed').

    properties
        state (1,1) string
    end

    methods
        function this = ListActiveBulkUploads(args)
            %LISTACTIVEBULKUPLOADS Creates a new ListActiveBulkUploads call.
            arguments
                args.cloudDatasetID (1,1) string
                args.state (1,1) string = "active"
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.state = args.state;
            this.endpointName = 'list_dataset_bulk_uploads';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('list_dataset_bulk_uploads', ...
                'dataset_id', this.cloudDatasetID, ...
                'state', this.state);

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
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end
end
